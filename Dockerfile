FROM kappnav/base-runtime:8-jre-ubi-min-alt2 as liberty
ARG LIBERTY_VERSION=19.0.0.12
ARG LIBERTY_SHA=b3a613cbad764a10ae57719ff9818c3bcfefdf8e
ARG LIBERTY_DOWNLOAD_URL=https://repo1.maven.org/maven2/io/openliberty/openliberty-runtime/$LIBERTY_VERSION/openliberty-runtime-$LIBERTY_VERSION.zip

LABEL maintainer="Arthur De Magalhaes" vendor="Open Liberty" url="https://openliberty.io/" github="https://github.com/OpenLiberty/ci.docker"

COPY apis/helpers /opt/ol/helpers

# Install Open Liberty

RUN microdnf -y install shadow-utils wget unzip \
    && wget -q $LIBERTY_DOWNLOAD_URL -U UA-Open-Liberty-Docker -O /tmp/wlp.zip \
    && echo "$LIBERTY_SHA  /tmp/wlp.zip" > /tmp/wlp.zip.sha1 \
    && sha1sum -c /tmp/wlp.zip.sha1 \
    && unzip -q /tmp/wlp.zip -d /opt/ol \
    && rm /tmp/wlp.zip \
    && rm /tmp/wlp.zip.sha1 \
    && adduser -u 1001 -r -g root -s /usr/sbin/nologin default \
    && microdnf -y remove shadow-utils wget unzip \
    && microdnf clean all \
    && chown -R 1001:0 /opt/ol/wlp \
    && chmod -R g+rw /opt/ol/wlp

# Set Path Shortcuts
ENV PATH=/opt/ol/wlp/bin:/opt/ol/docker/:/opt/ol/helpers/build:$PATH \
    LOG_DIR=/logs \
    WLP_OUTPUT_DIR=/opt/ol/wlp/output \
    WLP_SKIP_MAXPERMSIZE=true

# Configure WebSphere Liberty
RUN /opt/ol/wlp/bin/server create \
    && rm -rf $WLP_OUTPUT_DIR/.classCache /output/workarea


# Create symlinks && set permissions for non-root user
RUN mkdir /logs \
    && mkdir -p /opt/ol/wlp/usr/shared/resources/lib.index.cache \
    && ln -s /opt/ol/wlp/usr/shared/resources/lib.index.cache /lib.index.cache \
    && mkdir -p $WLP_OUTPUT_DIR/defaultServer \
    && ln -s $WLP_OUTPUT_DIR/defaultServer /output \
    && ln -s /opt/ol/wlp/usr/servers/defaultServer /config \
    && mkdir -p /config/configDropins/defaults \
    && mkdir -p /config/configDropins/overrides \
    && ln -s /opt/ol/wlp /liberty \
    && chown -R 1001:0 /config \
    && chmod -R g+rw /config \
    && chown -R 1001:0 /logs \
    && chmod -R g+rw /logs \
    && chown -R 1001:0 /opt/ol/wlp/usr \
    && chmod -R g+rw /opt/ol/wlp/usr \
    && chown -R 1001:0 /opt/ol/wlp/output \
    && chmod -R g+rw /opt/ol/wlp/output \
    && chown -R 1001:0 /opt/ol/helpers \
    && chmod -R g+rw /opt/ol/helpers \
    && mkdir /etc/wlp \
    && chown -R 1001:0 /etc/wlp \
    && chmod -R g+rw /etc/wlp \
    && echo "<server description=\"Default Server\"><httpEndpoint id=\"defaultHttpEndpoint\" host=\"*\" /></server>" > /config/configDropins/defaults/open-default-port.xml


#These settings are needed so that we can run as a different user than 1001 after server warmup
ENV RANDFILE=/tmp/.rnd \
    IBM_JAVA_OPTIONS="-Xshareclasses:name=liberty,nonfatal,cacheDir=/output/.classCache/ ${IBM_JAVA_OPTIONS}"

USER 1001

EXPOSE 9080 9443

ENV KEYSTORE_REQUIRED true

ENTRYPOINT ["/opt/ol/helpers/runtime/docker-server.sh"]

FROM maven:3.6.1-ibmjava-8 as builder
COPY apis/src /src
COPY apis/pom.xml /
RUN mvn install

FROM liberty

ARG VERSION
ARG BUILD_DATE
ARG COMMIT

LABEL name="Application Navigator" \
      vendor="kAppNav" \
      version=$VERSION \
      release=$VERSION \
      created=$BUILD_DATE \
      commit=$COMMIT \
      summary="Inventory image for Application Navigator" \
      description="This image contains the inventory commands action for Application Navigator"

COPY --from=builder --chown=1001:0 /target/liberty/wlp/usr/servers/defaultServer /config/

COPY --chown=1001:0 licenses/ /licenses/

USER root

ENV NODE_VERSION 8.11.4

ENV YARN_VERSION 1.13.0

# Install node
RUN microdnf update -y \
  && microdnf -y install shadow-utils tar xz gzip \
#  && useradd --uid 1001 --gid 0 --shell /bin/bash --create-home node \
  && ARCH=$(uname -p) \
   && if [ "$ARCH" != "ppc64le" ] && [ "$ARCH" != "s390x" ]; then \
     ARCH="x64" ; \
  fi \
  # gpg keys listed at https://github.com/nodejs/node#release-keys
  && set -ex \
  && for key in \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
  && set -ex \
  && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && microdnf remove -y shadow-utils tar xz gzip \
  && microdnf clean all

RUN microdnf install -y yum \
    && yum update -y \
    && microdnf remove yum

# Make the home dir writeable so that kubectl can use it for its cache.
RUN mkdir /home/default \
    && chown -R 1001:0 /home/default \
    && chmod -R g+rw /home/default

RUN  ARCH=$(uname -p) \
   && if [ "$ARCH" != "ppc64le" ] && [ "$ARCH" != "s390x" ]; then \
     ARCH="amd64" ; \
   fi \
   && curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/${ARCH}/kubectl \
   && chmod ug+x ./kubectl \
   && mv ./kubectl /usr/local/bin/kubectl

COPY --chown=1001:0 tool/ /tool/
WORKDIR /tool 
RUN npm install 

USER 1001

CMD ["./inventory.sh"]

#!/bin/bash

#*****************************************************************
#*
#* Copyright 2020 IBM Corporation
#*
#* Licensed under the Apache License, Version 2.0 (the "License");
#* you may not use this file except in compliance with the License.
#* You may obtain a copy of the License at

#* http://www.apache.org/licenses/LICENSE-2.0
#* Unless required by applicable law or agreed to in writing, software
#* distributed under the License is distributed on an "AS IS" BASIS,
#* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#* See the License for the specific language governing permissions and
#* limitations under the License.
#*
#*****************************************************************
# Usage:  set environment variable KAPPNAV_NAMESPACE to specify
#         the namespace value. Default is kappnav.
#
echo Begin kAppNav inventory ...
echo 

# get kappnav namespace
if [ x$KAPPNAV_NAMESPACE = 'x' ]; then
	namespace=kappnav
else
	namespace=$KAPPNAV_NAMESPACE
fi

date
server start 

echo 'App Navigator resources in '$namespace' namespace:'
echo 

kubectl get -n $namespace all 
echo 

# get pods and print images 

echo 'App Navigators Pods and Images:'
echo

kubectl get -n $namespace pods | awk '{ print $1 }' | while read p; do 
	if [ $p != NAME  ]; then 
		echo pod=$p 
		for i in $(kubectl get -n $namespace pod $p -o jsonpath='{.spec.containers[*].image}'); do
			echo '   '$i
		done
		echo 
	fi 
done

echo Searching for applications 
echo 

while true; do 

	curl http://localhost:9080/kappnav/applications 2>/dev/null > apps.json

	str=$(cat apps.json)

	if [ x${str:0:1} == x"{" ]; then
		echo Received application data from API server
        	break 
	else
		echo API server did not return application data
        	echo sleep and try again ... 
        	sleep 1 
	fi

done

cat apps.json | node ./js/apps.js | tr ":" " " | while read namespace name; do 
	echo Application $name, namespace $namespace
	curl http://localhost:9080/kappnav/components/$name?namespace=$namespace 2>/dev/null > comps.json 
	echo "  " Components: 
	cat comps.json | node ./js/comps.js | tr ":" " " | while read ns kind n; do 
		echo "    " kind=$kind, name=$n, namespace=$ns
	done 
        rm comps.json  
done 
rm apps.json 
echo 

server stop
date
echo ... kAppNav inventory done. 
exit 0

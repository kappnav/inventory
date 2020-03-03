const yaml = require('js-yaml');
const getStdin = require('get-stdin');

(async () => {
    	var stdin= await getStdin(); 

	var json= JSON.parse(stdin); 

	json.applications.forEach( (item) => { 
                var name= item.application.metadata.name
                var namespace= item.application.metadata.namespace
		console.log(namespace+":"+name) 
        } )

})();

const yaml = require('js-yaml');
const getStdin = require('get-stdin');

(async () => {
    	var stdin= await getStdin(); 

	var json= JSON.parse(stdin); 

	json.components.forEach( (item) => { 
                var name= item.component.metadata.name
                var namespace= item.component.metadata.namespace
                var kind= item.component.kind
		console.log(namespace+":"+kind+":"+name) 
        } )

})();

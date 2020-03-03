const yaml = require('js-yaml');
const getStdin = require('get-stdin');

(async () => {
    	var stdin= await getStdin(); 

	var json= JSON.parse(stdin); 

	json.items.forEach( (item) => { 
                var name= item.metadata.name
                var namespace= item.metadata.namespace
		console.log(namespace+":"+name) 
        } )

})();

const yaml = require('js-yaml');
const getStdin = require('get-stdin');

var padding=process.argv[2]; 

(async () => {
    	var stdin= await getStdin(); 
	var json= JSON.parse(stdin); 
	json.items.forEach( (item) => { 
                var name= item.metadata.name
		console.log(padding+name) 
        } )
})();

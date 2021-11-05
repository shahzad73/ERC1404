//const ERC1404 = artifacts.require("ERC1404Token");
//var ERC20 = artifacts.require("ERC20Token");

var ERC1404TokenMin = artifacts.require("ERC1404TokenMin");

module.exports = function (deployer) {	
	 var _tokenToMintAddress = "0xAD3DF0f1c421002B8Eff81288146AF9bC692d13d";
	 let _initialSupply = "1000000000000000000000000";
	
	
	 //var _name = "E1404"
	 //deployer.deploy(ERC1404, _tokenToMintAddress, _initialSupply, _name);
	
	 //_name = "E20"
	 //deployer.deploy(ERC20, _tokenToMintAddress, _initialSupply, _name);	
	
		
	 var _name = "ER14"
	 deployer.deploy(ERC1404TokenMin, _initialSupply, _name, _name, 5);
	
	
};





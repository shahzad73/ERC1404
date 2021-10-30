const ERC1404 = artifacts.require("ERC1404");
var ERC20Token = artifacts.require("ERC20Token");


module.exports = function (deployer) {	
	 var _tokenToMintAddress = "0xAD3DF0f1c421002B8Eff81288146AF9bC692d13d";
	 let _initialSupply = "100000000000000000000000";
	
	
	 var _name = "E1404"
	 deployer.deploy(ERC1404, _tokenToMintAddress, _initialSupply, _name);
	
	 _name = "E20"
	 deployer.deploy(ERC20Token, _tokenToMintAddress, _initialSupply, _name);	
	
};





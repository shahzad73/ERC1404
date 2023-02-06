//const ERC1404 = artifacts.require("ERC1404Token");
var ERC20 = artifacts.require("ERC20Token");
//var ERC1404TokenMinKYC = artifacts.require("ERC1404TokenMinKYC");
//var Swaper = artifacts.require("TokenSwapper")

module.exports = function (deployer) {	
	 var _tokenToMintAddress = "0xAD3DF0f1c421002B8Eff81288146AF9bC692d13d";
	 let _initialSupply = "100000000000000000000000";
	
	 //var _name = "E1404"
	 //deployer.deploy(ERC1404, _tokenToMintAddress, _initialSupply, _name);
	
	 _name = "USDCtest"
	 deployer.deploy(ERC20, _tokenToMintAddress, _initialSupply, _name);	

	 //deployer.deploy(Swaper);	
		
	 //var _name = "EK14"
	 //deployer.deploy(ERC1404TokenMinKYC, _initialSupply, _name, _name, 5, 18, "ShareCertificate", "CompanyHomepage", "CompanyLegalDocs");

};

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC1404.sol";

contract ERC20Token is ERC20, Ownable {

	constructor(address _tokenToMintAddress, uint256 _initialSupply, string memory _name ) ERC20(_name, _name) {

			_mint(_tokenToMintAddress , _initialSupply);

	}


    function mint (address to, uint256 amount)		
        external        
		onlyOwner
        returns (bool)
    {
		 super._mint(to, amount);
		 return true;
    }


    function burn (address to, uint256 amount)
		external     
		onlyOwner   
        returns (bool)
    {
		 super._burn(to, amount);
		 return true;
    }


}

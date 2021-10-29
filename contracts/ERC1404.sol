// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC1404.sol";


contract ERC1404 is IERC1404, ERC20, Ownable {

    mapping (address => bool) internal whitelisted;  
	
	uint8 SUCCESS_CODE = 1;
	uint8 FAILURE_CODE = 0;	

	constructor(address _tokenToMintAddress, uint256 _initialSupply, string memory _name ) ERC20(_name, _name) {
			_mint(_tokenToMintAddress , _initialSupply);
			whitelisted[msg.sender] = true;
	}

	  function addWhitelistAddress (address user) 
	  public 
	  onlyOwner 
	   returns (bool){ 
		  whitelisted[user] = true; 
		  return true;
	  }
	  
	  function removeWhitelistAddress (address user) 
	  public 
	  onlyOwner
	  returns (bool){ 
		  delete whitelisted[user];
		  return true;
	  }
	  
	  function isInvestorWhiteListed(address user) 
	  public 
	  view
	  returns (bool) {
		   return whitelisted[user]; 
	  }
	  

    modifier notRestricted (address from, address to, uint256 value) {
        uint8 restrictionCode = detectTransferRestriction(from, to, value);
        require(restrictionCode == SUCCESS_CODE, messageForTransferRestriction(restrictionCode));
        _;
    }


    function detectTransferRestriction (address _from, address _to, uint256 value) 
	public 
	override
	view 
	returns (uint8)
    {
		  if (whitelisted[_to])
		  {
			 if (whitelisted[_from]) 
				return SUCCESS_CODE;
			 else
				return FAILURE_CODE;
		  } else
			  return FAILURE_CODE;
    }


    function messageForTransferRestriction (uint8 restrictionCode)
    public
	override	
    view
    returns (string memory message)
    {
        if (restrictionCode == SUCCESS_CODE) {
            message = "Address is Whitelisted";
        } else if (restrictionCode == FAILURE_CODE) {
            message = "Address is not Whitelisted";
        }
    }



    function transfer (address to, uint256 value)
		override
		notRestricted (msg.sender, to, value)
        public        
        returns (bool)
    {
		 super.transfer(to, value);
		 return true;
    }



    function  transferFrom (address from, address to, uint256 value)
		override
		notRestricted (from, to, value)
        public
        returns (bool)
    {
		super.transferFrom(from, to, value);
		return true;
    }
	

}
 
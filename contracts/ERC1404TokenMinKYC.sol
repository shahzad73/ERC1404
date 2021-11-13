// SPDX-License-Identifier: MIT
// This contract is minimum implementation of ERC1404 protocol without any libraries 
pragma solidity ^0.8.0;

import "./IERC1404.sol";
import "./SafeMathMin.sol";

contract ERC1404TokenMinKYC is IERC1404 {

    using SafeMathMin for uint256;
	
	// Set buy and sell restrictions on investors.  
	// date is Linux Epoch datetime
	// Both date must be less than current date time to allow the respective operation. Like to get tokens from others, receiver's buy restriction
	// must be less than current date time. 
	// 0 means investor is not allowed to buy or sell his token.  0 indicates buyer or seller is not whitelisted. 
	// this condition is checked in detectTransferRestriction
    mapping (address => uint256) private _buyRestriction;  
	mapping (address => uint256) private _sellRestriction;	
	
	mapping (address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
	address private _owner;
	
	// These addresses can control addresses that can manage whitelisting of investor or in otherwords can call modifyKYCData
    mapping (address => bool) private _whitelistControlAuthority;  	
	

    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    event Transfer(address indexed from, address indexed to, uint tokens);

	uint256 public decimals = 18;
    uint256 public totalSupply;
    string public name;
    string public symbol;
	
	// These variables control how many investors can have tokens
	// if allowedInvestors = 0 then there is no limit of investors 
	uint256 public currentTotalInvestors = 0;		
	uint256 public allowedInvestors = 0;

	// If overall Trnasfers allowed or not     1=Normal Transfers     2=Stop all Transfers 
	uint256 public isTradingAllowed = 1;
	
	string private constant AddressZeroMessage = "Zero Address";
	string private constant AmountExceedBalance = "Amount > Balance";	
	string private constant NotWhitelisted = "Not Whitelisted";


	constructor(uint256 _initialSupply, string memory _name,  string memory _symbol, uint256 _allowedInvestors, uint256 _decimals ) {
		name = _name;
        symbol = _symbol;
		
		decimals = _decimals;

		_buyRestriction[msg.sender] = 1;
		_sellRestriction[msg.sender] = 1;
		_owner = msg.sender;

		allowedInvestors = _allowedInvestors;

		// Minting tokens for initial supply
        totalSupply = _initialSupply;
        _balances[msg.sender] = totalSupply;
		
		// add message sender to whitelist authority list
		_whitelistControlAuthority[msg.sender] = true;
				
		emit Transfer(address(0), msg.sender, totalSupply);
	}


	// _allowedInvestors = 0    No limit on number of investors        
	// _allowedInvestors > 0 only X number of investors can have positive balance 
    function resetAllowedInvestors(uint256 _allowedInvestors) 
	public 
	onlyOwner {
		 allowedInvestors = _allowedInvestors;
    }


	// 1 = Tading Allowed
	// 2 = Stop all Transfers 
    function setTradingEnabled(uint256 _isTradingAllowed) 
	public 
	onlyOwner {
		 isTradingAllowed = _isTradingAllowed;
    }
 
 
	//-----------------------------------------------------------------------
	// Get or set current owner of this smart contract
    function owner() 
	public 
	view 
	returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(_owner == msg.sender, "Not Owner");
        _;
    }
    function transferOwnership(address newOwner) 
	public 
	onlyOwner {
        require(newOwner != address(0), AddressZeroMessage);
		_owner = newOwner;
    }
	//-----------------------------------------------------------------------
	
  
  

	  


	  
 
	//-----------------------------------------------------------------------
    // Manage whitelist autority and KYC status
	
	function setWhitelistAuthorityStatus(address user)
	public 
	onlyOwner {
		_whitelistControlAuthority[user] = true;
	}
	function removeWhitelistAuthorityStatus(address user)
	public 
	onlyOwner {
		delete _whitelistControlAuthority[user];
	}	
	function getWhitelistAuthorityStatus(address user)
	public 
	view
	returns (bool) {
		 return _whitelistControlAuthority[user];
	}	
	
	
  	  // Set buy and sell restrictions on investors 
	  function modifyKYCData (address user, uint256 buyRestriction, uint256 sellRestriction) 
	  public 
	  { 
	  	    require(_whitelistControlAuthority[msg.sender] == true, "Not Whitelist Authority");
			
		   _buyRestriction[user] = buyRestriction;
		   _sellRestriction[user] = sellRestriction;
	  }
	  	  
	  function getKYCData(address user) 
	  public 
	  view
	  returns (uint256, uint256 ) {
		   return (_buyRestriction[user] , _sellRestriction[user] );
	  }
	//-----------------------------------------------------------------------





	//-----------------------------------------------------------------------
	// These are ERC1404 interface implementations 
	
    modifier notRestricted (address from, address to, uint256 value) {
        uint8 restrictionCode = detectTransferRestriction(from, to, value);
        require(restrictionCode == 1, messageForTransferRestriction(restrictionCode));
        _;
    }
	
    function detectTransferRestriction (address _from, address _to, uint256 value) 
	override
	public 
	view 
	returns (uint8)
    {
	      // check if trading is allowed 
		  require(isTradingAllowed == 1, "Transfer not allowed"); 		  			  
		  require(  _sellRestriction[_from] != 0 && _sellRestriction[_from] < block.timestamp, NotWhitelisted  );
		  require(  _buyRestriction[_to] != 0 && _buyRestriction[_to] < block.timestamp, NotWhitelisted  );

			// Following conditions make sure if number of token holders are within limit if enabled 
			// 0 means no restriction
			if(allowedInvestors == 0)
				return 1;
			else {
				if( _balances[_to] > 0 ) 
					return 1;
				else {
					if(  currentTotalInvestors < allowedInvestors  )
						return 1;
					else
						return 0;
				}
			}
    }

    function messageForTransferRestriction (uint8 restrictionCode)
	override
    public	
    pure returns (string memory message)
    {
        if (restrictionCode == 1) 
            message = "Whitelisted";
         else 
            message = NotWhitelisted;
    }
	//-----------------------------------------------------------------------






    function balanceOf(address account) 
    public 
    view 
    returns (uint256) {
        return _balances[account];
    }
	

    function transfer(
        address recipient,
        uint256 amount
    ) 	
	public 
	notRestricted (msg.sender, recipient, amount)
	{
        require(recipient != address(0), AddressZeroMessage);
        require(_balances[msg.sender] >= amount, AmountExceedBalance);

		transferSharesBetweenInvestors ( msg.sender, recipient, amount );
		
        emit Transfer(msg.sender, recipient, amount);
    }



    function approve(
        address spender,
        uint256 amount
    ) public {
        require(spender != address(0), AddressZeroMessage);
		require(amount > 0, "Amount 0");

        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
    }


    function allowance(address owner, address spender) 
	public 
	view 
	returns (uint256) {
        return _allowances[owner][spender];
    }	


    function transferFrom(
        address owner,
        address recipient,
        uint256 amount
    ) 
	public 
	notRestricted (owner, recipient, amount)
	{	
        require(_balances[owner] >= amount, AmountExceedBalance);
        require(_allowances[owner][msg.sender] >= amount, AmountExceedBalance );

		transferSharesBetweenInvestors ( owner, recipient, amount );
        _allowances[owner][msg.sender] = _allowances[owner][msg.sender].sub(amount);

        emit Transfer(owner, recipient, amount);	
    }


	// Transfer tokens from one account to other
	// Also manage current number of account holders
	function transferSharesBetweenInvestors(
        address sender,
        address recipient,
        uint256 amount	
	)
	internal
	{
			_balances[sender] = _balances[sender].sub(amount);
			if( _balances[sender] == 0 )
				currentTotalInvestors = currentTotalInvestors - 1;		

			if( _balances[recipient] == 0 )
				currentTotalInvestors = currentTotalInvestors + 1;
			_balances[recipient] = _balances[recipient].add(amount);
	}



    function mint(address account, uint256 amount) 
	onlyOwner 
	public {
        require(account != address(0), AddressZeroMessage);

        totalSupply = totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }


    function burn(address account, uint256 amount) 
	onlyOwner
	public {
        require(account != address(0), AddressZeroMessage);
        require(_balances[account] >= amount, AmountExceedBalance);

        totalSupply = totalSupply.sub(amount);
        _balances[account] = _balances[account].sub(amount);

        emit Transfer(account, address(0), amount);
    }

}
 




// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// This contract is minimum implementation of ERC1404 protocol without any libraries 

import "./IERC20Token.sol";
import "./IERC1404.sol";

contract ERC1404TokenMinKYCv12 is IERC20Token, IERC1404 {
	
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


	// These events are defined in IERC20Token.sol
    // event Approval(address indexed tokenOwner, address indexed spender, uint256 tokens);
    // event Transfer(address indexed from, address indexed to, uint256 tokens);
	
	// ERC20 related functions
	uint256 public decimals = 18;
	string public version = "1.1";
	string public IssuancePlatform = "DigiShares";
	string public issuanceProtocol = "ERC-1404";
    uint256 private _totalSupply;
    string public name;
    string public symbol;
	
	// Custom functions
	string public ShareCertificate;
	string public CompanyHomepage;
	string public CompanyLegalDocs;


	// These variables control how many investors can have tokens
	// if allowedInvestors = 0 then there is no limit of investors 
	uint256 public currentTotalInvestors = 0;		
	uint256 public allowedInvestors = 0;

	// Transfer Allowed = true
	// Transfer not allowed = false
	bool public isTradingAllowed = true;
	
	
	constructor(uint256 _initialSupply, string memory _name,  string memory _symbol, uint256 _allowedInvestors, uint256 _decimals, string memory _ShareCertificate, string memory _CompanyHomepage, string memory _CompanyLegalDocs, address _atomicSwapContractAddress ) {

			name = _name;
			symbol = _symbol;

			decimals = _decimals;

			_owner = msg.sender;
			_buyRestriction[_owner] = 1;
			_sellRestriction[_owner] = 1;
			_buyRestriction[_atomicSwapContractAddress] = 1;
			_sellRestriction[_atomicSwapContractAddress] = 1;


			allowedInvestors = _allowedInvestors;

			// Minting tokens for initial supply
			_totalSupply = _initialSupply;
			_balances[_owner] = _totalSupply;

			// add message sender to whitelist authority list
			_whitelistControlAuthority[_owner] = true;

			ShareCertificate = _ShareCertificate;
			CompanyHomepage = _CompanyHomepage;
			CompanyLegalDocs = _CompanyLegalDocs;

			emit Transfer(address(0), _owner, _totalSupply);

	}



    function resetShareCertificate(string memory _ShareCertificate) 
	external 
	onlyOwner {
		 ShareCertificate = _ShareCertificate;
    }

    function resetCompanyHomepage(string memory _CompanyHomepage) 
	external 
	onlyOwner {
		 CompanyHomepage = _CompanyHomepage;
    }
	
    function resetCompanyLegalDocs(string memory _CompanyLegalDocs) 
	external 
	onlyOwner {
		 CompanyLegalDocs = _CompanyLegalDocs;
    }




	// _allowedInvestors = 0    No limit on number of investors        
	// _allowedInvestors > 0 only X number of investors can have positive balance 
    function resetAllowedInvestors(uint256 _allowedInvestors) 
	external 
	onlyOwner {
		if( _allowedInvestors != 0 )
			require(_allowedInvestors >= currentTotalInvestors, "Allowed Investors cannot be less than Current holders");

		allowedInvestors = _allowedInvestors;
    }


    function flipTradingStatus() 
	external 
	onlyOwner {
		 isTradingAllowed = !isTradingAllowed;
    }


	//-----------------------------------------------------------------------
	// Get or set current owner of this smart contract
    function owner() 
	external 
	view 
	returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(_owner == msg.sender, "Only owner can call function");
        _;
    }
    function transferOwnership(address newOwner) 
	external 
	onlyOwner {
        require(newOwner != address(0), "Zero address not allowed");
		_owner = newOwner;
    }
	//-----------------------------------------------------------------------
	
  
  

	  


	  
 
	//-----------------------------------------------------------------------
    // Manage whitelist autority and KYC status
	
	function setWhitelistAuthorityStatus(address user)
	external 
	onlyOwner {
		_whitelistControlAuthority[user] = true;
	}
	function removeWhitelistAuthorityStatus(address user)
	external 
	onlyOwner {
		delete _whitelistControlAuthority[user];
	}	
	function getWhitelistAuthorityStatus(address user)
	external 
	view
	returns (bool) {
		 return _whitelistControlAuthority[user];
	}	
	

  	// Set buy and sell restrictions on investors 
	function modifyKYCData (
		address user, 
		uint256 buyRestriction, 
		uint256 sellRestriction 
	) 
	external 
	{ 
	  	require(_whitelistControlAuthority[msg.sender] == true, "Not Whitelist Authority");
		setupKYCDataForUser( user, buyRestriction, sellRestriction );
	}

	function bulkWhitelistWallets (
		address[] memory user, 
		uint256 buyRestriction, 
		uint256 sellRestriction 
	) 
	external 
	{ 
		require(_whitelistControlAuthority[msg.sender] == true, "Not Whitelist Authority");
		for (uint i=0; i<user.length; i++) {
			setupKYCDataForUser( user[i], buyRestriction, sellRestriction );			
		}		
	}

	function setupKYCDataForUser (
		address user, 
		uint256 buyRestriction, 
		uint256 sellRestriction
	)
	internal
	{
		_buyRestriction[user] = buyRestriction;
		_sellRestriction[user] = sellRestriction;
	}




	function getKYCData(address user) 
	external 
	view
	returns (uint256, uint256 ) {
		   return (_buyRestriction[user] , _sellRestriction[user] );
	}
	//-----------------------------------------------------------------------



	//-----------------------------------------------------------------------
	// These are ERC1404 interface implementations 
	
    modifier notRestricted (address from, address to, uint256 value) {
        uint256 restrictionCode = detectTransferRestriction(from, to, value);
        require(restrictionCode == 0, messageForTransferRestriction(restrictionCode));
        _;
    }


    function detectTransferRestriction (address _from, address _to, uint256 value) 
	override
	public 
	view 
	returns (uint256 status)
    {	
	      	// check if trading is allowed 
		  	if(isTradingAllowed == false)
			 	return 2;   

		  	if( value <= 0)
		  	  	return 3;   
		  
		  	if( _sellRestriction[_from] == 0 )
				return 4;   // Sender is not whitelisted or blocked

		  	if( _buyRestriction[_to] == 0 )
				return 5;	// Receiver is not whitelisted or blocked

			if( _sellRestriction[_from] > block.timestamp )
				return 6;	// Receiver is whitelisted but is not eligible to send tokens and still under holding period (KYC time restriction)

			if( _buyRestriction[_to] > block.timestamp )
				return 7;	// Receiver is whitelisted but is not yet eligible to receive tokens in his wallet (KYC time restriction)


			// Following conditions make sure if number of token holders are within limit if enabled
			// allowedInvestors = 0 means no restriction on number of token holders and is the default setting
			if(allowedInvestors == 0)
				return 0;
			else {
				if( _balances[_to] > 0 || _to == _owner) 
					// token can be transferred if the receiver alreay holding tokens and already counted in currentTotalInvestors
					// or receiver is issuer account. issuer account do not count in currentTotalInvestors
					return 0;
				else {
					if(  currentTotalInvestors < allowedInvestors  )
						// currentTotalInvestors is within limits of allowedInvestors
						return 0;
					else {
						// In this section currentTotalInvestors = allowedInvestors and no more transfers to new investors are allowed
						// except following conditions 
						// 1. sender is sending his whole balance to anohter whitelisted investor regardless he has any balance or not
						// 2. sender must not be owner/isser
						//    owner sending his whole balance to investor will exceed allowedInvestors restriction if currentTotalInvestors = allowedInvestors
						if( _balances[_from] == value && _from != _owner)    
							return 0;
						else
							return 1;
					}
				}
			}
    }

    function messageForTransferRestriction (uint256 restrictionCode)
	override
    public	
    pure 
	returns (string memory message)
    {
        if (restrictionCode == 0) 
            message = "No transfer restrictions found";
        else if (restrictionCode == 1) 
            message = "Max allowed investor restriction is in place, this token transfer will exceed this limitation";
        else if (restrictionCode == 2) 
            message = "Transfers are disabled by issuer";
        else if (restrictionCode == 3) 
            message = "Value bring transferred cannot be 0";
        else if (restrictionCode == 4) 
            message = "Sender is not whitelisted or blocked";
        else if (restrictionCode == 5) 
            message = "Receiver is not whitelisted or blocked";
        else if (restrictionCode == 6) 
            message = "Sender is whitelisted but is not eligible to send tokens and still under holding period (KYC time restriction)";
        else if (restrictionCode == 7) 
            message = "Receiver is whitelisted but is not yet eligible to receive tokens in his wallet (KYC time restriction)";			
		else
			message = "Error code is not yet defined";
    }
	//-----------------------------------------------------------------------




 	function totalSupply() 
	override
	external 
	view 
	returns (uint256) {
		return _totalSupply;
	}


    function balanceOf(address account) 
	override
    external 
    view 
    returns (uint256) {
        return _balances[account];
    }
	


    function approve(
        address spender,
        uint256 amount
    )  
	override
	external 
	returns (bool)
	{
        require(spender != address(0), "Zero address not allowed");
		require(amount > 0, "Amount cannot be 0");

        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
		return true;
    }


 
    function allowance(address ownby, address spender) 
	override
	external 
	view 
	returns (uint256) {
        return _allowances[ownby][spender];
    }



    function transfer(
        address recipient,
        uint256 amount
    ) 	
	override
	external 
	notRestricted (msg.sender, recipient, amount)
	returns (bool)
	{
		transferSharesBetweenInvestors ( msg.sender, recipient, amount );
		return true;
    }


    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) 
	override
	external 
	notRestricted (sender, recipient, amount)
	returns (bool)	
	{	
        require(_allowances[sender][msg.sender] >= amount, "Amount cannot be greater than Allowance" );
		transferSharesBetweenInvestors ( sender, recipient, amount );
        _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;

		return true;
    }


	// Force transfer of tokens
	function forceTransferToken(
        address from,
        uint256 amount
	)
	onlyOwner
	external 
	returns (bool)  {
		transferSharesBetweenInvestors(from, _owner, amount);
		return true;
	}


	// Transfer tokens from one account to other
	// Also manage current number of account holders
	function transferSharesBetweenInvestors (
        address sender,
        address recipient,
        uint256 amount	
	)
	internal
	{
        	require(_balances[sender] >= amount, " Amount greater than sender balance");
			
			// owner account is not counted in currentTotalInvestors in below conditions
			_balances[sender] = _balances[sender] - amount;
			if( _balances[sender] == 0 && sender != _owner )
				currentTotalInvestors = currentTotalInvestors - 1;		

			if( _balances[recipient] == 0 && recipient != _owner )
				currentTotalInvestors = currentTotalInvestors + 1;
			_balances[recipient] = _balances[recipient] + amount;

			emit Transfer(sender, recipient, amount);
	}



    function mint(address account, uint256 amount) 
	onlyOwner 
	external 
	returns (bool)	{
        require(account != address(0), "Zero address not allowed");

        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;
        emit Transfer(address(0), account, amount);
		return true;
    }


    function burn(address account, uint256 amount) 
	onlyOwner
	external 
	returns (bool)	{
        require(account != address(0), "Zero address not allowed");
        require(_balances[account] >= amount, "Amount greater than balance");

        _totalSupply = _totalSupply - amount;
        _balances[account] = _balances[account] - amount;
        emit Transfer(account, address(0), amount);
		return true;
    }

}
 





/*
version 1.0

1.  Standard ERC20 functionality

2.  ERC1404 compliance

3.  Control of transfer restrictions with Buy and Sell. There are two variable that control this
	mapping (address => uint256) private _buyRestriction;  
	mapping (address => uint256) private _sellRestriction;	
for each address that can receive/send token will have one entry in these mappings. The integer is linux epoch time.  If a address wants to receive tokens from another address, it must have date/time in _buyRestriciton less than the current date/time and must not be 0 which is default. Similarly if an address want to send token it must have an entry in  sellRestriction with date/time less than current date time.  This is check in the ERC1404 overridden function detectTransferRestriction. Both sender and receive addresses meet above condition, only then transfer will happen 

4.  isTradingAllowed     by default this variable will be 1 which means transfer will happen.  But owner of the contract can stop all transfers by setting this to 0.  this is also checked in detectTransferRestriction before any transfers

5.  Whitelist Authority control.       Following mapping manages this
  mapping (address => bool) private _whitelistControlAuthority;  	
only owner of this control can set another address true, also the owner of the address is added in this mapping in constructor of this contract.  Only those addresses who are set to true in this mapping by owner can call  modifyKYCData with address and buy and sell restriction date/time (mainly to whitelist or block a address to send or receive tokens) 

6.  Minting and Burning     only owner of this contract can mint or burn new tokens

The contract does not use libraries like OpenZappline to make sure that minimum code is used and deployment size of low to reduce the deployment cost 




Version 1.1

1. Forceful take over of token   ( forceTransferToken )

2. Bulk whitelisting  ( bulkWhitelistWallets )



Version 1.2


*/

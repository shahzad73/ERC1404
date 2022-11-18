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
	
	// These addresses can control addresses that can manage whitelisting of investor addresses and can call modifyKYCData
    mapping (address => bool) private _whitelistControlAuthority;  	


	// These events are defined in IERC20Token.sol
    // event Approval(address indexed tokenOwner, address indexed spender, uint256 tokens);
    // event Transfer(address indexed from, address indexed to, uint256 tokens);
	event TransferRestrictionDetected( address indexed from, address indexed to, string message );
	
	// ERC20 related functions
	uint256 public decimals = 18;
	string public version = "1.2";
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


	// Transfer Restriction Codes
	uint8 public constant No_Transfer_Restrictions_Found = 0;
	uint8 public constant Max_Allowed_Investors_Exceed = 1;
	uint8 public constant Transfers_Disabled = 2;
	uint8 public constant Transfer_Value_Cannot_Zero = 3;
	uint8 public constant Sender_Not_Whitelisted_or_Blocked = 4;
	uint8 public constant Receiver_Not_Whitelisted_or_Blocked = 5;
	uint8 public constant Sender_Under_Holding_Period = 6;
	uint8 public constant Receiver_Under_Holding_Period = 7;

	
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
        uint8 restrictionCode = detectTransferRestriction(from, to, value);
		if( restrictionCode != 0 ) {
			string memory errorMessage = messageForTransferRestriction(restrictionCode);
			emit TransferRestrictionDetected( from, to, errorMessage );
        	revert(errorMessage);
		} else 
        	_;
    }



    function detectTransferRestriction (address _from, address _to, uint256 value) 
	override
	public 
	view 
	returns (uint8 status)
    {	
	      	// check if trading is allowed 
		  	if(isTradingAllowed == false)
			 	return Transfers_Disabled;   

		  	if( value <= 0)
		  	  	return Transfer_Value_Cannot_Zero;   
		  
		  	if( _sellRestriction[_from] == 0 )
				return Sender_Not_Whitelisted_or_Blocked;   // Sender is not whitelisted or blocked

		  	if( _buyRestriction[_to] == 0 )
				return Receiver_Not_Whitelisted_or_Blocked;	// Receiver is not whitelisted or blocked

			if( _sellRestriction[_from] > block.timestamp )
				return Sender_Under_Holding_Period;	// Receiver is whitelisted but is not eligible to send tokens and still under holding period (KYC time restriction)

			if( _buyRestriction[_to] > block.timestamp )
				return Receiver_Under_Holding_Period;	// Receiver is whitelisted but is not yet eligible to receive tokens in his wallet (KYC time restriction)


			// Following conditions make sure if number of token holders are within limit if enabled
			// allowedInvestors = 0 means no restriction on number of token holders and is the default setting
			if(allowedInvestors == 0)
				return No_Transfer_Restrictions_Found;
			else {
				if( _balances[_to] > 0 || _to == _owner) 
					// token can be transferred if the receiver alreay holding tokens and already counted in currentTotalInvestors
					// or receiver is issuer account. issuer account do not count in currentTotalInvestors
					return No_Transfer_Restrictions_Found;
				else {
					if(  currentTotalInvestors < allowedInvestors  )
						// currentTotalInvestors is within limits of allowedInvestors
						return No_Transfer_Restrictions_Found;
					else {
						// In this section currentTotalInvestors = allowedInvestors and no more transfers to new investors are allowed
						// except following conditions 
						// 1. sender is sending his whole balance to anohter whitelisted investor regardless he has any balance or not
						// 2. sender must not be owner/isser
						//    owner sending his whole balance to investor will exceed allowedInvestors restriction if currentTotalInvestors = allowedInvestors
						if( _balances[_from] == value && _from != _owner)    
							return No_Transfer_Restrictions_Found;
						else
							return Max_Allowed_Investors_Exceed;
					}
				}
			}
    }


    function messageForTransferRestriction (uint8 restrictionCode)
	override
    public	
    pure 
	returns (string memory message)
    {
        if (restrictionCode == No_Transfer_Restrictions_Found) 
            message = "No transfer restrictions found";
        else if (restrictionCode == Max_Allowed_Investors_Exceed) 
            message = "Max allowed investor restriction is in place, this transfer will exceed this limitation";
        else if (restrictionCode == Transfers_Disabled) 
            message = "All transfers are disabled by issuer";
        else if (restrictionCode == Transfer_Value_Cannot_Zero) 
            message = "Zero transfer amount not allowed";
        else if (restrictionCode == Sender_Not_Whitelisted_or_Blocked) 
            message = "Sender is not whitelisted or blocked";
        else if (restrictionCode == Receiver_Not_Whitelisted_or_Blocked) 
            message = "Receiver is not whitelisted or blocked";
        else if (restrictionCode == Sender_Under_Holding_Period) 
            message = "Sender is whitelisted but is not eligible to send tokens and under holding period (KYC time restriction)";
        else if (restrictionCode == Receiver_Under_Holding_Period) 
            message = "Receiver is whitelisted but is not yet eligible to receive tokens in his wallet (KYC time restriction)";			
		else
			message = "Error code is not defined";
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

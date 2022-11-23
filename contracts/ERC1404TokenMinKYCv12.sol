// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// This contract is minimum implementation of ERC1404 protocol without any libraries 

import "./IERC20Token.sol";
import "./IERC1404.sol";

contract ERC1404TokenMinKYCv12 is IERC20Token, IERC1404 {
	
	// Set buy and sell restrictions on investors.  
	// date is Linux Epoch datetime
	// Both datetimes must be less than current datetime to allow the respective operation. Like to get tokens from others, receiver's buy restriction
	// must be less than current date time. 
	// 0 means investor is not allowed to buy or sell his token.  0 indicates buyer or seller is not whitelisted. 
    mapping (address => uint256) private _buyRestriction;  
	mapping (address => uint256) private _sellRestriction;	
	
	mapping (address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
	address private _owner;
	
	// These addresses act as whitelist authority and can call modifyKYCData
    mapping (address => bool) private _whitelistControlAuthority;  	


	// These events are already defined in IERC20Token.sol
    // event Approval(address indexed tokenOwner, address indexed spender, uint256 tokens);
    // event Transfer(address indexed from, address indexed to, uint256 tokens);
	event TransferRestrictionDetected( address indexed from, address indexed to, string message );
	event BurnTokens(address indexed account, uint256 amount);
	event MintTokens(address indexed account, uint256 amount);
	event KYCDataForUserSet (address indexed account, uint256 buyRestriction, uint256 sellRestriction);
	event KYCDataForUserModified (address indexed account, uint256 buyRestriction, uint256 sellRestriction);
    event ShareCertificateReset (string _ShareCertificate);
    event CompanyHomepageReset (string _CompanyHomepage);
    event CompanyLegalDocsReset (string _CompanyLegalDocs);
	event AllowedInvestorsReset(uint256 _allowedInvestors);
	event HoldingPeriodReset(uint256 _tradingHoldingPeriod);
	event WhitelistAuthorityStatusSet(address user);
	event WhitelistAuthorityStatusRemoved(address user);


	// ERC20 related functions
	uint256 public decimals = 18;
	string public version = "1.2";
	string public IssuancePlatform = "DigiShares";
	string public issuanceProtocol = "ERC-1404";
    uint256 private _totalSupply;
    string public name;
    string public symbol;
	
	string public ShareCertificate;
	string public CompanyHomepage;
	string public CompanyLegalDocs;


	// These variables control how many investors can have non-zero token balance
	// if allowedInvestors = 0 then there is no limit of number of investors who can hold non-zero balance
	uint256 public currentTotalInvestors = 0;		
	uint256 public allowedInvestors = 0;


	uint256 public tradingHoldingPeriod = 1;


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
		 emit ShareCertificateReset (_ShareCertificate);
    }

    function resetCompanyHomepage(string memory _CompanyHomepage) 
	external 
	onlyOwner {
		 CompanyHomepage = _CompanyHomepage;
		 emit CompanyHomepageReset (_CompanyHomepage);
    }
	
    function resetCompanyLegalDocs(string memory _CompanyLegalDocs) 
	external 
	onlyOwner {
		 CompanyLegalDocs = _CompanyLegalDocs;
		emit CompanyLegalDocsReset (_CompanyLegalDocs);
    }

    





	// _allowedInvestors = 0    No limit on number of investors        
	// _allowedInvestors > 0 only X number of investors can have non zero balance 
    function resetAllowedInvestors(uint256 _allowedInvestors) 
	external 
	onlyOwner {
		if( _allowedInvestors != 0 && _allowedInvestors < currentTotalInvestors )
			revert( "Allowed Investors cannot be less than current token holders");

		allowedInvestors = _allowedInvestors;
		emit AllowedInvestorsReset(_allowedInvestors);
    }


    function setTradingHoldingPeriod(uint256 _tradingHoldingPeriod) 
	external 
	onlyOwner {
		 tradingHoldingPeriod = _tradingHoldingPeriod;
		 emit HoldingPeriodReset(_tradingHoldingPeriod);
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
        require(_owner == msg.sender, "Only owner has access to function");
        _;
    }
    function transferOwnership(address newOwner) 
	external 
	onlyOwner {
        require(newOwner != address(0), "Zero address not allowed as owner");
		_owner = newOwner;
    }
	//-----------------------------------------------------------------------
	
  
  


 
	//-----------------------------------------------------------------------
    // Manage whitelist autority and KYC status
	
	function setWhitelistAuthorityStatus(address user)
	external 
	onlyOwner {
		_whitelistControlAuthority[user] = true;
		emit WhitelistAuthorityStatusSet(user);
	}
	function removeWhitelistAuthorityStatus(address user)
	external 
	onlyOwner {
		delete _whitelistControlAuthority[user];
		emit WhitelistAuthorityStatusRemoved(user);
	}	
	function getWhitelistAuthorityStatus(address user)
	external 
	view
	returns (bool) {
		 return _whitelistControlAuthority[user];
	}	
	

  	// Set buy and sell restrictions on investors 
	function modifyKYCData (
		address account, 
		uint256 buyRestriction, 
		uint256 sellRestriction 
	) 
	external 
	{ 
	  	require(_whitelistControlAuthority[msg.sender] == true, "Only authorized addresses can change KYC information of investors");
		setupKYCDataForUser( account, buyRestriction, sellRestriction );
	}

	function bulkWhitelistWallets (
		address[] memory account, 
		uint256 buyRestriction, 
		uint256 sellRestriction 
	) 
	external 
	{ 
		require(_whitelistControlAuthority[msg.sender] == true, "Only authorized addresses can change KYC information of investors");
		for (uint i=0; i<account.length; i++) {
			setupKYCDataForUser( account[i], buyRestriction, sellRestriction );			
		}		
	}

	function setupKYCDataForUser (
		address account, 
		uint256 buyRestriction, 
		uint256 sellRestriction
	)
	internal
	{	
		uint256 tmpBuyRestriction = _buyRestriction[account];
		uint256 tmpSellRestriction = _sellRestriction[account];

		_buyRestriction[account] = buyRestriction;
		_sellRestriction[account] = sellRestriction;		

		// If both buy restriction and sell restriction are 0 then this is kyc restrictions set 
		// otherwise kyc restrictions are being modified
		if(tmpBuyRestriction == 0 && tmpSellRestriction == 0)
			emit KYCDataForUserSet (account, buyRestriction, sellRestriction);
		else
			emit KYCDataForUserModified ( account, buyRestriction, sellRestriction);
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
		if( restrictionCode != No_Transfer_Restrictions_Found ) {
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
	      	// check if holding period is in effect on overall transfers and sender is not owner. 
			// only owner is allwed to transfer under holding period
		  	if(block.timestamp < tradingHoldingPeriod && _from != _owner)
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
            message = "All transfers are disabled because Holding Period is not yet expired";
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
        require(spender != address(0), "Zero address as spender not allowed");
		require(amount > 0, "Zero Amount not allowed");

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
        require(_allowances[sender][msg.sender] >= amount, "Sender cannot transfer amount greater than his Allowance" );
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
        	require(_balances[sender] >= amount, "Sender is trying to transfer amount greater than his balance");
			
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
        require(account != address(0), "Tokens cannot be minted for address zero");

        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;
        emit MintTokens(account, amount);
		return true;
    }


    function burn(address account, uint256 amount) 
	onlyOwner
	external 
	returns (bool)	{
        require(_balances[account] >= amount, "Burn amount is greater than address balance");

        _totalSupply = _totalSupply - amount;
        _balances[account] = _balances[account] - amount;
        emit BurnTokens(account, amount);
		return true;
    }

}
 




/*

	version 1.0
	Basic ERC20 + ERC1404 functionalities 


	Version 1.1

	1. Forceful take over of token   ( forceTransferToken )

	2. Bulk whitelisting  ( bulkWhitelistWallets )


	Version 1.2

	1. Dedicated transfer restriction codes defined in detectTransferRestriction and their descriptions in messageForTransferRestriction

	2. Events for multiple activities being performed  

	3. tradingHoldingPeriod - Holding period has been implemented. Admin can setup a future date and all investor transfers will be disabled 
	till that date. Previous it was a boolean variable with true and false

*/

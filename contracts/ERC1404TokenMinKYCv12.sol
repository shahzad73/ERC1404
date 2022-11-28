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
    mapping (address => uint256) private _receiveRestriction;  
	mapping (address => uint256) private _sendRestriction;	
	
	mapping (address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
	address private _owner;

	// These addresses act as whitelist authority and can call modifyKYCData
    mapping (address => bool) private _whitelistControlAuthority;  	


	// These events are already defined in IERC20Token.sol
    // event Approval(address indexed tokenOwner, address indexed spender, uint256 tokens);
    // event Transfer(address indexed from, address indexed to, uint256 tokens);
	event TransferRestrictionDetected( address indexed from, address indexed to, string message, uint8 errorCode );
	event BurnTokens(address indexed account, uint256 amount);
	event MintTokens(address indexed account, uint256 amount);
	event KYCDataForUserSet (address indexed account, uint256 receiveRestriction, uint256 sendRestriction);
	event KYCDataForUserModified (address indexed account, uint256 receiveRestriction, uint256 sendRestriction);
    event ShareCertificateReset (string _ShareCertificate);
    event CompanyHomepageReset (string _CompanyHomepage);
    event CompanyLegalDocsReset (string _CompanyLegalDocs);
	event AllowedInvestorsReset(uint256 _allowedInvestors);
	event HoldingPeriodReset(uint256 _tradingHoldingPeriod);
	event WhitelistAuthorityStatusSet(address user);
	event WhitelistAuthorityStatusRemoved(address user);
	event TransferFrom( address indexed spender, address indexed sender, address indexed recipient, uint256 amount );


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


	// Transfer Restriction Codes and corresponding error message in _messageForTransferRestriction
	uint8 private constant NO_TRANSFER_RESTRICTION_FOUND = 0;
	uint8 private constant MAX_ALLOWED_INVESTORS_EXCEED = 1;
	uint8 private constant TRANSFERS_DISABLED = 2;
	uint8 private constant TRANSFER_VALUE_CANNOT_ZERO = 3;
	uint8 private constant SENDER_NOT_WHITELISTED_OR_BLOCKED = 4;
	uint8 private constant RECEIVER_NOT_WHITELISTED_OR_BLOCKED = 5;
	uint8 private constant SENDER_UNDER_HOLDING_PERIOD = 6;
	uint8 private constant RECEIVER_UNDER_HOLDING_PERIOD = 7;
	string[] private _messageForTransferRestriction = [
		"No transfer restrictions found", 
		"Max allowed investor restriction is in place, this transfer will exceed this limitation", 
		"All transfers are disabled because Holding Period is not yet expired", 
		"Zero transfer amount not allowed",
		"Sender is not whitelisted or blocked",
		"Receiver is not whitelisted or blocked",
		"Sender is whitelisted but is not eligible to send tokens and under holding period (KYC time restriction)",
		"Receiver is whitelisted but is not yet eligible to receive tokens in his wallet (KYC time restriction)"
	];	



	constructor(
		uint256 _initialSupply, 
		string memory _name,  
		string memory _symbol, 
		uint256 _allowedInvestors, 
		uint256 _decimals, 
		string memory _ShareCertificate, 
		string memory _CompanyHomepage, 
		string memory _CompanyLegalDocs, 
		address _atomicSwapContractAddress 
	) {

			name = _name;
			symbol = _symbol;

			decimals = _decimals;

			_owner = msg.sender;
			_receiveRestriction[_owner] = 1;
			_sendRestriction[_owner] = 1;
			_receiveRestriction[_atomicSwapContractAddress] = 1;
			_sendRestriction[_atomicSwapContractAddress] = 1;


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


    function resetShareCertificate(
		string memory _ShareCertificate
	) 
	external 
	onlyOwner {

		 ShareCertificate = _ShareCertificate;
		 emit ShareCertificateReset (_ShareCertificate);

    }

    function resetCompanyHomepage(
		string memory _CompanyHomepage
	) 
	external 
	onlyOwner {

		 CompanyHomepage = _CompanyHomepage;
		 emit CompanyHomepageReset (_CompanyHomepage);

    }
	
    function resetCompanyLegalDocs(
		string memory _CompanyLegalDocs
	) 
	external 
	onlyOwner {

		CompanyLegalDocs = _CompanyLegalDocs;
		emit CompanyLegalDocsReset (_CompanyLegalDocs);

    }

    





	// _allowedInvestors = 0    No limit on number of investors        
	// _allowedInvestors > 0 only X number of investors can have non zero balance 
    function resetAllowedInvestors(
		uint256 _allowedInvestors
	) 
	external 
	onlyOwner {

		if( _allowedInvestors != 0 && _allowedInvestors < currentTotalInvestors ) {
			revert( "Allowed Investors cannot be less than current token holders");
		}

		allowedInvestors = _allowedInvestors;
		emit AllowedInvestorsReset(_allowedInvestors);
		
    }


    function setTradingHoldingPeriod(
		uint256 _tradingHoldingPeriod
	) 
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

    function transferOwnership (
		address newOwner
	) 
	external 
	onlyOwner {

        require(newOwner != address(0), "Zero address not allowed as owner");
		_owner = newOwner;

    }
	//-----------------------------------------------------------------------
	
  
  


 
	//-----------------------------------------------------------------------
    // Manage whitelist autority and KYC status
	
	function setWhitelistAuthorityStatus(
		address user
	) 
	external 
	onlyOwner {

		_whitelistControlAuthority[user] = true;
		emit WhitelistAuthorityStatusSet(user);

	}

	function removeWhitelistAuthorityStatus(
		address user
	) 
	external 
	onlyOwner {

		delete _whitelistControlAuthority[user];
		emit WhitelistAuthorityStatusRemoved(user);

	}	

	function getWhitelistAuthorityStatus(
		address user
	) 
	external 
	view
	returns (bool) {

		 return _whitelistControlAuthority[user];

	}	
	

  	// Set buy and sell restrictions on investors 
	function modifyKYCData (
		address account, 
		uint256 receiveRestriction, 
		uint256 sendRestriction 
	) external { 

	  	require(_whitelistControlAuthority[msg.sender] == true, "Only authorized addresses can change KYC information of investors");
		setupKYCDataForUser( account, receiveRestriction, sendRestriction );

	}


	function bulkWhitelistWallets (
		address[] memory account, 
		uint256 receiveRestriction, 
		uint256 sendRestriction 
	) external { 

		if(account.length > 50)
			revert ("Bulk whitelisting more than 50 addresses is not allowed");

		require(_whitelistControlAuthority[msg.sender] == true, "Only authorized addresses can change KYC information of investors");
		for (uint i=0; i<account.length; i++) {
			setupKYCDataForUser( account[i], receiveRestriction, sendRestriction );			
		}		

	}


	function setupKYCDataForUser (
		address account, 
		uint256 receiveRestriction, 
		uint256 sendRestriction
	) internal {	

		uint256 tmpReceiveRestriction = _receiveRestriction[account];
		uint256 tmpSendRestriction = _sendRestriction[account];

		_receiveRestriction[account] = receiveRestriction;
		_sendRestriction[account] = sendRestriction;		

		// If both buy restriction and sell restriction are 0 then this is kyc restrictions set 
		// otherwise kyc restrictions are being modified
		if(tmpReceiveRestriction == 0 && tmpSendRestriction == 0) {
			emit KYCDataForUserSet (account, receiveRestriction, sendRestriction);
		} else {
			emit KYCDataForUserModified ( account, receiveRestriction, sendRestriction);
		}

	}


	function getKYCData ( 
		address user 
	) 
	external 
	view
	returns ( uint256, uint256 ) {

		return (_receiveRestriction[user] , _sendRestriction[user] );

	}
	//-----------------------------------------------------------------------



	//-----------------------------------------------------------------------
	// These are ERC1404 interface implementations 

    modifier notRestricted (
		address from, 
		address to, 
		uint256 value 
	) {

        uint8 restrictionCode = detectTransferRestriction(from, to, value);
		if( restrictionCode != NO_TRANSFER_RESTRICTION_FOUND ) {

			string memory errorMessage = messageForTransferRestriction(restrictionCode);
			emit TransferRestrictionDetected( from, to, errorMessage, restrictionCode );
        	revert(errorMessage);

		} else 
        	_;

    }



    function detectTransferRestriction (address _from, address _to, uint256 value) 
	override
	public 
	view 
	returns ( uint8 status )  {	

	      	// check if holding period is in effect on overall transfers and sender is not owner. 
			// only owner is allwed to transfer under holding period
		  	if(block.timestamp < tradingHoldingPeriod && _from != _owner)
			 	return TRANSFERS_DISABLED;   

		  	if( value <= 0) {
		  	  	return TRANSFER_VALUE_CANNOT_ZERO;   
			}

		  	if( _sendRestriction[_from] == 0 ) {
				return SENDER_NOT_WHITELISTED_OR_BLOCKED;   // Sender is not whitelisted or blocked
			}

		  	if( _receiveRestriction[_to] == 0 ) {
				return RECEIVER_NOT_WHITELISTED_OR_BLOCKED;	// Receiver is not whitelisted or blocked
			}

			if( _sendRestriction[_from] > block.timestamp ) {
				return SENDER_UNDER_HOLDING_PERIOD;	// Receiver is whitelisted but is not eligible to send tokens and still under holding period (KYC time restriction)
			}

			if( _receiveRestriction[_to] > block.timestamp ) {
				return RECEIVER_UNDER_HOLDING_PERIOD;	// Receiver is whitelisted but is not yet eligible to receive tokens in his wallet (KYC time restriction)
			}

			// Following conditions make sure if number of token holders are within limit if enabled
			// allowedInvestors = 0 means no restriction on number of token holders and is the default setting
			if(allowedInvestors == 0) {
				return NO_TRANSFER_RESTRICTION_FOUND;
			} else {
				if( _balances[_to] > 0 || _to == _owner) {
					// token can be transferred if the receiver alreay holding tokens and already counted in currentTotalInvestors
					// or receiver is issuer account. issuer account do not count in currentTotalInvestors
					return NO_TRANSFER_RESTRICTION_FOUND;
				} else {
					if(  currentTotalInvestors < allowedInvestors  ) {
						// currentTotalInvestors is within limits of allowedInvestors
						return NO_TRANSFER_RESTRICTION_FOUND;
					} else {
						// In this section currentTotalInvestors = allowedInvestors and no more transfers to new investors are allowed
						// except following conditions 
						// 1. sender is sending his whole balance to anohter whitelisted investor regardless he has any balance or not
						// 2. sender must not be owner/isser
						//    owner sending his whole balance to investor will exceed allowedInvestors restriction if currentTotalInvestors = allowedInvestors
						if( _balances[_from] == value && _from != _owner)    
							return NO_TRANSFER_RESTRICTION_FOUND;
						else
							return MAX_ALLOWED_INVESTORS_EXCEED;
					}
				}
			}

    }


    function messageForTransferRestriction (uint8 restrictionCode)
	override
    public	
    view 
	returns ( string memory message )
    {

		if(restrictionCode <= 7) {
			message = _messageForTransferRestriction[restrictionCode];
		} else {
			message = "Error code is not defined";
		}

    }
	//-----------------------------------------------------------------------




 	function totalSupply() 
	override
	external 
	view 
	returns ( uint256 ) {

		return _totalSupply;

	}


    function balanceOf(
		address account
	) 
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
	returns (bool) {

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
	returns (bool) {

		transferSharesBetweenInvestors ( msg.sender, recipient, amount );
		return true;

    }


    function transferFrom (
        address sender,
        address recipient,
        uint256 amount
    ) 
	override
	external 
	notRestricted (sender, recipient, amount)
	returns (bool)	{	

        require(_allowances[sender][msg.sender] >= amount, "Sender cannot transfer amount greater than his Allowance" );
		transferSharesBetweenInvestors ( sender, recipient, amount );
        _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;

		emit TransferFrom( msg.sender, sender, recipient, amount );
		return true;

    }


	// Force transfer of  back to issuer
	function forceTransferToken (
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
	internal {
        	require(_balances[sender] >= amount, "Sender is trying to transfer amount greater than his balance");
			
			// owner account is not counted in currentTotalInvestors in below conditions
			_balances[sender] = _balances[sender] - amount;
			if( _balances[sender] == 0 && sender != _owner ) {
				currentTotalInvestors = currentTotalInvestors - 1;		
			}

			if( _balances[recipient] == 0 && recipient != _owner ) {
				currentTotalInvestors = currentTotalInvestors + 1;
			}
			_balances[recipient] = _balances[recipient] + amount;

			emit Transfer(sender, recipient, amount);
	}



    function mint(
		address account, 
		uint256 amount
	) 
	onlyOwner 
	external 
	returns (bool)	{

        require(account != address(0), "Tokens cannot be minted for address zero");

        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;
        emit MintTokens(account, amount);
		return true;

    }


    function burn(
		address account, 
		uint256 amount
	) 
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC1404.sol";


contract ERC1404TokenMinKYCv13 is ERC20, Ownable, IERC1404 {

	// Set receive and send restrictions on investors
	// date is Linux Epoch datetime
	// Default values is 0 which means investor is not whitelisted
    mapping (address => uint256) private _receiveRestriction;  
	mapping (address => uint256) private _sendRestriction;

	// These addresses act as whitelist authority and can call modifyKYCData
	// There is possibility that issuer may let third party like Exchange to control 
	// whitelisting addresses 
    mapping (address => bool) private _whitelistControlAuthority;

	event TransferRestrictionDetected( address indexed from, address indexed to, string message, uint8 errorCode );
	event BurnTokens(address indexed account, uint256 amount);
	event MintTokens(address indexed account, uint256 amount);
	event KYCDataForUserSet (address indexed account, uint256 receiveRestriction, uint256 sendRestriction);
    event ShareCertificateReset (string _ShareCertificate);
    event CompanyHomepageReset (string _CompanyHomepage);
    event CompanyLegalDocsReset (string _CompanyLegalDocs);
	event AllowedInvestorsReset(uint64 _allowedInvestors);
	event HoldingPeriodReset(uint64 _tradingHoldingPeriod);
	event WhitelistAuthorityStatusSet(address user);
	event WhitelistAuthorityStatusRemoved(address user);
	event TransferFrom( address indexed spender, address indexed sender, address indexed recipient, uint256 amount );
	event IssuerForceTransfer (address indexed from, address indexed to, uint256 amount);


	string public constant version = "1.3";
	string public constant IssuancePlatform = "DigiShares";
	string public constant issuanceProtocol = "ERC-1404";
	string public ShareCertificate;
	string public CompanyHomepage;
	string public CompanyLegalDocs;


	// These variables control how many investors can have non-zero token balance
	// if allowedInvestors = 0 then there is no limit of number of investors who can 
	// hold non-zero balance
	uint8 private constant ANY_NUMBER_OF_TOKEN_HOLDERS_ALLOWED = 0; 
	uint8 private immutable _decimals;	
	uint64 public currentTotalInvestors = 0;		
	uint64 public allowedInvestors;

	// Holding period in EpochTime, if set in future then it will stop 
	// all transfers between investors
	uint64 public tradingHoldingPeriod = 1;


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
		"Max allowed addresses with non-zero restriction is in place, this transfer will exceed this limitation", 
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
		uint64 _allowedInvestors, 
		uint8 _decimalsPlaces, 
		string memory _ShareCertificate, 
		string memory _CompanyHomepage, 
		string memory _CompanyLegalDocs, 
		address _atomicSwapContractAddress,
		uint64  _tradingHoldingPeriod
	) ERC20(_name, _symbol)  {

			address tmpSenderAddress = msg.sender;

			_decimals = _decimalsPlaces;
			tradingHoldingPeriod = _tradingHoldingPeriod;

			// These variables set EPOCH time    1 = 1 January 1970
			_receiveRestriction[tmpSenderAddress] = 1;
			_sendRestriction[tmpSenderAddress] = 1;
			_receiveRestriction[_atomicSwapContractAddress] = 1;
			_sendRestriction[_atomicSwapContractAddress] = 1;

			allowedInvestors = _allowedInvestors;

			// add message sender to whitelist authority list
			_whitelistControlAuthority[tmpSenderAddress] = true;

			ShareCertificate = _ShareCertificate;
			CompanyHomepage = _CompanyHomepage;
			CompanyLegalDocs = _CompanyLegalDocs;

			_mint(tmpSenderAddress , _initialSupply);
			emit MintTokens(tmpSenderAddress, _initialSupply);
	}
	



	// ------------------------------------------------------------------------
	// Modifiers for this contract 
	// ------------------------------------------------------------------------
    modifier onlyWhitelistControlAuthority () {

	  	require(_whitelistControlAuthority[msg.sender] == true, "Only authorized addresses can control whitelisting of holder addresses");
        _;

    }

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




	// ERC20 interface
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
	


    function mint (address account, uint256 amount)		
    external        
	Ownable.onlyOwner
    returns (bool)
    {
		require ( account != address(0), "Minting address cannot be zero");
		require ( _receiveRestriction[account] != 0, "Address is not yet whitelisted by issuer" );
		require ( amount > 0, "Zero amount cannot be minted" );
		
		// This is special case while minting tokens. if issuer is trying to mint to a address while max token holder restriction
		// is in place and smart contract already has max tpken holders then this will revert this transaction as it will result in
		// currentTotalInvestors getting larger than allowedInvestors. The issuer account is exempted from this condition as
		// issuer account is not counted in currentTotalInvestors
		if( 
			( account != Ownable.owner() ) &&       // issuer account is exempted from this condition
			( ERC20.balanceOf(account) == 0 ) &&    // account has zero balance so it will increase currentTotalInvestors
			( allowedInvestors != ANY_NUMBER_OF_TOKEN_HOLDERS_ALLOWED ) &&    // max number of token holder restriction is in place 
			( currentTotalInvestors + 1 ) > allowedInvestors ) // make sure minting to account with 0 balance do not exceed allowedInvestors
		{
			revert ("Minting not allowed to this address as allowed token holder restriction is in place and minting will increase the allowed limit");
		}

		// minting will sure increase currentTotalInvestors if address balance is 0
		if( ERC20.balanceOf(account) == 0 && account != Ownable.owner() ) {
			currentTotalInvestors = currentTotalInvestors + 1;
		}

		ERC20._mint(account, amount);		 
		emit MintTokens(account, amount);
		return true;
    }


    function burn (address account, uint256 amount)
	external     
	Ownable.onlyOwner
    returns (bool)
    {
		require( account != address(0), "Burn address cannot be zero");
		require ( amount > 0, "Zero amount cannot be burned" );		

		ERC20._burn(account, amount);

		// burning will decrease currentTotalInvestors if address balance becomes 0
		if( ERC20.balanceOf(account) == 0 && account != Ownable.owner() ) {
			currentTotalInvestors = currentTotalInvestors - 1;
		}

		 emit BurnTokens(account, amount);		 
		 return true;
    }





	// ------------------------------------------------------------------------
	// Token Links and Document information management 
	// ------------------------------------------------------------------------
    function resetShareCertificate(
		string calldata _ShareCertificate
	) 
	external 
	Ownable.onlyOwner {

		 ShareCertificate = _ShareCertificate;
		 emit ShareCertificateReset (_ShareCertificate);

    }

    function resetCompanyHomepage(
		string calldata _CompanyHomepage
	) 
	external 
	Ownable.onlyOwner {

		 CompanyHomepage = _CompanyHomepage;
		 emit CompanyHomepageReset (_CompanyHomepage);

    }
	
    function resetCompanyLegalDocs(
		string calldata _CompanyLegalDocs
	) 
	external 
	Ownable.onlyOwner {

		CompanyLegalDocs = _CompanyLegalDocs;
		emit CompanyLegalDocsReset (_CompanyLegalDocs);

    }


	// --------------------------------------------------------------------------------------
	// Manage number of addresses who can hold non-zero balance and holding period management
	// --------------------------------------------------------------------------------------
	// _allowedInvestors = 0    No limit on number of investors (or number of addresses with non-zero balance)         
	// _allowedInvestors > 0    only X number of addresses can have non zero balance 
    function resetAllowedInvestors(
		uint64 _allowedInvestors
	) 
	external 
	Ownable.onlyOwner {

		if( _allowedInvestors != ANY_NUMBER_OF_TOKEN_HOLDERS_ALLOWED && _allowedInvestors < currentTotalInvestors ) {
			revert( "Allowed Token holders cannot be less than current token holders with non-zero balance");
		}

		allowedInvestors = _allowedInvestors;
		emit AllowedInvestorsReset(_allowedInvestors);
		
    }


    function setTradingHoldingPeriod (
		uint64 _tradingHoldingPeriod
	) 
	external 
	Ownable.onlyOwner {

		 tradingHoldingPeriod = _tradingHoldingPeriod;
		 emit HoldingPeriodReset(_tradingHoldingPeriod);

    }




	//-----------------------------------------------------------------------
    // Manage whitelist authority and KYC status
	//-----------------------------------------------------------------------
	
	function setWhitelistAuthorityStatus(
		address user
	) 
	external 
	Ownable.onlyOwner {

		_whitelistControlAuthority[user] = true;
		emit WhitelistAuthorityStatusSet(user);

	}

	function removeWhitelistAuthorityStatus(
		address user
	) 
	external 
	Ownable.onlyOwner {

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
	


  	// Set Receive and Send restrictions on addresses. Both values are EPOCH time
	function modifyKYCData (
		address account, 
		uint256 receiveRestriction, 
		uint256 sendRestriction 
	) 
	external 
	onlyWhitelistControlAuthority { 
		setupKYCDataForUser( account, receiveRestriction, sendRestriction );
	}


	function bulkWhitelistWallets (
		address[] calldata account, 
		uint256 receiveRestriction, 
		uint256 sendRestriction 
	) 
	external 
	onlyWhitelistControlAuthority { 

		if(account.length > 50) {
			revert ("Bulk whitelisting more than 50 addresses is not allowed");
		}

		for (uint i=0; i<account.length; i++) {
			setupKYCDataForUser( account[i], receiveRestriction, sendRestriction );			
		}		

	}


	function setupKYCDataForUser (
		address account, 
		uint256 receiveRestriction, 
		uint256 sendRestriction
	) internal {	

		_receiveRestriction[account] = receiveRestriction;
		_sendRestriction[account] = sendRestriction;		
		emit KYCDataForUserSet (account, receiveRestriction, sendRestriction);

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
	//-----------------------------------------------------------------------

    function detectTransferRestriction (address _from, address _to, uint256 value) 
	override
	public 
	view 
	returns ( uint8 status )  {	

	      	// check if holding period is in effect on overall transfers and sender is not owner. 
			// only owner is allowed to transfer under holding period
		  	if(block.timestamp < tradingHoldingPeriod && _from != Ownable.owner()) {
			 	return TRANSFERS_DISABLED;   
			}

		  	if( value < 1) {
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

			// Following conditions make sure number of token holders will stay within limit if max token holder restriction is in place
			// allowedInvestors = 0 means no restriction on number of token holders and is the default setting
			if(allowedInvestors == ANY_NUMBER_OF_TOKEN_HOLDERS_ALLOWED) {
				return NO_TRANSFER_RESTRICTION_FOUND;
			} else {
				if( ERC20.balanceOf(_to) > 0 || _to == Ownable.owner()) {
					// token can be transferred if the receiver already holding tokens and already counted in currentTotalInvestors
					// or receiver is issuer account. issuer/owner account do not count in currentTotalInvestors
					return NO_TRANSFER_RESTRICTION_FOUND;
				} else {
					// if To address has zero balance then check this transfer do not exceed allowedInvestors as 
					// this transfer will surely increase currentTotalInvestors
					if(  currentTotalInvestors < allowedInvestors  ) {
						// currentTotalInvestors is within limits of allowedInvestors
						return NO_TRANSFER_RESTRICTION_FOUND;
					} else {
						// In this section currentTotalInvestors = allowedInvestors and no more transfers to new investors are allowed
						// except following conditions 
						// 1. sender is sending his whole balance to another whitelisted investor regardless he has any balance or not
						// 2. sender must not be owner/issuer
						//    owner sending his whole balance to investor will exceed allowedInvestors restriction if currentTotalInvestors = allowedInvestors
						if( ERC20.balanceOf(_from) == value && _from != Ownable.owner()) {    
							return NO_TRANSFER_RESTRICTION_FOUND;
						} else {
							return MAX_ALLOWED_INVESTORS_EXCEED;
						}
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

		if(restrictionCode <= (_messageForTransferRestriction.length - 1) ) {
			message = _messageForTransferRestriction[restrictionCode];
		} else {
			message = "Error code is not defined";
		}

    }
	//-----------------------------------------------------------------------





	//-----------------------------------------------------------------------
	// Transfers
	//-----------------------------------------------------------------------

    function transfer(
        address recipient,
        uint256 amount
    ) 	
	override
	public 
	notRestricted (msg.sender, recipient, amount)
	returns (bool) {

		transferSharesBetweenInvestors ( msg.sender, recipient, amount, true );
		return true;

    }



    function transferFrom (
        address sender,
        address recipient,
        uint256 amount
    ) 
	public
	override
	notRestricted (sender, recipient, amount)
	returns (bool)	{	

		transferSharesBetweenInvestors ( sender, recipient, amount, false );
		emit TransferFrom( msg.sender, sender, recipient, amount );
		return true;

    }



	// Force transfer of token back to issuer
	function forceTransferToken (
        address from,
        uint256 amount
	) 
	Ownable.onlyOwner
	external 
	returns (bool)  {
		
		transferSharesBetweenInvestors ( from, Ownable.owner(), amount, true );
		emit IssuerForceTransfer (from, Ownable.owner(), amount);
		return true;

	}



	// Transfer tokens from one account to other
	// Also manage current number of token holders
	function transferSharesBetweenInvestors (
        address sender,
        address recipient,
        uint256 amount,
		bool simpleTransfer	   // true = transfer,   false = transferFrom
	) 
	internal {

		// Transfer will surely increase currentTotalInvestors if recipient current balance is 0
		if( ERC20.balanceOf(recipient) == 0 && recipient != Ownable.owner() ) {
			currentTotalInvestors = currentTotalInvestors + 1;
		}

		if( simpleTransfer == true ) {
			ERC20._transfer(sender, recipient, amount);
		} else {
			ERC20.transferFrom(sender, recipient, amount);
		}

		if( ERC20.balanceOf(sender) == 0 && sender != Ownable.owner() ) {
			currentTotalInvestors = currentTotalInvestors - 1;		
		}

	}



}

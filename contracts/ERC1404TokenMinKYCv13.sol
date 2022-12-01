// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC1404.sol";


contract ERC1404TokenMinKYCv13 is ERC20, Ownable, IERC1404 {

	// Set receive and send restrictions on investors
	// date is Linux Epoch datetime
	// Both datetimes must be less than current datetime to allow the respective operation
	// Default values is 0 which means investor is not whitelisted
    mapping (address => uint64) private _receiveRestriction;  
	mapping (address => uint64) private _sendRestriction;		

	// These addresses act as whitelist authority and can call modifyKYCData
    mapping (address => bool) private _whitelistControlAuthority;  	

	// These events are already defined in IERC20Token.sol
    // event Approval(address indexed tokenOwner, address indexed spender, uint256 tokens);
    // event Transfer(address indexed from, address indexed to, uint256 tokens);
	event TransferRestrictionDetected( address indexed from, address indexed to, string message, uint8 errorCode );
	event BurnTokens(address indexed account, uint256 amount);
	event MintTokens(address indexed account, uint256 amount);
	event KYCDataForUserSet (address indexed account, uint256 receiveRestriction, uint256 sendRestriction);
    event ShareCertificateReset (string _ShareCertificate);
    event CompanyHomepageReset (string _CompanyHomepage);
    event CompanyLegalDocsReset (string _CompanyLegalDocs);
	event AllowedInvestorsReset(uint256 _allowedInvestors);
	event HoldingPeriodReset(uint256 _tradingHoldingPeriod);
	event WhitelistAuthorityStatusSet(address user);
	event WhitelistAuthorityStatusRemoved(address user);
	event TransferFrom( address indexed spender, address indexed sender, address indexed recipient, uint256 amount );


	string public version = "1.3";
	string public IssuancePlatform = "DigiShares";
	string public issuanceProtocol = "ERC-1404";
	string public ShareCertificate;
	string public CompanyHomepage;
	string public CompanyLegalDocs;


	// These variables control how many investors can have non-zero token balance, holding period and decimal places
	// if allowedInvestors = 0 then there is no limit of number of investors who can hold non-zero balance
	// tradingHoldingPeriod is EpochTime, if set in future then it will stop all tradings between investors
	uint64 public currentTotalInvestors = 0;		
	uint64 public allowedInvestors = 0;
	uint64 public tradingHoldingPeriod = 1;
	uint8 private _decimals = 18;	


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
		uint64 _allowedInvestors, 
		uint8 _decimalsPlaces, 
		string memory _ShareCertificate, 
		string memory _CompanyHomepage, 
		string memory _CompanyLegalDocs, 
		address _atomicSwapContractAddress 
	) ERC20(_name, _symbol)  {
		
			_decimals = _decimalsPlaces;

			_receiveRestriction[owner()] = 1;
			_sendRestriction[owner()] = 1;
			_receiveRestriction[_atomicSwapContractAddress] = 1;
			_sendRestriction[_atomicSwapContractAddress] = 1;

			allowedInvestors = _allowedInvestors;

			// add message sender to whitelist authority list
			_whitelistControlAuthority[owner()] = true;

			ShareCertificate = _ShareCertificate;
			CompanyHomepage = _CompanyHomepage;
			CompanyLegalDocs = _CompanyLegalDocs;

			_mint(owner() , _initialSupply);
			emit MintTokens(owner(), _initialSupply);
	}
	

	// ERC20 interface
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
	

    function mint (address account, uint256 amount)		
    public        
	onlyOwner
    returns (bool)
    {
		 super._mint(account, amount);
		 emit MintTokens(account, amount);
		 return true;
    }


    function burn (address account, uint256 amount)
	public     
	onlyOwner   
    returns (bool)
    {
		 super._burn(account, amount);
		 emit BurnTokens(account, amount);		 
		 return true;
    }





	// ------------------------------------------------------------------------
	// Token Links and Document information management 
	// ------------------------------------------------------------------------
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


	// ------------------------------------------------------------------------
	// Number of investors and holding period management
	// ------------------------------------------------------------------------
	// _allowedInvestors = 0    No limit on number of investors        
	// _allowedInvestors > 0 only X number of investors can have non zero balance 
    function resetAllowedInvestors(
		uint64 _allowedInvestors
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
		uint64 _tradingHoldingPeriod
	) 
	external 
	onlyOwner {

		 tradingHoldingPeriod = _tradingHoldingPeriod;
		 emit HoldingPeriodReset(_tradingHoldingPeriod);

    }




	//-----------------------------------------------------------------------
    // Manage whitelist autority and KYC status
	//-----------------------------------------------------------------------
	
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
	

  	// Set receive and send restrictions on investors 
	function modifyKYCData (
		address account, 
		uint64 receiveRestriction, 
		uint64 sendRestriction 
	) external { 

	  	require(_whitelistControlAuthority[msg.sender] == true, "Only authorized addresses can change KYC information of investors");
		setupKYCDataForUser( account, receiveRestriction, sendRestriction );

	}


	function bulkWhitelistWallets (
		address[] memory account, 
		uint64 receiveRestriction, 
		uint64 sendRestriction 
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
		uint64 receiveRestriction, 
		uint64 sendRestriction
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
		  	if(block.timestamp < tradingHoldingPeriod && _from != owner())
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
				if( balanceOf(_to) > 0 || _to == owner()) {
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
						if( balanceOf(_from) == value && _from != owner())    
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

		if(restrictionCode <= _messageForTransferRestriction.length) {
			message = _messageForTransferRestriction[restrictionCode];
		} else {
			message = "Error code is not defined";
		}

    }
	//-----------------------------------------------------------------------







    function transfer(
        address recipient,
        uint256 amount
    ) 	
	override
	public 
	notRestricted (_msgSender(), recipient, amount)
	returns (bool) {

		super._transfer ( _msgSender(), recipient, amount );
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

		super.transferFrom(sender, recipient, amount);

		emit TransferFrom( msg.sender, sender, recipient, amount );
		return true;

    }



	// Force transfer of token back to issuer
	function forceTransferToken (
        address from,
        uint256 amount
	) 
	onlyOwner
	external 
	returns (bool)  {

		super._transfer(from, owner(), amount);
		return true;

	}





}

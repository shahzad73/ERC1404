# ERC1404

This is ERC1404 protocol implementation. It allows issuer to launch a ERC1404 based security token and provides whitelisting functionalities. Here are the functionalities provided 

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

# ERC1404 implementation 

This repository contains ERC1404 based smart contracts with following main functionalities  

1.  Standard ERC20 functionality

2.  ERC1404 compliance

3.  Control of transfer restrictions with Buy and Sell. There are two variable that control this
	mapping (address => uint256) private _buyRestriction;  
	mapping (address => uint256) private _sellRestriction;	
The integer is linux epoch time.  If a address wants to receive tokens from another address, it must have date/time in _buyRestriciton less than the current date/time and must not be 0 which is default. Similarly if an address want to send token it must have an entry in  sellRestriction with date/time less than current date time.  Both sender and receive addresses must meet above condition, only then transfer will happen 

4.  isTradingAllowed     by default this variable will be true which means transfer will happen.  But owner of the contract can stop all transfers by setting this to false.  this is also checked in detectTransferRestriction before any transfers

5.  Whitelist Authority control.       Following mapping manages this
only owner of this control can set another address true,  Addresses in this mapping can manage whitelisting of addresses. Owner is by default added in this mapping in constructor 

6.  Minting and Burning     only owner of this contract can mint or burn new tokens

The contract does not use libraries like OpenZeppelin to make sure that minimum code is used and deployment size of low to reduce the deployment cost 

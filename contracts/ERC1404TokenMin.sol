// SPDX-License-Identifier: MIT
// This contract is minimum implementation of ERC1404 protocol without any libraries 
pragma solidity ^0.8.0;


contract ERC1404TokenMin {

    using SafeMathInternal for uint256;

    mapping (address => bool) internal whitelisted;  

	mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;
	
	address private _owner;

    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    event Transfer(address indexed from, address indexed to, uint tokens);

	
	uint8 public decimals = 18;
    uint256 public totalSupply;
    string public name;
    string public symbol;
	
	constructor(uint256 _initialSupply, string memory _name,  string memory _symbol ) {
		name = _name;
        symbol = _symbol;

		whitelisted[msg.sender] = true;
		_owner = msg.sender;

		// Minting tokens for initial supply
         totalSupply = _initialSupply;
        _balances[msg.sender] = totalSupply;
		
		emit Transfer(address(0), msg.sender, totalSupply);
	}


    function getOwner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(_owner == msg.sender, "caller is not the owner");
        _;
    }
    function transferOwnership(address newOwner) 
	public 
	onlyOwner {
        require(newOwner != address(0), "Address 0");
		_owner = newOwner;
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
        require(restrictionCode == 1, messageForTransferRestriction(restrictionCode));
        _;
    }


    function detectTransferRestriction (address _from, address _to, uint256 value) 
	public 
	view 
	returns (uint8)
    {
		  if (whitelisted[_to])
		  {
			 if (whitelisted[_from]) 
				return 1;
			 else
				return 0;
		  } else
			  return 0;
    }


    function messageForTransferRestriction (uint8 restrictionCode)
    public	
    pure returns (string memory message)
    {
        if (restrictionCode == 1) 
            message = "Whitelisted";
         else 
            message = "Not Whitelisted";
    }








    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
	
	
    function allowance(address owner, address spender) 
	public 
	view 
	returns (uint256) {
        return _allowances[owner][spender];
    }	

	
	
	

    function transfer(
        address recipient,
        uint256 amount
    ) 	
	public 
	notRestricted (msg.sender, recipient, amount)
	{
        require(msg.sender != address(0), "Zero Address");
        require(recipient != address(0), "Zero Address");

        uint256 senderBalance = _balances[msg.sender];
        require(senderBalance >= amount, "Transfer amount exceeds");
        _balances[msg.sender] = senderBalance.sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(msg.sender, recipient, amount);
    }



    function approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "Zero Address");
        require(spender != address(0), "Zero Address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
	

    function transferFrom(
        address owner,
        address buyer,
        uint256 amount
    ) 
	public 
	notRestricted (owner, buyer, amount)
	{
        require(owner != address(0), "Zero Address");
        require(buyer != address(0), "Zero Address");
        require(msg.sender != address(0), "Zero Address");
		
        require(amount <= _balances[owner]);
        require(amount <= _allowances[owner][msg.sender]);

        _balances[owner] = _balances[owner].sub(amount);
        _allowances[owner][msg.sender] = _allowances[owner][msg.sender].sub(amount);
        _balances[buyer] = _balances[buyer].add(amount);
		
        emit Transfer(owner, buyer, amount);	
    }
 





    function mint(address account, uint256 amount) 
	onlyOwner 
	public {
        require(account != address(0), "Zero Address");

        totalSupply.add(amount);
        _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }


    function _burn(address account, uint256 amount) 
	onlyOwner 
	public {
        require(account != address(0), "Zero Address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "Amount exceeds balance");
        _balances[account] = accountBalance.sub(amount);
        totalSupply.sub(amount);

        emit Transfer(account, address(0), amount);
    }


}
 
 
library SafeMathInternal {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      assert(b <= a);
      return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      assert(c >= a);
      return c;
    }
} 
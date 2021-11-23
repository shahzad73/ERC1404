// SPDX-License-Identifier: MIT
// This contract is minimum implementation of ERC1404 protocol without any libraries 
pragma solidity ^0.8.0;


contract ERC1404TokenMinStandard {

    using SafeMathInternal for uint256;

    mapping (address => bool) private _whitelisted;  
	mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
	address private _owner;

    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    event Transfer(address indexed from, address indexed to, uint tokens);

	uint8 public decimals = 18;
    uint256 public totalSupply;
    string public name;
    string public symbol;
	
	string private AddressZeroMessage = "Address Zero not allowed";
	string private AmountExceedBalance = "Amount Exceed Balance";	

	constructor(uint256 _initialSupply, string memory _name,  string memory _symbol ) {
		name = _name;
        symbol = _symbol;

		_whitelisted[msg.sender] = true;
		_owner = msg.sender;

		// Minting tokens for initial supply
        totalSupply = _initialSupply;
        _balances[msg.sender] = totalSupply;
		
		emit Transfer(address(0), msg.sender, totalSupply);
	}



    function getOwner() 
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



	  function addWhitelistAddress (address user) 
	  public 
	  onlyOwner 
	  { 
		  _whitelisted[user] = true; 
	  }
	  
	  function removeWhitelistAddress (address user) 
	  public 
	  onlyOwner
	  { 
		  delete _whitelisted[user];
	  }
	  
	  function isInvestorWhiteListed(address user) 
	  public 
	  view
	  returns (bool) {
		   return _whitelisted[user]; 
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
		  require( value != 0, "Value cannot be 0");
	
		  if (_whitelisted[_to])
		  {
			 if (_whitelisted[_from]) 
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
		
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(msg.sender, recipient, amount);
    }



    function approve(
        address spender,
        uint256 amount
    ) public {
        require(spender != address(0), AddressZeroMessage);

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

        _balances[owner] = _balances[owner].sub(amount);
        _allowances[owner][msg.sender] = _allowances[owner][msg.sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
		
        emit Transfer(owner, recipient, amount);	
    }






    function mint(address account, uint256 amount) 
	onlyOwner 
	public {
        require(account != address(0), AddressZeroMessage);

        totalSupply.add(amount);
        _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }


    function burn(address account, uint256 amount) 
	onlyOwner
	public {
        require(account != address(0), AddressZeroMessage);
        require(_balances[account] >= amount, AmountExceedBalance);
		
        _balances[account] = _balances[account].sub(amount);
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


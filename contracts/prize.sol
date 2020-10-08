/**
 *Submitted for verification at Etherscan.io on 2020-02-22
*/

pragma solidity 0.4.26;

library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    return a / b;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

contract TOKEN {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract Ownable {
  address public owner;

  constructor() public {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  function changeOwner(address new_owner) public onlyOwner {
    owner = new_owner;
  }
}

contract PRZ is Ownable {
    using SafeMath for uint256;

    uint ACTIVATION_TIME = 1582416000;

    modifier isActivated {
        require(now >= ACTIVATION_TIME);

        if (now <= (ACTIVATION_TIME + 2 minutes)) {
            require(tx.gasprice <= 0.1 szabo);
        }
        _;
    }

    modifier onlyTokenHolders() {
        require(myTokens() > 0);
        _;
    }

    event onDistribute(
        address indexed customerAddress,
        uint256 tokens
    );

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 tokens
    );

    event onTokenPurchase(
        address indexed customerAddress,
        uint256 incomingPION,
        uint256 tokensMinted,
        uint256 timestamp
    );

    event onTokenSell(
        address indexed customerAddress,
        uint256 tokensBurned,
        uint256 pionEarned,
        uint256 timestamp
    );

    string public name = "Prize";
    string public symbol = "PRIZE";
    uint8 constant public decimals = 9;
    uint256 constant internal magnitude = 1e9;

    uint8 constant internal feePerc = 2;

    mapping(address => uint256) private tokenBalanceLedger;

    struct Stats {
       uint256 deposits;
       uint256 withdrawals;
    }

    mapping(address => Stats) public playerStats;

    uint256 public totalPlayer = 0;
    uint256 public totalDonation = 0;

    uint256 private tokenSupply = 0;
    //uint256 private contractValue = 0;
    //uint256 private tokenPrice = 10 ** uint256(decimals);

    TOKEN public erc20;

    constructor(TOKEN _erc20) public {
        erc20 = _erc20;
    }

    function() public payable {
        revert();
    }

    function checkAndTransferPION(uint256 _amount) private {
        require(erc20.transferFrom(msg.sender, address(this), _amount) == true, "transfer must succeed");
    }

    function appreciateTokenPrice(uint256 _amount) public isActivated {
        require(_amount > 0, "must be a positive value");
        checkAndTransferPION(_amount);
        totalDonation += _amount;

        emit onDistribute(msg.sender, _amount);
    }

    function buy(uint256 _amount) public returns (uint256) {
        uint256 result = purchaseTokens(msg.sender, _amount);
        checkAndTransferPION(_amount);
        return result;
    }

    function buyFor(uint256 _amount, address _customerAddress) public returns (uint256) {
        uint256 result = purchaseTokens(_customerAddress, _amount);
        checkAndTransferPION(_amount);
        return result;
    }

    function _purchaseTokens(address _customerAddress, uint256 _incomingPION) private returns(uint256) {
        uint256 tokenPrice = getPrice(false);
        uint256 _amountOfTokens = (_incomingPION.mul(magnitude)) / tokenPrice;

        require(_amountOfTokens > 0 && _amountOfTokens.add(tokenSupply) > tokenSupply);

        tokenBalanceLedger[_customerAddress] =  tokenBalanceLedger[_customerAddress].add(_amountOfTokens);
        tokenSupply = tokenSupply.add(_amountOfTokens);

        emit Transfer(address(0), _customerAddress, _amountOfTokens);

        return _amountOfTokens;
    }

    function purchaseTokens(address _customerAddress, uint256 _incomingPION) private isActivated returns (uint256) {
        if (playerStats[_customerAddress].deposits == 0) {
            totalPlayer++;
        }

        playerStats[_customerAddress].deposits += _incomingPION;

        require(_incomingPION > 0);

        uint256 _fee = _incomingPION.mul(feePerc).div(100);

        uint256 _amountOfTokens = _purchaseTokens(_customerAddress, _incomingPION.sub(_fee));

        emit onTokenPurchase(_customerAddress, _incomingPION, _amountOfTokens, block.timestamp);

        return _amountOfTokens;
    }

    function sell(uint256 _amountOfTokens) public isActivated onlyTokenHolders {
        address _customerAddress = msg.sender;

        require(_amountOfTokens > 0 && _amountOfTokens <= tokenBalanceLedger[_customerAddress]);

        uint256 _pion = _amountOfTokens.mul(getPrice(false)).div(magnitude);
        uint256 _fee = _pion.mul(feePerc).div(100);

        tokenSupply = tokenSupply.sub(_amountOfTokens);
        tokenBalanceLedger[_customerAddress] = tokenBalanceLedger[_customerAddress].sub(_amountOfTokens);

        _pion = _pion.sub(_fee);

        erc20.transfer(_customerAddress, _pion);
        playerStats[_customerAddress].withdrawals += _pion;

        emit Transfer(_customerAddress, address(0), _amountOfTokens);
        emit onTokenSell(_customerAddress, _amountOfTokens, _pion, block.timestamp);
    }

    function transfer(address _toAddress, uint256 _amountOfTokens) external isActivated onlyTokenHolders returns (bool) {
        address _customerAddress = msg.sender;

        require(_amountOfTokens > 0 && _amountOfTokens <= tokenBalanceLedger[_customerAddress]);

        uint256 _tokenFee = _amountOfTokens.mul(feePerc).div(100);
        uint256 _taxedTokens = _amountOfTokens.sub(_tokenFee);

        tokenBalanceLedger[_customerAddress] = tokenBalanceLedger[_customerAddress].sub(_amountOfTokens);
        tokenBalanceLedger[_toAddress] = tokenBalanceLedger[_toAddress].add(_taxedTokens);

        tokenSupply = tokenSupply.sub(_tokenFee);

        emit Transfer(_customerAddress, address(0), _tokenFee);
        emit Transfer(_customerAddress, _toAddress, _taxedTokens);

        return true;
    }

    function setName(string _name) public onlyOwner
    {
        name = _name;
    }

    function setSymbol(string _symbol) public onlyOwner
    {
        symbol = _symbol;
    }

    function totalPionBalance() public view returns (uint256) {
        return erc20.balanceOf(address(this));
    }

    function totalSupply() public view returns(uint256) {
        return tokenSupply;
    }

    function myTokens() public view returns (uint256) {
        address _customerAddress = msg.sender;
        return balanceOf(_customerAddress);
    }

    function balanceOf(address _customerAddress) public view returns (uint256) {
        return tokenBalanceLedger[_customerAddress];
    }

    function getPrice(bool _includeFees) private view returns (uint256) {
        uint256 _fee = 0;
        uint256 tokenPrice;
        if (tokenSupply == 0)
            tokenPrice = 10 ** uint256(decimals);
        else
            tokenPrice = totalPionBalance().mul(magnitude).div(tokenSupply);
        if (_includeFees) {
            _fee = tokenPrice.mul(feePerc).div(100);
        }

        return (tokenPrice.sub(_fee));
    }

    function calculateTokensReceived(uint256 _pionToSpend, bool _includeFees) public view returns (uint256) {
        return (_pionToSpend.mul(magnitude)).div(getPrice(_includeFees));
    }

    function pionBalanceOf(address _customerAddress) public view returns(uint256) {
        uint256 _price = getPrice(true);
        uint256 _balance = balanceOf(_customerAddress);
        uint256 _value = (_balance.mul(_price)) / magnitude;

        return _value;
    }

    function pionBalanceOfNoFee(address _customerAddress) public view returns(uint256) {
        uint256 _price = getPrice(false);
        uint256 _balance = balanceOf(_customerAddress);
        uint256 _value = (_balance.mul(_price)) / magnitude;

        return _value;
    }
}

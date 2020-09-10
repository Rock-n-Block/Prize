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
    owner = address(0xAeFeB36820bd832038E8e4F73eDbD5f48D3b4E50);
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
}

contract HRS is Ownable {
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

    event onTokenAppreciation(
        uint256 tokenPrice,
        uint256 timestamp
    );

    string public name = "Prize";
    string public symbol = "PRIZE";
    uint8 constant public decimals = 8;
    uint256 constant internal magnitude = 1e8;

    uint8 constant internal transferFee = 2;
    uint8 constant internal buyInFee = 2;
    uint8 constant internal sellOutFee = 2;

    mapping(address => uint256) private tokenBalanceLedger;

    struct Stats {
       uint256 deposits;
       uint256 withdrawals;
    }

    mapping(address => Stats) public playerStats;

    uint256 public totalPlayer = 0;
    uint256 public totalDonation = 0;

    uint256 private tokenSupply = 0;
    uint256 private contractValue = 0;
    uint256 private tokenPrice = 100000000;

    TOKEN erc20;

    constructor() public {
        erc20 = TOKEN(address(0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39));
    }

    function() payable public {
        revert();
    }

    function checkAndTransferPION(uint256 _amount) private {
        require(erc20.transferFrom(msg.sender, address(this), _amount) == true, "transfer must succeed");
    }

    function appreciateTokenPrice(uint256 _amount) isActivated public {
        require(_amount > 0, "must be a positive value");
        checkAndTransferPION(_amount);
        contractValue = contractValue.add(_amount);
        totalDonation += _amount;

        if (tokenSupply > magnitude) {
            tokenPrice = (contractValue.mul(magnitude)) / tokenSupply;
        }

        emit onDistribute(msg.sender, _amount);
        emit onTokenAppreciation(tokenPrice, now);
    }

    function buy(uint256 _amount) public returns (uint256) {
        checkAndTransferPION(_amount);
        return purchaseTokens(msg.sender, _amount);
    }

    function buyFor(uint256 _amount, address _customerAddress) public returns (uint256) {
        checkAndTransferPION(_amount);
        return purchaseTokens(_customerAddress, _amount);
    }

    function _purchaseTokens(address _customerAddress, uint256 _incomingPION) private returns(uint256) {
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

        uint256 _fee = _incomingPION.mul(buyInFee).div(100);

        uint256 _amountOfTokens = _purchaseTokens(_customerAddress, _incomingPION.sub(_fee));

        contractValue = contractValue.add(_incomingPION);

        if (tokenSupply > magnitude) {
            tokenPrice = (contractValue.mul(magnitude)) / tokenSupply;
        }

        emit onTokenPurchase(_customerAddress, _incomingPION, _amountOfTokens, now);
        emit onTokenAppreciation(tokenPrice, now);

        return _amountOfTokens;
    }

    function sell(uint256 _amountOfTokens) isActivated onlyTokenHolders public {
        address _customerAddress = msg.sender;

        require(_amountOfTokens > 0 && _amountOfTokens <= tokenBalanceLedger[_customerAddress]);

        uint256 _pion = _amountOfTokens.mul(tokenPrice).div(magnitude);
        uint256 _fee = _pion.mul(sellOutFee).div(100);

        tokenSupply = tokenSupply.sub(_amountOfTokens);
        tokenBalanceLedger[_customerAddress] = tokenBalanceLedger[_customerAddress].sub(_amountOfTokens);

        _pion = _pion.sub(_fee);

        contractValue = contractValue.sub(_pion);

        if (tokenSupply > magnitude) {
            tokenPrice = (contractValue.mul(magnitude)) / tokenSupply;
        }

        erc20.transfer(_customerAddress, _pion);
        playerStats[_customerAddress].withdrawals += _pion;

        emit Transfer(_customerAddress, address(0), _amountOfTokens);
        emit onTokenSell(_customerAddress, _amountOfTokens, _pion, now);
        emit onTokenAppreciation(tokenPrice, now);
    }

    function transfer(address _toAddress, uint256 _amountOfTokens) isActivated onlyTokenHolders external returns (bool) {
        address _customerAddress = msg.sender;

        require(_amountOfTokens > 0 && _amountOfTokens <= tokenBalanceLedger[_customerAddress]);

        uint256 _tokenFee = _amountOfTokens.mul(transferFee).div(100);
        uint256 _taxedTokens = _amountOfTokens.sub(_tokenFee);

        tokenBalanceLedger[_customerAddress] = tokenBalanceLedger[_customerAddress].sub(_amountOfTokens);
        tokenBalanceLedger[_toAddress] = tokenBalanceLedger[_toAddress].add(_taxedTokens);

        tokenSupply = tokenSupply.sub(_tokenFee);

        if (tokenSupply>magnitude)
        {
            tokenPrice = (contractValue.mul(magnitude)) / tokenSupply;
        }

        emit Transfer(_customerAddress, address(0), _tokenFee);
        emit Transfer(_customerAddress, _toAddress, _taxedTokens);
        emit onTokenAppreciation(tokenPrice, now);

        return true;
    }

    function setName(string _name) onlyOwner public
    {
        name = _name;
    }

    function setSymbol(string _symbol) onlyOwner public
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

    function sellPrice(bool _includeFees) public view returns (uint256) {
        uint256 _fee = 0;

        if (_includeFees) {
            _fee = tokenPrice.mul(sellOutFee).div(100);
        }

        return (tokenPrice.sub(_fee));
    }

    function buyPrice(bool _includeFees) public view returns(uint256) {
        uint256 _fee = 0;

        if (_includeFees) {
            _fee = tokenPrice.mul(buyInFee).div(100);
        }

        return (tokenPrice.add(_fee));
    }

    function calculateTokensReceived(uint256 _pionToSpend, bool _includeFees) public view returns (uint256) {
        uint256 _fee = 0;

        if (_includeFees) {
            _fee = _pionToSpend.mul(buyInFee).div(100);
        }

        uint256 _taxedPION = _pionToSpend.sub(_fee);
        uint256 _amountOfTokens = (_taxedPION.mul(magnitude)) / tokenPrice;

        return _amountOfTokens;
    }

    function pionBalanceOf(address _customerAddress) public view returns(uint256) {
        uint256 _price = sellPrice(true);
        uint256 _balance = balanceOf(_customerAddress);
        uint256 _value = (_balance.mul(_price)) / magnitude;

        return _value;
    }

    function pionBalanceOfNoFee(address _customerAddress) public view returns(uint256) {
        uint256 _price = sellPrice(false);
        uint256 _balance = balanceOf(_customerAddress);
        uint256 _value = (_balance.mul(_price)) / magnitude;

        return _value;
    }
}
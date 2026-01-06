pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
    // ------------------------------------------ //
    // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
    // ------------------------------------------ //
    using SafeMath for uint256;
    uint256 public totalSupply;
    uint256 public decimals = 18;
    string public name = "Test token";
    string public symbol = "TEST";
    mapping(address => uint256) public balanceOf;
    // ------------------------------------------ //
    // ----- END: DO NOT EDIT THIS SECTION ------ //
    // ------------------------------------------ //

    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) private _dividendBalances;
    address[] private _tokenHolders;
    mapping(address => bool) private _isTokenHolder;

    // IERC20

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(
        address to,
        uint256 value
    ) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(
        address spender,
        uint256 value
    ) external override returns (bool) {
        _allowances[msg.sender][spender] = value;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= value, "insufficient allowance");
        _allowances[from][msg.sender] = currentAllowance.sub(value);
        _transfer(from, to, value);
        return true;
    }

    // IMintableToken

    function mint() external payable override {
        require(msg.value > 0, "Must send ETH to mint tokens");

        if (balanceOf[msg.sender] == 0) {
            _addTokenHolder(msg.sender);
        }

        balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
        totalSupply = totalSupply.add(msg.value);
    }

    function burn(address payable dest) external override {
        uint256 balance = balanceOf[msg.sender];
        require(balance > 0, "No tokens to burn");

        balanceOf[msg.sender] = 0;
        totalSupply = totalSupply.sub(balance);

        _removeTokenHolder(msg.sender);

        dest.transfer(balance);
    }

    // IDividends

    function getNumTokenHolders() external view override returns (uint256) {
        return _tokenHolders.length;
    }

    function getTokenHolder(
        uint256 index
    ) external view override returns (address) {
        if (index == 0 || index > _tokenHolders.length) {
            return address(0);
        }
        return _tokenHolders[index - 1];
    }

    function recordDividend() external payable override {
        require(msg.value > 0, "Must send ETH for dividend");
        require(totalSupply > 0, "No tokens in circulation");

        for (uint256 i = 0; i < _tokenHolders.length; i++) {
            address holder = _tokenHolders[i];
            if (balanceOf[holder] > 0) {
                uint256 dividend = msg.value.mul(balanceOf[holder]).div(
                    totalSupply
                );
                _dividendBalances[holder] = _dividendBalances[holder].add(
                    dividend
                );
            }
        }
    }

    function getWithdrawableDividend(
        address payee
    ) external view override returns (uint256) {
        return _dividendBalances[payee];
    }

    function withdrawDividend(address payable dest) external override {
        uint256 dividend = _dividendBalances[msg.sender];
        require(dividend > 0, "No dividend to withdraw");

        _dividendBalances[msg.sender] = 0;
        dest.transfer(dividend);
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0), "transfer from zero address");
        require(to != address(0), "transfer to zero address");
        require(balanceOf[from] >= value, "insufficient balance");

        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);

        if (balanceOf[from] == 0) {
            _removeTokenHolder(from);
        }
        if (balanceOf[to] > 0 && !_isTokenHolder[to]) {
            _addTokenHolder(to);
        }
    }

    function _addTokenHolder(address holder) internal {
        if (!_isTokenHolder[holder]) {
            _tokenHolders.push(holder);
            _isTokenHolder[holder] = true;
        }
    }

    function _removeTokenHolder(address holder) internal {
        if (_isTokenHolder[holder]) {
            for (uint256 i = 0; i < _tokenHolders.length; i++) {
                if (_tokenHolders[i] == holder) {
                    _tokenHolders[i] = _tokenHolders[_tokenHolders.length - 1];
                    _tokenHolders.pop();
                    _isTokenHolder[holder] = false;
                    break;
                }
            }
        }
    }
}

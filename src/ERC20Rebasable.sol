// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import { IERC20Rebasable } from "src/interfaces/IERC20Rebasable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

/**
 * @title ERC20Rebasable
 * @dev This abstract contract is an extension of the ERC20 contract that allows for rebasing of the token supply.
 */
abstract contract ERC20Rebasable is ERC20Permit, IERC20Rebasable {
    using Math for uint256;

    /**
     * @notice the total supply is redefined over time. Each user has a share of the total supply.
     * @dev balanceOf(user) = sharesOf[user] * totalSupply() / totalShare
     */
    mapping(address => uint256) internal _sharesOf;

    /// @dev total shares of the contract
    uint256 internal _totalShares;

    /// @dev blacklist for addresses that should not trigger a total supply update
    mapping(address => bool) internal _blacklistForUpdateSupply;

    /// @inheritdoc IERC20Rebasable
    uint256 public constant SHARES_PRECISION_FACTOR = 1e3;

    constructor(string memory name, string memory symbol, uint256 initialSupply)
        ERC20(name, symbol)
        ERC20Permit(name)
    {
        _sharesOf[msg.sender] = initialSupply * SHARES_PRECISION_FACTOR;
        _totalShares = initialSupply * SHARES_PRECISION_FACTOR;
    }

    /* -------------------------------------------------------------------------- */
    /*                             external functions                             */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IERC20Rebasable
    function totalShares() external view override returns (uint256) {
        return _totalShares;
    }

    /// @inheritdoc IERC20Rebasable
    function sharesOf(address user) external view returns (uint256) {
        return _sharesOf[user];
    }

    /// @inheritdoc IERC20Rebasable
    function transferShares(address to, uint256 shares) external returns (bool) {
        return _transferShares(msg.sender, to, shares, sharesToToken(shares));
    }

    /// @inheritdoc IERC20Rebasable
    function transferSharesFrom(address from, address to, uint256 shares) external returns (bool) {
        // round up the token amount to decrease the allowance in all cases
        uint256 tokenAmount = _sharesToTokenUp(shares);

        if (tokenAmount == 0 && shares > 0) {
            tokenAmount += 1;
        }

        _spendAllowance(from, msg.sender, tokenAmount);

        return _transferShares(from, to, shares, tokenAmount);
    }

    /// @inheritdoc IERC20Rebasable
    function updateTotalSupply() external virtual;

    /* -------------------------------------------------------------------------- */
    /*                              public functions                              */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IERC20Permit
    function nonces(address owner) public view virtual override(ERC20Permit, IERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) public view virtual override(ERC20, IERC20) returns (uint256) {
        return sharesToToken(_sharesOf[account]);
    }

    /// @inheritdoc IERC20Rebasable
    function tokenToShares(uint256 amount) public view returns (uint256) {
        return tokenToShares(amount, _totalShares, totalSupply());
    }

    /// @inheritdoc IERC20Rebasable
    function tokenToShares(uint256 amount, uint256 newTotalShares, uint256 newTotalSupply)
        public
        pure
        returns (uint256)
    {
        return amount.mulDiv(newTotalShares, newTotalSupply);
    }

    /// @inheritdoc IERC20Rebasable
    function sharesToToken(uint256 shares) public view returns (uint256 tokenAmount_) {
        tokenAmount_ = sharesToToken(shares, _totalShares, totalSupply());
    }

    /// @inheritdoc IERC20Rebasable
    function sharesToToken(uint256 shares, uint256 newTotalShares, uint256 newTotalSupply)
        public
        pure
        returns (uint256 tokenAmount_)
    {
        // we round down to be conservative
        tokenAmount_ = shares.mulDiv(newTotalSupply, newTotalShares);
    }

    /* -------------------------------------------------------------------------- */
    /*                             internal functions                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Transfer tokens to a specified address by specifying the amount of shares.
     * @param from The address to transfer the tokens from.
     * @param to The address to transfer the tokens to.
     * @param shareAmount The amount of shares to be transferred.
     * @param tokenAmount The amount of token corresponding to the amount of shares (not verified, used for events)
     * @return True if the transfer was successful, revert otherwise.
     * @dev this function updates the total supply by calling `updateTotalSupply()`
     */
    function _transferShares(address from, address to, uint256 shareAmount, uint256 tokenAmount)
        internal
        returns (bool)
    {
        if (from == address(0)) {
            revert ERC20InvalidSender(from);
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(to);
        }
        if (shareAmount > _sharesOf[from]) {
            revert ERC20InsufficientBalance(from, sharesToToken(_sharesOf[from]), tokenAmount);
        }

        if (
            !_blacklistForUpdateSupply[from] && !_blacklistForUpdateSupply[to] && !_blacklistForUpdateSupply[msg.sender]
        ) {
            // slither-disable-next-line reentrancy-no-eth
            try this.updateTotalSupply() { } catch { }
        }

        _sharesOf[from] -= shareAmount;
        _sharesOf[to] += shareAmount;

        emit Transfer(from, to, tokenAmount);
        return true;
    }

    /**
     * @inheritdoc ERC20
     * @dev mint and burn will revert, use _mintShares for that, or modify the totalSupply
     */
    function _update(address from, address to, uint256 value) internal override {
        _transferShares(from, to, tokenToShares(value), value);
    }

    /// @inheritdoc ERC20
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal override {
        try this.updateTotalSupply() { } catch { }
        super._approve(owner, spender, value, emitEvent);
    }

    /**
     * @notice Mint shares to an account.
     * @param account The account to mint the shares to.
     * @param shares The number of shares to mint.
     */
    function _mintShares(address account, uint256 shares) internal virtual {
        _sharesOf[account] += shares;
        _totalShares += shares;
    }

    function _sharesToTokenUp(uint256 shares) internal view returns (uint256 tokenAmount_) {
        tokenAmount_ = shares.mulDiv(totalSupply(), _totalShares, Math.Rounding.Ceil);
    }
}

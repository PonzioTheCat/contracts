// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import { IPonzioTheCat } from "src/interfaces/IPonzioTheCat.sol";
import { IWrappedPonzioTheCat } from "src/interfaces/IWrappedPonzioTheCat.sol";

/**
 * @title WrappedPonzioTheCat
 * @notice Implementation of the WrappedPonzioTheCat.
 * This contract is used to wrap and unwrap the Ponzio.
 */
contract WrappedPonzioTheCat is IWrappedPonzioTheCat, ERC20Permit {
    /// @notice The Ponzio contract.
    IPonzioTheCat private immutable _asset;
    /// @notice The precision factor of the shares of the Ponzio contract.
    uint256 private immutable SHARES_PRECISION_FACTOR;

    constructor(IPonzioTheCat token) ERC20("Wrapped Ponzio The Cat", "WPONZIO") ERC20Permit("Wrapped Ponzio The Cat") {
        _asset = token;
        SHARES_PRECISION_FACTOR = token.SHARES_PRECISION_FACTOR();
    }

    /* -------------------------------------------------------------------------- */
    /*                             external functions                             */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IWrappedPonzioTheCat
    function asset() external view returns (IPonzioTheCat) {
        return _asset;
    }

    /// @inheritdoc IWrappedPonzioTheCat
    function previewWrap(uint256 assets, uint256 newTotalShares, uint256 newTotalSupply)
        external
        view
        returns (uint256 amount_)
    {
        amount_ = _asset.tokenToShares(assets, newTotalShares, newTotalSupply) / SHARES_PRECISION_FACTOR;
    }

    /// @inheritdoc IWrappedPonzioTheCat
    function wrap(uint256 assets) external returns (uint256 amount_) {
        amount_ = _wrap(msg.sender, assets, msg.sender);
    }

    /// @inheritdoc IWrappedPonzioTheCat
    function wrap(uint256 assets, address receiver) external returns (uint256 amount_) {
        amount_ = _wrap(msg.sender, assets, receiver);
    }

    /// @inheritdoc IWrappedPonzioTheCat
    function wrapShares(uint256 shares, address receiver) external returns (uint256 amount_) {
        amount_ = _wrap(msg.sender, _asset.sharesToToken(shares), receiver);
    }

    /// @inheritdoc IWrappedPonzioTheCat
    function previewUnwrap(uint256 amount) external view returns (uint256 assets_) {
        uint256 shares = amount * SHARES_PRECISION_FACTOR;
        assets_ = _asset.sharesToToken(shares);
    }

    /// @inheritdoc IWrappedPonzioTheCat
    function previewUnwrap(uint256 amount, uint256 newTotalShares, uint256 newTotalSupply)
        external
        view
        returns (uint256 assets_)
    {
        uint256 shares = amount * SHARES_PRECISION_FACTOR;
        assets_ = _asset.sharesToToken(shares, newTotalShares, newTotalSupply);
    }

    /// @inheritdoc IWrappedPonzioTheCat
    function unwrap(uint256 amount) external returns (uint256 assets_) {
        assets_ = _unwrap(msg.sender, amount, msg.sender);
    }

    /// @inheritdoc IWrappedPonzioTheCat
    function unwrap(uint256 amount, address receiver) external returns (uint256 assets_) {
        assets_ = _unwrap(msg.sender, amount, receiver);
    }

    /* -------------------------------------------------------------------------- */
    /*                              public functions                              */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IWrappedPonzioTheCat
    function previewWrap(uint256 assets) public view returns (uint256 amount_) {
        amount_ = _asset.tokenToShares(assets) / SHARES_PRECISION_FACTOR;
    }

    /* -------------------------------------------------------------------------- */
    /*                             internal functions                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Wraps the underlying asset into the wrapped token.
     * @param from The address from which the underlying assets are transferred.
     * @param assets The amount of underlying assets to be wrapped.
     * @param receiver The address to which the wrapped tokens are minted.
     * @return amount_ The amount of wrapped tokens minted.
     * @dev This function first calculates the amount of wrapped tokens that will be minted using the `previewWrap`
     * function (assets / SHARES_PRECISION_FACTOR).
     * It then calculates the amount of shares that will be transferred to this contract
     * (amount * SHARES_PRECISION_FACTOR), transfers the underlying shares from the `from` address to this contract and
     * mints the wrapped tokens to the `receiver` address.
     */
    function _wrap(address from, uint256 assets, address receiver) internal returns (uint256 amount_) {
        amount_ = previewWrap(assets);
        uint256 shares = amount_ * SHARES_PRECISION_FACTOR;
        _asset.transferSharesFrom(from, address(this), shares);
        _mint(receiver, amount_);
    }

    /**
     * @dev Unwraps the wrapped tokens into the underlying asset.
     * @param owner The address from which the wrapped tokens are burnt.
     * @param amount The amount of wrapped tokens to be unwrapped.
     * @param receiver The address to which the underlying assets are transferred.
     * @return assets_ The amount of underlying assets transferred.
     * @dev This function first calculates the amount of shares that will be sent to the `receiver`
     * (amount * SHARES_PRECISION_FACTOR).
     * It then burns the wrapped tokens from the `owner` address and transfers the shares to the `receiver` address.
     */
    function _unwrap(address owner, uint256 amount, address receiver) internal returns (uint256 assets_) {
        uint256 shares = amount * SHARES_PRECISION_FACTOR;
        _burn(owner, amount);
        _asset.transferShares(receiver, shares);

        assets_ = _asset.sharesToToken(shares);
    }
}

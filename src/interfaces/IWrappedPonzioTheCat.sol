// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { IPonzioTheCat } from "src/interfaces/IPonzioTheCat.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWrappedPonzioTheCat is IERC20 {
    /// @notice Returns the underlying asset of the wrapped token.
    function asset() external view returns (IPonzioTheCat);

    /**
     * @notice Returns the amount of wrapped tokens that will be minted when wrapping the underlying assets given the
     * new total shares and total supply.
     * @param assets The amount of underlying assets to be wrapped.
     * @param newTotalShares The new total shares of the wrapped token.
     * @param newTotalSupply The new total supply of the wrapped token.
     * @return amount_ The amount of wrapped tokens that will be minted.
     */
    function previewWrap(uint256 assets, uint256 newTotalShares, uint256 newTotalSupply)
        external
        view
        returns (uint256 amount_);

    /**
     * @notice Wraps the underlying assets into the wrapped token.
     * @param assets The amount of underlying assets to be wrapped.
     * @return amount_ The amount of wrapped tokens minted.
     */
    function wrap(uint256 assets) external returns (uint256 amount_);

    /**
     * @notice Wraps the underlying assets into the wrapped token and mints them to the receiver.
     * @param assets The amount of underlying assets to be wrapped.
     * @param receiver The address to which the wrapped tokens are minted.
     * @return amount_ The amount of wrapped tokens minted.
     */
    function wrap(uint256 assets, address receiver) external returns (uint256 amount_);

    /**
     * @notice Wraps the underlying shares into the wrapped token and mints them to the receiver.
     * @param shares The amount of underlying shares to be wrapped.
     * @param receiver The address to which the wrapped tokens are minted.
     * @return amount_ The amount of wrapped tokens minted.
     */
    function wrapShares(uint256 shares, address receiver) external returns (uint256 amount_);

    /**
     * @notice Returns the amount of underlying assets that will be received when unwrapping the wrapped tokens.
     * @param amount The amount of wrapped tokens to be unwrapped.
     * @return assets_ The amount of underlying assets that will be received.
     */
    function previewUnwrap(uint256 amount) external view returns (uint256 assets_);

    /**
     * @notice Returns the amount of underlying assets that will be received when unwrapping the wrapped tokens given
     * the new total shares and total supply.
     * @param amount The amount of wrapped tokens to be unwrapped.
     * @param newTotalShares The new total shares of the wrapped token.
     * @param newTotalSupply The new total supply of the wrapped token.
     * @return assets_ The amount of underlying assets that will be received.
     */
    function previewUnwrap(uint256 amount, uint256 newTotalShares, uint256 newTotalSupply)
        external
        view
        returns (uint256 assets_);

    /**
     * @notice Unwraps the wrapped tokens into the underlying assets.
     * @param amount The amount of wrapped tokens to be unwrapped.
     * @return assets_ The amount of underlying assets received.
     */
    function unwrap(uint256 amount) external returns (uint256 assets_);

    /**
     * @notice Unwraps the wrapped tokens into the underlying assets and sends them to the receiver.
     * @param amount The amount of wrapped tokens to be unwrapped.
     * @param receiver The address to which the underlying assets are sent.
     * @return assets_ The amount of underlying assets received.
     */
    function unwrap(uint256 amount, address receiver) external returns (uint256 assets_);

    /**
     * @notice Returns the amount of wrapped tokens that will be minted when wrapping the underlying assets.
     * @param assets The amount of underlying assets to be wrapped.
     * @return amount_ The amount of wrapped tokens that will be minted.
     */
    function previewWrap(uint256 assets) external view returns (uint256 amount_);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IPonzioTheCat } from "src/interfaces/IPonzioTheCat.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRouter {
    /// @notice Revert when the user sent a value but it wasn't needed
    error Router_valueNotNeeded();

    /// @notice Revert when no value was added to the transaction but it was needed
    error Router_valueNeeded();

    /**
     * @notice Revert when the user passes an invalid path (length < 2).
     * @param path the invalid array of addresses
     */
    error Router_invalidPath(address[] path);

    /// @notice Revert when the refund in addLiquidity fails.
    error Router_refundFailed();

    /// @notice Revert when the amount isn't enough in addLiquidity.
    error Router_insufficientAmount();

    /// @notice Revert when the calculation of liquidity to add fails.
    error Router_liquidityError();

    /**
     * @notice Returns the address of the staking token.
     * @return IERC20 address of the staking token
     */
    function LP_TOKEN() external view returns (IERC20);

    /**
     * @notice Returns the address of the Ponzio.
     * @return IPonzioTheCat address of the Ponzio
     */
    function PONZIO() external view returns (IPonzioTheCat);

    /**
     * @notice Update the supply of Ponzio and add liquidity to the pair.
     * @param amountWETHDesired The amount of WETH the user wants to add as liquidity.
     * @param amountPonzioDesired The amount of Ponzio token the user wants to add as liquidity.
     * @param amountETHMin The minimum amount of ETH/WETH the user wants to add as liquidity.
     * @param amountPonzioMin The minimum amount of Ponzio token the user wants to add as liquidity.
     * @param to The address to which the liquidity tokens will be minted.
     * @return amountPonzio_ The actual amount of Ponzio token added as liquidity.
     * @return amountETH_ The actual amount of ETH (or equivalent) added as liquidity.
     * @return liquidity_ The amount of liquidity tokens minted.
     * @dev amountWETHDesired = 0 when adding liquidity with ETH
     */
    function updateSupplyAndAddLiquidity(
        uint256 amountWETHDesired,
        uint256 amountPonzioDesired,
        uint256 amountETHMin,
        uint256 amountPonzioMin,
        address to
    ) external payable returns (uint256 amountPonzio_, uint256 amountETH_, uint256 liquidity_);

    /**
     * @notice Swaps a certain `amountIn` of a token for another token, ensuring a minimum output `amountOutMin`.
     * @param amountIn The amount of input tokens to be sent.
     * @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
     * @param path An array of token addresses. The path[0] address is the input token and the last address is the
     * output token.
     * @param to The address to send the output tokens to.
     * @param deadline The time after which the swap is invalid.
     *
     * @dev :
     * This function supports both ETH and ERC20 tokens as input and output. The address
     * 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE is used as a placeholder for ETH.
     * If the input token is ETH, it is replaced with the actual WETH address and
     * `swapExactETHForTokensSupportingFeeOnTransferTokens` is called.
     * If the output token is ETH, it is replaced with the actual WETH address and
     * `swapExactTokensForETHSupportingFeeOnTransferTokens` is called.
     * Otherwise, `swapExactTokensForTokensSupportingFeeOnTransferTokens` is called.
     *
     * If there is any ETH balance left in the contract, it is sent back to the caller.
     *
     * Requirements:
     * - The `path` must have at least two addresses.
     * - The sender must have approved this contract to spend the input tokens.
     */
    function swap(uint256 amountIn, uint256 amountOutMin, address[] memory path, address to, uint256 deadline)
        external
        payable;
}

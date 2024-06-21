// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface IERC20Rebasable is IERC20, IERC20Permit {
    /**
     * @notice returns the precision factor for shares.
     * @return The precision factor for shares.
     */
    function SHARES_PRECISION_FACTOR() external view returns (uint256);

    /**
     * @notice returns the total shares.
     * @return The total shares.
     */
    function totalShares() external view returns (uint256);

    /**
     * @notice returns the share of the user.
     * @param user The address of the user to get the share of.
     * @return The share of the user.
     */
    function sharesOf(address user) external view returns (uint256);

    /**
     * @notice Transfer tokens to a specified address by specifying the share amount.
     * @param to The address to transfer the tokens to.
     * @param shares The amount of shares to be transferred.
     * @return True if the transfer was successful, revert otherwise.
     */
    function transferShares(address to, uint256 shares) external returns (bool);

    /**
     * @notice Transfer shares from a specified address to another specified address.
     * @param from The address to transfer the shares from.
     * @param to The address to transfer the shares to.
     * @param shares The amount of shares to be transferred.
     * @return True if the transfer was successful, revert otherwise.
     * @dev This function tries to update the total supply by calling `updateTotalSupply()`
     */
    function transferSharesFrom(address from, address to, uint256 shares) external returns (bool);

    /**
     * @notice update the total supply, compute the debase accordingly and transfer the fees to the feesCollector.
     * @dev This function is already called at each approval and transfer. It needs to be implemented by a child
     * contract
     */
    function updateTotalSupply() external;

    /**
     * @notice Convert tokens to shares.
     * @param amount The amount of tokens to convert to shares.
     * @return shares_ The number of shares corresponding to the tokens.
     */
    function tokenToShares(uint256 amount) external view returns (uint256 shares_);

    /**
     * @notice Convert tokens to shares given the new total shares and total supply.
     * @param amount The amount of tokens to convert to shares.
     * @param newTotalShares The new total shares.
     * @param newTotalSupply The new total supply.
     * @return shares_ The number of shares corresponding to the tokens.
     */
    function tokenToShares(uint256 amount, uint256 newTotalShares, uint256 newTotalSupply)
        external
        view
        returns (uint256 shares_);

    /**
     * @notice Convert shares to tokens.
     * @param shares The amount of shares to convert to tokens.
     * @return tokenAmount_ The amount of tokens corresponding to the shares.
     */
    function sharesToToken(uint256 shares) external view returns (uint256 tokenAmount_);

    /**
     * @notice Convert shares to tokens given the new total shares and total supply.
     * @param shares The amount of shares to convert to tokens.
     * @param newTotalShares The new total shares.
     * @param newTotalSupply The new total supply.
     * @return tokenAmount_ The amount of tokens corresponding to the shares.
     */
    function sharesToToken(uint256 shares, uint256 newTotalShares, uint256 newTotalSupply)
        external
        view
        returns (uint256 tokenAmount_);
}

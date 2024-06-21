// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { IERC20Rebasable } from "src/interfaces/IERC20Rebasable.sol";
import { IUniswapV2Pair } from "src/interfaces/UniswapV2/IUniswapV2Pair.sol";

interface IPonzioTheCat is IERC20Rebasable {
    /// @notice Error code is thrown when the contract is being initialized a 2nd time.
    error PONZIO_alreadyInitialized();

    /// @notice Error code thrown in setFeesCollector when the contract has not been initialized yet.
    error PONZIO_notInitialized();

    /// @notice Error code thrown in setFeesCollector when the new feesCollector is the zero address.
    error PONZIO_feeCollectorZeroAddress();

    /**
     * @notice Emitted when the max shares are reached.
     * @param timestamp The timestamp at which the maximum is reached.
     */
    event MaxSharesReached(uint256 timestamp);

    /**
     * @notice Emitted FeesCollector changes.
     * @param feesCollector The new feesCollector.
     * It's ok to set the feesCollector to the zero address, in which case no fees will be collected.
     */
    event FeesCollectorSet(address indexed feesCollector);

    /**
     * @notice Emitted when the Uniswap V2 pair address is set.
     * @param uniV2PoolPair The new uniV2PoolPair.
     */
    event UniV2PoolPairSet(address indexed uniV2PoolPair);

    /**
     * @notice Emitted when an account is blacklisted for UpdateTotalSupply.
     * @param account The account that is blacklisted.
     * @param value The new value of the blacklist.
     */
    event BlacklistForUpdateSupplySet(address indexed account, bool indexed value);

    /**
     * @notice Emitted when the total supply is updated.
     * @param oldTotalSupply The old total supply.
     * @param newTotalSupply The new total supply.
     * @param oldTotalShare The old total share.
     * @param newTotalShare The new total share.
     * @param fees The fees collected.
     */
    event TotalSupplyUpdated(
        uint256 oldTotalSupply, uint256 newTotalSupply, uint256 oldTotalShare, uint256 newTotalShare, uint256 fees
    );

    /**
     * @notice Initial supply of the token.
     * @return The initial supply of the token.
     */
    function INITIAL_SUPPLY() external view returns (uint256);

    /**
     * @notice Time between each halving.
     * @return The time between each halving.
     */
    function HALVING_EVERY() external view returns (uint256);

    /**
     * @notice Time between each debasing.
     * @return The time between each debasing.
     */
    function DEBASE_EVERY() external view returns (uint256);

    /**
     * @notice Number of debasing per halving.
     * @return The number of debasing per halving.
     */
    function NB_DEBASE_PER_HALVING() external view returns (uint256);

    /**
     * @notice Minimum total supply. When the total supply reaches this value, it can't go lower.
     * @return The minimum total supply.
     */
    function MINIMUM_TOTAL_SUPPLY() external view returns (uint256);

    /**
     * @notice The time at which the contract was deployed.
     * @return The time at which the contract was deployed.
     */
    function DEPLOYED_TIME() external view returns (uint256);

    /**
     * @notice Fees collected on each debasing, in FEES_BASE percent.
     * @return The fees collected on each debasing.
     */
    function FEES_STAKING() external view returns (uint256);

    /**
     * @notice The fee base used for FEES_STAKING
     * @return The fee base
     */
    function FEES_BASE() external view returns (uint256);

    /**
     * @notice The address that collects the fees (the staking contract)
     * @return The address that collects the fees
     */
    function feesCollector() external view returns (address);

    /**
     * @notice returns if the max shares are reached.
     * @return True if the max shares are reached, false otherwise.
     * @dev The max shares are reached when the total of shares is about to overflow.
     * When reached, fees are not collected anymore.
     */
    function maxSharesReached() external view returns (bool);

    /**
     * @notice The Uniswap V2 pair to sync when debasing.
     * @return The Uniswap V2 pair.
     */
    function uniswapV2Pair() external view returns (IUniswapV2Pair);

    /**
     * @notice Changes the Uniswap V2 pair address.
     * @param uniV2PoolAddr_ The new Uniswap V2 pair address.
     * @dev Set the Uniswap V2 pair address to zero address to disable syncing.
     */
    function setUniswapV2Pair(address uniV2PoolAddr_) external;

    /**
     * @notice Changes the fees collector.
     * @param feesCollector_ The new fees collector.
     */
    function setFeesCollector(address feesCollector_) external;

    /**
     * @notice Blacklist an address for UpdateTotalSupply.
     * @param addrToBlacklist The address to blacklist.
     * @param value The new value of the blacklist.
     */
    function setBlacklistForUpdateSupply(address addrToBlacklist, bool value) external;

    /**
     * @notice Initialize the contract by setting the fees collector and staking the first amount of tokens.
     * @param feesCollector_ The address that will collect the fees.
     * @param uniV2PoolAddr_ The address of the uniswap V2 pool.
     */
    function initialize(address feesCollector_, address uniV2PoolAddr_) external;

    /**
     * @notice Return the real-time balance of an account after an UpdateTotalSupply() call.
     * @param account_ The account to check the balance of.
     * @return balance_ The real-time balance of the account.
     * @dev This function will only return the right balance if the feesCollector is set.
     */
    function realBalanceOf(address account_) external view returns (uint256 balance_);

    /**
     * @notice Compute the total supply and the fees to collect.
     * @return totalSupply_ The new total supply.
     * @return fees_ The fees to collect.
     */
    function computeSupply() external view returns (uint256 totalSupply_, uint256 fees_);

    /**
     * @notice Compute the total shares, supply and the fees to collect.
     * @return totalShares_ The new total shares.
     * @return totalSupply_ The new total supply.
     * @return fees_ The fees to collect.
     */
    function computeNewState() external view returns (uint256 totalShares_, uint256 totalSupply_, uint256 fees_);
}

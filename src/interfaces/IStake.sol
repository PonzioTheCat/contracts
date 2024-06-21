// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { IPonzioTheCat } from "src/interfaces/IPonzioTheCat.sol";
import { IWrappedPonzioTheCat } from "src/interfaces/IWrappedPonzioTheCat.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStake {
    /**
     * @notice Information about each staker's balance and reward debt.
     * @param amount staked amount
     * @param rewardDebt reward debt of the user used to calculate the pending rewards
     */
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    /**
     * @notice Emitted when a user deposits LP tokens to the contract.
     * @param recipient address of the recipient
     * @param depositBy address of the msg.sender
     * @param amount amount of deposited tokens
     */
    event Deposit(address indexed recipient, address depositBy, uint256 amount);

    /**
     * @notice Emitted when a user withdraws LP tokens from the contract.
     * @param user address of the user
     * @param recipient address of the recipient
     * @param amount amount of withdrawn tokens
     */
    event Withdraw(address indexed user, address recipient, uint256 amount);

    /**
     * @notice Emitted when a user claims rewards from the contract.
     * @param user address of the user
     * @param recipient address of the recipient
     * @param reward amount of claimed tokens
     */
    event ClaimReward(address indexed user, address recipient, uint256 reward);

    /**
     * @notice Emitted when a user forces the withdrawal of LP tokens from the contract.
     * @param user address of the user
     * @param amount amount of withdrawn LP tokens
     */
    event EmergencyWithdraw(address indexed user, uint256 amount);

    /**
     * @notice Emitted when the contract is skimmed.
     * @param user address of the user
     * @param amount amount of skimmed lp tokens
     */
    event Skim(address indexed user, uint256 amount);

    /// @notice Reverted when the user tries to deposit an amount of 0 tokens.
    error Stake_depositZeroAmount();

    /// @notice Reverted when the user tries to withdraw an amount of 0 tokens.
    error Stake_withdrawZeroAmount();

    /// @notice Revert when the refund fails.
    error Stake_refundFailed();

    /// @notice Revert when the refund fails.
    error Stake_noPendingRewards();

    /// @notice Revert when no value was added to the transaction but it was needed
    error Stake_valueNeeded();

    /**
     * @notice Revert when the user tries to withdraw an amount higher than the staked amount.
     * @param withdrawAmount amount the user tries to withdraw
     * @param stakedAmount amount the user has staked
     */
    error Stake_withdrawTooHigh(uint256 withdrawAmount, uint256 stakedAmount);

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
     * @notice Returns the address of the Ponzio token vault.
     * @return IWrappedPonzioTheCat address of the Ponzio token vault
     */
    function WRAPPED_PONZIO() external view returns (IWrappedPonzioTheCat);

    /**
     * @notice Returns the staked amount and the reward debt of a user.
     * @param user address of the user
     * @return struct containing the user's staked amount and reward debt
     */
    function userInfo(address user) external view returns (UserInfo memory);

    /**
     * @notice Returns the precision factor used to compute the reward per share.
     * @return The precision factor.
     */
    function PRECISION_FACTOR() external view returns (uint256);

    /**
     * @notice Reinvests the user's rewards by adding liquidity to the Uniswap pair and staking the LP tokens.
     * @param amountPonzioMin The minimum amount of Ponzio tokens the user wants to add as liquidity.
     * @param amountEthMin The minimum amount of ETH the user wants to add as liquidity.
     *
     * This function first harvests the user's rewards.
     *
     * It then adds liquidity to the Uniswap pair with the harvested rewards and the ETH sent by the user. The LP
     * tokens received from adding liquidity are then staked.
     *
     * If there are any ETH or Ponzio tokens left in the contract, they are sent back to the user.
     *
     * Requirement:
     * - The `msg.value` (amount of ETH sent) must not be zero.
     */
    function reinvest(uint256 amountPonzioMin, uint256 amountEthMin) external payable;

    /**
     * @notice Returns the reward amount that a user has pending to claim.
     * @param userAddr address of the user
     * @return rewards_ amount of pending rewards
     */
    function pendingRewards(address userAddr) external view returns (uint256 rewards_);

    /**
     * @notice Deposits staking tokens to the contract.
     * @param amount amount of staking tokens to deposit
     * @param recipient address of the recipient
     */
    function deposit(uint256 amount, address recipient) external;

    /**
     * @notice Withdraws staking tokens from the contract.
     * @param amount amount of staking tokens to withdraw
     * @param recipient address of the recipient
     */
    function withdraw(uint256 amount, address recipient) external;

    /**
     * @notice Updates the pool and sends the pending reward amount of msg.sender.
     * @param recipient address of the recipient
     */
    function harvest(address recipient) external;

    /**
     * @notice Convert all rewards to vault tokens
     * @dev Only call the vault if the balance is not zero
     */
    function sync() external;

    /**
     * @notice Function to force the withdrawal of LP tokens from the contract.
     * @dev This function is used to withdraw the LP tokens in case of emergency.
     * It will send the LP tokens to the user without claiming the rewards.
     */
    function emergencyWithdraw() external;

    /**
     * @notice Function to skim any excess lp tokens sent to the contract.
     * @dev Receiver is msg.sender
     */
    function skim() external;
}

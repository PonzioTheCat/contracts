// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IStake } from "src/interfaces/IStake.sol";
import { IPonzioTheCat } from "src/interfaces/IPonzioTheCat.sol";
import { IWrappedPonzioTheCat } from "src/interfaces/IWrappedPonzioTheCat.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Router02 } from "src/interfaces/UniswapV2/IUniswapV2Router02.sol";

/**
 * @title Stake
 * @notice This contract allows users to stake LP tokens and earn rewards.
 */
contract Stake is IStake, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for IPonzioTheCat;
    using SafeERC20 for IERC20;

    /// @inheritdoc IStake
    IERC20 public immutable LP_TOKEN;
    /// @inheritdoc IStake
    IPonzioTheCat public immutable PONZIO;
    /// @inheritdoc IStake
    IWrappedPonzioTheCat public immutable WRAPPED_PONZIO;
    /// @inheritdoc IStake
    uint256 public constant PRECISION_FACTOR = 1e18;

    /// @notice the address of the Uniswap V2 Router
    address internal constant UNISWAPV2_ROUTER_ADDR = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    /// @notice Mapping from user address to UserInfo
    mapping(address => UserInfo) internal _userInfo;
    ///@notice internal data used to compute the number of rewards to distribute to each staker.
    uint256 internal _accRewardPerShare;
    /// @notice the last reward amount
    uint256 internal _lastRewardAmount;
    /// @notice the LP_TOKEN balance
    uint256 internal _lpBalance;

    constructor(address lpToken, address wrappedPonzioTheCatAddress) {
        LP_TOKEN = IERC20(lpToken);
        WRAPPED_PONZIO = IWrappedPonzioTheCat(wrappedPonzioTheCatAddress);
        PONZIO = IWrappedPonzioTheCat(wrappedPonzioTheCatAddress).asset();
    }

    receive() external payable { }

    /* -------------------------------------------------------------------------- */
    /*                             external functions                             */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IStake
    function userInfo(address userAddr) external view returns (UserInfo memory) {
        return _userInfo[userAddr];
    }

    /// @inheritdoc IStake
    function reinvest(uint256 amountPonzioMin, uint256 amountEthMin) external payable nonReentrant {
        if (msg.value == 0) {
            revert Stake_valueNeeded();
        }

        uint256 balanceBefore = PONZIO.balanceOf(address(this));
        // first harvest the user rewards
        _harvest(_userInfo[msg.sender], msg.sender, address(this));
        uint256 amountPonzio = PONZIO.balanceOf(address(this)) - balanceBefore;

        // slither-disable-next-line incorrect-equality
        if (amountPonzio == 0) {
            revert Stake_noPendingRewards();
        }

        if (PONZIO.allowance(address(this), UNISWAPV2_ROUTER_ADDR) < amountPonzio) {
            PONZIO.forceApprove(UNISWAPV2_ROUTER_ADDR, type(uint256).max);
        }

        (uint256 amountPonzioDeposited, uint256 amountETHDeposited, uint256 liquidity) = IUniswapV2Router02(
            UNISWAPV2_ROUTER_ADDR
        ).addLiquidityETH{ value: msg.value }(
            address(PONZIO), amountPonzio, amountPonzioMin, amountEthMin, address(this), block.timestamp
        );

        // stake the LP
        _deposit(liquidity, msg.sender, address(this));

        if (amountPonzioDeposited < amountPonzio) {
            PONZIO.safeTransfer(msg.sender, amountPonzio - amountPonzioDeposited);
        }

        if (amountETHDeposited < msg.value) {
            (bool success,) = msg.sender.call{ value: msg.value - amountETHDeposited }("");
            if (!success) {
                revert Stake_refundFailed();
            }
        }
    }

    /// @inheritdoc IStake
    function pendingRewards(address userAddr) external view returns (uint256 pendingRewards_) {
        UserInfo memory userInfoMem = _userInfo[userAddr];
        // slither-disable-next-line incorrect-equality
        if (userInfoMem.amount == 0) {
            return 0;
        }

        (uint256 newTotalShares, uint256 newTotalSupply, uint256 fees) = PONZIO.computeNewState();

        uint256 wrappedRewards = 0;
        if (PONZIO.feesCollector() == address(this) && fees != 0) {
            wrappedRewards = WRAPPED_PONZIO.previewWrap(fees, newTotalShares, newTotalSupply);
        }

        (uint256 accRewardPerShare,) = _getUpdatedRewardPerShare(wrappedRewards);
        uint256 pendingRewardsShares_ = _pendingRewards(userInfoMem, accRewardPerShare);
        pendingRewards_ = WRAPPED_PONZIO.previewUnwrap(pendingRewardsShares_, newTotalShares, newTotalSupply);
    }

    /// @inheritdoc IStake
    function deposit(uint256 amount, address recipient) external nonReentrant {
        _deposit(amount, recipient, msg.sender);
    }

    /// @inheritdoc IStake
    function withdraw(uint256 amount, address recipient) external nonReentrant {
        _withdraw(amount, recipient);
    }

    /// @inheritdoc IStake
    function harvest(address recipient) external nonReentrant {
        _harvest(_userInfo[msg.sender], msg.sender, recipient);
    }

    /// @inheritdoc IStake
    function sync() external {
        uint256 rewardBalance = PONZIO.balanceOf(address(this));

        if (rewardBalance != 0) {
            if (PONZIO.allowance(address(this), address(WRAPPED_PONZIO)) < rewardBalance) {
                PONZIO.forceApprove(address(WRAPPED_PONZIO), type(uint256).max);
            }
            // slither-disable-next-line unused-return
            WRAPPED_PONZIO.wrap(rewardBalance, address(this));
        }
    }

    /// @inheritdoc IStake
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = _userInfo[msg.sender];
        uint256 amount = user.amount;
        if (amount > 0) {
            user.amount = 0;
            user.rewardDebt = 0;
            _lpBalance -= amount;
            LP_TOKEN.safeTransfer(msg.sender, amount);
            emit EmergencyWithdraw(msg.sender, amount);
        }
    }

    /// @inheritdoc IStake
    function skim() external nonReentrant {
        uint256 lpBalance = _lpBalance;
        uint256 balance = LP_TOKEN.balanceOf(address(this));
        if (balance > lpBalance) {
            LP_TOKEN.safeTransfer(msg.sender, balance - lpBalance);
            emit Skim(msg.sender, balance - lpBalance);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                             internal functions                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice returns the pending rewards of a user.
     * @param user information of the user
     * @param accRewardPerShare the accumulated reward per share
     * @return pendingRewards_ amount of rewards pending to claim
     * @dev Used when userInfo where already loaded to memory, to avoid multiple SLOAD operations.
     */
    function _pendingRewards(UserInfo memory user, uint256 accRewardPerShare)
        internal
        pure
        returns (uint256 pendingRewards_)
    {
        pendingRewards_ = user.amount.mulDiv(accRewardPerShare, PRECISION_FACTOR) - user.rewardDebt;
    }

    /**
     * @notice Deposits staking tokens to the contract.
     * @param amount amount of staking tokens to deposit
     * @param recipient address of the recipient
     * @param from address of the sender
     */
    function _deposit(uint256 amount, address recipient, address from) internal {
        // slither-disable-next-line incorrect-equality
        if (amount == 0) {
            revert Stake_depositZeroAmount();
        }
        UserInfo memory user = _userInfo[recipient];

        // slither-disable-next-line reentrancy-no-eth
        uint256 accRewardPerShare = _harvest(user, recipient, recipient);

        user.amount += amount;
        user.rewardDebt = user.amount.mulDiv(accRewardPerShare, PRECISION_FACTOR);
        _userInfo[recipient] = user;

        _lpBalance += amount;
        if (from != address(this)) {
            LP_TOKEN.safeTransferFrom(from, address(this), amount);
        }

        emit Deposit(recipient, from, amount);
    }

    /**
     * @notice Withdraws staking tokens from the contract.
     * @param amount amount of staking tokens to withdraw
     * @param recipient address of the recipient
     */
    function _withdraw(uint256 amount, address recipient) internal {
        UserInfo memory user = _userInfo[msg.sender];

        if (amount > user.amount) {
            revert Stake_withdrawTooHigh(amount, user.amount);
        } else if (amount == 0) {
            revert Stake_withdrawZeroAmount();
        }

        // slither-disable-next-line reentrancy-no-eth
        uint256 accRewardPerShare = _harvest(user, msg.sender, recipient);

        unchecked {
            user.amount -= amount;
        }
        user.rewardDebt = user.amount.mulDiv(accRewardPerShare, PRECISION_FACTOR);
        _userInfo[msg.sender] = user;

        _lpBalance -= amount;
        LP_TOKEN.safeTransfer(recipient, amount);
        emit Withdraw(msg.sender, recipient, amount);
    }

    /**
     * @notice Harvests the pending rewards of a user and transfers them to the user.
     * @param user information of the user
     * @param userAddr address of the user
     * @param recipient address of the receiver of the rewards
     * @return accRewardPerShare_ The updated reward per share.
     * @dev Used when userInfo where already loaded to memory, to avoid multiple SLOAD operations.
     */
    function _harvest(UserInfo memory user, address userAddr, address recipient)
        internal
        returns (uint256 accRewardPerShare_)
    {
        // slither-disable-next-line reentrancy-no-eth
        (accRewardPerShare_,) = _updatePool();

        if (user.amount > 0) {
            uint256 pendingReward = _pendingRewards(user, accRewardPerShare_);

            if (pendingReward > 0) {
                uint256 lastRewardAmountMem = _lastRewardAmount;
                if (pendingReward > lastRewardAmountMem) {
                    pendingReward = lastRewardAmountMem;
                }

                _lastRewardAmount -= pendingReward;
                _userInfo[userAddr].rewardDebt = user.amount.mulDiv(accRewardPerShare_, PRECISION_FACTOR);

                uint256 rewards = WRAPPED_PONZIO.unwrap(pendingReward, recipient);
                emit ClaimReward(userAddr, recipient, rewards);
            }
        }
    }

    /**
     * @notice Updates the pool and returns the updated reward per share and the last reward amount.
     * @return accRewardPerShare_ The updated reward per share.
     * @return newLastRewardAmount_ The last reward amount.
     */
    function _updatePool() internal returns (uint256 accRewardPerShare_, uint256 newLastRewardAmount_) {
        PONZIO.updateTotalSupply();
        (accRewardPerShare_, newLastRewardAmount_) = _getUpdatedRewardPerShare(0);

        _accRewardPerShare = accRewardPerShare_;
        _lastRewardAmount = newLastRewardAmount_;
    }

    /**
     * @notice Returns the updated reward per share and the last reward amount.
     * @param newRewards The new rewards to distribute.
     * @return accRewardPerShare_ The updated reward per share.
     * @return newLastRewardAmount_ The last reward amount.
     */
    function _getUpdatedRewardPerShare(uint256 newRewards)
        internal
        view
        returns (uint256 accRewardPerShare_, uint256 newLastRewardAmount_)
    {
        uint256 lpBalance = _lpBalance;
        // slither-disable-next-line incorrect-equality
        if (lpBalance == 0) {
            return (_accRewardPerShare, _lastRewardAmount);
        }

        uint256 currentRewardAmount = WRAPPED_PONZIO.balanceOf(address(this));

        currentRewardAmount += newRewards;

        newLastRewardAmount_ = currentRewardAmount;
        accRewardPerShare_ =
            _accRewardPerShare + (currentRewardAmount - _lastRewardAmount).mulDiv(PRECISION_FACTOR, lpBalance);
    }
}

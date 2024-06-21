// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { USER_1, USER_2, USER_3, USER_4 } from "test/utils/Constants.sol";
import { PonzioTheCatFixture } from "test/utils/PonzioTheCatFixture.sol";
import { IStake } from "src/interfaces/IStake.sol";

/**
 * @custom:feature Invariants of `Stake`
 * @custom:background Given four users that can deposit tokens, withdraw, harvest and
 * update the total supply of the token
 */
contract TestInvariantsStake is PonzioTheCatFixture {
    uint256 initTimestamp = block.timestamp;
    uint256 initialAmount = 100 ether;

    function setUp() public {
        address DEPLOYER = vm.envAddress("DEPLOYER_ADDRESS");
        _setUp(DEPLOYER);

        targetContract(address(stake));
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = stake.depositTest.selector;
        selectors[1] = stake.withdrawTest.selector;
        selectors[2] = stake.harvestTest.selector;
        selectors[3] = stake.updateTotalSupplyTest.selector;
        targetSelector(FuzzSelector({ addr: address(stake), selectors: selectors }));
        targetSender(USER_1);
        targetSender(USER_2);
        targetSender(USER_3);
        targetSender(USER_4);
        vm.startPrank(DEPLOYER);
        uniV2Pair.transfer(USER_1, initialAmount);
        uniV2Pair.transfer(USER_2, initialAmount);
        uniV2Pair.transfer(USER_3, initialAmount);
        uniV2Pair.transfer(USER_4, initialAmount);
        vm.stopPrank();
        stake.setLpBalances(USER_1, initialAmount);
        stake.setLpBalances(USER_2, initialAmount);
        stake.setLpBalances(USER_3, initialAmount);
        stake.setLpBalances(USER_4, initialAmount);
    }

    function invariant_deposit() public displayBalances {
        IStake.UserInfo memory info = stake.userInfo(USER_1);
        assertEq(info.amount, stake.lpDeposits(USER_1), "lpDeposits of user 1");
        info = stake.userInfo(USER_2);
        assertEq(info.amount, stake.lpDeposits(USER_2), "lpDeposits of user 2");
        info = stake.userInfo(USER_3);
        assertEq(info.amount, stake.lpDeposits(USER_3), "lpDeposits of user 3");
        info = stake.userInfo(USER_4);
        assertEq(info.amount, stake.lpDeposits(USER_4), "lpDeposits of user 4");
    }

    function invariant_lpToken() public displayBalances {
        IStake.UserInfo memory info = stake.userInfo(USER_1);
        assertEq(info.amount, initialAmount - uniV2Pair.balanceOf(USER_1), "lp balance of user 1");
        info = stake.userInfo(USER_2);
        assertEq(info.amount, initialAmount - uniV2Pair.balanceOf(USER_2), "lp balance of user 2");
        info = stake.userInfo(USER_3);
        assertEq(info.amount, initialAmount - uniV2Pair.balanceOf(USER_3), "lp balance of user 3");
        info = stake.userInfo(USER_4);
        assertEq(info.amount, initialAmount - uniV2Pair.balanceOf(USER_4), "lp balance of user 4");
    }

    function invariant_rewards() public displayBalances {
        uint256 pendingRewardsSum = stake.pendingRewards(USER_1) + stake.pendingRewards(USER_2)
            + stake.pendingRewards(USER_3) + stake.pendingRewards(USER_4);

        ponzio.updateTotalSupply();
        if (
            stake.userInfo(USER_1).amount != 0 || stake.userInfo(USER_2).amount != 0
                || stake.userInfo(USER_3).amount != 0 || stake.userInfo(USER_4).amount != 0
        ) {
            assertApproxEqRel(
                pendingRewardsSum, ponzio.balanceOf(address(wrappedPonzioTheCat)), 1, "pending rewards sum"
            );
        } else {
            assertEq(pendingRewardsSum, 0, "pending rewards sum");
        }

        uint256 pendingRewards = stake.pendingRewards(USER_1);
        uint256 balance = ponzio.balanceOf(USER_1);
        vm.prank(USER_1);
        stake.harvest(USER_1);
        assertApproxEqAbs(pendingRewards, ponzio.balanceOf(USER_1) - balance, 1, "pending rewards of user 1");
        assertEq(stake.pendingRewards(USER_1), 0, "pending rewards of user 1 after harvest");

        pendingRewards = stake.pendingRewards(USER_2);
        balance = ponzio.balanceOf(USER_2);
        vm.prank(USER_2);
        stake.harvest(USER_2);
        assertApproxEqAbs(pendingRewards, ponzio.balanceOf(USER_2) - balance, 1, "pending rewards of user 2");
        assertEq(stake.pendingRewards(USER_2), 0, "pending rewards of user 2 after harvest");

        pendingRewards = stake.pendingRewards(USER_3);
        balance = ponzio.balanceOf(USER_3);
        vm.prank(USER_3);
        stake.harvest(USER_3);
        assertApproxEqAbs(pendingRewards, ponzio.balanceOf(USER_3) - balance, 1, "pending rewards of user 3");
        assertEq(stake.pendingRewards(USER_3), 0, "pending rewards of user 3 after harvest");

        pendingRewards = stake.pendingRewards(USER_4);
        balance = ponzio.balanceOf(USER_4);
        vm.prank(USER_4);
        stake.harvest(USER_4);
        assertApproxEqAbs(pendingRewards, ponzio.balanceOf(USER_4) - balance, 1, "pending rewards of user 4");
        assertEq(stake.pendingRewards(USER_4), 0, "pending rewards of user 4 after harvest");
    }

    modifier displayBalances() {
        IStake.UserInfo memory info = stake.userInfo(USER_1);
        emit log_named_decimal_uint("USER_1 shares ", info.amount, 18);
        info = stake.userInfo(USER_2);
        emit log_named_decimal_uint("USER_2 shares ", info.amount, 18);
        info = stake.userInfo(USER_3);
        emit log_named_decimal_uint("USER_3 shares ", info.amount, 18);
        info = stake.userInfo(USER_4);
        emit log_named_decimal_uint("USER_4 shares ", info.amount, 18);
        emit log_named_decimal_uint("USER_1 balance", uniV2Pair.balanceOf(USER_1), 18);
        emit log_named_decimal_uint("USER_2 balance", uniV2Pair.balanceOf(USER_2), 18);
        emit log_named_decimal_uint("USER_3 balance", uniV2Pair.balanceOf(USER_3), 18);
        emit log_named_decimal_uint("USER_4 balance", uniV2Pair.balanceOf(USER_4), 18);
        _;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { PonzioTheCatFixture } from "test/utils/PonzioTheCatFixture.sol";
import { USER_1, USER_2 } from "test/utils/Constants.sol";

import { PonzioTheCat } from "src/PonzioTheCat.sol";
import { Stake } from "src/Stake.sol";

/**
 * @title TestStake
 * @dev Test for Stake contract
 */
contract TestStake is PonzioTheCatFixture {
    using Math for uint256;

    uint256 initialTimestamp;
    uint256 decimals;
    uint256 initialDeposit = 100 ether;
    uint256 rewardsAmount;

    function setUp() public virtual {
        _setUp(address(0));
        initialTimestamp = block.timestamp;
        decimals = ponzio.decimals();
        rewardsAmount = 1000 * 10 ** decimals;
    }

    function test_initialState() public {
        // ponzio
        assertEq(ponzio.totalSupply(), ponzio.INITIAL_SUPPLY());
        assertEq(ponzio.balanceOf(address(this)), ponzio.INITIAL_SUPPLY());
        // uniV2Pair
        assertEq(uniV2Pair.totalSupply(), 100_000 ether);
        assertEq(uniV2Pair.balanceOf(address(this)), 100_000 ether);
        // vault
        assertEq(address(wrappedPonzioTheCat.asset()), address(ponzio));
        assertEq(wrappedPonzioTheCat.totalSupply(), 0);
    }

    function test_rewardSoloUser() public {
        uniV2Pair.transfer(USER_1, initialDeposit);

        // ------ DEPOSIT ------
        vm.startPrank(USER_1);
        uniV2Pair.approve(address(stake), UINT256_MAX);
        stake.deposit(initialDeposit, USER_1);
        vm.stopPrank();
        // distribute rewards to staking contract
        ponzio.transfer(address(stake), rewardsAmount);
        stake.sync();
        // ponzio
        assertEq(
            ponzio.balanceOf(address(wrappedPonzioTheCat)),
            rewardsAmount,
            "wrappedPonzioTheCat should have rewardsAmount of ponzio"
        );
        assertEq(ponzio.balanceOf(USER_1), 0, "USER_1 should have 0 ether of ponzio");
        assertEq(ponzio.balanceOf(address(stake)), 0, "stake should have 0 ether of ponzio");
        // uniV2Pair
        assertEq(uniV2Pair.balanceOf(address(stake)), initialDeposit, "stake should have initialDeposit of uniV2Pair");
        assertEq(uniV2Pair.balanceOf(USER_1), 0, "USER_1 should have 0 ether of uniV2Pair");
        // stake
        assertEq(stake.pendingRewards(USER_1), rewardsAmount, "pending rewards should be rewardsAmount ");
        // vault
        assertEq(
            wrappedPonzioTheCat.balanceOf(address(stake)), rewardsAmount, "stake should have rewardsAmount of ponzioV"
        );
        assertEq(wrappedPonzioTheCat.totalSupply(), rewardsAmount, "stake should have rewardsAmount of ponzioV");

        // ------ HARVEST ------
        uint256 pendingRewards = stake.pendingRewards(USER_1);
        vm.startPrank(USER_1);
        stake.harvest(USER_1);

        // ponzio
        assertEq(ponzio.balanceOf(USER_1), rewardsAmount);
        assertEq(ponzio.balanceOf(USER_1), pendingRewards);
        assertEq(
            ponzio.balanceOf(address(wrappedPonzioTheCat)), 0, "after harvest, wrappedPonzioTheCat should have 0"
        );
        // uniV2Pair
        assertEq(uniV2Pair.balanceOf(address(stake)), initialDeposit);
        assertEq(uniV2Pair.balanceOf(USER_1), 0);
        // stake
        assertEq(stake.pendingRewards(USER_1), 0);
        // vault
        assertEq(wrappedPonzioTheCat.balanceOf(address(stake)), 0, "stake should have 0 of ponzioV");
        assertEq(wrappedPonzioTheCat.totalSupply(), 0, "stake should have 0 of ponzioV");

        // ------ WITHDRAW ------
        stake.withdraw(initialDeposit, USER_1);
        vm.stopPrank();

        // ponzio
        assertEq(uniV2Pair.balanceOf(address(stake)), 0);
        assertEq(uniV2Pair.balanceOf(USER_1), initialDeposit);
    }

    function test_rewardTwoUser() public {
        uniV2Pair.transfer(USER_1, initialDeposit);
        uniV2Pair.transfer(USER_2, initialDeposit);

        vm.startPrank(USER_1);
        uniV2Pair.approve(address(stake), UINT256_MAX);
        stake.deposit(initialDeposit, USER_1);
        vm.stopPrank();
        vm.startPrank(USER_2);
        uniV2Pair.approve(address(stake), UINT256_MAX);
        stake.deposit(initialDeposit, USER_2);
        vm.stopPrank();

        // distribute rewards to staking contract and sync
        ponzio.transfer(address(stake), rewardsAmount);
        stake.sync();
        // ponzio
        assertEq(
            ponzio.balanceOf(address(wrappedPonzioTheCat)),
            rewardsAmount,
            "wrappedPonzioTheCat should have rewardsAmount of ponzio"
        );
        assertEq(ponzio.balanceOf(USER_1), 0, "USER_1 should have 0 ether of ponzio");
        assertEq(ponzio.balanceOf(USER_2), 0, "USER_2 should have 0 ether of ponzio");
        // uniV2Pair
        assertEq(uniV2Pair.balanceOf(address(stake)), 2 * initialDeposit);
        assertEq(uniV2Pair.balanceOf(USER_1), 0, "USER_1 should have 0 ether of uniV2Pair");
        assertEq(uniV2Pair.balanceOf(USER_2), 0, "USER_2 should have 0 ether of uniV2Pair");
        // stake
        assertEq(stake.pendingRewards(address(ponzio)), 0);
        assertEq(stake.pendingRewards(USER_1), rewardsAmount / 2);
        assertEq(stake.pendingRewards(USER_1), stake.pendingRewards(USER_2));
        // vault
        assertEq(
            wrappedPonzioTheCat.balanceOf(address(stake)), rewardsAmount, "stake should have rewardsAmount of ponzioV"
        );
        assertEq(wrappedPonzioTheCat.totalSupply(), rewardsAmount, "stake should have rewardsAmount of ponzioV");

        // ------ HARVEST 1 user ------
        uint256 pendingRewards = stake.pendingRewards(USER_1);
        vm.prank(USER_1);
        stake.harvest(USER_1);

        assertEq(ponzio.balanceOf(USER_1), rewardsAmount / 2);
        assertEq(ponzio.balanceOf(USER_1), pendingRewards);
        assertEq(
            ponzio.balanceOf(address(wrappedPonzioTheCat)),
            rewardsAmount / 2,
            "After USER_1 harvest, wrappedPonzioTheCat should have rewardsAmount / 2 of ponzio"
        );

        // ------ WITHDRAW ------
        vm.prank(USER_1);
        stake.withdraw(initialDeposit, USER_1);
        assertEq(uniV2Pair.balanceOf(address(stake)), initialDeposit);
        assertEq(uniV2Pair.balanceOf(USER_1), initialDeposit);

        pendingRewards = stake.pendingRewards(USER_2);
        vm.prank(USER_2);
        stake.withdraw(initialDeposit, USER_2);

        // ponzio
        assertEq(
            ponzio.balanceOf(address(wrappedPonzioTheCat)), 0, "after all withdraw, wrappedPonzioTheCat should have 0"
        );
        assertEq(ponzio.balanceOf(USER_2), rewardsAmount / 2);
        assertEq(ponzio.balanceOf(USER_2), pendingRewards);
        assertEq(ponzio.balanceOf(USER_1), ponzio.balanceOf(USER_2));
        // uniV2Pair
        assertEq(uniV2Pair.balanceOf(address(stake)), 0);
        assertEq(uniV2Pair.balanceOf(USER_2), initialDeposit);
        assertEq(uniV2Pair.balanceOf(USER_1), uniV2Pair.balanceOf(USER_2));
        // stake
        assertEq(stake.pendingRewards(address(ponzio)), 0);
        assertEq(stake.pendingRewards(USER_2), 0);
        assertEq(stake.pendingRewards(USER_1), 0);
        // vault
        assertEq(wrappedPonzioTheCat.balanceOf(address(stake)), 0);
        assertEq(wrappedPonzioTheCat.totalSupply(), 0);
        assertEq(wrappedPonzioTheCat.totalSupply(), wrappedPonzioTheCat.balanceOf(address(stake)));
    }

    function test_multipleRewards() public {
        uniV2Pair.transfer(USER_1, initialDeposit);
        uniV2Pair.transfer(USER_2, initialDeposit);

        vm.startPrank(USER_1);
        uniV2Pair.approve(address(stake), UINT256_MAX);
        stake.deposit(initialDeposit, USER_1);
        vm.stopPrank();
        vm.startPrank(USER_2);
        uniV2Pair.approve(address(stake), UINT256_MAX);
        stake.deposit(initialDeposit, USER_2);
        vm.stopPrank();

        // distribute rewards to staking contract and sync
        ponzio.transfer(address(stake), rewardsAmount);
        stake.sync();

        assertEq(
            ponzio.balanceOf(address(wrappedPonzioTheCat)),
            rewardsAmount,
            "wrappedPonzioTheCat should have rewardsAmount of ponzio"
        );
        assertEq(
            wrappedPonzioTheCat.balanceOf(address(stake)), rewardsAmount, "stake should have rewardsAmount of ponzioV"
        );
        assertEq(uniV2Pair.balanceOf(address(stake)), 2 * initialDeposit);
        assertEq(stake.pendingRewards(USER_1), rewardsAmount / 2);
        assertEq(stake.pendingRewards(USER_2), stake.pendingRewards(USER_1));

        // ------ WITHDRAW 1 user ------
        uint256 pendingRewards = stake.pendingRewards(USER_1);
        vm.prank(USER_1);
        stake.withdraw(initialDeposit, USER_1);

        assertEq(ponzio.balanceOf(USER_1), pendingRewards);
        assertEq(uniV2Pair.balanceOf(address(stake)), initialDeposit);
        assertEq(uniV2Pair.balanceOf(USER_1), initialDeposit);

        // distribute rewards to staking contract and sync
        ponzio.transfer(address(stake), rewardsAmount);
        stake.sync();

        pendingRewards = stake.pendingRewards(USER_2);
        vm.prank(USER_2);
        stake.withdraw(initialDeposit, USER_2);

        // ponzio
        assertEq(ponzio.balanceOf(USER_2), pendingRewards);
        assertEq(
            ponzio.balanceOf(address(wrappedPonzioTheCat)), 0, "after all withdraw, wrappedPonzioTheCat should have 0"
        );
        // USER_2 should have rewardsAmount + rewardsAmount / 2 - rewards for the initial deposit
        assertEq(ponzio.balanceOf(USER_2), rewardsAmount * 3 / 2);
        assertEq(ponzio.balanceOf(USER_1), rewardsAmount / 2);
        // // uniV2Pair
        assertEq(uniV2Pair.balanceOf(address(stake)), 0);
        assertEq(uniV2Pair.balanceOf(USER_2), initialDeposit);
        assertEq(uniV2Pair.balanceOf(USER_1), uniV2Pair.balanceOf(USER_2));
        // stake
        assertEq(stake.pendingRewards(address(ponzio)), 0);
        assertEq(0, stake.pendingRewards(USER_2));
        assertEq(0, stake.pendingRewards(USER_1));
        // vault
        assertEq(wrappedPonzioTheCat.balanceOf(address(stake)), 0);
        assertEq(wrappedPonzioTheCat.totalSupply(), 0);
    }

    function test_pendingRewards() public {
        uniV2Pair.transfer(USER_1, initialDeposit);

        vm.startPrank(USER_1);
        uniV2Pair.approve(address(stake), UINT256_MAX);
        stake.deposit(initialDeposit, USER_1);
        vm.stopPrank();

        ponzio.transfer(address(stake), rewardsAmount);
        stake.sync();

        skip(1 weeks);
        uint256 rewards = stake.pendingRewards(USER_1);
        uint256 balanceBefore = ponzio.balanceOf(USER_1);
        vm.prank(USER_1);
        stake.harvest(USER_1);
        uint256 balanceAfter = ponzio.balanceOf(USER_1);
        assertEq(balanceAfter - balanceBefore, rewards);
    }

    function test_pendingRewards_whenFeeGtSupply() public {
        uniV2Pair.transfer(USER_1, initialDeposit);

        vm.startPrank(USER_1);
        uniV2Pair.approve(address(stake), UINT256_MAX);
        stake.deposit(initialDeposit, USER_1);
        vm.stopPrank();

        ponzio.transfer(address(stake), rewardsAmount);
        stake.sync();

        skip(4 * 4 weeks);
        (uint256 supply, uint256 fees) = ponzio.computeSupply();
        assertGt(fees, supply);

        uint256 rewards = stake.pendingRewards(USER_1);
        uint256 balanceBefore = ponzio.balanceOf(USER_1);
        vm.prank(USER_1);
        stake.harvest(USER_1);

        uint256 balanceAfter = ponzio.balanceOf(USER_1);
        assertEq(balanceAfter - balanceBefore, rewards);
    }

    function test_pendingRewards_maxShares() public {
        uniV2Pair.transfer(USER_1, initialDeposit);

        vm.startPrank(USER_1);
        uniV2Pair.approve(address(stake), UINT256_MAX);
        stake.deposit(initialDeposit, USER_1);
        vm.stopPrank();

        ponzio.transfer(address(stake), rewardsAmount);
        stake.sync();

        bool success = true;
        uint256 totalShares;
        uint256 newShares;
        while (success) {
            skip(1 weeks);
            totalShares = ponzio.totalShares();
            (uint256 tokenSupply, uint256 fees) = ponzio.computeSupply();

            uint256 tokenRewards;
            if (fees >= tokenSupply) {
                newShares = totalShares;
                tokenRewards = tokenSupply / 2;
            } else {
                newShares = totalShares.mulDiv(fees, tokenSupply - fees);
                tokenRewards = fees;
            }

            uint256 newTotSupply;
            (success, newTotSupply) = totalShares.tryAdd(newShares);

            if (success) {
                ponzio.updateTotalSupply();
            }
        }

        uint256 rewards = stake.pendingRewards(USER_1);
        uint256 balanceBefore = ponzio.balanceOf(USER_1);
        vm.prank(USER_1);
        stake.harvest(USER_1);
        uint256 balanceAfter = ponzio.balanceOf(USER_1);
        assertEq(balanceAfter - balanceBefore, rewards);
    }
}

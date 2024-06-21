// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { Test } from "forge-std/Test.sol";

import { PonzioTheCat } from "src/PonzioTheCat.sol";
import { Stake } from "src/Stake.sol";
/**
 * @title StakeHandler
 * @dev Wrapper to test internal functions and access internal constants, as well as perform invariant testing
 */

contract StakeHandler is Stake, Test {
    mapping(address account => uint256) public lpDeposits;
    mapping(address account => uint256) public lpBalances;

    constructor(address[] memory _actors, address lptoken, address wrappedPonzioTheCat)
        Stake(lptoken, wrappedPonzioTheCat)
    {
        // actors = _actors;
    }

    function setLpBalances(address account, uint256 amount) external {
        lpBalances[account] = amount;
        vm.prank(account);
        LP_TOKEN.approve(address(this), UINT256_MAX);
    }

    /* ------------------ Functions used for invariant testing ------------------ */

    function depositTest(uint256 amount, uint256 timeToSkip) public {
        // address to = actors[bound(actorTo, 0, actors.length - 1)];
        if (LP_TOKEN.balanceOf(msg.sender) == 0) {
            return;
        }

        amount = bound(amount, 1, LP_TOKEN.balanceOf(msg.sender));
        lpDeposits[msg.sender] += amount;
        lpBalances[msg.sender] -= amount;

        _deposit(amount, msg.sender, msg.sender);

        skip(bound(timeToSkip, 1 days, 2 weeks));
    }

    function withdrawTest(uint256 amount, uint256 timeToSkip) external {
        // address to = actors[bound(actorTo, 0, actors.length - 1)];
        uint256 balance = this.userInfo(msg.sender).amount;
        if (balance == 0) {
            return;
        }
        amount = bound(amount, 1, balance);

        lpDeposits[msg.sender] -= amount;
        lpBalances[msg.sender] += amount;

        _withdraw(amount, msg.sender);

        skip(bound(timeToSkip, 1 days, 2 weeks));
    }

    function harvestTest(uint256 timeToSkip) external {
        // address to = actors[bound(actorTo, 0, actors.length - 1)];
        uint256 pendingRewards = this.pendingRewards(msg.sender);
        if (pendingRewards == 0) {
            return;
        }

        _harvest(this.userInfo(msg.sender), msg.sender, msg.sender);

        skip(bound(timeToSkip, 1 days, 2 weeks));
    }

    function updateTotalSupplyTest(uint256 timeToSkip) external {
        PonzioTheCat(address(PONZIO)).updateTotalSupply();

        skip(bound(timeToSkip, 1 days, 2 weeks));
    }
}

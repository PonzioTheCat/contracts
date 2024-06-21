// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { USER_1 } from "test/utils/Constants.sol";
import { PonzioTheCatFixture } from "test/utils/PonzioTheCatFixture.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { Stake } from "src/Stake.sol";
import { PonzioTheCat } from "src/PonzioTheCat.sol";

/**
 * @title TestPonzioMinSupply
 * @dev Test for Ponzio contract when the total supply is at its minimum.
 */
contract TestPonzioMinSupply is PonzioTheCatFixture {
    uint256 initialTimestamp;
    uint256 decimals;
    uint256 initialDeposit = 100 ether;
    uint256 rewardsAmount;

    function setUp() public virtual {
        _setUp(address(0));
        initialTimestamp = block.timestamp;
        decimals = ponzio.decimals();
    }

    function test_minSupply() public {
        uint256 minSupply = ponzio.MINIMUM_TOTAL_SUPPLY();
        uniV2Pair.approve(address(stake), uniV2Pair.balanceOf(address(this)));
        stake.deposit(1 ether, address(this));

        uint256 reachEnd = (4 * 12 * 31 days);

        skip(reachEnd / 7);

        ponzio.updateTotalSupply();
        assertEq(ponzio.totalSupply(), minSupply);

        stake.harvest(address(this));
        uint256 ts = block.timestamp;

        skip(ponzio.DEBASE_EVERY());

        ponzio.updateTotalSupply();
        assertEq(ponzio.totalSupply(), minSupply);
        uint256 res = (minSupply * ponzio.FEES_STAKING() * (block.timestamp - ts)) / ponzio.HALVING_EVERY()
            / ponzio.FEES_BASE();
        assertApproxEqAbs(res, ponzio.balanceOf(address(wrappedPonzioTheCat)), 2);
    }

    function test_csv() public {
        vm.skip(true);
        uniV2Pair.approve(address(stake), UINT256_MAX);
        stake.deposit(initialDeposit, USER_1);

        console2.log("timestamp,totalSupply,fees,shares");
        while (true) {
            if (ponzio.maxSharesReached()) {
                break;
            }

            logLine(ponzio.totalSupply(), stake.pendingRewards(USER_1), ponzio.totalShares());

            skip(4 hours);
            ponzio.updateTotalSupply();
        }
    }

    function logLine(uint256 ts, uint256 fees, uint256 shares) internal view {
        console2.log(
            string.concat(
                Strings.toString(block.timestamp - initialTimestamp),
                ",",
                Strings.toString(ts),
                ",",
                Strings.toString(fees),
                ",",
                Strings.toString(shares)
            )
        );
    }
}

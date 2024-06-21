// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { USER_1 } from "test/utils/Constants.sol";
import { PonzioTheCatFixture } from "test/utils/PonzioTheCatFixture.sol";

import { PonzioTheCat } from "src/PonzioTheCat.sol";
import { IERC20Errors } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TestPonzioMaxShares
 * @dev Test for Ponzio contract.
 */
contract TestPonzioMaxShares is PonzioTheCatFixture, IERC20Errors {
    uint256 initialTimestamp;
    uint256 decimals;

    function setUp() public virtual {
        _setUp(address(0));
        initialTimestamp = block.timestamp;
        decimals = ponzio.decimals();
    }

    function test_maxShares() public {
        uniV2Pair.approve(address(stake), type(uint256).max);
        stake.deposit(1 ether, address(this));

        uint256 totShares;
        while (ponzio.maxSharesReached() == false) {
            skip(4 hours);
            ponzio.updateTotalSupply();
            totShares = ponzio.totalShares();
        }
        skip(12 * 4 weeks);
        ponzio.updateTotalSupply();
        assertEq(ponzio.totalShares(), totShares);
    }

    function test_transferSharesFrom_lt1wei() public {
        ponzio.transfer(USER_1, 1 ether);

        // test transferSharesFrom with less than 1 wei
        uint256 minimumShares = ponzio.tokenToShares(1);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientAllowance.selector, address(this), 0, 1));
        ponzio.transferSharesFrom(USER_1, address(this), minimumShares - 1);

        while (ponzio.tokenToShares(1) <= ponzio.SHARES_PRECISION_FACTOR()) {
            skip(4 hours);
            ponzio.updateTotalSupply();
        }
        // test transferSharesFrom with less rounding != 0 when tokenToShares(1) > SHARES_PRECISION_FACTOR
        uint256 shares = ponzio.tokenToShares(1000);
        vm.prank(USER_1);
        ponzio.approve(address(this), 1000);

        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientAllowance.selector, address(this), 1000, 1001));
        ponzio.transferSharesFrom(USER_1, address(this), shares + 1);
    }
}

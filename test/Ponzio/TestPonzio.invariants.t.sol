// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { console2 } from "forge-std/Test.sol";

import { USER_1, USER_2, USER_3, USER_4 } from "test/utils/Constants.sol";
import { PonzioTheCatFixture } from "test/utils/PonzioTheCatFixture.sol";

/**
 * @custom:feature Invariants of `PonzioTheCat`
 * @custom:background Given four users that have 1000 tokens, they can transfer to other users
 * and update the total supply of the token.
 */
contract TestPonzioTheCatInvariants is PonzioTheCatFixture {
    uint256 initTimestamp = block.timestamp;

    function setUp() public {
        _setUp(address(0));

        targetContract(address(ponzio));
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = ponzio.transferTest.selector;
        selectors[1] = ponzio.updateTotalSupplyTest.selector;
        targetSelector(FuzzSelector({ addr: address(ponzio), selectors: selectors }));
        ponzio.transfer(USER_1, 1000 * 10 ** ponzio.decimals());
        ponzio.transfer(USER_2, 1000 * 10 ** ponzio.decimals());
        ponzio.transfer(USER_3, 1000 * 10 ** ponzio.decimals());
        ponzio.transfer(USER_4, 1000 * 10 ** ponzio.decimals());
        ponzio.setShares(USER_1, ponzio.sharesOf(USER_1));
        ponzio.setShares(USER_2, ponzio.sharesOf(USER_2));
        ponzio.setShares(USER_3, ponzio.sharesOf(USER_3));
        ponzio.setShares(USER_4, ponzio.sharesOf(USER_4));
    }

    /// @custom:scenario Check that the contract returns the expected number of shares for each user
    function invariant_shares() public displayBalancesAndShares {
        assertEq(ponzio.sharesOf(USER_1), ponzio.shares(USER_1), "shares of user 1");
        assertEq(ponzio.sharesOf(USER_2), ponzio.shares(USER_2), "shares of user 2");
        assertEq(ponzio.sharesOf(USER_3), ponzio.shares(USER_3), "shares of user 3");
        assertEq(ponzio.sharesOf(USER_4), ponzio.shares(USER_4), "shares of user 4");
        assertTotalSupply();
    }

    /**
     * @custom:scenario Check that the sum of all user balances is approximately equal to the total supply
     * @dev The sum of all user balances is not exactly equal to the total supply because of the rounding errors that
     * can stack up.
     */
    function invariant_totalSupply() public displayBalancesAndShares {
        ponzio.updateTotalSupply();

        uint256 userSum = ponzio.balanceOf(USER_1) + ponzio.balanceOf(USER_2) + ponzio.balanceOf(USER_3)
            + ponzio.balanceOf(USER_4);
        uint256 otherSum = ponzio.balanceOf(address(this)) + ponzio.balanceOf(address(wrappedPonzioTheCat))
            + ponzio.balanceOf(address(ponzio));

        assertLe(userSum + otherSum, ponzio.totalSupply(), "sum of user balances <= total supply");
        assertApproxEqRel(userSum + otherSum, ponzio.totalSupply(), 1, "sum of user balances vs total supply");
        assertTotalSupply();
    }

    function assertTotalSupply() internal {
        uint256 timeSinceInit = block.timestamp - initTimestamp;
        // to calculate the total supply, we need to take into account the halving
        uint256 updatedSupply = ponzio.INITIAL_SUPPLY() / 2 ** (timeSinceInit / ponzio.HALVING_EVERY());
        // and debasing
        updatedSupply = updatedSupply
            - updatedSupply * ((timeSinceInit % ponzio.HALVING_EVERY()) / ponzio.DEBASE_EVERY())
                / ponzio.NB_DEBASE_PER_HALVING() / 2;

        ponzio.updateTotalSupply();
        assertEq(updatedSupply, ponzio.totalSupply(), "total supply");
    }

    modifier displayBalancesAndShares() {
        console2.log("USER_1 balance", ponzio.balanceOf(USER_1));
        console2.log("USER_2 balance", ponzio.balanceOf(USER_2));
        console2.log("USER_3 balance", ponzio.balanceOf(USER_3));
        console2.log("USER_4 balance", ponzio.balanceOf(USER_4));
        console2.log("USER_1 shares ", ponzio.sharesOf(USER_1));
        console2.log("USER_2 shares ", ponzio.sharesOf(USER_2));
        console2.log("USER_3 shares ", ponzio.sharesOf(USER_3));
        console2.log("USER_4 shares ", ponzio.sharesOf(USER_4));
        _;
    }
}

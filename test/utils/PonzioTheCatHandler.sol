// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { Test } from "forge-std/Test.sol";

import { PonzioTheCat } from "src/PonzioTheCat.sol";

/**
 * @title PonzioTheCatHandler
 * @dev Wrapper to test internal functions and access internal constants, as well as perform invariant testing
 */
contract PonzioTheCatHandler is PonzioTheCat, Test {
    // use multiple actors for invariant testing
    address[] public actors;

    // current actor
    address internal _currentActor;

    // track theoretical shares
    mapping(address account => uint256) public shares;

    constructor(address[] memory _actors) PonzioTheCat() {
        actors = _actors;
    }

    function setShares(address account, uint256 amount) external {
        shares[account] = amount;
    }

    /* ------------------ Functions used for invariant testing ------------------ */

    modifier useActor(uint256 actorIndexSeed) {
        _currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(_currentActor);
        _;
        vm.stopPrank();
    }

    function transferTest(uint256 actorTo, uint256 amount, uint256 actorIndexSeed, uint256 timeToSkip)
        external
        useActor(actorIndexSeed)
    {
        address to = actors[bound(actorTo, 0, actors.length - 1)];
        if (balanceOf(_currentActor) == 0) {
            return;
        }
        amount = bound(amount, 1, balanceOf(_currentActor));
        uint256 amountShares = (amount * _totalShares) / totalSupply();

        shares[_currentActor] -= amountShares;
        shares[to] += amountShares;
        _transfer(_currentActor, to, amount);

        skip(bound(timeToSkip, 1 hours, 6 hours));
    }

    function updateTotalSupplyTest(uint256 timeToSkip) external {
        (uint256 totalSupply, uint256 fees) = computeSupply();
        if (fees > 0) {
            shares[_feesCollector] += _totalShares * fees / (totalSupply - fees);
        }

        this.updateTotalSupply();
        skip(bound(timeToSkip, 1 hours, 6 hours));
    }
}

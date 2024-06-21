// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { Stake } from "src/Stake.sol";
import { Router } from "src/Router.sol";
import { PonzioTheCat } from "src/PonzioTheCat.sol";
import { WrappedPonzioTheCat } from "src/WrappedPonzioTheCat.sol";

import { IUniswapV2Router02 } from "src/interfaces/UniswapV2/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "src/interfaces/UniswapV2/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "src/interfaces/UniswapV2/IUniswapV2Pair.sol";

/**
 * @title TestStakeReinvest
 * @dev Test for Stake contract
 */
contract TestStakeReinvest is Test {
    Stake public stake;
    PonzioTheCat public ponzio;
    Router public router;
    IUniswapV2Pair public uniV2Pair;
    WrappedPonzioTheCat public wrappedPonzioTheCat;

    IUniswapV2Router02 routerUniV2 = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Factory uniV2Factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 decimals;

    function setUp() public virtual {
        uint256 mainnetFork = vm.createFork(vm.envString("URL_ETH_MAINNET"));
        vm.selectFork(mainnetFork);

        ponzio = new PonzioTheCat();
        decimals = ponzio.decimals();

        wrappedPonzioTheCat = new WrappedPonzioTheCat(ponzio);

        ponzio.approve(address(routerUniV2), UINT256_MAX);
        routerUniV2.addLiquidityETH{ value: 133.7 ether }(
            address(ponzio), ponzio.balanceOf(address(this)), 0, 0, address(this), block.timestamp + 10 minutes
        );

        uniV2Pair = IUniswapV2Pair(uniV2Factory.getPair(address(ponzio), WETH));

        router = new Router(address(uniV2Pair), address(ponzio));
        stake = new Stake(address(uniV2Pair), address(wrappedPonzioTheCat));

        ponzio.initialize(address(stake), address(uniV2Pair));
    }

    function test_reinvest() public {
        uniV2Pair.approve(address(stake), uniV2Pair.balanceOf(address(this)));
        stake.deposit(uniV2Pair.balanceOf(address(this)), address(this));
        uint256 amountDepositedBefore = stake.userInfo(address(this)).amount;
        uint256 someTime = 2 weeks;

        skip(someTime / 7);

        stake.reinvest{ value: 10 ether }(0, 0);

        assertGt(stake.userInfo(address(this)).amount, amountDepositedBefore);
        assertEq(stake.pendingRewards(address(this)), 0);
        assertEq(ponzio.balanceOf(address(this)), 0);
        assertEq(ponzio.balanceOf(address(stake)), 0);
    }

    function test_reinvestRefundToken() public {
        uniV2Pair.approve(address(stake), uniV2Pair.balanceOf(address(this)));
        stake.deposit(uniV2Pair.balanceOf(address(this)), address(this));
        uint256 amountDepositedBefore = stake.userInfo(address(this)).amount;

        skip(2 weeks);

        stake.reinvest{ value: 1 ether }(0, 0);

        assertGt(stake.userInfo(address(this)).amount, amountDepositedBefore);
        assertEq(stake.pendingRewards(address(this)), 0);
        assertGt(ponzio.balanceOf(address(this)), 0);
        assertEq(ponzio.balanceOf(address(stake)), 0);
    }

    receive() external payable { }
}

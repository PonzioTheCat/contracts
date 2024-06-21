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
 * @title TestUniswapIntegration
 */
contract TestUniswapIntegration is Test {
    Stake public stake;
    Router public router;
    PonzioTheCat public ponzio;
    IUniswapV2Pair public uniV2Pair;
    WrappedPonzioTheCat public wrappedPonzioTheCat;

    IUniswapV2Router02 routerUniV2 = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Factory uniV2Factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 decimals;
    uint256 amountIn;
    address USER = address(1);

    function setUp() public virtual {
        uint256 mainnetFork = vm.createFork(vm.envString("URL_ETH_MAINNET"));
        vm.selectFork(mainnetFork);

        ponzio = new PonzioTheCat();
        decimals = ponzio.decimals();

        wrappedPonzioTheCat = new WrappedPonzioTheCat(ponzio);

        ponzio.approve(address(routerUniV2), UINT256_MAX);
        routerUniV2.addLiquidityETH{ value: 133.7 ether }(
            address(ponzio),
            ponzio.balanceOf(address(this)) - 1_000_000 * 10 ** decimals,
            0,
            0,
            address(this),
            block.timestamp + 10 minutes
        );

        uniV2Pair = IUniswapV2Pair(uniV2Factory.getPair(address(ponzio), WETH));

        router = new Router(address(uniV2Pair), address(ponzio));
        stake = new Stake(address(uniV2Pair), address(wrappedPonzioTheCat));

        ponzio.initialize(address(stake), address(uniV2Pair));
        amountIn = 145_243 * 10 ** ponzio.decimals();
    }

    function test_swapExactETHForTokens() public {
        (bool success,) = USER.call{ value: 2 ether }("");
        assertTrue(success);
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(ponzio);
        uint256 balanceETHBefore = USER.balance;

        skip(4 weeks);

        uint256 snapshot = vm.snapshot();

        vm.prank(USER);
        routerUniV2.swapExactETHForTokens{ value: 1 ether }(amountIn * 9 / 10, path, USER, block.timestamp + 10 minutes);
        assertGt(ponzio.balanceOf(USER), amountIn * 9 / 10);
        assertEq(balanceETHBefore - USER.balance, 1 ether);

        // ----- without pair in blacklist -----
        vm.revertTo(snapshot);
        ponzio.setBlacklistForUpdateSupply(address(uniV2Pair), false);

        vm.prank(USER);
        routerUniV2.swapExactETHForTokens{ value: 1 ether }(amountIn * 9 / 10, path, USER, block.timestamp + 10 minutes);
        assertGt(ponzio.balanceOf(USER), amountIn * 9 / 10);
        assertEq(balanceETHBefore - USER.balance, 1 ether);
    }

    function test_swapETHForExactTokens() public {
        (bool success,) = USER.call{ value: 2 ether }("");
        assertTrue(success);
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(ponzio);
        uint256 balanceETHBefore = USER.balance;

        skip(4 weeks);

        uint256 snapshot = vm.snapshot();

        vm.prank(USER);
        routerUniV2.swapETHForExactTokens{ value: 1 ether }(amountIn, path, USER, block.timestamp + 10 minutes);
        assertEq(ponzio.balanceOf(USER), amountIn);
        assertGt(balanceETHBefore - USER.balance, 0.9 ether);

        // ----- without pair in blacklist -----
        vm.revertTo(snapshot);
        ponzio.setBlacklistForUpdateSupply(address(uniV2Pair), false);

        vm.prank(USER);
        routerUniV2.swapETHForExactTokens{ value: 1 ether }(amountIn, path, USER, block.timestamp + 10 minutes);
        assertEq(ponzio.balanceOf(USER), amountIn);
        assertGt(balanceETHBefore - USER.balance, 0.9 ether);
    }

    function test_swapTokensForExactETH() public {
        ponzio.transfer(USER, amountIn);
        address[] memory path = new address[](2);
        path[0] = address(ponzio);
        path[1] = WETH;
        vm.prank(USER);
        ponzio.approve(address(routerUniV2), UINT256_MAX);
        uint256 balanceETHBefore = USER.balance;

        skip(ponzio.HALVING_EVERY());

        uint256 snapshot = vm.snapshot();

        vm.prank(USER);
        routerUniV2.swapTokensForExactETH(0.9 ether, amountIn, path, USER, block.timestamp + 10 minutes);
        assertEq(USER.balance - balanceETHBefore, 0.9 ether);

        // ----- without pair in blacklist -----
        vm.revertTo(snapshot);
        ponzio.setBlacklistForUpdateSupply(address(uniV2Pair), false);

        vm.expectRevert();
        vm.prank(USER);
        routerUniV2.swapTokensForExactETH(0.9 ether, amountIn, path, USER, block.timestamp + 10 minutes);
    }

    function test_swapExactTokensForETH() public {
        ponzio.transfer(USER, amountIn);
        address[] memory path = new address[](2);
        path[0] = address(ponzio);
        path[1] = WETH;
        vm.prank(USER);
        ponzio.approve(address(routerUniV2), UINT256_MAX);
        uint256 balanceETHBefore = USER.balance;

        skip(4 weeks);

        uint256 snapshot = vm.snapshot();

        vm.prank(USER);
        routerUniV2.swapExactTokensForETH(amountIn, 0.9 ether, path, USER, block.timestamp + 10 minutes);
        assertGt(USER.balance - balanceETHBefore, 0.9 ether);
        assertEq(ponzio.balanceOf(USER), 0);

        // ----- without pair in blacklist -----
        vm.revertTo(snapshot);
        ponzio.setBlacklistForUpdateSupply(address(uniV2Pair), false);

        vm.prank(USER);
        routerUniV2.swapExactTokensForETH(amountIn, 0.9 ether, path, USER, block.timestamp + 10 minutes);
        assertGt(USER.balance - balanceETHBefore, 0.9 ether);
        assertEq(ponzio.balanceOf(USER), 0);
    }

    function test_addLiquidityETH() public {
        (bool success,) = USER.call{ value: 1 ether }("");
        assertTrue(success);
        ponzio.transfer(USER, amountIn);
        vm.prank(USER);
        ponzio.approve(address(routerUniV2), UINT256_MAX);
        uint256 balanceETHBefore = USER.balance;

        skip(4 weeks);

        uint256 snapshot = vm.snapshot();

        vm.prank(USER);
        routerUniV2.addLiquidityETH{ value: 1 ether }(
            address(ponzio), amountIn, amountIn * 9 / 10, 0.9 ether, USER, block.timestamp + 10 minutes
        );

        assertLt(ponzio.balanceOf(USER), amountIn / 10);
        assertGt(balanceETHBefore - USER.balance, 0.9 ether);

        // ----- without pair in blacklist -----
        vm.revertTo(snapshot);
        ponzio.setBlacklistForUpdateSupply(address(uniV2Pair), false);

        vm.prank(USER);
        routerUniV2.addLiquidityETH{ value: 1 ether }(
            address(ponzio), amountIn, amountIn * 9 / 10, 0.9 ether, USER, block.timestamp + 10 minutes
        );

        assertLt(ponzio.balanceOf(USER), amountIn / 10);
        assertGt(balanceETHBefore - USER.balance, 0.9 ether);
    }

    function test_removeLiquidityETH() public {
        (bool success,) = USER.call{ value: 1 ether }("");
        assertTrue(success);
        ponzio.transfer(USER, amountIn);
        vm.startPrank(USER);
        ponzio.approve(address(routerUniV2), UINT256_MAX);
        uniV2Pair.approve(address(routerUniV2), UINT256_MAX);
        routerUniV2.addLiquidityETH{ value: 1 ether }(
            address(ponzio), amountIn, amountIn * 9 / 10, 0.9 ether, USER, block.timestamp + 10 minutes
        );

        uint256 lpBalance = uniV2Pair.balanceOf(USER);

        skip(4 weeks);

        uint256 snapshot = vm.snapshot();

        routerUniV2.removeLiquidityETH(
            address(ponzio), lpBalance, amountIn * 9 / 10, 0.9 ether, USER, block.timestamp + 10 minutes
        );
        vm.stopPrank();

        vm.revertTo(snapshot);

        ponzio.setBlacklistForUpdateSupply(address(uniV2Pair), false);

        vm.prank(USER);
        routerUniV2.removeLiquidityETH(
            address(ponzio), lpBalance, amountIn * 9 / 10, 0.9 ether, USER, block.timestamp + 10 minutes
        );
    }

    receive() external payable { }
}

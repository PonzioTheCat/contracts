// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { Stake } from "src/Stake.sol";
import { Router } from "src/Router.sol";
import { PonzioTheCat } from "src/PonzioTheCat.sol";
import { WrappedPonzioTheCat } from "src/WrappedPonzioTheCat.sol";
import { UniswapV2Library } from "src/libraries/UniswapV2Library.sol";

import { IWETH } from "src/interfaces/IWETH.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Router02 } from "src/interfaces/UniswapV2/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "src/interfaces/UniswapV2/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "src/interfaces/UniswapV2/IUniswapV2Factory.sol";

/**
 * @title TestStakeAddLiquidity
 * @dev Test for Router AddLiquidity function
 */
contract TestRouterAddLiquidity is Test {
    Stake public stake;
    Router public router;
    PonzioTheCat public ponzio;
    IUniswapV2Pair public uniV2Pair;
    WrappedPonzioTheCat public wrappedPonzioTheCat;

    uint256 decimals;
    uint256 mainnetFork;
    IUniswapV2Router02 routerUniV2 = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Factory uniV2Factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address pairAddr;

    function setUp() public virtual {
        mainnetFork = vm.createFork(vm.envString("URL_ETH_MAINNET"));
        vm.selectFork(mainnetFork);

        ponzio = new PonzioTheCat();
        decimals = ponzio.decimals();

        wrappedPonzioTheCat = new WrappedPonzioTheCat(ponzio);

        ponzio.approve(address(routerUniV2), UINT256_MAX);
        routerUniV2.addLiquidityETH{ value: 133.7 ether }(
            address(ponzio), 19_000_000 * 10 ** decimals, 0, 0, address(this), block.timestamp + 10 minutes
        );

        uniV2Pair = IUniswapV2Pair(uniV2Factory.getPair(address(ponzio), WETH));

        router = new Router(address(uniV2Pair), address(ponzio));
        stake = new Stake(address(uniV2Pair), address(wrappedPonzioTheCat));

        uniV2Pair.approve(address(ponzio), UINT256_MAX);
        ponzio.initialize(address(stake), address(uniV2Pair));

        ponzio.approve(address(router), UINT256_MAX);
    }

    function test_addLiquidityWeth() public {
        pairAddr = UniswapV2Library.pairFor(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f, address(ponzio), WETH);
        IWETH(WETH).deposit{ value: 3 ether }();
        IWETH(WETH).approve(address(router), 3 ether);
        ponzio.approve(address(router), 500_000 * 10 ** decimals);

        skip(1 weeks);

        uint256 balanceWETHBefore = IERC20(WETH).balanceOf(address(this));
        uint256 balancePairBefore = IERC20(pairAddr).balanceOf(address(this));
        assertGt(balancePairBefore, 0);

        (uint256 amountPonzio, uint256 amountWETH, uint256 liquidity) =
            router.updateSupplyAndAddLiquidity(3 ether, 500_000 * 10 ** decimals, 0, 0, address(this));

        assertGt(amountPonzio, 0);
        assertGt(liquidity, 0);
        assertGt(amountWETH, 0);
        assertEq(IERC20(WETH).balanceOf(address(this)), balanceWETHBefore - amountWETH);
        assertEq(IERC20(pairAddr).balanceOf(address(this)), balancePairBefore + liquidity);
    }

    function test_addLiquidityEth() public {
        pairAddr = UniswapV2Library.pairFor(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f, address(ponzio), WETH);
        ponzio.approve(address(router), 500_000 * 10 ** decimals);

        skip(1 weeks);

        uint256 balanceETHBefore = address(this).balance;
        uint256 balancePairBefore = IERC20(pairAddr).balanceOf(address(this));
        assertGt(balancePairBefore, 0);

        (uint256 amountPonzio, uint256 amountETH, uint256 liquidity) =
            router.updateSupplyAndAddLiquidity{ value: 3 ether }(0, 500_000 * 10 ** decimals, 0, 0, address(this));

        assertGt(amountPonzio, 0);
        assertGt(amountETH, 0);
        assertGt(liquidity, 0);
        assertEq(address(this).balance, balanceETHBefore - amountETH);
        assertEq(IERC20(pairAddr).balanceOf(address(this)), balancePairBefore + liquidity);
    }

    receive() external payable { }
}

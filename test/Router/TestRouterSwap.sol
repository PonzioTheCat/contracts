// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { Stake } from "src/Stake.sol";
import { Router } from "src/Router.sol";
import { PonzioTheCat } from "src/PonzioTheCat.sol";
import { TokenERC20 } from "test/utils/TokenERC20.sol";
import { WrappedPonzioTheCat } from "src/WrappedPonzioTheCat.sol";

import { IUniswapV2Router02 } from "src/interfaces/UniswapV2/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "src/interfaces/UniswapV2/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "src/interfaces/UniswapV2/IUniswapV2Pair.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IWETH } from "src/interfaces/IWETH.sol";

/**
 * @title TestStakeSwap
 * @dev Test for Router contract
 */
contract TestRouterSwap is Test {
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
    }

    function test_swapETH() public {
        address[] memory path = new address[](2);
        path[0] = ETH;
        path[1] = address(ponzio);

        skip(2 weeks);

        // Eth -> Ponzio

        uint256 balanceEthBefore = address(this).balance;
        uint256 balancePonzioBefore = ponzio.realBalanceOf(address(this));

        router.swap{ value: 1 ether }(1 ether, 0, path, address(this), block.timestamp + 10 minutes);

        assertEq(address(this).balance, balanceEthBefore - 1 ether);
        assertGt(ponzio.realBalanceOf(address(this)), balancePonzioBefore);

        skip(2 weeks);

        uint256 balanceEthAfter = address(this).balance;
        uint256 balancePonzioAfter = ponzio.realBalanceOf(address(this));

        // Ponzio -> Eth

        path[0] = address(ponzio);
        path[1] = ETH;

        ponzio.approve(address(router), balancePonzioAfter);
        router.swap(balancePonzioAfter, 0, path, address(this), block.timestamp + 10 minutes);

        assertGt(address(this).balance, balanceEthAfter);
        assertEq(ponzio.realBalanceOf(address(this)), 0);
    }

    function test_swapWETH() public {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(ponzio);

        skip(2 weeks);

        uint256 balancePonzioBefore = ponzio.realBalanceOf(address(this));

        // WETH -> Ponzio

        IWETH(WETH).deposit{ value: 1 ether }();
        IWETH(WETH).approve(address(router), 1 ether);
        router.swap(1 ether, 0, path, address(this), block.timestamp + 10 minutes);

        assertEq(IERC20(WETH).balanceOf(address(this)), 0);
        assertGt(ponzio.balanceOf(address(this)), balancePonzioBefore);
        // assert 1e8 tolerance for tx fee, done to check if refund is working
        skip(2 weeks);

        uint256 balancePonzioAfter = ponzio.realBalanceOf(address(this));

        // Ponzio -> WETH

        path[0] = address(ponzio);
        path[1] = WETH;

        ponzio.approve(address(router), balancePonzioAfter);
        router.swap(balancePonzioAfter, 0, path, address(this), block.timestamp + 10 minutes);

        assertGt(IERC20(WETH).balanceOf(address(this)), 0);
        assertEq(ponzio.realBalanceOf(address(this)), 0);
    }

    function test_swapToken() public {
        TokenERC20 token = new TokenERC20("Token", "TKN", 1_000_000 * 10 ** 18);
        token.approve(address(routerUniV2), UINT256_MAX);
        ponzio.approve(address(routerUniV2), UINT256_MAX);
        routerUniV2.addLiquidity(
            address(token),
            address(ponzio),
            100_000 * 10 ** token.decimals(),
            1_000_000 * 10 ** decimals,
            0,
            0,
            address(this),
            block.timestamp + 10 minutes
        );
        address pairAddress = uniV2Factory.getPair(address(token), address(ponzio));

        uint256 balanceTokenBefore = token.balanceOf(address(this));
        uint256 balancePonzioBefore = ponzio.balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(ponzio);

        skip(2 weeks);

        // we need to update the total supply of ponzio to get the correct balance and sync the pair
        ponzio.updateTotalSupply();
        IUniswapV2Pair(pairAddress).sync();

        // Token -> Ponzio

        token.approve(address(router), 10 ** token.decimals());
        router.swap(10 ** token.decimals(), 0, path, address(this), block.timestamp + 10 minutes);

        assertEq(token.balanceOf(address(this)), balanceTokenBefore - 10 ** token.decimals());
        assertGt(ponzio.balanceOf(address(this)), balancePonzioBefore);

        skip(2 weeks);

        uint256 balanceTokenAfter = token.balanceOf(address(this));
        uint256 balancePonzioAfter = ponzio.realBalanceOf(address(this));

        // Ponzio -> Token

        path[0] = address(ponzio);
        path[1] = address(token);

        // we need to update the total supply of ponzio to get the correct balance and sync the pair
        ponzio.updateTotalSupply();
        IUniswapV2Pair(pairAddress).sync();

        ponzio.approve(address(router), balancePonzioAfter);
        router.swap(balancePonzioAfter, 0, path, address(this), block.timestamp + 10 minutes);

        assertGt(token.balanceOf(address(this)), balanceTokenAfter);
        assertEq(ponzio.realBalanceOf(address(this)), 0);
    }

    receive() external payable { }
}

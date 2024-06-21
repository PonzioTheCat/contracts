// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { UniswapV2Library } from "src/libraries/UniswapV2Library.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IWETH } from "src/interfaces/IWETH.sol";
import { IRouter } from "src/interfaces/IRouter.sol";
import { IPonzioTheCat } from "src/interfaces/IPonzioTheCat.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Pair } from "src/interfaces/UniswapV2/IUniswapV2Pair.sol";
import { IUniswapV2Router02 } from "src/interfaces/UniswapV2/IUniswapV2Router02.sol";

/**
 * @title Router
 * @dev This contract is responsible for handling token swaps and liquidity provisions on a UniswapV2 pair.
 */
contract Router is IRouter, ReentrancyGuard {
    using SafeERC20 for IPonzioTheCat;
    using SafeERC20 for IERC20;

    /// @inheritdoc IRouter
    IERC20 public immutable LP_TOKEN;
    /// @inheritdoc IRouter
    IPonzioTheCat public immutable PONZIO;
    /// @notice the address of the Uniswap V2 Router
    address internal constant UNISWAPV2_ROUTER_ADDR = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    /// @notice the address of the WETH token
    address internal constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor(address lpToken, address ponzioTheCatAddress) {
        LP_TOKEN = IERC20(lpToken);
        PONZIO = IPonzioTheCat(ponzioTheCatAddress);
    }

    /* -------------------------------------------------------------------------- */
    /*                             external functions                             */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IRouter
    function updateSupplyAndAddLiquidity(
        uint256 amountWETHDesired,
        uint256 amountPonzioDesired,
        uint256 amountETHMin,
        uint256 amountPonzioMin,
        address to
    ) external payable nonReentrant returns (uint256 amountPonzio_, uint256 amountETH_, uint256 liquidity_) {
        PONZIO.updateTotalSupply();

        (amountPonzio_, amountETH_, liquidity_) = _handlePairAndAddLiquidity(
            amountWETHDesired, amountPonzioDesired, amountETHMin, amountPonzioMin, to, msg.sender
        );
    }

    /// @inheritdoc IRouter
    function swap(uint256 amountIn, uint256 amountOutMin, address[] memory path, address to, uint256 deadline)
        external
        payable
        nonReentrant
    {
        if (path.length < 2) {
            revert Router_invalidPath(path);
        }

        PONZIO.updateTotalSupply();

        if (path[0] == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            if (msg.value == 0) {
                revert Router_valueNeeded();
            }

            path[0] = WETH_ADDR;
            IUniswapV2Router02(UNISWAPV2_ROUTER_ADDR).swapExactETHForTokensSupportingFeeOnTransferTokens{
                value: msg.value
            }(amountOutMin, path, to, deadline);
        } else {
            if (msg.value != 0) {
                revert Router_valueNotNeeded();
            }

            IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
            IERC20(path[0]).forceApprove(UNISWAPV2_ROUTER_ADDR, amountIn);

            if (path[path.length - 1] == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
                path[path.length - 1] = WETH_ADDR;
                IUniswapV2Router02(UNISWAPV2_ROUTER_ADDR).swapExactTokensForETHSupportingFeeOnTransferTokens(
                    amountIn, amountOutMin, path, to, deadline
                );
            } else {
                IUniswapV2Router02(UNISWAPV2_ROUTER_ADDR).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    amountIn, amountOutMin, path, to, deadline
                );
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                             internal functions                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Calculates liquidity to add to the Uniswap pair for Ponzio and WETH.
     * @param amountPonzioDesired The amount of Ponzio the user wants to add as liquidity.
     * @param amountWETHDesired The amount of WETH the user wants to add as liquidity.
     * @param amountPonzioMin The minimum amount of Ponzio the user wants to add as liquidity.
     * @param amountWETHMin The minimum amount of WETH the user wants to add as liquidity.
     * @return amountPonzio_ The actual amount of Ponzio added as liquidity.
     * @return amountWETH_ The actual amount of WETH added as liquidity.
     */
    function _calcLiquidityToAdd(
        uint256 amountPonzioDesired,
        uint256 amountWETHDesired,
        uint256 amountPonzioMin,
        uint256 amountWETHMin
    ) internal view returns (uint256 amountPonzio_, uint256 amountWETH_) {
        address token0 = WETH_ADDR < address(PONZIO) ? WETH_ADDR : address(PONZIO);

        // slither-disable-next-line unused-return
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(address(LP_TOKEN)).getReserves();
        (uint256 reservePonzio, uint256 reserveWETH) =
            address(PONZIO) == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

        uint256 amountWETHOptimal = UniswapV2Library.quote(amountPonzioDesired, reservePonzio, reserveWETH);

        if (amountWETHOptimal <= amountWETHDesired) {
            if (amountWETHMin > amountWETHOptimal) {
                revert Router_insufficientAmount();
            }

            (amountPonzio_, amountWETH_) = (amountPonzioDesired, amountWETHOptimal);
        } else {
            uint256 amountPonzioOptimal = UniswapV2Library.quote(amountWETHDesired, reserveWETH, reservePonzio);

            if (amountPonzioOptimal > amountPonzioDesired) {
                revert Router_liquidityError();
            }
            if (amountPonzioMin > amountPonzioOptimal) {
                revert Router_insufficientAmount();
            }

            (amountPonzio_, amountWETH_) = (amountPonzioOptimal, amountWETHDesired);
        }
    }

    /**
     * @notice Handle the pair address and add liquidity to it.
     * @param amountWETHDesired The amount of WETH the user wants to add as liquidity.
     * @param amountPonzioDesired The amount of Ponzio token the user wants to add as liquidity.
     * @param amountETHMin The minimum amount of ETH/WETH the user wants to add as liquidity.
     * @param amountPonzioMin The minimum amount of Ponzio token the user wants to add as liquidity.
     * @param to The address to which the liquidity tokens will be minted.
     * @param from The address from which the tokens will be transferred.
     * @return amountPonzio_ The actual amount of Ponzio token added as liquidity.
     * @return amountETH_ The actual amount of token A added as liquidity.
     * @return liquidity_ The amount of liquidity tokens minted.
     */
    function _handlePairAndAddLiquidity(
        uint256 amountWETHDesired,
        uint256 amountPonzioDesired,
        uint256 amountETHMin,
        uint256 amountPonzioMin,
        address to,
        address from
    ) internal returns (uint256 amountPonzio_, uint256 amountETH_, uint256 liquidity_) {
        if (msg.value == 0) {
            (amountPonzio_, amountETH_) =
                _calcLiquidityToAdd(amountPonzioDesired, amountWETHDesired, amountPonzioMin, amountETHMin);

            IERC20(WETH_ADDR).safeTransferFrom(from, address(LP_TOKEN), amountETH_);
            PONZIO.safeTransferFrom(from, address(LP_TOKEN), amountPonzio_);

            liquidity_ = IUniswapV2Pair(address(LP_TOKEN)).mint(to);
        } else {
            (amountPonzio_, amountETH_) = _calcLiquidityToAdd(amountPonzioDesired, msg.value, amountPonzioMin, amountETHMin);

            IWETH(WETH_ADDR).deposit{ value: amountETH_ }();
            IERC20(WETH_ADDR).safeTransfer(address(LP_TOKEN), amountETH_);
            PONZIO.safeTransferFrom(from, address(LP_TOKEN), amountPonzio_);

            liquidity_ = IUniswapV2Pair(address(LP_TOKEN)).mint(to);

            // refund dust eth, if any
            if (msg.value > amountETH_) {
                (bool success,) = msg.sender.call{ value: msg.value - amountETH_ }("");
                if (!success) {
                    revert Router_refundFailed();
                }
            }
        }
    }
}

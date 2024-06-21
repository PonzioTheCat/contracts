// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FakeUniV2Pair is ERC20 {
    constructor() ERC20("Uniswap V2", "UNI-V2") {
        _mint(msg.sender, 100_000 * 10 ** 18);
    }

    function sync() external {
        // do nothing
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) { }

    function PERMIT_TYPEHASH() external pure returns (bytes32) { }

    function nonces(address owner) external view returns (uint256) { }

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    { }

    function MINIMUM_LIQUIDITY() external pure returns (uint256) { }

    function factory() external view returns (address) { }

    function token0() external view returns (address) { }

    function token1() external view returns (address) { }

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) { }

    function price0CumulativeLast() external view returns (uint256) { }

    function price1CumulativeLast() external view returns (uint256) { }

    function kLast() external view returns (uint256) { }

    function mint(address to) external returns (uint256 liquidity) { }

    function burn(address to) external returns (uint256 amount0, uint256 amount1) { }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external { }

    function skim(address to) external { }

    function initialize(address, address) external { }
}

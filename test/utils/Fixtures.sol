// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "./Constants.sol";

contract BaseFixture is Test {
    constructor() {
        vm.label(DEPLOYER, "Deployer");
        vm.label(ADMIN, "Admin");
        vm.label(USER_1, "User1");
        vm.label(USER_2, "User2");
        vm.label(USER_3, "User3");
        vm.label(USER_4, "User4");
    }
}
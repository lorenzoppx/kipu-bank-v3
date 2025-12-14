// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/CompileCheck.sol";

contract CompileTest is Test {
    function testCompile() public {
        CompileCheck c = new CompileCheck();
        assertTrue(address(c) != address(0));
    }
}

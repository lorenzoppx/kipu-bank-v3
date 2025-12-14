// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/forge-std/src/Test.sol";
import "../src/Kipu.sol";

contract CompileTest is Test {
    function testCompile() public {
        address owner = address(0x123);
        Kipu kipu = new Kipu(owner, address(0x456), address(0x789));
    }
}

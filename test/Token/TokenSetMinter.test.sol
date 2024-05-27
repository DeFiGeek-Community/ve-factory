// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Token.sol";

contract TokenSetMinterTest is Test {
    Token token;
    address admin;
    address nonAdmin;
    address newMinter;
    address newAdmin;

    function setUp() public {
        vm.warp(block.timestamp + 365 days * 10);
        admin = address(this);
        nonAdmin = address(0x1);
        newMinter = address(0x2);
        newAdmin = address(0x3);
        token = new Token(
            "Token",
            "TKN",
            18,
            1e24, // 1,000,000 tokens for simplicity
            55_000_000,
            365 days,
            10,
            1 days
        );
    }

    function testRevertNonAdminSetMinter() public {
        vm.prank(nonAdmin);
        vm.expectRevert("dev: admin only");
        token.setMinter(newMinter);
    }

    function testRevertNonAdminSetAdmin() public {
        vm.prank(nonAdmin);
        vm.expectRevert("dev: admin only");
        token.setAdmin(newAdmin);
    }

    function testAllowAdminToSetMinter() public {
        token.setMinter(newMinter);
        assertEq(token.tokenMinter(), newMinter);
    }

    function testAllowAdminToSetAdmin() public {
        token.setAdmin(newAdmin);
        assertEq(token.admin(), newAdmin);
    }
}

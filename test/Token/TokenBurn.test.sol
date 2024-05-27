// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Token.sol";

contract TokenBurnTest is Test {
    Token token;
    address account0;
    address account1;

    function setUp() public {
        vm.warp(block.timestamp + 365 days * 10);
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
        account0 = address(this);
        account1 = address(0x1);
    }

    function testBurn() public {
        uint256 balance = token.balanceOf(account0);
        uint256 initialSupply = token.totalSupply();

        token.burn(31337);

        assertEq(token.balanceOf(account0), balance - 31337);
        assertEq(token.totalSupply(), initialSupply - 31337);
    }

    function testBurnNotAdmin() public {
        uint256 initialSupply = token.totalSupply();

        token.transfer(account1, 1e6);
        vm.prank(account1);
        token.burn(31337);

        assertEq(token.balanceOf(account1), 1e6 - 31337);
        assertEq(token.totalSupply(), initialSupply - 31337);
    }

    function testBurnAll() public {
        uint256 initialSupply = token.totalSupply();

        token.burn(initialSupply);

        assertEq(token.balanceOf(account0), 0);
        assertEq(token.totalSupply(), 0);
    }

    error ERC20InsufficientBalance(
        address sender,
        uint256 balance,
        uint256 needed
    );

    function testOverBurn() public {
        uint256 initialSupply = token.totalSupply();
        address from = address(this);
        uint256 currentBalance = token.balanceOf(from);
        uint256 amountRequested = initialSupply + 1;

        bytes memory encodedError = abi.encodeWithSelector(
            ERC20InsufficientBalance.selector,
            from,
            currentBalance,
            amountRequested
        );
        vm.expectRevert(encodedError);
        token.burn(amountRequested);
    }
}

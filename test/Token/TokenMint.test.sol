// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Token.sol";

contract TokenMintTest is Test {
    Token token;
    uint256 constant week = 1 weeks;
    address constant ZERO_ADDRESS = address(0);

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
        vm.warp(block.timestamp + 1 days);
        token.updateMiningParameters();
    }

    function testAvailableSupply() public {
        uint256 creationTime = token.startEpochTime();
        uint256 initialSupply = token.totalSupply();
        uint256 rate = token.rate();

        vm.warp(block.timestamp + week);

        uint256 expected = initialSupply + (block.timestamp - creationTime) * rate;
        assertEq(token.availableSupply(), expected);
    }

    function testMint() public {
        token.setMinter(address(this));
        uint256 creationTime = token.startEpochTime();
        uint256 initialSupply = token.totalSupply();
        uint256 rate = token.rate();

        vm.warp(block.timestamp + week);

        uint256 amount = (block.timestamp - creationTime) * rate;
        token.mint(address(1), amount);

        assertEq(token.balanceOf(address(1)), amount);
        assertEq(token.totalSupply(), initialSupply + amount);
    }

    function testOvermint() public {
        token.setMinter(address(this));
        uint256 creationTime = token.startEpochTime();
        uint256 rate = token.rate();

        vm.warp(block.timestamp + week);

        uint256 amount = (block.timestamp - creationTime + 2) * rate;
        vm.expectRevert("dev: exceeds allowable mint amount");
        token.mint(address(1), amount);
    }

    function testMinterOnly() public {
        token.setMinter(address(this));
        vm.prank(address(1)); // アカウント1からの呼び出しをシミュレート
        vm.expectRevert("dev: tokenMinter only");
        token.mint(address(1), 0);
    }

    function testZeroAddress() public {
        token.setMinter(address(this));
        vm.expectRevert("dev: zero address");
        token.mint(ZERO_ADDRESS, 0);
    }
}

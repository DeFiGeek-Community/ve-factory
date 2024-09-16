// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Token.sol";

contract TokenInflationDelayTest is Test {
    Token token;
    uint256 constant YEAR = 365 days;

    function setUp() public {
        vm.warp(block.timestamp + 365 days * 10);
        token = new Token(
            "Token",
            "TKN",
            18,
            1e10, // 1,000,000 tokens for simplicity
            55_000_000,
            365 days,
            10,
            1 days
        );
    }

    function testRate() public {
        assertEq(token.rate(), 0);

        vm.warp(block.timestamp + 86401);
        token.updateMiningParameters();

        assertTrue(token.rate() > 0);
    }

    function testStartEpochTime() public {
        uint256 creationTime = token.startEpochTime();

        vm.warp(block.timestamp + 86401);
        token.updateMiningParameters();

        assertEq(token.startEpochTime(), creationTime + YEAR);
    }

    function testMiningEpoch() public {
        assertEq(token.miningEpoch(), -1);

        vm.warp(block.timestamp + 86401);
        token.updateMiningParameters();

        assertEq(token.miningEpoch(), 0);
    }

    function testAvailableSupply() public {
        uint256 initialSupply = 1e10 * (10 ** 18);
        assertEq(token.availableSupply(), initialSupply);

        vm.warp(block.timestamp + 86401);
        token.updateMiningParameters();

        assertTrue(token.availableSupply() > initialSupply);
    }
}

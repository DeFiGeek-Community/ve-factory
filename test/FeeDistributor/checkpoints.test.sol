// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/FeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributorCheckpointTest is Test {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;
    uint256 constant YEAR = DAY * 365;
    address alice;
    address bob;
    address charlie;

    FeeDistributor distributor;
    VeToken veToken;
    IERC20 token;
    SampleToken coinA;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);

        token = new SampleToken(2e18);
        coinA = new SampleToken(2e18);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        uint256 currentTime = block.timestamp;
        distributor = new FeeDistributor(
            address(veToken),
            currentTime,
            address(coinA),
            alice,
            bob
        );

        token.approve(address(veToken), type(uint256).max);
        veToken.createLock(1e18 * 1000, block.timestamp + WEEK * 52);
    }

    function testCheckpointTotalSupply() public {
        uint256 startTime = distributor.timeCursor();
        uint256 weekEpoch = ((block.timestamp + WEEK) / WEEK) * WEEK;

        vm.warp(weekEpoch);

        distributor.checkpointTotalSupply();

        assertEq(distributor.veSupply(startTime), 0);
        assertEq(distributor.veSupply(weekEpoch), veToken.totalSupply());
    }

    function testAdvanceTimeCursor() public {
        uint256 startTime = distributor.timeCursor();
        vm.warp(block.timestamp + YEAR);
        distributor.checkpointTotalSupply();
        uint256 newTimeCursor = distributor.timeCursor();

        assertEq(newTimeCursor, startTime + WEEK * 20);
        assertTrue(distributor.veSupply(startTime + WEEK * 19) > 0);
        assertEq(distributor.veSupply(startTime + WEEK * 20), 0);

        distributor.checkpointTotalSupply();

        assertEq(distributor.timeCursor(), startTime + WEEK * 40);
        assertTrue(distributor.veSupply(startTime + WEEK * 20) > 0);
        assertTrue(distributor.veSupply(startTime + WEEK * 39) > 0);
        assertEq(distributor.veSupply(startTime + WEEK * 40), 0);
    }

    function testClaimCheckpointsTotalSupply() public {
        uint256 startTime = distributor.timeCursor();

        distributor.claim(alice);

        assertEq(distributor.timeCursor(), startTime + WEEK);
    }

    function testToggleAllowCheckpoint() public {
        uint256 lastTokenTime = distributor.lastTokenTime();

        vm.warp(block.timestamp + WEEK);

        distributor.claim(alice);
        assertEq(distributor.lastTokenTime(), lastTokenTime);

        distributor.toggleAllowCheckpointToken();
        vm.prank(alice);
        distributor.claim();

        uint256 newLastTokenTime = distributor.lastTokenTime();
        assertTrue(newLastTokenTime > lastTokenTime);
    }
}

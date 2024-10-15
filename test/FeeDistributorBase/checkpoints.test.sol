// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "src/FeeDistributorBase.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributorBase_CheckpointTest is Test {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;
    uint256 constant YEAR = DAY * 365;
    address alice;
    address bob;
    address charlie;

    FeeDistributorBase public feeDistributor;
    VeToken veToken;
    IERC20 token;
    SampleToken coinA;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);

        token = new SampleToken(1e26);
        coinA = new SampleToken(1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        feeDistributor = new FeeDistributorBase();
        feeDistributor.initialize(address(veToken), vm.getBlockTimestamp(), address(coinA), alice, bob);

        token.transfer(alice, 1e24);
        vm.startPrank(alice);
        token.approve(address(veToken), type(uint256).max);
        veToken.createLock(1e18 * 1000, vm.getBlockTimestamp() + WEEK * 52);
    }

    function testCheckpointTotalSupply() public {
        uint256 startTime = feeDistributor.timeCursor();
        uint256 weekEpoch = ((vm.getBlockTimestamp() + WEEK) / WEEK) * WEEK;

        vm.warp(weekEpoch);

        feeDistributor.checkpointTotalSupply();

        assertEq(feeDistributor.veSupply(startTime), 0);
        assertEq(feeDistributor.veSupply(weekEpoch), veToken.totalSupply());
    }

    function testAdvanceTimeCursor() public {
        uint256 startTime = feeDistributor.timeCursor();
        vm.warp(vm.getBlockTimestamp() + YEAR);
        feeDistributor.checkpointTotalSupply();
        uint256 newTimeCursor = feeDistributor.timeCursor();

        assertEq(newTimeCursor, startTime + WEEK * 20);
        assertTrue(feeDistributor.veSupply(startTime + WEEK * 19) > 0);
        assertEq(feeDistributor.veSupply(startTime + WEEK * 20), 0);

        feeDistributor.checkpointTotalSupply();

        assertEq(feeDistributor.timeCursor(), startTime + WEEK * 40);
        assertTrue(feeDistributor.veSupply(startTime + WEEK * 20) > 0);
        assertTrue(feeDistributor.veSupply(startTime + WEEK * 39) > 0);
        assertEq(feeDistributor.veSupply(startTime + WEEK * 40), 0);
    }

    function testClaimCheckpointsTotalSupply() public {
        uint256 startTime = feeDistributor.timeCursor();

        feeDistributor.claim();

        assertEq(feeDistributor.timeCursor(), startTime + WEEK);
    }

    function testToggleAllowCheckpoint() public {
        uint256 lastTokenTime = feeDistributor.lastTokenTime();

        vm.warp(vm.getBlockTimestamp() + WEEK);

        feeDistributor.claim();
        assertEq(feeDistributor.lastTokenTime(), lastTokenTime);

        feeDistributor.toggleAllowCheckpointToken();
        vm.stopPrank();
        vm.prank(alice);
        feeDistributor.claim();

        uint256 newLastTokenTime = feeDistributor.lastTokenTime();
        assertTrue(newLastTokenTime > lastTokenTime);
    }
}

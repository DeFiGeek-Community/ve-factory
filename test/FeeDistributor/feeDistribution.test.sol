// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/FeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributorFeeDistributionTest is Test {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;

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

        token = new SampleToken(1e22);
        coinA = new SampleToken(1e22);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        uint256 currentTime = block.timestamp;
        distributor = new FeeDistributor(
            address(veToken),
            currentTime,
            address(coinA),
            alice,
            bob
        );
    }

    function testDepositedAfter() public {
        uint256 amount = 1e18 * 1000; // 1000 tokens
        token.approve(address(veToken), amount * 10);
        coinA.transfer(address(bob), 1e18 * 100);

        for (uint256 i = 0; i < 5; i++) {
            for (uint256 j = 0; j < 7; j++) {
                coinA.transfer(address(distributor), 1e18);
                distributor.checkpointToken();
                distributor.checkpointTotalSupply();
                vm.warp(block.timestamp + DAY);
            }
        }

        vm.warp(block.timestamp + WEEK);
        veToken.createLock(amount, block.timestamp + 3 * WEEK);
        vm.warp(block.timestamp + 2 * WEEK);

        distributor.claim(alice);

        uint256 balanceBefore = coinA.balanceOf(alice);
        distributor.claim(alice);
        uint256 balanceAfter = coinA.balanceOf(alice);
        assertEq(balanceAfter - balanceBefore, 0);
    }

    function testDepositedDuring() public {
        uint256 amount = 1e18 * 1000; // 1000 tokens
        token.approve(address(veToken), amount * 10);
        coinA.transfer(address(bob), 1e18 * 100);

        vm.warp(block.timestamp + WEEK);
        veToken.createLock(amount, block.timestamp + 8 * WEEK);
        vm.warp(block.timestamp + WEEK);

        distributor = new FeeDistributor(
            address(veToken),
            block.timestamp,
            address(coinA),
            alice,
            alice
        );

        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = 0; j < 7; j++) {
                coinA.transfer(address(distributor), 1e18);
                distributor.checkpointToken();
                distributor.checkpointTotalSupply();
                vm.warp(block.timestamp + DAY);
            }
        }

        vm.warp(block.timestamp + WEEK);
        distributor.checkpointToken();
        distributor.claim(alice);

        uint256 balanceAlice = coinA.balanceOf(alice);
        uint256 diff = balanceAlice > 21e18
            ? balanceAlice - 21e18
            : 21e18 - balanceAlice;
        assertTrue(diff < 10);
    }

    function testDepositedBefore() public {
        uint256 amount = 1e18 * 1000; // 1000 tokens

        token.approve(address(veToken), amount * 10);
        coinA.transfer(address(bob), 1e18 * 100);

        veToken.createLock(amount, block.timestamp + 8 * WEEK);
        vm.warp(block.timestamp + WEEK);
        uint256 startTime = block.timestamp;
        vm.warp(block.timestamp + WEEK * 5);

        distributor = new FeeDistributor(
            address(veToken),
            startTime,
            address(coinA),
            alice,
            alice
        );

        coinA.transfer(address(distributor), 1e18 * 10);
        distributor.checkpointToken();
        vm.warp(block.timestamp + WEEK);
        distributor.checkpointToken();
        distributor.claim(alice);

        uint256 balanceAlice = coinA.balanceOf(alice);
        assertTrue(balanceAlice >= 1e18 * 10 && balanceAlice <= 1e18 * 10 + 10);
    }

    function testDepositedTwice() public {
        uint256 amount = 1e18 * 1000; // 1000 tokens

        token.approve(address(veToken), amount * 10);
        coinA.transfer(address(bob), 1e18 * 100);

        veToken.createLock(amount, block.timestamp + 4 * WEEK);
        vm.warp(block.timestamp + WEEK);

        uint256 startTime = block.timestamp;
        vm.warp(block.timestamp + 3 * WEEK);

        veToken.withdraw();
        uint256 excludeTime = (block.timestamp / WEEK) * WEEK;
        veToken.createLock(amount, block.timestamp + 4 * WEEK);

        vm.warp(block.timestamp + 2 * WEEK);

        distributor = new FeeDistributor(
            address(veToken),
            startTime,
            address(coinA),
            alice,
            alice
        );

        coinA.transfer(address(distributor), 1e18 * 10);
        distributor.checkpointToken();
        vm.warp(block.timestamp + WEEK);
        distributor.checkpointToken();
        distributor.claim(alice);

        uint256 tokensToExclude = distributor.tokensPerWeek(excludeTime);
        uint256 balanceAlice = coinA.balanceOf(alice);
        assertTrue(balanceAlice + tokensToExclude >= 1e18 * 10);
    }

    function testDepositedParallel() public {
        uint256 amount = 1e18 * 1000; // 1000 tokens

        token.transfer(bob, amount);
        token.approve(address(veToken), amount * 10);

        vm.prank(bob);
        token.approve(address(veToken), amount * 10);

        coinA.transfer(address(charlie), 1e18 * 100);

        veToken.createLock(amount, block.timestamp + 8 * WEEK);

        vm.prank(bob);
        veToken.createLock(
            amount,
            block.timestamp + 8 * WEEK
        );

        vm.warp(block.timestamp + WEEK);
        uint256 startTime = block.timestamp;
        vm.warp(block.timestamp + 5 * WEEK);

        distributor = new FeeDistributor(
            address(veToken),
            startTime,
            address(coinA),
            alice,
            alice
        );

        coinA.transfer(address(distributor), 1e18 * 10);
        distributor.checkpointToken();
        vm.warp(block.timestamp + WEEK);
        distributor.checkpointToken();

        distributor.claim(alice);
        distributor.claim(bob);

        uint256 balanceAlice = coinA.balanceOf(alice);
        uint256 balanceBob = coinA.balanceOf(bob);

        assertTrue(balanceAlice == balanceBob);
        assertTrue(balanceAlice + balanceBob >= 1e18 * 10);
    }
}

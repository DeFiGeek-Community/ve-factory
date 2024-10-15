// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";
import "script/DeployMultiTokenFeeDistributor.s.sol";

contract MultiTokenFeeDistributor_InitializeClaimTimingTest is Test, DeployMultiTokenFeeDistributor {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;

    address alice;
    address bob;
    address charlie;

    IMultiTokenFeeDistributor public feeDistributor;

    VeToken veToken;
    IERC20 token;
    SampleToken coinA;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);
        vm.warp(WEEK * 1000);

        token = new SampleToken(1e40);
        token.transfer(alice, 1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        token.approve(address(veToken), 1e24);
        vm.prank(alice);
        token.approve(address(veToken), type(uint256).max);
        vm.prank(bob);
        token.approve(address(veToken), type(uint256).max);
        vm.prank(charlie);
        token.approve(address(veToken), type(uint256).max);

        (address proxyAddress,) = deploy(address(veToken), address(this), bob, false);
        feeDistributor = IMultiTokenFeeDistributor(proxyAddress);

        feeDistributor.toggleAllowCheckpointToken();
    }

    function testClaimAfterTokenDeposit() public {
        vm.warp(WEEK * 1000);
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        feeDistributor.addToken(address(coinA), vm.getBlockTimestamp());
        assertTrue(feeDistributor.canCheckpointToken());
        vm.warp(feeDistributor.lastTokenTime(address(coinA)));

        uint256 amount = 1000 * 1e18;

        // トークンの転送
        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e18);

        vm.startPrank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 3 * WEEK);
        vm.warp(vm.getBlockTimestamp() + 2 * WEEK);

        feeDistributor.claimFor(alice, address(coinA));
        uint256 balanceBefore = coinA.balanceOf(alice);

        feeDistributor.claimFor(alice, address(coinA));
        uint256 balanceAfter = coinA.balanceOf(alice);

        assertEq(balanceAfter - balanceBefore, 0);
    }

    function testClaimDuringTokenDepositPeriod() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        vm.warp(vm.getBlockTimestamp() + WEEK);

        vm.prank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 30 * WEEK);
        vm.warp(vm.getBlockTimestamp() + WEEK);

        feeDistributor.addToken(address(coinA), vm.getBlockTimestamp());
        vm.warp(feeDistributor.lastTokenTime(address(coinA)));
        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = 0; j < 7; j++) {
                vm.prank(bob);
                coinA.transfer(address(feeDistributor), 1e18);
                vm.warp(vm.getBlockTimestamp() + DAY);
            }
        }

        vm.warp(vm.getBlockTimestamp() + WEEK * 10);
        vm.prank(alice);
        feeDistributor.claimFor(alice, address(coinA));
        coinA.balanceOf(address(this));

        assertApproxEqAbs(coinA.balanceOf(alice), 21 * 1e18, 1e2);
    }

    function testClaimBeforeTokenDeposit() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        vm.prank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 8 * WEEK);
        vm.warp(vm.getBlockTimestamp() + WEEK);
        uint256 startTime = vm.getBlockTimestamp();
        vm.warp(vm.getBlockTimestamp() + WEEK * 5);

        feeDistributor.addToken(address(coinA), startTime);

        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e19);
        vm.warp(vm.getBlockTimestamp() + WEEK * 2);
        feeDistributor.claimFor(alice, address(coinA));

        assertApproxEqAbs(coinA.balanceOf(alice), 1e19, 1e2);
    }

    function testClaimForMultipleTokenDeposits() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        vm.prank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 4 * WEEK);
        vm.warp(vm.getBlockTimestamp() + WEEK);
        uint256 startTime = vm.getBlockTimestamp();
        vm.warp(vm.getBlockTimestamp() + WEEK * 3);

        vm.prank(alice);
        veToken.withdraw();

        vm.prank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 10 * WEEK);
        vm.warp(vm.getBlockTimestamp() + WEEK * 2);

        feeDistributor.addToken(address(coinA), startTime);

        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e19);
        vm.warp(vm.getBlockTimestamp() + WEEK * 2);
        feeDistributor.claimFor(alice, address(coinA));

        assertApproxEqAbs(coinA.balanceOf(alice), 1e19, 1e2);
    }

    function testDepositedParallel() public {
        vm.prank(charlie);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;

        token.transfer(bob, amount);
        uint256 currentTimestamp = vm.getBlockTimestamp();
        vm.prank(alice);
        veToken.createLock(amount, currentTimestamp + 8 * WEEK);
        vm.prank(bob);
        veToken.createLock(amount, currentTimestamp + 8 * WEEK);
        vm.warp(vm.getBlockTimestamp() + WEEK);
        uint256 startTime = vm.getBlockTimestamp();
        vm.warp(vm.getBlockTimestamp() + WEEK * 5);

        feeDistributor.addToken(address(coinA), startTime);

        vm.prank(charlie);
        coinA.transfer(address(feeDistributor), 1e19);
        feeDistributor.checkpointToken(address(coinA));
        vm.warp(vm.getBlockTimestamp() + WEEK);
        feeDistributor.checkpointToken(address(coinA));
        feeDistributor.claimFor(alice, address(coinA));
        feeDistributor.claimFor(bob, address(coinA));

        uint256 balanceAlice = coinA.balanceOf(alice);
        uint256 balanceBob = coinA.balanceOf(bob);
        assertEq(balanceAlice, balanceBob);
        assertApproxEqAbs(balanceAlice + balanceBob, 1e19, 1e2);
    }
}

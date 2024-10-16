// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "src/Interfaces/IFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";
import "script/DeployFeeDistributor.s.sol";

contract SingleTokenFeeDistributor_FeeDistributionTest is Test, DeployFeeDistributor {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;

    address alice;
    address bob;
    address charlie;

    IFeeDistributor public feeDistributor;

    VeToken veToken;
    IERC20 token;
    SampleToken coinA;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);

        vm.warp(WEEK * 100);

        token = new SampleToken(1e32);
        token.transfer(alice, 1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        token.approve(address(veToken), 1e24);
        vm.prank(alice);
        token.approve(address(veToken), type(uint256).max);
        vm.prank(bob);
        token.approve(address(veToken), type(uint256).max);
        vm.prank(charlie);
        token.approve(address(veToken), type(uint256).max);
    }

    function feeDistributorInitialize(uint256 time) internal {
        (address proxyAddress,) = deploy(address(veToken), time, address(coinA), address(this), bob, false);
        feeDistributor = IFeeDistributor(proxyAddress);
        // feeDistributor.initialize(address(veToken), time, address(coinA), address(this), bob);
    }

    function testDepositedAfter() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);
        feeDistributorInitialize(vm.getBlockTimestamp());
        uint256 amount = 1000 * 1e18;
        vm.prank(alice);
        token.approve(address(veToken), amount * 10);
        // トークンの転送とチェックポイントの作成
        for (uint256 i = 0; i < 5; i++) {
            for (uint256 j = 0; j < 7; j++) {
                vm.prank(bob);
                coinA.transfer(address(feeDistributor), 1e18);
                feeDistributor.checkpointToken();
                feeDistributor.checkpointTotalSupply();
                vm.warp(vm.getBlockTimestamp() + DAY);
            }
        }

        vm.warp(vm.getBlockTimestamp() + WEEK);

        vm.prank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 3 * WEEK);
        vm.warp(vm.getBlockTimestamp() + 2 * WEEK);

        vm.prank(alice);
        feeDistributor.claimFor(alice);
        uint256 balanceBefore = coinA.balanceOf(alice);
        vm.prank(alice);
        feeDistributor.claimFor(alice);
        uint256 balanceAfter = coinA.balanceOf(alice);

        assertEq(balanceAfter - balanceBefore, 0);
    }

    function testDepositedDuring() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        vm.prank(alice);
        token.approve(address(veToken), amount * 10);

        vm.warp(vm.getBlockTimestamp() + WEEK);

        vm.prank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 8 * WEEK);
        vm.warp(vm.getBlockTimestamp() + WEEK);

        feeDistributorInitialize(vm.getBlockTimestamp());

        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = 0; j < 7; j++) {
                vm.prank(bob);
                coinA.transfer(address(feeDistributor), 1e18);
                feeDistributor.checkpointToken();
                feeDistributor.checkpointTotalSupply();
                vm.warp(vm.getBlockTimestamp() + DAY);
            }
        }

        vm.warp(vm.getBlockTimestamp() + WEEK);
        feeDistributor.checkpointToken();
        vm.prank(alice);
        feeDistributor.claimFor(alice);

        assertApproxEqAbs(coinA.balanceOf(alice), 21 * 1e18, 1e2);
    }

    function testDepositedBefore() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        vm.prank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 8 * WEEK);
        vm.warp(vm.getBlockTimestamp() + WEEK);
        uint256 startTime = vm.getBlockTimestamp();
        vm.warp(vm.getBlockTimestamp() + WEEK * 5);
        feeDistributorInitialize(startTime);

        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e19);
        feeDistributor.checkpointToken();
        vm.warp(vm.getBlockTimestamp() + WEEK);
        feeDistributor.checkpointToken();
        feeDistributor.claimFor(alice);

        assertApproxEqAbs(coinA.balanceOf(alice), 1e19, 1e2);
    }

    function testDepositedTwice() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        vm.prank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 4 * WEEK);
        vm.warp(vm.getBlockTimestamp() + WEEK);
        vm.warp(vm.getBlockTimestamp() + WEEK * 3);

        vm.prank(alice);
        veToken.withdraw();
        uint256 excludeTime = (vm.getBlockTimestamp() / WEEK) * WEEK;

        vm.prank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 4 * WEEK);
        vm.warp(vm.getBlockTimestamp() + WEEK * 2);

        feeDistributorInitialize(vm.getBlockTimestamp());

        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e19);
        feeDistributor.checkpointToken();
        vm.warp(vm.getBlockTimestamp() + WEEK);
        feeDistributor.checkpointToken();
        feeDistributor.claimFor(alice);

        uint256 tokensToExclude = feeDistributor.tokensPerWeek(excludeTime);
        assertApproxEqAbs(1e19 - coinA.balanceOf(alice), tokensToExclude, 1e2);
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

        feeDistributorInitialize(startTime);

        vm.prank(charlie);
        coinA.transfer(address(feeDistributor), 1e19);
        feeDistributor.checkpointToken();
        vm.warp(vm.getBlockTimestamp() + WEEK);
        feeDistributor.checkpointToken();
        feeDistributor.claimFor(alice);
        feeDistributor.claimFor(bob);

        uint256 balanceAlice = coinA.balanceOf(alice);
        uint256 balanceBob = coinA.balanceOf(bob);
        assertEq(balanceAlice, balanceBob);
        assertApproxEqAbs(balanceAlice + balanceBob, 1e19, 1e2);
    }
}

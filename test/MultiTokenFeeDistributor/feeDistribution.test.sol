// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";
import "script/DeployMultiTokenFeeDistributor.s.sol";

contract MultiTokenFeeDistributor_FeeDistributionTest is Test, DeployMultiTokenFeeDistributor {
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

        (address proxyAddress,) = deploy(address(veToken), address(this), bob, false);
        feeDistributor = IMultiTokenFeeDistributor(proxyAddress);
    }

    function testDepositedAfter() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);
        address[] memory tokens = new address[](1);
        tokens[0] = address(coinA);
        feeDistributor.addToken(address(coinA), vm.getBlockTimestamp());
        uint256 amount = 1000 * 1e18;
        vm.prank(alice);
        token.approve(address(veToken), amount * 10);
        // トークンの転送とチェックポイントの作成
        for (uint256 i = 0; i < 5; i++) {
            for (uint256 j = 0; j < 7; j++) {
                vm.prank(bob);
                coinA.transfer(address(feeDistributor), 1e18);
                feeDistributor.checkpointToken(address(coinA));
                feeDistributor.checkpointTotalSupply();
                vm.warp(vm.getBlockTimestamp() + DAY);
            }
        }

        vm.warp(vm.getBlockTimestamp() + WEEK);

        vm.prank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 3 * WEEK);
        vm.warp(vm.getBlockTimestamp() + 2 * WEEK);

        vm.prank(alice);
        feeDistributor.claimFor(alice, address(coinA));
        uint256 balanceBefore = coinA.balanceOf(alice);
        vm.prank(alice);
        feeDistributor.claimFor(alice, address(coinA));
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

        address[] memory tokens = new address[](1);
        tokens[0] = address(coinA);
        feeDistributor.addToken(address(coinA), vm.getBlockTimestamp());

        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = 0; j < 7; j++) {
                vm.prank(bob);
                coinA.transfer(address(feeDistributor), 1e18);
                feeDistributor.checkpointToken(address(coinA));
                feeDistributor.checkpointTotalSupply();
                vm.warp(vm.getBlockTimestamp() + DAY);
            }
        }

        vm.warp(vm.getBlockTimestamp() + WEEK);
        feeDistributor.checkpointToken(address(coinA));
        vm.prank(alice);
        feeDistributor.claimFor(alice, address(coinA));

        assertApproxEqAbs(coinA.balanceOf(alice), 21 * 1e18, 1e2);
    }

    function testDepositedBefore() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        vm.prank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 8 * WEEK);
        vm.warp(vm.getBlockTimestamp() + WEEK);
        vm.warp(vm.getBlockTimestamp() + WEEK * 5);
        feeDistributor.addToken(address(coinA), vm.getBlockTimestamp());

        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e19);
        feeDistributor.checkpointToken(address(coinA));
        vm.warp(vm.getBlockTimestamp() + WEEK);
        feeDistributor.checkpointToken(address(coinA));
        feeDistributor.claimFor(alice, address(coinA));

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

        feeDistributor.addToken(address(coinA), vm.getBlockTimestamp());

        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e19);
        feeDistributor.checkpointToken(address(coinA));
        vm.warp(vm.getBlockTimestamp() + WEEK);
        feeDistributor.checkpointToken(address(coinA));
        feeDistributor.claimFor(alice, address(coinA));

        uint256 tokensToExclude = feeDistributor.tokensPerWeek(address(coinA), excludeTime);

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

        vm.warp(vm.getBlockTimestamp() + WEEK * 5);

        feeDistributor.addToken(address(coinA), vm.getBlockTimestamp());

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
        // assertTrue(abs(balanceAlice + balanceBob - 1e19) < 20);
        assertApproxEqAbs(balanceAlice + balanceBob, 1e19, 1e2);
    }
}

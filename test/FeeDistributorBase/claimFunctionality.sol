// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "src/FeeDistributorBase.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributorBase_ClaimFunctionalityTest is Test {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;

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
        feeDistributor = new FeeDistributorBase();

        vm.warp(WEEK * 1000);
    }

    function feeDistributorInitialize(uint256 time) internal {
        feeDistributor.initialize(address(veToken), time, address(coinA), address(this), bob);
    }

    // このテストでは、チェックポイントトークンの許可後に請求が正しく行われるかを確認します。
    // 特に、Aliceがトークンをロックし、チェックポイント後に請求を行うシナリオをテストします。
    function testClaimWithCheckpointAfterToggle() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;

        vm.prank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 8 * WEEK);

        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e18);

        uint256 startTime = vm.getBlockTimestamp() + WEEK * 2;
        feeDistributorInitialize(startTime);

        feeDistributor.toggleAllowCheckpointToken();
        vm.warp(feeDistributor.lastTokenTime());

        vm.startPrank(alice);

        vm.warp(vm.getBlockTimestamp() + 6 days);
        feeDistributor.claimFor(alice);
        assertEq(coinA.balanceOf(alice), 0);

        vm.warp(vm.getBlockTimestamp() + 1 days);
        feeDistributor.claimFor(alice);
        uint256 balanceAlice = coinA.balanceOf(alice);

        assertApproxEqAbs(balanceAlice, 1e18, 1e2);
    }

    // このテストでは、複数回にわたるトークンの預金とチェックポイント後、
    // Aliceが期待通りのトークン残高を請求できるかを確認します。
    function testAccumulatedClaimsAfterMultipleTokenDeposits() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        // Aliceにトークンをロックさせる
        vm.prank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 4 * WEEK);
        vm.warp(vm.getBlockTimestamp() + WEEK);

        // FeeDistributorを初期化し、チェックポイントトークンを許可する
        feeDistributorInitialize(vm.getBlockTimestamp());
        feeDistributor.toggleAllowCheckpointToken();

        // 1回目のトークン転送とチェックポイント
        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e18);

        // Aliceが1回目の請求を行い、トークンの残高を確認する
        vm.warp(vm.getBlockTimestamp() + WEEK);
        vm.prank(alice);
        feeDistributor.claimFor(alice);
        uint256 balanceAfterFirstClaim = coinA.balanceOf(alice);
        assertEq(balanceAfterFirstClaim, 1e18);

        // 2回目のトークン転送とチェックポイント
        vm.warp(vm.getBlockTimestamp() + WEEK);
        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 2e18);
        feeDistributor.checkpointToken();

        // Aliceが2回目の請求を行い、トークンの残高を確認する
        vm.prank(alice);
        feeDistributor.claimFor(alice);
        uint256 balanceAfterSecondClaim = coinA.balanceOf(alice);

        // 2回目の請求で2e18が加算されていることを確認
        assertEq(balanceAfterSecondClaim, 3e18);
    }

    // このテストでは、VeTokenの残高がない状態での請求が失敗することを確認します。
    // Aliceがトークンをロックし、チェックポイント後に請求を試みるが、
    // VeTokenの残高がないために請求が加算されないことを検証します。
    function testClaimFailsWithoutVeTokenBalance() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        // Aliceにトークンをロックさせる
        vm.prank(alice);
        veToken.createLock(amount, vm.getBlockTimestamp() + 4 * WEEK);
        vm.warp(vm.getBlockTimestamp() + WEEK);

        // FeeDistributorを初期化し、チェックポイントトークンを許可する
        feeDistributorInitialize(vm.getBlockTimestamp());
        feeDistributor.toggleAllowCheckpointToken();

        // トークンをFeeDistributorに転送
        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e18);

        // Aliceが請求を行い、トークンの残高を確認する
        vm.warp(vm.getBlockTimestamp() + WEEK);
        vm.prank(alice);
        feeDistributor.claimFor(alice);
        uint256 balanceAfterFirstClaim = coinA.balanceOf(alice);
        assertEq(balanceAfterFirstClaim, 1e18);

        vm.warp(vm.getBlockTimestamp() + WEEK * 4);
        feeDistributor.checkpointToken();

        // さらにトークンを転送し、チェックポイントを作成
        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 2e18);

        // veTokenの残高がない状態でAliceが請求を試みる
        vm.prank(alice);
        feeDistributor.claimFor(alice);
        uint256 balanceAfterSecondAttempt = coinA.balanceOf(alice);

        // veTokenの残高がないため、2回目の請求でトークンが加算されていないことを確認
        assertEq(balanceAfterSecondAttempt, balanceAfterFirstClaim);
    }

    // このテストでは、大量のユーザー（10000人）がトークンをロックし、
    // それぞれが請求を行った際に正しい量のトークンを受け取れるかを確認します。
    function testClaimWithLargeNumberOfUsers() public {
        uint256 userCount = 1000; // テストするユーザーの数
        uint256 amount = 1e18; // 各ユーザーがロックするトークンの量

        // トークンをFeeDistributorに転送
        vm.prank(bob);
        coinA = new SampleToken(userCount * 1e18);

        // FeeDistributorを初期化し、チェックポイントトークンを許可する
        feeDistributorInitialize(vm.getBlockTimestamp());
        feeDistributor.toggleAllowCheckpointToken();

        vm.prank(bob);
        coinA.transfer(address(feeDistributor), userCount * 1e18);

        // 100人のユーザーがveTokenをロック
        for (uint256 i = 0; i < userCount; i++) {
            address user = address(uint160(i + 1)); // ユーザーアドレスを生成
            token.transfer(address(user), amount);
            vm.prank(user);
            token.approve(address(veToken), type(uint256).max);
            vm.prank(user);
            veToken.createLock(amount, vm.getBlockTimestamp() + 10 * WEEK);
        }

        vm.warp(vm.getBlockTimestamp() + WEEK * 3);

        // 各ユーザーがclaimを行う
        for (uint256 i = 0; i < userCount; i++) {
            address user = address(uint160(i + 1)); // ユーザーアドレスを生成
            uint256 balanceBefore = coinA.balanceOf(user); // claim前のトークン残高を記録

            vm.prank(user);
            feeDistributor.claimFor(user);

            uint256 balanceAfter = coinA.balanceOf(user); // claim後のトークン残高を記録
            uint256 claimedAmount = balanceAfter - balanceBefore; // claimによって得られたトークン量を計算

            // 各ユーザーが正しい量のトークンをclaimできたことを確認
            assertApproxEqAbs(claimedAmount, 1e18, 1e2);
        }
    }
}

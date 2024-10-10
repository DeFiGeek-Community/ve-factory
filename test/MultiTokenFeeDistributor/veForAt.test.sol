// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";
import {console} from "forge-std/console.sol";

contract MultiTokenFeeDistributor_VeForAtTest is TestBase {
    uint256 constant WEEK = 7 days;
    address alice;
    address bob;

    IMultiTokenFeeDistributor public feeDistributor = IMultiTokenFeeDistributor(target);

    MultiTokenFeeDistributor distributor;
    VeToken veToken;
    SampleToken token;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);
        token = new SampleToken(1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        distributor = new MultiTokenFeeDistributor();

        _use(MultiTokenFeeDistributor.initialize.selector, address(distributor));
        _use(MultiTokenFeeDistributor.veForAt.selector, address(distributor));

        vm.warp(365 * 1 days);

        feeDistributor.initialize(address(veToken), alice, bob);

        // Aliceがトークンをロック
        token.transfer(alice, 1e24);
        vm.prank(alice);
        token.approve(address(veToken), 1e24);
        vm.prank(alice);
        veToken.createLock(1e24, block.timestamp + 4 * 365 * 86400); // 4年間ロック
    }

    // テスト名: testVeForAt
    // コメント: 特定のタイムスタンプにおけるveToken残高を確認するテスト
    function testVeForAt() public {
        // 現在のタイムスタンプでのveToken残高を取得
        uint256 currentBalance = feeDistributor.veForAt(alice, block.timestamp);
        assertTrue(currentBalance > 0, "veToken balance should be greater than 0");

        // 1週間後のタイムスタンプでのveToken残高を取得
        vm.warp(block.timestamp + WEEK);
        uint256 futureBalance = feeDistributor.veForAt(alice, block.timestamp);
        assertTrue(futureBalance < currentBalance, "veToken balance should decrease over time");

        // ロック期間終了後のタイムスタンプでのveToken残高を取得
        vm.warp(block.timestamp + 4 * 365 * 86400);
        uint256 expiredBalance = feeDistributor.veForAt(alice, block.timestamp);
        assertEq(expiredBalance, 0, "veToken balance should be 0 after lock expires");
    }
}

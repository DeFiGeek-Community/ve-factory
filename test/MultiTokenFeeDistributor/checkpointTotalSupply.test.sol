// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";
import {console} from "forge-std/console.sol";

contract MultiTokenFeeDistributor_CheckpointTotalSupplyTest is TestBase {
    uint256 constant WEEK = 7 days;
    address alice;
    address bob;

    IMultiTokenFeeDistributor public feeDistributor = IMultiTokenFeeDistributor(target);

    MultiTokenFeeDistributor distributor;
    VeToken veToken;
    SampleToken token;
    SampleToken tokenA;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);
        token = new SampleToken(1e26);
        tokenA = new SampleToken(1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        distributor = new MultiTokenFeeDistributor();

        _use(MultiTokenFeeDistributor.initialize.selector, address(distributor));
        _use(MultiTokenFeeDistributor.addToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.checkpointTotalSupply.selector, address(distributor));
        _use(MultiTokenFeeDistributor.veSupply.selector, address(distributor));
        _use(MultiTokenFeeDistributor.timeCursor.selector, address(distributor));
        _use(MultiTokenFeeDistributor.lastCheckpointTotalSupplyTime.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claim.selector, address(distributor));

        vm.warp(365 * 1 days);

        feeDistributor.initialize(address(veToken), alice, bob);
        vm.prank(alice);
        feeDistributor.addToken(address(tokenA), block.timestamp);

        // Aliceがトークンをロック
        token.transfer(alice, 1e24);
        vm.prank(alice);
        token.approve(address(veToken), 1e24);
        vm.prank(alice);
        veToken.createLock(1e24, block.timestamp + 4 * 365 * 86400); // 4年間ロック
    }

    // テスト名: testCheckpointTotalSupply
    // コメント: 1週間後にcheckpointTotalSupplyを呼び出すテスト
    function testCheckpointTotalSupply() public {
        // 初期のtimeCursorとlastCheckpointTotalSupplyTimeを取得
        uint256 initialTimeCursor = feeDistributor.timeCursor();
        uint256 initialLastCheckpointTime = feeDistributor.lastCheckpointTotalSupplyTime();
        uint256 weekEpoch = ((block.timestamp + WEEK) / WEEK) * WEEK;

        // 時間を進める
        vm.warp(weekEpoch);

        // checkpointTotalSupplyを呼び出し
        feeDistributor.checkpointTotalSupply();

        // timeCursorが更新されたか確認
        uint256 updatedTimeCursor = feeDistributor.timeCursor();
        assertTrue(updatedTimeCursor > initialTimeCursor, "Time cursor should be updated");

        // veSupplyが更新されたか確認
        assertEq(feeDistributor.veSupply(initialTimeCursor), 0, "Initial veSupply should be 0");
        assertEq(feeDistributor.veSupply(weekEpoch), veToken.totalSupply(), "veSupply should be updated to totalSupply");

        // lastCheckpointTotalSupplyTimeが更新されたか確認
        uint256 updatedLastCheckpointTime = feeDistributor.lastCheckpointTotalSupplyTime();
        assertTrue(updatedLastCheckpointTime > initialLastCheckpointTime, "Last checkpoint total supply time should be updated");
        assertEq(updatedLastCheckpointTime, weekEpoch, "Last checkpoint total supply time should match the current week epoch");
    }

    function testClaimCheckpointsTotalSupply() public {
        uint256 startTime = feeDistributor.timeCursor();
        feeDistributor.claim(address(tokenA));
        assertEq(feeDistributor.timeCursor(), startTime + WEEK, "Time cursor should be updated by one week after claim");
    }

    // テスト名: testCheckpointTotalSupplyMultipleTimes
    // コメント: 複数回checkpointTotalSupplyを呼び出すテスト
    function testCheckpointTotalSupplyMultipleTimes() public {
        // 初期のtimeCursorを取得
        uint256 initialTimeCursor = feeDistributor.timeCursor();

        // 時間を進める
        vm.warp(block.timestamp + WEEK);

        // checkpointTotalSupplyを複数回呼び出し
        vm.prank(alice);
        feeDistributor.checkpointTotalSupply();
        vm.warp(block.timestamp + WEEK);
        vm.prank(alice);
        feeDistributor.checkpointTotalSupply();

        // timeCursorが更新されたか確認
        uint256 updatedTimeCursor = feeDistributor.timeCursor();
        assertTrue(updatedTimeCursor > initialTimeCursor, "Time cursor should be updated after multiple calls");

        // veSupplyが更新されたか確認
        uint256 initialVeSupply = feeDistributor.veSupply(initialTimeCursor);
        assertEq(initialVeSupply, 0, "Initial veSupply should be 0");
        uint256 updatedVeSupply = feeDistributor.veSupply(updatedTimeCursor - WEEK);
        assertTrue(updatedVeSupply > 0, "veSupply should be updated after multiple calls");
    }

    // テスト名: testCheckpointTotalSupplyAfter20Weeks
    // コメント: 20週間後にcheckpointTotalSupplyを呼び出すテスト
    function testCheckpointTotalSupplyAfter20Weeks() public {
        // 初期のtimeCursorを取得
        uint256 initialTimeCursor = feeDistributor.timeCursor();

        // 20週間時間を進める
        vm.warp(block.timestamp + 20 * WEEK);

        // checkpointTotalSupplyを呼び出し
        vm.prank(alice);
        feeDistributor.checkpointTotalSupply();

        // timeCursorが更新されたか確認
        uint256 updatedTimeCursor = feeDistributor.timeCursor();
        assertTrue(updatedTimeCursor > initialTimeCursor, "Time cursor should be updated after 20 weeks");

        // veSupplyが更新されたか確認
        for (uint256 i = 1; i < 20; ++i) {
            uint256 week = updatedTimeCursor - (i * WEEK);
            uint256 veSupply = feeDistributor.veSupply(week);
            assertTrue(veSupply > 0, "veSupply should be updated for each week");
        }
    }

    // テスト名: testCheckpointTotalSupplyAfter40Weeks
    // コメント: 40週間後にcheckpointTotalSupplyを呼び出すテスト
    function testCheckpointTotalSupplyAfter40Weeks() public {
        // 初期のtimeCursorを取得
        uint256 initialTimeCursor = feeDistributor.timeCursor();

        // 40週間時間を進める
        vm.warp(block.timestamp + 45 * WEEK);

        vm.prank(alice);
        feeDistributor.checkpointTotalSupply();

        // timeCursorが更新されたか確認
        uint256 updatedTimeCursor = feeDistributor.timeCursor();
        assertTrue(updatedTimeCursor > initialTimeCursor, "Time cursor should be updated after 40 weeks");

        // veSupplyが更新されたか確認
        for (uint256 i = 1; i < 21; i++) {
            uint256 week = updatedTimeCursor - (i * WEEK);
            uint256 veSupply = feeDistributor.veSupply(week);
            assertTrue(veSupply > 0, "veSupply should be updated for each week within 20 weeks");
        }

        // 20週間以上経過している場合のveSupplyが0であることを確認
        for (uint256 i = 21; i < 45; i++) {
            uint256 week = updatedTimeCursor - (i * WEEK);
            uint256 veSupply = feeDistributor.veSupply(week);
            assertTrue(veSupply == 0, "veSupply should be zero for each week after 20 weeks");
        }
    }

    // テスト名: testCheckpointTotalSupplyAfter60Weeks
    // コメント: 20週間ごと3回のcheckpointTotalSupplyを呼び出すテスト
    function testCheckpointTotalSupplyAfter60Weeks() public {
        // 初期のtimeCursorを取得
        uint256 initialTimeCursor = feeDistributor.timeCursor();

        for (uint256 i = 0; i < 3; i++) {
            // 20週間時間を進める
            vm.warp(block.timestamp + 20 * WEEK);

            vm.prank(alice);
            feeDistributor.checkpointTotalSupply();
        }
        // timeCursorが更新されたか確認
        uint256 updatedTimeCursor = feeDistributor.timeCursor();
        assertTrue(updatedTimeCursor > initialTimeCursor, "Time cursor should be updated after 60 weeks");

        // veSupplyが更新されたか確認
        for (uint256 i = 1; i < 60; i++) {
            uint256 week = updatedTimeCursor - (i * WEEK);
            uint256 veSupply = feeDistributor.veSupply(week);
            console.log(i);
            assertTrue(veSupply > 0, "veSupply should be updated for each week within 60 weeks");
        }
    }
}

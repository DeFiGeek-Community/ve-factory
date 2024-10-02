// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/Storage/Storage.sol";
import "src/test/SampleToken.sol";

contract MultiTokenFeeDistributorAddTokenTest is Test {
    MultiTokenFeeDistributor distributor;
    SampleToken tokenA;
    SampleToken tokenB;
    address admin = address(0x1);
    address emergencyReturn = address(0x2);

    uint256 constant WEEK = 7 days;

    function setUp() public {
        distributor = new MultiTokenFeeDistributor();
        tokenA = new SampleToken(1e26); // SampleTokenを1e26発行
        tokenB = new SampleToken(1e26);

        distributor.initialize(address(this), admin, emergencyReturn);

        vm.warp(100 weeks);
    }

    function testAddToken() public {
        uint256 startTime = block.timestamp;
        // `addToken`を呼び出してトークンを追加
        vm.prank(admin);
        distributor.addToken(address(tokenA), startTime);

        // トークンが正しく追加されたかどうかを確認
        bool isTokenPresent = distributor.isTokenPresent(address(tokenA));
        assertTrue(isTokenPresent, "Token should be added");

        // `startTime`と`timeCursor`が正しく設定されているか確認
        uint256 expectedStartTime = (startTime / WEEK) * WEEK;
        assertEq(
            distributor.startTime(address(tokenA)), expectedStartTime, "Start time should be aligned to the week start"
        );
        assertEq(distributor.timeCursor(), expectedStartTime, "Time cursor should be aligned to the week start");
    }

    function testAddTokenAlreadyAdded() public {
        uint256 startTime = block.timestamp;
        // 最初のトークン追加
        vm.prank(admin);
        distributor.addToken(address(tokenA), startTime);

        // 2回目のトークン追加で失敗するかをテスト
        vm.expectRevert("Token already added");
        vm.prank(admin);
        distributor.addToken(address(tokenA), startTime);
    }

    function testAddMultipleTokens() public {
        uint256 startTime = block.timestamp;
        uint256 startTime3 = startTime + 3 weeks;

        // tokenAを追加
        vm.prank(admin);
        distributor.addToken(address(tokenA), startTime);

        // 3週間後にtokenBを追加
        vm.prank(admin);
        distributor.addToken(address(tokenB), startTime3);

        uint256 expectedStartTime = (startTime / WEEK) * WEEK;

        // tokenAが正しく追加されたかを確認
        bool isTokenAPresent = distributor.isTokenPresent(address(tokenA));
        assertTrue(isTokenAPresent, "Token A should be added");

        // tokenAのlastTokenTimeとstartTimeが正しく設定されているか確認
        assertEq(
            distributor.lastTokenTime(address(tokenA)),
            expectedStartTime,
            "Last token time for token A should be aligned to the week start"
        );
        assertEq(
            distributor.startTime(address(tokenA)),
            expectedStartTime,
            "Start time for token A should be aligned to the week start"
        );

        // timeCursorが正しく設定されているか確認
        assertEq(distributor.timeCursor(), expectedStartTime, "Time cursor should be aligned to the week start");

        // tokenBが正しく追加されたかを確認
        bool isTokenBPresent = distributor.isTokenPresent(address(tokenB));
        assertTrue(isTokenBPresent, "Token B should be added");

        uint256 expectedStartTime2 = (startTime3 / WEEK) * WEEK;

        // tokenBのlastTokenTimeとstartTimeが正しく設定されているか確認
        assertEq(
            distributor.lastTokenTime(address(tokenB)),
            expectedStartTime2,
            "Last token time for token B should be aligned to the week start"
        );
        assertEq(
            distributor.startTime(address(tokenB)),
            expectedStartTime2,
            "Start time for token B should be aligned to the week start"
        );
    }
}

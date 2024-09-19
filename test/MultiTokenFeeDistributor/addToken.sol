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
        assertEq(distributor.startTime(), expectedStartTime, "Start time should be aligned to the week start");
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
        // 複数トークンを追加
        vm.prank(admin);
        distributor.addToken(address(tokenA), startTime);
        vm.prank(admin);
        distributor.addToken(address(tokenB), startTime);

        // 両方のトークンが正しく追加されたかを確認
        bool isTokenAPresent = distributor.isTokenPresent(address(tokenA));
        bool isTokenBPresent = distributor.isTokenPresent(address(tokenB));
        assertTrue(isTokenAPresent, "Token A should be added");
        assertTrue(isTokenBPresent, "Token B should be added");
    }
}

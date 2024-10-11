// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/test/SampleToken.sol";
import "script/DeployMultiTokenFeeDistributor.s.sol";

contract MultiTokenFeeDistributor_AddTokenTest is Test, DeployMultiTokenFeeDistributor {
    uint256 constant WEEK = 7 days;
    address admin = address(0x1);
    address emergencyReturn = address(0x2);

    IMultiTokenFeeDistributor public feeDistributor;
    SampleToken tokenA;
    SampleToken tokenB;

    function setUp() public {
        tokenA = new SampleToken(1e26);
        tokenB = new SampleToken(1e26);

        (address proxyAddress,) = deploy(address(this), admin, emergencyReturn, false);
        feeDistributor = IMultiTokenFeeDistributor(proxyAddress);

        vm.warp(100 weeks);
    }

    function testAddToken() public {
        uint256 startTime = vm.getBlockTimestamp();
        // `addToken`を呼び出してトークンを追加
        vm.prank(admin);
        feeDistributor.addToken(address(tokenA), startTime);

        // トークンが正しく追加されたかどうかを確認
        bool isTokenPresent = feeDistributor.isTokenPresent(address(tokenA));
        assertTrue(isTokenPresent, "Token should be added");

        // `startTime`と`timeCursor`が正しく設定されているか確認
        uint256 expectedStartTime = (startTime / WEEK) * WEEK;
        assertEq(
            feeDistributor.startTime(address(tokenA)),
            expectedStartTime,
            "Start time should be aligned to the week start"
        );
        assertEq(feeDistributor.timeCursor(), expectedStartTime, "Time cursor should be aligned to the week start");
    }

    function testAddTokenAlreadyAdded() public {
        uint256 startTime = vm.getBlockTimestamp();
        // 最初のトークン追加
        vm.prank(admin);
        feeDistributor.addToken(address(tokenA), startTime);

        // 2回目のトークン追加で失敗するかをテスト
        vm.expectRevert(IMultiTokenFeeDistributor.TokenAlreadyAdded.selector);
        vm.prank(admin);
        feeDistributor.addToken(address(tokenA), startTime);
    }

    function testAddMultipleTokens() public {
        uint256 startTime = vm.getBlockTimestamp();
        uint256 startTime3 = startTime + 3 weeks;

        // tokenAを追加
        vm.prank(admin);
        feeDistributor.addToken(address(tokenA), startTime);

        // 3週間後にtokenBを追加
        vm.prank(admin);
        feeDistributor.addToken(address(tokenB), startTime3);

        uint256 expectedStartTime = (startTime / WEEK) * WEEK;

        // tokenAが正しく追加されたかを確認
        bool isTokenAPresent = feeDistributor.isTokenPresent(address(tokenA));
        assertTrue(isTokenAPresent, "Token A should be added");

        // tokenAのlastTokenTimeとstartTimeが正しく設定されているか確認
        assertEq(
            feeDistributor.lastTokenTime(address(tokenA)),
            expectedStartTime,
            "Last token time for token A should be aligned to the week start"
        );
        assertEq(
            feeDistributor.startTime(address(tokenA)),
            expectedStartTime,
            "Start time for token A should be aligned to the week start"
        );

        // timeCursorが正しく設定されているか確認
        assertEq(feeDistributor.timeCursor(), expectedStartTime, "Time cursor should be aligned to the week start");

        // tokenBが正しく追加されたかを確認
        bool isTokenBPresent = feeDistributor.isTokenPresent(address(tokenB));
        assertTrue(isTokenBPresent, "Token B should be added");

        uint256 expectedStartTime2 = (startTime3 / WEEK) * WEEK;

        // tokenBのlastTokenTimeとstartTimeが正しく設定されているか確認
        assertEq(
            feeDistributor.lastTokenTime(address(tokenB)),
            expectedStartTime2,
            "Last token time for token B should be aligned to the week start"
        );
        assertEq(
            feeDistributor.startTime(address(tokenB)),
            expectedStartTime2,
            "Start time for token B should be aligned to the week start"
        );
    }

    function testTokensFunction() public {
        uint256 startTime = vm.getBlockTimestamp();

        // tokenAとtokenBを追加
        vm.prank(admin);
        feeDistributor.addToken(address(tokenA), startTime);
        vm.prank(admin);
        feeDistributor.addToken(address(tokenB), startTime);

        // tokens関数で取得したトークンリストを確認
        address[] memory tokensList = feeDistributor.tokens();
        assertEq(tokensList.length, 2, "There should be two tokens in the list");
        assertEq(tokensList[0], address(tokenA), "First token should be tokenA");
        assertEq(tokensList[1], address(tokenB), "Second token should be tokenB");
    }
}

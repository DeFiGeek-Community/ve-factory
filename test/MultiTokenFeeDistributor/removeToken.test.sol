// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/test/SampleToken.sol";
import "script/DeployMultiTokenFeeDistributor.s.sol";

contract MultiTokenFeeDistributor_RemoveTokenTest is Test, DeployMultiTokenFeeDistributor {
    MultiTokenFeeDistributor distributor;
    SampleToken tokenA;
    SampleToken tokenB;
    address admin = address(0x1);
    address emergencyReturn = address(0x2);

    IMultiTokenFeeDistributor public feeDistributor;

    function setUp() public {
        distributor = new MultiTokenFeeDistributor();
        tokenA = new SampleToken(1e26); // サンプルトークンを1e26発行
        tokenB = new SampleToken(1e26);

        (address proxyAddress,) = deploy(address(this), admin, emergencyReturn, false);
        feeDistributor = IMultiTokenFeeDistributor(proxyAddress);

        // トークンを事前に追加しておく
        vm.prank(admin);
        feeDistributor.addToken(address(tokenA), vm.getBlockTimestamp());
        vm.prank(admin);
        feeDistributor.addToken(address(tokenB), vm.getBlockTimestamp());
    }

    function testRemoveToken() public {
        // トークンを削除
        vm.prank(admin);
        feeDistributor.removeToken(address(tokenA));

        // トークンが削除されたかどうかを確認
        bool isTokenPresent = feeDistributor.isTokenPresent(address(tokenA));
        assertFalse(isTokenPresent, "Token A should be removed");

        // 削除されていないトークンがまだ存在するかを確認
        isTokenPresent = feeDistributor.isTokenPresent(address(tokenB));
        assertTrue(isTokenPresent, "Token B should still be present");
    }

    function testRemoveNonExistentToken() public {
        // 存在しないトークンを削除しようとするとエラーが発生するかを確認
        vm.expectRevert(IMultiTokenFeeDistributor.TokenNotFound.selector);
        vm.prank(admin);
        feeDistributor.removeToken(address(0x3));
    }

    function testRemoveTokenTwice() public {
        // 既に削除されたトークンを再度削除しようとするとエラーが発生するかを確認
        vm.prank(admin);
        feeDistributor.removeToken(address(tokenA));

        vm.expectRevert(IMultiTokenFeeDistributor.TokenNotFound.selector);
        vm.prank(admin);
        feeDistributor.removeToken(address(tokenA));
    }

    function testAddAndRemoveTokenRepeatedly() public {
        // Token Aを削除
        vm.prank(admin);
        feeDistributor.removeToken(address(tokenA));

        // Token Aが削除されたかどうかを確認
        bool isTokenPresentA = feeDistributor.isTokenPresent(address(tokenA));
        assertFalse(isTokenPresentA, "Token A should be removed");

        // Token Bがまだ存在するかを確認
        bool isTokenPresentB = feeDistributor.isTokenPresent(address(tokenB));
        assertTrue(isTokenPresentB, "Token B should still be present");

        // Token Aを再度追加
        vm.prank(admin);
        feeDistributor.addToken(address(tokenA), vm.getBlockTimestamp());

        // Token Aが再度追加されたかどうかを確認
        isTokenPresentA = feeDistributor.isTokenPresent(address(tokenA));
        assertTrue(isTokenPresentA, "Token A should be present after re-adding");

        // Token Bを削除
        vm.prank(admin);
        feeDistributor.removeToken(address(tokenB));

        // Token Bが削除されたかどうかを確認
        isTokenPresentB = feeDistributor.isTokenPresent(address(tokenB));
        assertFalse(isTokenPresentB, "Token B should be removed");

        // Token Aを再度削除
        vm.prank(admin);
        feeDistributor.removeToken(address(tokenA));

        // Token Aが再度削除されたかどうかを確認
        isTokenPresentA = feeDistributor.isTokenPresent(address(tokenA));
        assertFalse(isTokenPresentA, "Token A should be removed again");

        // Token Bを再度追加
        vm.prank(admin);
        feeDistributor.addToken(address(tokenB), vm.getBlockTimestamp());

        // Token Bが再度追加されたかどうかを確認
        isTokenPresentB = feeDistributor.isTokenPresent(address(tokenB));
        assertTrue(isTokenPresentB, "Token B should be present after re-adding");
    }
}

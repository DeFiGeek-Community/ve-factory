// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";
import "script/DeployMultiTokenFeeDistributor.s.sol";

contract MultiTokenFeeDistributor_BurnTest is Test, DeployMultiTokenFeeDistributor {
    IERC20 token;
    VeToken veToken;
    SampleToken tokenA;
    address admin = address(0x1);
    address emergencyReturn = address(0x2);

    IMultiTokenFeeDistributor public feeDistributor;

    function setUp() public {
        token = new SampleToken(1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        tokenA = new SampleToken(1e26); // サンプルトークンを1e26発行

        (address proxyAddress,) = deploy(address(veToken), admin, emergencyReturn, false);
        feeDistributor = IMultiTokenFeeDistributor(proxyAddress);

        // トークンを事前に追加しておく
        vm.prank(admin);
        feeDistributor.addToken(address(tokenA), vm.getBlockTimestamp());

        // トークンをadminに転送
        tokenA.transfer(admin, 1e18 * 100); // 100トークンをadminに転送
    }

    function testBurnToken() public {
        // adminがトークンをバーン
        vm.startPrank(admin);
        tokenA.approve(address(feeDistributor), 1e18 * 100); // バーンするトークンを承認
        bool success = feeDistributor.burn(address(tokenA));
        assertTrue(success, "Burn should succeed");

        // バーン後のトークンバランスを確認
        uint256 balanceAfterBurn = tokenA.balanceOf(admin);
        assertEq(balanceAfterBurn, 0, "Admin's balance should be zero after burn");

        // コントラクトのトークンバランスを確認
        uint256 contractBalance = tokenA.balanceOf(address(feeDistributor));
        assertEq(contractBalance, 1e18 * 100, "Contract should hold the burned tokens");
    }

    function testBurnInvalidToken() public {
        // 存在しないトークンをバーンしようとするとエラーが発生するかを確認
        vm.expectRevert(IMultiTokenFeeDistributor.InvalidToken.selector);
        vm.prank(admin);
        feeDistributor.burn(address(0x3));
    }

    function testBurnWhenContractIsKilled() public {
        // コントラクトを停止
        vm.prank(admin);
        feeDistributor.killMe();

        // 停止されたコントラクトでバーンしようとするとエラーが発生するかを確認
        vm.expectRevert(IMultiTokenFeeDistributor.ContractIsKilled.selector);
        vm.prank(admin);
        feeDistributor.burn(address(tokenA));
    }
}

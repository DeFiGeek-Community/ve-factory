// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract MultiTokenFeeDistributor_BurnTest is TestBase {
    MultiTokenFeeDistributor distributor;
    IERC20 token;
    VeToken veToken;
    SampleToken tokenA;
    address admin = address(0x1);
    address emergencyReturn = address(0x2);

    IMultiTokenFeeDistributor public feeDistributor = IMultiTokenFeeDistributor(target);

    function setUp() public {
        distributor = new MultiTokenFeeDistributor();
        token = new SampleToken(1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        tokenA = new SampleToken(1e26); // サンプルトークンを1e26発行

        distributor = new MultiTokenFeeDistributor();
        _use(MultiTokenFeeDistributor.initialize.selector, address(distributor));
        _use(MultiTokenFeeDistributor.addToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.burn.selector, address(distributor));
        _use(MultiTokenFeeDistributor.isTokenPresent.selector, address(distributor));
        _use(MultiTokenFeeDistributor.killMe.selector, address(distributor));

        feeDistributor.initialize(address(veToken), admin, emergencyReturn);

        // トークンを事前に追加しておく
        vm.prank(admin);
        feeDistributor.addToken(address(tokenA), block.timestamp);

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
        assertEq(contractBalance, 1e26, "Contract should hold the burned tokens");
    }

    function testBurnInvalidToken() public {
        // 存在しないトークンをバーンしようとするとエラーが発生するかを確認
        vm.expectRevert("Invalid token");
        vm.prank(admin);
        feeDistributor.burn(address(0x3));
    }

    function testBurnWhenContractIsKilled() public {
        // コントラクトを停止
        vm.prank(admin);
        feeDistributor.killMe();

        // 停止されたコントラクトでバーンしようとするとエラーが発生するかを確認
        vm.expectRevert("Contract is killed");
        vm.prank(admin);
        feeDistributor.burn(address(tokenA));
    }
}
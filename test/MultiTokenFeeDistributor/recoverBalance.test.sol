// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/test/SampleToken.sol";

contract MultiTokenFeeDistributor_RecoverBalanceTest is TestBase {
    MultiTokenFeeDistributor distributor;
    SampleToken tokenA;
    address admin = address(0x1);
    address emergencyReturn = address(0x2);

    IMultiTokenFeeDistributor public feeDistributor = IMultiTokenFeeDistributor(target);

    function setUp() public {
        distributor = new MultiTokenFeeDistributor();
        tokenA = new SampleToken(1e26); // サンプルトークンを1e26発行

        distributor = new MultiTokenFeeDistributor();
        _use(MultiTokenFeeDistributor.initialize.selector, address(distributor));
        _use(MultiTokenFeeDistributor.addToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.recoverBalance.selector, address(distributor));
        _use(MultiTokenFeeDistributor.isTokenPresent.selector, address(distributor));

        feeDistributor.initialize(address(this), admin, emergencyReturn);

        // トークンを事前に追加しておく
        vm.prank(admin);
        feeDistributor.addToken(address(tokenA), block.timestamp);

        // トークンをコントラクトに転送
        tokenA.transfer(address(feeDistributor), 1e18 * 100); // 100トークンをコントラクトに転送
    }

    function testRecoverBalance() public {
        // コントラクトのトークンバランスを確認
        uint256 contractBalanceBefore = tokenA.balanceOf(address(feeDistributor));
        assertEq(contractBalanceBefore, 1e26, "Contract should initially hold 100 tokens");

        // adminがトークンを回収
        vm.prank(admin);
        bool success = feeDistributor.recoverBalance(address(tokenA));
        assertTrue(success, "Recover balance should succeed");

        // コントラクトのトークンバランスを確認
        uint256 contractBalanceAfter = tokenA.balanceOf(address(feeDistributor));
        assertEq(contractBalanceAfter, 0, "Contract balance should be zero after recovery");

        // emergencyReturnのトークンバランスを確認
        uint256 emergencyReturnBalance = tokenA.balanceOf(emergencyReturn);
        assertEq(emergencyReturnBalance, 1e26, "Emergency return should hold the recovered tokens");
    }

    function testRecoverBalanceInvalidToken() public {
        // 存在しないトークンを回収しようとするとエラーが発生するかを確認
        vm.expectRevert(IMultiTokenFeeDistributor.CannotRecoverToken.selector);
        vm.prank(admin);
        feeDistributor.recoverBalance(address(0x3));
    }
}

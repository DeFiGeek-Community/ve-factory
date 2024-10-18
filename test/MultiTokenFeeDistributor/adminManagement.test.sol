// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/test/SampleToken.sol";
import "script/DeployMultiTokenFeeDistributor.s.sol";

contract MultiTokenFeeDistributor_AdminManagementTest is Test, DeployMultiTokenFeeDistributor {
    address admin;
    address newAdmin;
    address nonAdmin;

    IMultiTokenFeeDistributor public feeDistributor;

    function setUp() public {
        admin = address(0x1);
        newAdmin = address(0x2);
        nonAdmin = address(0x3);

        vm.startPrank(admin);
        (address proxyAddress,) = deploy(address(0), admin, address(0), false);
        feeDistributor = IMultiTokenFeeDistributor(proxyAddress);
        vm.stopPrank();
    }

    function testCommitAdmin() public {
        // 新しい管理者をコミット
        vm.prank(admin);
        feeDistributor.commitAdmin(newAdmin);

        // コミットされた管理者が正しいか確認
        assertEq(feeDistributor.futureAdmin(), newAdmin);
    }

    function testApplyAdmin() public {
        // 新しい管理者をコミット
        vm.prank(admin);
        feeDistributor.commitAdmin(newAdmin);

        // コミットされた管理者が正しいか確認
        assertEq(feeDistributor.futureAdmin(), newAdmin);

        // 新しい管理者を適用
        vm.prank(admin);
        feeDistributor.applyAdmin();

        // 管理者が新しい管理者に変更されたか確認
        assertEq(feeDistributor.admin(), newAdmin);
    }

    function testApplyAdminWithoutCommit() public {
        // コミットなしで管理者を適用しようとするとエラーが発生するか確認
        vm.expectRevert(IMultiTokenFeeDistributor.NoAdminSet.selector);
        vm.prank(admin);
        feeDistributor.applyAdmin();
    }

    function testNonAdminCannotCommitAdmin() public {
        // admin以外がcommitAdminを実行しようとするとエラーが発生するか確認
        vm.expectRevert(IMultiTokenFeeDistributor.AccessDenied.selector);
        vm.prank(nonAdmin);
        feeDistributor.commitAdmin(newAdmin);
    }

    function testNonAdminCannotApplyAdmin() public {
        // admin以外がapplyAdminを実行しようとするとエラーが発生するか確認
        vm.expectRevert(IMultiTokenFeeDistributor.AccessDenied.selector);
        vm.prank(nonAdmin);
        feeDistributor.applyAdmin();
    }
}

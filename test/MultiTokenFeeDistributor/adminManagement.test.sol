// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/test/SampleToken.sol";

contract MultiTokenFeeDistributor_AdminManagementTest is TestBase {
    MultiTokenFeeDistributor distributor;
    address admin;
    address newAdmin;
    address nonAdmin;

    IMultiTokenFeeDistributor public feeDistributor = IMultiTokenFeeDistributor(target);

    function setUp() public {
        admin = address(0x1);
        newAdmin = address(0x2);
        nonAdmin = address(0x3);
        distributor = new MultiTokenFeeDistributor();
        _use(MultiTokenFeeDistributor.initialize.selector, address(distributor));
        _use(MultiTokenFeeDistributor.commitAdmin.selector, address(distributor));
        _use(MultiTokenFeeDistributor.futureAdmin.selector, address(distributor));
        _use(MultiTokenFeeDistributor.applyAdmin.selector, address(distributor));
        _use(MultiTokenFeeDistributor.admin.selector, address(distributor));
        feeDistributor.initialize(address(0), admin, address(0));
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
        vm.expectRevert("No admin set");
        vm.prank(admin);
        feeDistributor.applyAdmin();
    }

    function testNonAdminCannotCommitAdmin() public {
        // admin以外がcommitAdminを実行しようとするとエラーが発生するか確認
        vm.expectRevert("Access denied");
        vm.prank(nonAdmin);
        feeDistributor.commitAdmin(newAdmin);
    }

    function testNonAdminCannotApplyAdmin() public {
        // admin以外がapplyAdminを実行しようとするとエラーが発生するか確認
        vm.expectRevert("Access denied");
        vm.prank(nonAdmin);
        feeDistributor.applyAdmin();
    }
}

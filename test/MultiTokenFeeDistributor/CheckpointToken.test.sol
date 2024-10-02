// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract MultiTokenFeeDistributorCheckpointTokenTest is TestBase {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;
    uint256 constant YEAR = DAY * 365;
    address admin = address(0x1);
    address emergencyReturn = address(0x2);
    address user1 = address(0x3);
    address user2 = address(0x4);

    IMultiTokenFeeDistributor public feeDistributor = IMultiTokenFeeDistributor(target);

    MultiTokenFeeDistributor distributor;
    VeToken veToken;
    IERC20 token;
    SampleToken coinA;

    function setUp() public {
        vm.prank(admin);
        token = new SampleToken(1e26);
        vm.prank(admin);
        coinA = new SampleToken(1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        distributor = new MultiTokenFeeDistributor();
        vm.warp(WEEK * 100);
        _use(MultiTokenFeeDistributor.initialize.selector, address(distributor));
        _use(MultiTokenFeeDistributor.addToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.checkpointToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.tokenLastBalance.selector, address(distributor));
        _use(MultiTokenFeeDistributor.lastTokenTime.selector, address(distributor));
        _use(MultiTokenFeeDistributor.tokensPerWeek.selector, address(distributor));
        _use(MultiTokenFeeDistributor.toggleAllowCheckpointToken.selector, address(distributor));

        feeDistributor.initialize(address(veToken), admin, emergencyReturn);
        vm.prank(admin);
        feeDistributor.addToken(address(coinA), block.timestamp);
    }

    function testCheckpointToken() public {
        vm.startPrank(admin);

        // coinAをディストリビューターに送信
        coinA.transfer(address(feeDistributor), 1e18 * 100);

        // checkpointTokenを呼び出し
        feeDistributor.checkpointToken(address(coinA));

        // tokenLastBalanceとlastTokenTimeが正しく更新されたか確認
        uint256 tokenLastBalance = feeDistributor.tokenLastBalance(address(coinA));
        uint256 lastTokenTime = feeDistributor.lastTokenTime(address(coinA));

        assertEq(tokenLastBalance, 1e18 * 100, "Token last balance should be updated");
        assertEq(lastTokenTime, block.timestamp, "Last token time should be updated to current block timestamp");
    }

    function testCheckpointTokenMultipleTimes() public {
        vm.startPrank(admin);

        // coinAをディストリビューターに送信
        coinA.transfer(address(feeDistributor), 1e18 * 100);

        // checkpointTokenを複数回呼び出し
        feeDistributor.checkpointToken(address(coinA));

        vm.warp(block.timestamp + WEEK);
        coinA.transfer(address(feeDistributor), 1e18 * 50);

        feeDistributor.checkpointToken(address(coinA));

        // tokenLastBalanceとlastTokenTimeが正しく更新されたか確認
        uint256 tokenLastBalance = feeDistributor.tokenLastBalance(address(coinA));
        uint256 lastTokenTime = feeDistributor.lastTokenTime(address(coinA));

        assertEq(tokenLastBalance, 1e18 * 150, "Token last balance should be updated after multiple calls");
        assertEq(lastTokenTime, block.timestamp, "Last token time should be updated to current block timestamp");
    }

    function testCheckpointTokenAfter20Weeks() public {
        vm.startPrank(admin);

        // coinAをディストリビューターに送信
        coinA.transfer(address(feeDistributor), 1e18 * 100);

        // 20週間後にcheckpointTokenを呼び出し
        vm.warp(block.timestamp + 20 * WEEK);
        feeDistributor.checkpointToken(address(coinA));

        // tokenLastBalanceとlastTokenTimeが正しく更新されたか確認
        uint256 tokenLastBalance = feeDistributor.tokenLastBalance(address(coinA));
        uint256 lastTokenTime = feeDistributor.lastTokenTime(address(coinA));

        assertEq(tokenLastBalance, 1e18 * 100, "Token last balance should be updated after 20 weeks");
        assertEq(lastTokenTime, block.timestamp, "Last token time should be updated to current block timestamp");
    }



    function testToggleAllowCheckpoint() public {
        uint256 lastTokenTime = feeDistributor.lastTokenTime(address(coinA));

        vm.warp(block.timestamp + WEEK);

        vm.expectRevert("Unauthorized");
        feeDistributor.checkpointToken(address(coinA));

        assertEq(feeDistributor.lastTokenTime(address(coinA)), lastTokenTime);

        vm.prank(admin);
        feeDistributor.toggleAllowCheckpointToken();

        vm.prank(user1);
        feeDistributor.checkpointToken(address(coinA));

        uint256 newLastTokenTime = feeDistributor.lastTokenTime(address(coinA));
        assertTrue(newLastTokenTime > lastTokenTime);
    }
}

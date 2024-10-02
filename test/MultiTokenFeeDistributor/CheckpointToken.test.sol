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
        _use(MultiTokenFeeDistributor.veSupply.selector, address(distributor));
        _use(MultiTokenFeeDistributor.startTime.selector, address(distributor));
        _use(MultiTokenFeeDistributor.toggleAllowCheckpointToken.selector, address(distributor));

        feeDistributor.initialize(address(veToken), admin, emergencyReturn);
        vm.prank(admin);
        feeDistributor.addToken(address(coinA), block.timestamp);

        // user1がトークンをロック
        vm.prank(admin);
        token.transfer(user1, 1e24);
        vm.prank(user1);
        token.approve(address(veToken), 1e24);
        vm.prank(user1);
        veToken.createLock(1e24, block.timestamp + 4 * 365 * 86400); // 4年間ロック
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

        // tokensPerWeekが正しく更新されたか確認
        uint256 startTime = feeDistributor.startTime(address(coinA));
        uint256 tokensPerWeek = feeDistributor.tokensPerWeek(address(coinA), startTime);
        assertEq(tokensPerWeek, 1e18 * 100, "Tokens per week should be updated");
    }

    function testCheckpointTokenMultipleTimes() public {
        vm.startPrank(admin);

        uint256 startTime = feeDistributor.startTime(address(coinA));

        // coinAをディストリビューターに送信
        coinA.transfer(address(feeDistributor), 1e18 * 100);

        // 1週間後にcheckpointTokenを呼び出し
        vm.warp(startTime + WEEK);
        feeDistributor.checkpointToken(address(coinA));

        // さらに1週間後にcoinAを追加送信し、再度checkpointTokenを呼び出し
        vm.warp(startTime + WEEK * 2);
        coinA.transfer(address(feeDistributor), 1e18 * 50);
        feeDistributor.checkpointToken(address(coinA));

        // tokenLastBalanceとlastTokenTimeが正しく更新されたか確認
        uint256 tokenLastBalance = feeDistributor.tokenLastBalance(address(coinA));
        uint256 lastTokenTime = feeDistributor.lastTokenTime(address(coinA));

        assertEq(tokenLastBalance, 1e18 * 150, "Token last balance should be 150 after multiple calls");
        assertEq(lastTokenTime, block.timestamp, "Last token time should be updated to current block timestamp");

        // tokensPerWeekが正しく更新されたか確認
        uint256 tokensPerWeek = feeDistributor.tokensPerWeek(address(coinA), startTime);
        assertEq(tokensPerWeek, 1e18 * 100, "Tokens per week should be 100 after the first call");
        uint256 tokensPerWeek2 = feeDistributor.tokensPerWeek(address(coinA), startTime + WEEK);
        assertEq(tokensPerWeek2, 1e18 * 50, "Tokens per week should be 50 after the second call");
        uint256 tokensPerWeek3 = feeDistributor.tokensPerWeek(address(coinA), lastTokenTime);
        assertEq(tokensPerWeek3, 0, "Tokens per week should be 0 at the last token time");
    }

    function testCheckpointTokenAfter20Weeks() public {
        vm.startPrank(admin);

        uint256 startTime = feeDistributor.startTime(address(coinA));

        // coinAをディストリビューターに送信
        coinA.transfer(address(feeDistributor), 1e18 * 100);

        // 20週間後にcheckpointTokenを呼び出し
        vm.warp(block.timestamp + 20 * WEEK);
        feeDistributor.checkpointToken(address(coinA));

        // tokenLastBalanceとlastTokenTimeが正しく更新されたか確認
        uint256 tokenLastBalance = feeDistributor.tokenLastBalance(address(coinA));
        uint256 lastTokenTime = feeDistributor.lastTokenTime(address(coinA));

        assertEq(tokenLastBalance, 1e18 * 100, "Token last balance should be 100 after 20 weeks");
        assertEq(lastTokenTime, block.timestamp, "Last token time should be updated to current block timestamp");

        // tokensPerWeekが正しく更新されたか確認
        for (uint256 i = 1; i < 20; ++i) {
            uint256 tokensPerWeek = feeDistributor.tokensPerWeek(address(coinA), startTime + (i * WEEK));
            assertTrue(tokensPerWeek > 0, "Tokens per week should be greater than 0 after 20 weeks");
        }
        assertEq(
            feeDistributor.tokensPerWeek(address(coinA), lastTokenTime),
            0,
            "Tokens per week should be 0 at the last token time"
        );

        // veSupplyが正しく更新されたか確認
        for (uint256 i = 1; i < 20; ++i) {
            uint256 veSupply = feeDistributor.veSupply(startTime + (i * WEEK));
            assertTrue(veSupply > 0, "veSupply should be greater than 0 after 20 weeks");
        }
    }

    function testCheckpointTokenAfter21Weeks() public {
        vm.startPrank(admin);

        // coinAをディストリビューターに送信
        coinA.transfer(address(feeDistributor), 1e18 * 100);

        // 21週間後にcheckpointTokenを呼び出し
        vm.warp(block.timestamp + 21 * WEEK);
        feeDistributor.checkpointToken(address(coinA));

        // tokenLastBalanceとlastTokenTimeが正しく更新されたか確認
        uint256 tokenLastBalance = feeDistributor.tokenLastBalance(address(coinA));
        uint256 lastTokenTime = feeDistributor.lastTokenTime(address(coinA));

        assertEq(tokenLastBalance, 1e18 * 100, "Token last balance should be 100 after 21 weeks");
        assertEq(lastTokenTime, block.timestamp, "Last token time should be updated to current block timestamp");

        // tokensPerWeekが正しく更新されたか確認
        for (uint256 i = 1; i < 20; ++i) {
            uint256 tokensPerWeek = feeDistributor.tokensPerWeek(address(coinA), lastTokenTime - (i * WEEK));
            assertTrue(tokensPerWeek > 0, "Tokens per week should be greater than 0 after 21 weeks");
        }
        for (uint256 i = 20; i < 23; ++i) {
            uint256 tokensPerWeek = feeDistributor.tokensPerWeek(address(coinA), lastTokenTime - (i * WEEK));
            assertTrue(tokensPerWeek == 0, "Tokens per week should be 0 after 21 weeks");
        }
        assertEq(
            feeDistributor.tokensPerWeek(address(coinA), lastTokenTime),
            0,
            "Tokens per week should be 0 at the last token time"
        );

        // veSupplyが正しく更新されたか確認
        for (uint256 i = 1; i < 20; ++i) {
            uint256 veSupply = feeDistributor.veSupply(lastTokenTime - (i * WEEK));
            assertTrue(veSupply > 0, "veSupply should be greater than 0 after 21 weeks");
        }
        for (uint256 i = 20; i < 23; ++i) {
            uint256 veSupply = feeDistributor.veSupply(lastTokenTime - (i * WEEK));
            assertTrue(veSupply == 0, "veSupply should be 0 after 21 weeks");
        }
    }

    function testToggleAllowCheckpoint() public {
        uint256 initialLastTokenTime = feeDistributor.lastTokenTime(address(coinA));

        // 1週間後にwarp
        vm.warp(block.timestamp + WEEK);

        // 権限がないため、checkpointTokenの呼び出しが失敗することを確認
        vm.expectRevert("Unauthorized");
        feeDistributor.checkpointToken(address(coinA));

        // lastTokenTimeが変更されていないことを確認
        assertEq(
            feeDistributor.lastTokenTime(address(coinA)),
            initialLastTokenTime,
            "Last token time should not change without authorization"
        );

        // 管理者がcheckpointTokenの許可を切り替える
        vm.prank(admin);
        feeDistributor.toggleAllowCheckpointToken();

        // 一般ユーザーがcheckpointTokenを呼び出す
        vm.prank(user1);
        feeDistributor.checkpointToken(address(coinA));

        // lastTokenTimeが更新されたことを確認
        uint256 updatedLastTokenTime = feeDistributor.lastTokenTime(address(coinA));
        assertTrue(
            updatedLastTokenTime > initialLastTokenTime,
            "Last token time should be updated after checkpointToken is called"
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "script/DeployMultiTokenFeeDistributor.s.sol";
import "script/CloneMultiTokenFeeDistributor.s.sol";
import "@ucs/dictionary/interfaces/IDictionary.sol";

contract CloneMultiTokenFeeDistributorTest is Test {
    uint256 constant amount = 1e18 * 1000; // 1000 tokens

    uint256 createTime;
    address admin = address(0x1);
    address emergencyReturn = address(0x2);
    address user1 = address(0x3);
    address user2 = address(0x4);

    CloneMultiTokenFeeDistributor cloneScript;
    DeployMultiTokenFeeDistributor deployScript;

    IMultiTokenFeeDistributor distributor;
    IMultiTokenFeeDistributor distributor2;
    address dictionary;
    VeToken veToken;
    SampleToken rewardToken1;
    SampleToken rewardToken2;
    SampleToken rewardToken3;
    SampleToken rewardToken4;
    SampleToken stakeToken;

    function setUp() public {
        vm.warp(100 weeks);

        rewardToken1 = new SampleToken(1e26);
        rewardToken2 = new SampleToken(1e26);
        rewardToken3 = new SampleToken(1e26);
        rewardToken4 = new SampleToken(1e26);
        stakeToken = new SampleToken(1e26);
        veToken = new VeToken(address(stakeToken), "veToken", "veTKN");

        createTime = block.timestamp + 100 weeks;
        stakeToken.transfer(user1, amount);
        vm.prank(user1);
        stakeToken.approve(address(veToken), amount);
        vm.prank(user1);
        veToken.createLock(amount, createTime);

        deployScript = new DeployMultiTokenFeeDistributor();
        (address proxyAddress, address dictionaryAddress) =
            deployScript.deploy(address(veToken), admin, emergencyReturn, false);
        dictionary = dictionaryAddress;
        distributor = IMultiTokenFeeDistributor(proxyAddress);

        cloneScript = new CloneMultiTokenFeeDistributor();
    }

    function testCloneDeployment() public {
        vm.startPrank(admin);
        distributor.addToken(address(rewardToken1), block.timestamp);
        distributor.addToken(address(rewardToken2), block.timestamp);
        distributor.toggleAllowCheckpointToken();
        vm.stopPrank();

        rewardToken1.transfer(address(distributor), 1e18);
        rewardToken2.transfer(address(distributor), 1e18);
        vm.warp(distributor.startTime(address(rewardToken1)) + 1 weeks);

        vm.prank(user1);
        uint256 claimedAmount1 = distributor.claim(address(rewardToken1));
        vm.prank(user1);
        uint256 claimedAmount2 = distributor.claim(address(rewardToken2));

        assertApproxEqAbs(claimedAmount1, 1e18, 1e4);
        assertApproxEqAbs(claimedAmount2, 1e18, 1e4);

        assertEq(distributor.votingEscrow(), address(veToken));
        assertEq(distributor.isTokenPresent(address(rewardToken1)), true);
        assertEq(distributor.isTokenPresent(address(rewardToken2)), true);
        assertEq(distributor.admin(), admin);
        assertEq(distributor.emergencyReturn(), emergencyReturn);
        assertNotEq(distributor.startTime(address(rewardToken1)), 0);
        assertNotEq(distributor.startTime(address(rewardToken2)), 0);
        assertNotEq(distributor.lastTokenTime(address(rewardToken1)), 0);
        assertNotEq(distributor.lastTokenTime(address(rewardToken2)), 0);
        assertNotEq(distributor.timeCursor(), 0, "timeCursor should not be zero");

        //  ２つ目のproxyをデプロイし、cloneをする。
        address distributor2Address = cloneScript.clone(dictionary, address(veToken), user1, user2, false);
        distributor2 = IMultiTokenFeeDistributor(distributor2Address);

        vm.startPrank(user1);
        distributor2.addToken(address(rewardToken3), block.timestamp);
        distributor2.addToken(address(rewardToken4), block.timestamp);
        distributor2.toggleAllowCheckpointToken();
        vm.stopPrank();

        assertEq(distributor2.votingEscrow(), address(veToken));
        assertEq(distributor2.isTokenPresent(address(rewardToken3)), true);
        assertEq(distributor2.isTokenPresent(address(rewardToken4)), true);
        assertEq(distributor2.admin(), user1);
        assertEq(distributor2.emergencyReturn(), user2);
    }
}

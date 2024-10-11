// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "script/DeployMultiTokenFeeDistributor.s.sol";
import "script/CloneMultiTokenFeeDistributor.s.sol";
import "@ucs/dictionary/interfaces/IDictionary.sol";

contract MultiTokenFeeDistributor_ProxyCloneTest is Test, DeployMultiTokenFeeDistributor {
    uint256 constant amount = 1e18 * 1000; // 1000 tokens

    uint256 createTime;
    address admin = address(0x1);
    address emergencyReturn = address(0x2);
    address user1 = address(0x3);
    address user2 = address(0x4);

    CloneMultiTokenFeeDistributor cloneScript;
    DeployMultiTokenFeeDistributor deployScript;

    IMultiTokenFeeDistributor public feeDistributor;
    IMultiTokenFeeDistributor public feeDistributor2;
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

        createTime = vm.getBlockTimestamp() + 100 weeks;
        stakeToken.transfer(user1, amount);
        vm.prank(user1);
        stakeToken.approve(address(veToken), amount);
        vm.prank(user1);
        veToken.createLock(amount, createTime);

        (address proxyAddress, address _dictionary) = deploy(address(veToken), admin, emergencyReturn, false);
        dictionary = _dictionary;
        feeDistributor = IMultiTokenFeeDistributor(proxyAddress);

        cloneScript = new CloneMultiTokenFeeDistributor();
    }

    function testCloneDeployment() public {
        vm.startPrank(admin);
        feeDistributor.addToken(address(rewardToken1), vm.getBlockTimestamp());
        feeDistributor.addToken(address(rewardToken2), vm.getBlockTimestamp());
        feeDistributor.toggleAllowCheckpointToken();
        vm.stopPrank();

        rewardToken1.transfer(address(feeDistributor), 1e18);
        rewardToken2.transfer(address(feeDistributor), 1e18);
        vm.warp(feeDistributor.startTime(address(rewardToken1)) + 1 weeks);

        vm.prank(user1);
        uint256 claimedAmount1 = feeDistributor.claim(address(rewardToken1));
        vm.prank(user1);
        uint256 claimedAmount2 = feeDistributor.claim(address(rewardToken2));

        assertApproxEqAbs(claimedAmount1, 1e18, 1e4);
        assertApproxEqAbs(claimedAmount2, 1e18, 1e4);

        assertEq(feeDistributor.votingEscrow(), address(veToken));
        assertEq(feeDistributor.isTokenPresent(address(rewardToken1)), true);
        assertEq(feeDistributor.isTokenPresent(address(rewardToken2)), true);
        assertEq(feeDistributor.admin(), admin);
        assertEq(feeDistributor.emergencyReturn(), emergencyReturn);
        assertNotEq(feeDistributor.startTime(address(rewardToken1)), 0);
        assertNotEq(feeDistributor.startTime(address(rewardToken2)), 0);
        assertNotEq(feeDistributor.lastTokenTime(address(rewardToken1)), 0);
        assertNotEq(feeDistributor.lastTokenTime(address(rewardToken2)), 0);
        assertNotEq(feeDistributor.timeCursor(), 0);

        //  ２つ目のproxyをデプロイし、cloneをする。
        address distributor2Address = cloneScript.clone(dictionary, address(veToken), user1, user2, false);
        feeDistributor2 = IMultiTokenFeeDistributor(distributor2Address);

        vm.startPrank(user1);
        feeDistributor2.addToken(address(rewardToken3), vm.getBlockTimestamp());
        feeDistributor2.addToken(address(rewardToken4), vm.getBlockTimestamp());
        feeDistributor2.toggleAllowCheckpointToken();
        vm.stopPrank();

        assertEq(feeDistributor2.votingEscrow(), address(veToken));
        assertEq(feeDistributor2.isTokenPresent(address(rewardToken3)), true);
        assertEq(feeDistributor2.isTokenPresent(address(rewardToken4)), true);
        assertEq(feeDistributor2.admin(), user1);
        assertEq(feeDistributor2.emergencyReturn(), user2);
    }
}

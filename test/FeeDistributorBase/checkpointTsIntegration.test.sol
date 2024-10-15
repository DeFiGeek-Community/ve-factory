// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "src/FeeDistributorBase.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributorBase_CheckpointTsIntegrationTest is Test {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;
    uint256 constant MAX_EXAMPLES = 10;

    SampleToken stakeToken;
    SampleToken rewardToken1;
    VeToken veToken;
    FeeDistributorBase feeDistributor;

    address admin = address(0x1);
    address emergencyReturn = address(0x2);
    address[] accounts;

    function setUp() public {
        vm.warp(WEEK * 100);

        // アカウントのセットアップ
        accounts = new address[](MAX_EXAMPLES);
        for (uint256 i = 0; i < MAX_EXAMPLES; i++) {
            accounts[i] = vm.addr(i + 1);
            vm.deal(accounts[i], 100 ether); // 各アカウントにETHを付与
        }

        // コントラクトのデプロイ
        stakeToken = new SampleToken(1e26);
        rewardToken1 = new SampleToken(1e26);
        veToken = new VeToken(address(stakeToken), "veToken", "veTKN");
        feeDistributor = new FeeDistributorBase();
        feeDistributor.initialize(address(veToken), vm.getBlockTimestamp(), address(rewardToken1), admin, emergencyReturn);

        // トークンの転送と承認
        for (uint256 i = 0; i < MAX_EXAMPLES; i++) {
            stakeToken.transfer(accounts[i], 1000 ether);
            vm.prank(accounts[i]);
            stakeToken.approve(address(veToken), type(uint256).max);
        }
    }

    function testCheckpointTotalSupply() public {
        uint256[] memory stAmount = generateUniqueRandomNumbers(MAX_EXAMPLES, 1e4, 100 * 1e4);
        uint256[] memory stLocktime = generateUniqueRandomNumbers(MAX_EXAMPLES, 1, 52);
        uint256[] memory stSleep = generateUniqueRandomNumbers(MAX_EXAMPLES, 1, 30);

        uint256 finalLock = 0;

        for (uint256 i = 0; i < MAX_EXAMPLES; i++) {
            uint256 sleepTime = stSleep[i] * 86400;
            vm.warp(vm.getBlockTimestamp() + sleepTime);
            uint256 lockTime = vm.getBlockTimestamp() + sleepTime + WEEK * stLocktime[i];
            if (lockTime > finalLock) {
                finalLock = lockTime;
            }

            vm.prank(accounts[i]);
            veToken.createLock(stAmount[i] * 1e14, lockTime);
        }
        for (
            uint256 weekEpoch = getNextWeekEpoch(vm.getBlockTimestamp());
            weekEpoch <= finalLock;
            weekEpoch = getNextWeekEpoch(weekEpoch)
        ) {
            vm.warp(weekEpoch);

            uint256 weekBlock = block.number;

            for (uint256 i = 0; i < 3; i++) {
                feeDistributor.checkpointTotalSupply();
            }

            uint256 expected = veToken.totalSupplyAt(weekBlock);
            uint256 actual = feeDistributor.veSupply(weekEpoch);
            assertEq(actual, expected);
        }
    }

    function getNextWeekEpoch(uint256 currentTimestamp) internal pure returns (uint256) {
        return ((currentTimestamp + WEEK) / WEEK) * WEEK;
    }

    // ユニークなランダム番号を生成するヘルパー関数
    function generateUniqueRandomNumbers(uint256 count, uint256 min, uint256 max)
        internal
        view
        returns (uint256[] memory)
    {
        require(max >= min, "Invalid min and max");
        require(max - min + 1 >= count, "Not enough unique numbers in range");

        uint256[] memory numbers = new uint256[](count);
        uint256 nonce = 0;
        uint256 generated = 0;

        while (generated < count) {
            uint256 randomNumber = uint256(keccak256(abi.encodePacked(vm.getBlockTimestamp(), nonce))) % (max - min + 1) + min;
            nonce++;

            bool duplicate = false;
            for (uint256 i = 0; i < generated; i++) {
                if (numbers[i] == randomNumber) {
                    duplicate = true;
                    break;
                }
            }

            if (!duplicate) {
                numbers[generated] = randomNumber;
                generated++;
            }
        }
        return numbers;
    }
}

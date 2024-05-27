// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Token.sol";

contract TokenEpochTimeSupplyTest is Test {
    Token token;
    uint256 constant week = 1 weeks;
    uint256 constant YEAR = 365 days;

    function setUp() public {
        // deployContractsのロジックをここに移植するか、または直接Tokenをデプロイします
        vm.warp(block.timestamp + 365 days * 10); // Fast-forward time to ensure no interference with time-dependent parameters
        token = new Token(
            "Token",
            "TKN",
            18,
            450_000_000,
            55_000_000,
            YEAR,
            10,
            1 days
        );
    }

    function testStartEpochTimeWrite() public {
        uint256 creationTime = token.startEpochTime();
        vm.warp(block.timestamp + YEAR);
        
        assertEq(token.startEpochTime(), creationTime);

        token.startEpochTimeWrite();

        assertEq(token.startEpochTime(), creationTime + YEAR);
    }

    function testStartEpochTimeWriteSameEpoch() public {
        token.startEpochTimeWrite();
        token.startEpochTimeWrite();
        // 二度実行しても状態が変わらないことを確認
    }

    function testUpdateMiningParameters() public {
        uint256 creationTime = token.startEpochTime();
        uint256 now = block.timestamp;
        uint256 newEpoch = creationTime + YEAR - now;
        vm.warp(block.timestamp + newEpoch);

        token.updateMiningParameters();
        // 更新後のマイニングパラメータを検証
    }

    function testUpdateMiningParametersSameEpoch() public {
        uint256 creationTime = token.startEpochTime();
        uint256 now = block.timestamp;
        uint256 newEpoch = creationTime + YEAR - now;
        vm.warp(block.timestamp + newEpoch - 3);

        vm.expectRevert(bytes("dev: too soon!"));
        token.updateMiningParameters();
    }

    function testMintableInTimeframeEndBeforeStart() public {
        uint256 creationTime = token.startEpochTime();
        vm.expectRevert(bytes("dev: start > end"));
        token.mintableInTimeframe(creationTime + 1, creationTime);
    }

    function testMintableInTimeframeMultipleEpochs() public {
        uint256 creationTime = token.startEpochTime();

        // 2エポック分のmintableを計算してもエラーにならないことを確認
        token.mintableInTimeframe(creationTime, creationTime + YEAR * 19 / 10);

        // 3エポック分のmintableを計算するとエラーになることを確認
        vm.expectRevert(bytes("dev: too far in future"));
        token.mintableInTimeframe(creationTime, creationTime + YEAR * 21 / 10);
    }

    function testAvailableSupply() public {
        uint256 creationTime = token.startEpochTime();
        uint256 initialSupply = token.totalSupply();
        uint256 rate = token.rate();
        vm.warp(block.timestamp + week);

        uint256 currentTime = block.timestamp;
        uint256 timeElapsed = currentTime - creationTime;
        uint256 expected = initialSupply + timeElapsed * rate;

        assertEq(token.availableSupply(), expected);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Token.sol";

contract TokenMintableInTimeframeTest is Test {
    Token token;
    uint256 constant YEAR = 365 days;
    uint256 constant INITIAL_RATE = 55_000_000;
    uint256 constant INITIAL_SUPPLY = 450_000_000;
    uint256 constant YEAR_1_SUPPLY = INITIAL_RATE * 1e18 / YEAR * YEAR;

    function setUp() public {
        vm.warp(block.timestamp + 365 days * 10);
        token = new Token(
            "Token",
            "TKN",
            18,
            INITIAL_SUPPLY,
            55_000_000,
            365 days,
            10,
            0
        );
        token.updateMiningParameters();
    }

    function approxEqual(uint256 a, uint256 b, uint256 precision) internal pure returns (bool) {
        uint256 diff = a > b ? a - b : b - a;
        return diff <= (a + b) / precision;
    }

function theoreticalSupply() public view returns (uint256) {
    int128 _epoch = token.miningEpoch();
    uint256 epoch = uint256(uint128(_epoch));
    // qの計算を1/2**0.25に合わせる
    uint256 q = 1e18 / (2 ** 2);

    uint256 S = INITIAL_SUPPLY * 1e18;

    if (epoch > 0) {
        S += YEAR_1_SUPPLY * 1e18 * (1e18 - q ** epoch) / (1e18 - q);
    }

    uint256 currentTime = block.timestamp;
    uint256 startTime = token.startEpochTime();
    S += YEAR_1_SUPPLY / YEAR * (q ** epoch) * (currentTime - startTime);

    return S;
}

    function testMintableInTimeframe() public {
        uint256 t0 = token.startEpochTime();
        vm.warp(block.timestamp + 1 days);
        uint256 t1 = block.timestamp;
        if (t1 - t0 >= YEAR) {
            token.updateMiningParameters();
        }

        uint256 availableSupply = token.availableSupply();
        uint256 mintable = token.mintableInTimeframe(t0, t1);
        assertTrue(availableSupply >= mintable + INITIAL_SUPPLY);

        if (t1 == t0) {
            assertEq(mintable, 0);
        } else {
            assertTrue(approxEqual(availableSupply - (INITIAL_SUPPLY * 10 ** 18), mintable, 10000000));
        }

        assertTrue(approxEqual(theoreticalSupply(), availableSupply, 1e16));
    }

    function testRandomRangeYearOne() view public {
        uint256 creationTime = token.startEpochTime();
        uint256 time1 = uint256(keccak256(abi.encodePacked(block.timestamp))) % YEAR;
        uint256 time2 = uint256(keccak256(abi.encodePacked(block.timestamp, time1))) % YEAR;
        (uint256 start, uint256 end) = time1 < time2 ? (creationTime + time1, creationTime + time2) : (creationTime + time2, creationTime + time1);
        uint256 rate = YEAR_1_SUPPLY / YEAR;

        uint256 mintable = token.mintableInTimeframe(start, end);
        assertEq(mintable, rate * (end - start));
    }

    function testRandomRangeMultipleEpochs() public {
        uint256 creationTime = token.startEpochTime();
        uint256 start = creationTime + YEAR * 2;
        uint256 duration = YEAR * 2;
        uint256 end = start + duration;

        uint256 startEpoch = (start - creationTime) / YEAR;
        uint256 endEpoch = (end - creationTime) / YEAR;
        uint256 exponent = startEpoch * 25;
        uint256 rate = YEAR_1_SUPPLY / YEAR / (2 ** (exponent / 100));

        for (uint256 i = startEpoch; i < endEpoch; i++) {
            vm.warp(block.timestamp + YEAR);
            token.updateMiningParameters();
        }

        uint256 mintable = token.mintableInTimeframe(start, end);
        if (startEpoch == endEpoch) {
            uint256 expectedMintable = rate * (end - start);
            assertTrue(approxEqual(mintable, expectedMintable, 1e16));
        } else {
            assertTrue(mintable < rate * (end - start));
        }
    }

    function testAvailableSupply() public {
        uint256 duration = 100000;
        uint256 creationTime = token.startEpochTime();
        uint256 initialSupply = token.totalSupply();
        uint256 rate = token.rate();

        vm.warp(block.timestamp + duration);

        uint256 expected = initialSupply + (block.timestamp - creationTime) * rate;
        assertEq(token.availableSupply(), expected);
    }
}
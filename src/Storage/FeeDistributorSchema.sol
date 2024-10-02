// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library FeeDistributorSchema {
    /// @custom:storage-location erc7201:FeeDistributor.Storage
    struct Storage {
        // 基本的な設定と状態
        uint256 startTime;
        uint256 timeCursor;
        uint256 lastCheckpointTotalSupplyTime;
        uint256 lastTokenTime;
        uint256 totalReceived;
        uint256 tokenLastBalance;
        bool canCheckpointToken;
        bool isKilled;
        // アドレス関連
        address votingEscrow;
        address token;
        address admin;
        address futureAdmin;
        address emergencyReturn;
        // ユーザーと週ごとのデータ
        mapping(address => uint256) timeCursorOf;
        mapping(address => uint256) userEpochOf;
        mapping(uint256 => uint256) tokensPerWeek;
        mapping(uint256 => uint256) veSupply;
    }

    struct Point {
        int128 bias;
        int128 slope;
        uint256 ts;
        uint256 blk;
    }
}

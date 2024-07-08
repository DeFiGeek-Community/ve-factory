// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library MultiTokenFeeDistributorSchema {
    /// @custom:storage-location erc7201:MultiTokenFeeDistributor.Storage
    struct TokenData {
        uint256 lastTokenTime;
        uint256 tokenLastBalance;
        mapping(uint256 => uint256) tokensPerWeek;
        mapping(address => uint256) timeCursorOf;
        mapping(address => uint256) userEpochOf;
    }

    struct Storage {
        // 基本的な設定と状態
        uint256 startTime;
        uint256 timeCursor;
        bool canCheckpointToken;
        bool isKilled;
        // アドレス関連
        address votingEscrow;
        address[] tokens;
        address admin;
        address futureAdmin;
        address emergencyReturn;
        // ユーザーと週ごとのデータ
        mapping(address => TokenData) tokenData; // トークンごとのデータ
        mapping(uint256 => uint256) veSupply;
    }


    struct Point {
        int128 bias;
        int128 slope;
        uint256 ts;
        uint256 blk;
    }
}

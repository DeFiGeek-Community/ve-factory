// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IMultiTokenFeeDistributor {
    // イベント
    event CommitAdmin(address indexed admin);
    event ApplyAdmin(address indexed admin);
    event ToggleAllowCheckpointToken(bool toggleFlag);
    event CheckpointToken(address indexed tokenAddress, uint256 time, uint256 tokens);
    event Claimed(
        address indexed tokenAddress, address indexed recipient, uint256 amount, uint256 claimEpoch, uint256 maxEpoch
    );
    event eventTokensPerWeek(uint256 time, uint256 value);
    event eventVeSupply(uint256 time, uint256 value);
    event eventBalance(uint256 time, uint256 value);

    // カスタムエラー
    error TokenNotFound();
    error Unauthorized();
    error ContractIsKilled();
    error NoTokensProvided();
    error TransferFailed();
    error InvalidToken();
    error AccessDenied();
    error NoAdminSet();
    error TokenAlreadyAdded();
    error CannotRecoverToken();

    // 関数
    function initialize(address votingEscrow_, address admin_, address emergencyReturn_) external;
    function checkpointToken(address tokenAddress_) external;
    function veForAt(address user_, uint256 timestamp_) external view returns (uint256);
    function checkpointTotalSupply() external;
    function claim(address tokenAddress_) external returns (uint256);
    function claimFor(address userAddress_, address tokenAddress_) external returns (uint256);
    function claimMany(address[] memory receivers_, address tokenAddress_) external returns (bool);
    function claimMultipleTokens(address[] calldata tokenAddresses) external returns (bool);
    function burn(address tokenAddress_) external returns (bool);
    function addToken(address tokenAddress_, uint256 startTime_) external;
    function removeToken(address tokenAddress_) external;
    function commitAdmin(address addr_) external;
    function applyAdmin() external;
    function toggleAllowCheckpointToken() external;
    function killMe() external;
    function recoverBalance(address tokenAddress_) external returns (bool);
    function isTokenPresent(address tokenAddress_) external view returns (bool);
    // View functions for storage variables
    function startTime(address tokenAddress) external view returns (uint256);
    function timeCursor() external view returns (uint256);
    function lastCheckpointTotalSupplyTime() external view returns (uint256);
    function lastTokenTime(address tokenAddress) external view returns (uint256);
    function tokenLastBalance(address tokenAddress) external view returns (uint256);
    function canCheckpointToken() external view returns (bool);
    function isKilled() external view returns (bool);
    function votingEscrow() external view returns (address);
    function tokens() external view returns (address[] memory);
    function admin() external view returns (address);
    function futureAdmin() external view returns (address);
    function emergencyReturn() external view returns (address);
    function timeCursorOf(address tokenAddress, address user) external view returns (uint256);
    function userEpochOf(address tokenAddress, address user) external view returns (uint256);
    function tokensPerWeek(address tokenAddress, uint256 week) external view returns (uint256);
    function veSupply(uint256 week) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MultiTokenFeeDistributorFacade {
    function initialize(address votingEscrow_, address admin_, address emergencyReturn_) external {}

    function checkpointToken(address token_) external {}

    function veForAt(address user_, uint256 timestamp_) external view returns (uint256) {}

    function checkpointTotalSupply() external {}

    function claim(address token_) external returns (uint256) {}

    function claimFor(address userAddress_, address tokenAddress_) external returns (uint256) {}

    function claimMany(address[] memory receivers_, address tokenAddress_) external returns (bool) {}

    function claimMultipleTokens(address[] calldata tokenAddresses) external returns (bool) {}

    function burn(address token_) external returns (bool) {}

    function addToken(address token_, uint256 startTime_) external {}

    function removeToken(address token_) external {}

    function commitAdmin(address addr_) external {}

    function applyAdmin() external {}

    function toggleAllowCheckpointToken() external {}

    function killMe() external {}

    function recoverBalance(address token_) external returns (bool) {}

    function isTokenPresent(address tokenAddress_) external view returns (bool) {}

    // View functions for storage variables
    function startTime(address tokenAddress) external view returns (uint256) {}

    function timeCursor() external view returns (uint256) {}

    function lastCheckpointTotalSupplyTime() external view returns (uint256) {}

    function lastTokenTime(address token_) external view returns (uint256) {}

    function tokenLastBalance(address token_) external view returns (uint256) {}

    function canCheckpointToken() external view returns (bool) {}

    function isKilled() external view returns (bool) {}

    function votingEscrow() external view returns (address) {}

    function tokens() external view returns (address[] memory) {}

    function admin() external view returns (address) {}

    function futureAdmin() external view returns (address) {}

    function emergencyReturn() external view returns (address) {}

    function timeCursorOf(address token_, address user) external view returns (uint256) {}

    function userEpochOf(address token_, address user) external view returns (uint256) {}

    function tokensPerWeek(address token_, uint256 week) external view returns (uint256) {}

    function veSupply(uint256 week) external view returns (uint256) {}
}

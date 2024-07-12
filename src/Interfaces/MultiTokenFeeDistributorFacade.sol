// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24 {}

contract MultiTokenFeeDistributorFacade {
    // Initialization and administrative functions
    function initialize(
        address votingEscrow_,
        address admin_,
        address emergencyReturn_
    ) external {}

    function commitAdmin(address addr_) external {}

    function applyAdmin() external {}

    function toggleAllowCheckpointToken() external {}

    function killMe() external {}

    function recoverBalance(address token_) external returns (bool) {}

    // Token management functions
    function addToken(address token_, uint256 startTime_) external {}

    function removeToken(address token_) external {}

    function checkpointToken(address token_) external {}

    function burn(address token_) external returns (bool) {}

    // Claiming and distribution functions
    function claim(address token_) external returns (uint256) {}

    function claimMultipleTokens(address[] calldata tokens_) external returns (bool) {}

    function checkpointTotalSupply() external {}

    // View functions for storage variables
    function startTime() external view returns (uint256) {}

    function timeCursor() external view returns (uint256) {}

    function lastTokenTime(address token_) external view returns (uint256) {}

    function tokenLastBalance(address token_) external view returns (uint256) {}

    function canCheckpointToken() external view returns (bool) {}

    function isKilled() external view returns (bool) {}

    function votingEscrow() external view returns (address) {}

    function admin() external view returns (address) {}

    function futureAdmin() external view returns (address) {}

    function emergencyReturn() external view returns (address) {}

    function tokens() external view returns (address[] memory) {}

    // Additional view functions specific to MultiTokenFeeDistributor
    function tokensPerWeek(address token_, uint256 week) external view returns (uint256) {}

    function veSupply(uint256 week) external view returns (uint256) {}

    function timeCursorOf(address token_, address user) external view returns (uint256) {}

    function userEpochOf(address token_, address user) external view returns (uint256) {}
}
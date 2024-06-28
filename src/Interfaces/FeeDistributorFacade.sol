// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract FeeDistributorFacade {
    // Functions
    function initialize(address votingEscrow_, uint256 startTime_, address token_, address admin_, address emergencyReturn_) external {}

    function checkpointToken() external {}

    function veForAt(address user_, uint256 timestamp_) external view returns (uint256) {}

    function checkpointTotalSupply() external {}

    function claim() external returns (uint256) {}

    function claim(address addr_) external returns (uint256) {}

    function claimMany(address[] memory receivers_) external returns (bool) {}

    function burn(address coin_) external returns (bool) {}

    function commitAdmin(address addr_) external {}

    function applyAdmin() external {}

    function toggleAllowCheckpointToken() external {}

    function killMe() external {}

    function recoverBalance(address coin_) external returns (bool) {}

    // View functions for storage variables
    function startTime() external view returns (uint256) {}

    function timeCursor() external view returns (uint256) {}

    function lastTokenTime() external view returns (uint256) {}

    function totalReceived() external view returns (uint256) {}

    function tokenLastBalance() external view returns (uint256) {}

    function canCheckpointToken() external view returns (bool) {}

    function isKilled() external view returns (bool) {}

    function votingEscrow() external view returns (address) {}

    function token() external view returns (address) {}

    function admin() external view returns (address) {}

    function futureAdmin() external view returns (address) {}

    function emergencyReturn() external view returns (address) {}

    function timeCursorOf(address user) external view returns (uint256) {}

    function userEpochOf(address user) external view returns (uint256) {}

    function tokensPerWeek(uint256 week) external view returns (uint256) {}

    function veSupply(uint256 week) external view returns (uint256) {}
}
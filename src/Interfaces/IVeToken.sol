// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "src/Storage/FeeDistributorSchema.sol";

/// @title IVeToken
/// @notice Interface for veToken contract
interface IVeToken {
    function getLastUserSlope(address addr_) external view returns (int128);

    function userPointHistoryTs(address addr_, uint256 idx_) external view returns (uint256);

    function userPointEpoch(address addr) external view returns (uint256);

    function epoch() external view returns (uint256);

    function userPointHistory(address addr, uint256 loc) external view returns (FeeDistributorSchema.Point memory);

    function pointHistory(uint256 loc) external view returns (FeeDistributorSchema.Point memory);

    function lockedEnd(address addr_) external view returns (uint256);

    function checkpoint() external;

    function depositFor(address addr_, uint256 value_) external;

    function createLock(uint256 value_, uint256 unlockTime_) external;

    function increaseAmount(uint256 value_) external;

    function increaseUnlockTime(uint256 unlockTime_) external;

    function withdraw() external;

    function balanceOf(address addr_, uint256 t_) external view returns (uint256);

    function balanceOf(address addr_) external view returns (uint256);

    function balanceOfAt(address addr_, uint256 block_) external view returns (uint256);

    function totalSupply(uint256 t_) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function totalSupplyAt(uint256 block_) external view returns (uint256);
}

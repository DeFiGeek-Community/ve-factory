// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FeeDistributorSchema} from "./FeeDistributorSchema.sol";
import {MultiTokenFeeDistributorSchema} from "./MultiTokenFeeDistributorSchema.sol";

library Storage {
    // ERC-7201に基づく名前空間ID "fees.distributor.main"のストレージ位置を計算
    // keccak256(abi.encode(uint256(keccak256("fees.distributor.main")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant FEE_DISTRIBUTOR_STORAGE_LOCATION =
        0x965167c5566e6400ca5c0b84cde19d419bf7efdf30963b12dce3259d1e4b8d11;

    function FeeDistributor()
        internal
        pure
        returns (FeeDistributorSchema.Storage storage s)
    {
        assembly {
            s.slot := FEE_DISTRIBUTOR_STORAGE_LOCATION
        }
    }

    // ERC-7201に基づく名前空間ID "multi.token.fees.distributor.main"のストレージ位置を計算
    // keccak256(abi.encode(uint256(keccak256("multi.token.fees.distributor.main")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant MULTI_TOKEN_FEE_DISTRIBUTOR_STORAGE_LOCATION =
        0x7696fbeb7b2058c668a217a0eec72abde89fab471f589cf41a33a6b2983cd600;

    function MultiTokenFeeDistributor()
        internal
        pure
        returns (MultiTokenFeeDistributorSchema.Storage storage s)
    {
        assembly {
            s.slot := MULTI_TOKEN_FEE_DISTRIBUTOR_STORAGE_LOCATION
        }
    }
}

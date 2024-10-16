// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/MultiTokenFeeDistributorFacade.sol";
import {UcsDeployLibrary} from "./UcsDeployLibrary.sol";
import {DeployBase} from "./DeployBase.sol";

contract CloneMultiTokenFeeDistributor is DeployBase {
    using UcsDeployLibrary for address;

    function run() public {
        uint256 deployerPrivateKey = getEnvUint("DEPLOYER_PRIVATE_KEY");
        address votingEscrow = getEnvAddress("VOTING_ESCROW");
        address admin = getEnvAddress("ADMIN");
        address emergencyReturn = getEnvAddress("EMERGENCY_RETURN");
        address dictionaryAddress = readDeployedAddress("MultiTokenFeeDistributor_Dictionary");

        vm.startBroadcast(deployerPrivateKey);

        address cloneAddress = clone(dictionaryAddress, votingEscrow, admin, emergencyReturn, bool(true));

        console.log("Deployed MultiTokenFeeDistributor at:", cloneAddress);

        vm.stopBroadcast();
    }

    function clone(address dictionaryAddress, address votingEscrow, address admin, address emergencyReturn, bool output)
        public
        returns (address)
    {
        bytes memory initializerData =
            abi.encodeCall(MultiTokenFeeDistributor.initialize, (votingEscrow, admin, emergencyReturn));

        vm.startPrank(admin);
        address cloneProxy = dictionaryAddress.deployProxy(initializerData);

        if (output) writeDeployedAddress(cloneProxy, addTimestampToFileName("MultiTokenFeeDistributor_Proxy"));

        vm.stopPrank();
        if (output) console.log("Deployed MultiTokenFeeDistributor proxy at:", cloneProxy);

        return cloneProxy;
    }
}

// デプロイコマンド
// forge script script/DeployMultiTokenFeeDistributor.s.sol:DeployMultiTokenFeeDistributor --fork-url <RPC_URL> --broadcast --verify -vvvv

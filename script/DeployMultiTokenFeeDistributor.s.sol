// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/MultiTokenFeeDistributorFacade.sol";
import {UcsDeployLibrary} from "./util/UcsDeployLibrary.sol";
import {DeployBase} from "./util/DeployBase.sol";

contract DeployMultiTokenFeeDistributor is DeployBase {
    using UcsDeployLibrary for address;

    function run() public {
        uint256 deployerPrivateKey = getEnvUint("DEPLOYER_PRIVATE_KEY");
        address votingEscrow = getEnvAddress("VOTING_ESCROW");
        address admin = getEnvAddress("ADMIN");
        address emergencyReturn = getEnvAddress("EMERGENCY_RETURN");

        vm.startBroadcast(deployerPrivateKey);

        // MultiTokenFeeDistributorのデプロイ
        (address proxyAddress, address dictionary) = deploy(votingEscrow, admin, emergencyReturn, true);

        console.log("Deployed MultiTokenFeeDistributor proxy at:", proxyAddress);
        console.log("Deployed MultiTokenFeeDistributor dictionary at:", dictionary);

        vm.stopBroadcast();
    }

    function deploy(address votingEscrow, address admin, address emergencyReturn, bool output)
        public
        returns (address, address)
    {
        bytes memory initializerData =
            abi.encodeCall(MultiTokenFeeDistributor.initialize, (votingEscrow, admin, emergencyReturn));
        MultiTokenFeeDistributor distributor = new MultiTokenFeeDistributor();
        if (output) writeDeployedAddress(address(distributor), "MultiTokenFeeDistributor_Impl");

        address dictionary = admin.deployDictionary();
        if (output) writeDeployedAddress(dictionary, "MultiTokenFeeDistributor_Dictionary");

        dictionary.use(MultiTokenFeeDistributor.initialize.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.checkpointToken.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.veForAt.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.checkpointTotalSupply.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.claim.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.claimFor.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.claimMany.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.claimMultipleTokens.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.burn.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.addToken.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.removeToken.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.commitAdmin.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.applyAdmin.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.toggleAllowCheckpointToken.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.killMe.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.recoverBalance.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.isTokenPresent.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.startTime.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.timeCursor.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.lastCheckpointTotalSupplyTime.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.lastTokenTime.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.tokenLastBalance.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.canCheckpointToken.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.isKilled.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.votingEscrow.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.tokens.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.admin.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.futureAdmin.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.emergencyReturn.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.timeCursorOf.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.userEpochOf.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.tokensPerWeek.selector, address(distributor));
        dictionary.use(MultiTokenFeeDistributor.veSupply.selector, address(distributor));

        address facadeAddress = address(new MultiTokenFeeDistributorFacade());
        if (output) writeDeployedAddress(facadeAddress, "MultiTokenFeeDistributor_Facade");
        dictionary.useFacade(facadeAddress);

        address proxyAddress = dictionary.deployProxy(initializerData);
        if (output) writeDeployedAddress(proxyAddress, "MultiTokenFeeDistributor_Proxy");

        return (proxyAddress, dictionary);
    }
}

// デプロイコマンド
// ｓｈ script/sh/DeployMultiTokenFeeDistributor.sh

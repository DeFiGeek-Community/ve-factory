// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";
import "src/FeeDistributor.sol";
import "src/Interfaces/FeeDistributorFacade.sol";
import {UcsDeployLibrary} from "./util/UcsDeployLibrary.sol";
import {DeployBase} from "./util/DeployBase.sol";

contract DeployFeeDistributor is DeployBase {
    using UcsDeployLibrary for address;

    function run() public {
        uint256 deployerPrivateKey = getEnvUint("DEPLOYER_PRIVATE_KEY");
        address votingEscrow = getEnvAddress("VOTING_ESCROW");
        uint256 startTime = getEnvUint("START_TIME");
        address token = getEnvAddress("TOKEN");
        address admin = getEnvAddress("ADMIN");
        address emergencyReturn = getEnvAddress("EMERGENCY_RETURN");

        vm.startBroadcast(deployerPrivateKey);

        // deploy関数に環境変数から読み込んだ引数を渡す
        (address proxyAddress, address dictionary) =
            deploy(votingEscrow, startTime, token, admin, emergencyReturn, true);

        console.log("Deployed FeeDistributor proxy at:", proxyAddress);
        console.log("Deployed FeeDistributor dictionary at:", dictionary);

        vm.stopBroadcast();
    }

    function deploy(
        address votingEscrow,
        uint256 startTime,
        address token,
        address admin,
        address emergencyReturn,
        bool output
    ) internal returns (address, address) {
        // 初期化関数とその引数をエンコード
        bytes memory initializerData =
            abi.encodeCall(FeeDistributor.initialize, (votingEscrow, startTime, token, admin, emergencyReturn));
        FeeDistributor distributor = new FeeDistributor();
        if (output) writeDeployedAddress(address(distributor), "FeeDistributor_Impl");

        // UcsDeployLibraryを使用してデプロイ
        address dictionary = admin.deployDictionary();
        if (output) writeDeployedAddress(dictionary, "FeeDistributor_Dictionary");

        vm.startPrank(admin);

        dictionary.use(FeeDistributor.initialize.selector, address(distributor));
        dictionary.use(FeeDistributor.checkpointToken.selector, address(distributor));
        dictionary.use(FeeDistributor.veForAt.selector, address(distributor));
        dictionary.use(FeeDistributor.checkpointTotalSupply.selector, address(distributor));
        dictionary.use(FeeDistributor.claim.selector, address(distributor));
        dictionary.use(FeeDistributor.claimFor.selector, address(distributor));
        dictionary.use(FeeDistributor.claimMany.selector, address(distributor));
        dictionary.use(FeeDistributor.burn.selector, address(distributor));
        dictionary.use(FeeDistributor.commitAdmin.selector, address(distributor));
        dictionary.use(FeeDistributor.applyAdmin.selector, address(distributor));
        dictionary.use(FeeDistributor.toggleAllowCheckpointToken.selector, address(distributor));
        dictionary.use(FeeDistributor.killMe.selector, address(distributor));
        dictionary.use(FeeDistributor.recoverBalance.selector, address(distributor));
        dictionary.use(FeeDistributor.startTime.selector, address(distributor));
        dictionary.use(FeeDistributor.timeCursor.selector, address(distributor));
        dictionary.use(FeeDistributor.lastCheckpointTotalSupplyTime.selector, address(distributor));
        dictionary.use(FeeDistributor.lastTokenTime.selector, address(distributor));
        dictionary.use(FeeDistributor.tokenLastBalance.selector, address(distributor));
        dictionary.use(FeeDistributor.canCheckpointToken.selector, address(distributor));
        dictionary.use(FeeDistributor.isKilled.selector, address(distributor));
        dictionary.use(FeeDistributor.votingEscrow.selector, address(distributor));
        dictionary.use(FeeDistributor.token.selector, address(distributor));
        dictionary.use(FeeDistributor.admin.selector, address(distributor));
        dictionary.use(FeeDistributor.futureAdmin.selector, address(distributor));
        dictionary.use(FeeDistributor.emergencyReturn.selector, address(distributor));
        dictionary.use(FeeDistributor.timeCursorOf.selector, address(distributor));
        dictionary.use(FeeDistributor.userEpochOf.selector, address(distributor));
        dictionary.use(FeeDistributor.tokensPerWeek.selector, address(distributor));
        dictionary.use(FeeDistributor.veSupply.selector, address(distributor));

        address facadeAddress = address(new FeeDistributorFacade());
        if (output) writeDeployedAddress(facadeAddress, "FeeDistributor_Facade");
        dictionary.useFacade(facadeAddress);

        address proxyAddress = dictionary.deployProxy(initializerData);
        if (output) writeDeployedAddress(proxyAddress, "FeeDistributor_Proxy");

        vm.stopPrank();

        return (proxyAddress, dictionary);
    }
}

// Deploy command
// sh script/sh/DeployFeeDistributor.sh

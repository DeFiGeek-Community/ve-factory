// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";
import "src/FeeDistributor.sol";
import "src/Interfaces/FeeDistributorFacade.sol";
import {UcsDeployLibrary} from "./UcsDeployLibrary.sol";
import {DeployBase} from "./DeployBase.sol";

contract DeployFeeDistributor is DeployBase {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        require(deployerPrivateKey != 0, "PRIVATE_KEY is not set");

        address votingEscrow = vm.envAddress("VOTING_ESCROW");
        require(votingEscrow != address(0), "VOTING_ESCROW is not set");

        uint256 startTime = vm.envUint("START_TIME");
        require(startTime != 0, "START_TIME is not set");

        address token = vm.envAddress("TOKEN");
        require(token != address(0), "TOKEN is not set");

        address admin = vm.envAddress("ADMIN");
        require(admin != address(0), "ADMIN is not set");

        address emergencyReturn = vm.envAddress("EMERGENCY_RETURN");
        require(emergencyReturn != address(0), "EMERGENCY_RETURN is not set");

        vm.startBroadcast(deployerPrivateKey);

        // deploy関数に環境変数から読み込んだ引数を渡す
        deploy(votingEscrow, startTime, token, admin, emergencyReturn);

        vm.stopBroadcast();
    }

    function deploy(address votingEscrow, uint256 startTime, address token, address admin, address emergencyReturn)
        internal
        returns (address)
    {
        // 初期化関数とその引数をエンコード
        bytes memory initializerData =
            abi.encodeCall(FeeDistributor.initialize, (votingEscrow, startTime, token, admin, emergencyReturn));
        FeeDistributor distributor = new FeeDistributor();
        writeDeployedAddress(address(distributor), "FeeDistributor_Impl");

        // UcsDeployLibraryを使用してデプロイ
        address dictionary = UcsDeployLibrary.deployDictionary(admin);
        writeDeployedAddress(dictionary, "FeeDistributor_Dictionary");

        UcsDeployLibrary.use(dictionary, FeeDistributor.initialize.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.checkpointToken.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.veForAt.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.checkpointTotalSupply.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, bytes4(keccak256("claim()")), address(distributor));
        UcsDeployLibrary.use(dictionary, bytes4(keccak256("claim(address)")), address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.claimMany.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.burn.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.commitAdmin.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.applyAdmin.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.toggleAllowCheckpointToken.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.killMe.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.recoverBalance.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.startTime.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.timeCursor.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.lastTokenTime.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.totalReceived.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.tokenLastBalance.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.canCheckpointToken.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.isKilled.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.votingEscrow.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.token.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.admin.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.futureAdmin.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.emergencyReturn.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.timeCursorOf.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.userEpochOf.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.tokensPerWeek.selector, address(distributor));
        UcsDeployLibrary.use(dictionary, FeeDistributor.veSupply.selector, address(distributor));
        UcsDeployLibrary.useFacade(dictionary, address(new FeeDistributorFacade()));

        address proxyAddress = UcsDeployLibrary.deployProxy(dictionary, initializerData);
        writeDeployedAddress(address(distributor), "FeeDistributor_Proxy");

        console.log("Deployed VeFactory proxy at:", proxyAddress);
        return proxyAddress;
    }
}

// Deploy command
// forge script script/DeployScript.s.sol:DeployFeeDistributor --fork-url <RPC_URL> --broadcast --verify -vvvv

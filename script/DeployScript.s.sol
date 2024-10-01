// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";
import "src/FeeDistributor.sol";
import "src/Interfaces/FeeDistributorFacade.sol";
import {UcsDeployLibrary} from "./UcsDeployLibrary.sol";
import {DeployBase} from "./DeployBase.sol";

contract DeployFeeDistributor is DeployBase {
    using UcsDeployLibrary for address;

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
        address dictionary = admin.deployDictionary();
        writeDeployedAddress(dictionary, "FeeDistributor_Dictionary");

        dictionary.use(FeeDistributor.initialize.selector, address(distributor));
        dictionary.use(FeeDistributor.checkpointToken.selector, address(distributor));
        dictionary.use(FeeDistributor.veForAt.selector, address(distributor));
        dictionary.use(FeeDistributor.checkpointTotalSupply.selector, address(distributor));
        dictionary.use(bytes4(keccak256("claim()")), address(distributor));
        dictionary.use(bytes4(keccak256("claim(address)")), address(distributor));
        dictionary.use(FeeDistributor.claimMany.selector, address(distributor));
        dictionary.use(FeeDistributor.burn.selector, address(distributor));
        dictionary.use(FeeDistributor.commitAdmin.selector, address(distributor));
        dictionary.use(FeeDistributor.applyAdmin.selector, address(distributor));
        dictionary.use(FeeDistributor.toggleAllowCheckpointToken.selector, address(distributor));
        dictionary.use(FeeDistributor.killMe.selector, address(distributor));
        dictionary.use(FeeDistributor.recoverBalance.selector, address(distributor));
        dictionary.use(FeeDistributor.startTime.selector, address(distributor));
        dictionary.use(FeeDistributor.timeCursor.selector, address(distributor));
        dictionary.use(FeeDistributor.lastTokenTime.selector, address(distributor));
        dictionary.use(FeeDistributor.totalReceived.selector, address(distributor));
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
        dictionary.useFacade(address(new FeeDistributorFacade()));

        address proxyAddress = dictionary.deployProxy(initializerData);
        writeDeployedAddress(address(distributor), "FeeDistributor_Proxy");

        console.log("Deployed VeFactory proxy at:", proxyAddress);
        return proxyAddress;
    }
}

// Deploy command
// forge script script/DeployScript.s.sol:DeployFeeDistributor --fork-url <RPC_URL> --broadcast --verify -vvvv

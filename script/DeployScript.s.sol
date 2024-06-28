// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MCScript} from "@mc/devkit/MCScript.sol";
import "forge-std/console.sol";
import "src/FeeDistributor.sol";
import "src/Interfaces/FeeDistributorFacade.sol";

contract DeployFeeDistributor is MCScript {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // .envからデプロイに必要な引数を読み込む
        address votingEscrow = vm.envAddress("VOTING_ESCROW");
        uint256 startTime = vm.envUint("START_TIME");
        address token = vm.envAddress("TOKEN");
        address admin = vm.envAddress("ADMIN");
        address emergencyReturn = vm.envAddress("EMERGENCY_RETURN");

        vm.startBroadcast(deployerPrivateKey);

        // deploy関数に環境変数から読み込んだ引数を渡す
        deploy(votingEscrow, startTime, token, admin, emergencyReturn);

        vm.stopBroadcast();
    }

    function deploy(
        address votingEscrow,
        uint256 startTime,
        address token,
        address admin,
        address emergencyReturn
    ) internal returns (address) {
        // 初期化関数とその引数をエンコード
        bytes memory initializerData = abi.encodeCall(
            FeeDistributor.initialize,
            (votingEscrow, startTime, startTime, startTime, startTime)
        );
        FeeDistributor distributor = new FeeDistributor();


        mc.init("FeeDistributor");
        mc.use(FeeDistributor.initialize.selector, address(distributor));
        mc.use(FeeDistributor.checkpointToken.selector, address(distributor));
        mc.use(FeeDistributor.veForAt.selector, address(distributor));
        mc.use(FeeDistributor.checkpointTotalSupply.selector, address(distributor));
        mc.use(bytes4(keccak256("claim()")), address(distributor));
        mc.use(bytes4(keccak256("claim(address)")), address(distributor));
        mc.use(FeeDistributor.claimMany.selector, address(distributor));
        mc.use(FeeDistributor.burn.selector, address(distributor));
        mc.use(FeeDistributor.commitAdmin.selector, address(distributor));
        mc.use(FeeDistributor.applyAdmin.selector, address(distributor));
        mc.use(FeeDistributor.toggleAllowCheckpointToken.selector, address(distributor));
        mc.use(FeeDistributor.killMe.selector, address(distributor));
        mc.use(FeeDistributor.recoverBalance.selector, address(distributor));
        mc.use(FeeDistributor.startTime.selector, address(distributor));
        mc.use(FeeDistributor.timeCursor.selector, address(distributor));
        mc.use(FeeDistributor.lastTokenTime.selector, address(distributor));
        mc.use(FeeDistributor.totalReceived.selector, address(distributor));
        mc.use(FeeDistributor.tokenLastBalance.selector, address(distributor));
        mc.use(FeeDistributor.canCheckpointToken.selector, address(distributor));
        mc.use(FeeDistributor.isKilled.selector, address(distributor));
        mc.use(FeeDistributor.votingEscrow.selector, address(distributor));
        mc.use(FeeDistributor.token.selector, address(distributor));
        mc.use(FeeDistributor.admin.selector, address(distributor));
        mc.use(FeeDistributor.futureAdmin.selector, address(distributor));
        mc.use(FeeDistributor.emergencyReturn.selector, address(distributor));
        mc.use(FeeDistributor.timeCursorOf.selector, address(distributor));
        mc.use(FeeDistributor.userEpochOf.selector, address(distributor));
        mc.use(FeeDistributor.tokensPerWeek.selector, address(distributor));
        mc.use(FeeDistributor.veSupply.selector, address(distributor));
        mc.useFacade(address(new FeeDistributorFacade()));
        address proxyAddress = mc.deploy(initializerData).toProxyAddress();
        console.log("Deployed VeFactory proxy at:", proxyAddress);
        return proxyAddress;
    }
}

// Deploy command
// forge script script/DeployScript.s.sol:DeployFeeDistributor --fork-url <RPC_URL> --broadcast --verify -vvvv

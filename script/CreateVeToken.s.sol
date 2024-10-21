// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DeployBase} from "./util/DeployBase.sol";
import "forge-std/console.sol";
import "src/VeFactory.sol";

contract CreateVeToken is DeployBase {
    function run() external {
        uint256 deployerPrivateKey = getEnvUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // .envからトークンアドレス、名前、シンボルを取得
        address tokenAddr = getEnvAddress("TOKEN_ADDRESS");
        string memory name = vm.envString("VE_TOKEN_NAME");
        string memory symbol = vm.envString("VE_TOKEN_SYMBOL");

        // VeFactoryのプロキシアドレスを読み込む
        address veFactoryProxy = readDeployedAddress("VeFactory_Proxy");

        // VeFactoryインスタンスを作成
        VeFactory veFactory = VeFactory(veFactoryProxy);

        // createVeTokenを呼び出し
        address veTokenAddr = veFactory.createVeToken(tokenAddr, name, symbol);
        console.log("Created veToken at:", veTokenAddr);

        // veTokenのアドレスを名前でファイルに書き出し
        writeDeployedAddress(veTokenAddr, name);

        vm.stopBroadcast();
    }
}

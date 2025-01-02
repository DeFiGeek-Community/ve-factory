// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DeployBase} from "script/util/DeployBase.sol";
import "forge-std/console.sol";
import "src/test/MockToken.sol";

contract DeployMockToken is DeployBase {
    function run() external {
        uint256 deployerPrivateKey = getEnvUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // トークンの名前、シンボル、初期供給量を指定
        string memory name = vm.envString("MOCK_TOKEN_NAME");
        string memory symbol = vm.envString("MOCK_TOKEN_SYMBOL");
        uint256 initialSupply = 2e20;

        // MockTokenをデプロイ
        MockToken mockToken = new MockToken(name, symbol, initialSupply);
        address mockTokenAddress = address(mockToken);
        console.log("Deployed MockToken at:", mockTokenAddress);

        // MockTokenのアドレスをファイルに書き出し
        writeDeployedAddress(mockTokenAddress, symbol);

        vm.stopBroadcast();
    }
}
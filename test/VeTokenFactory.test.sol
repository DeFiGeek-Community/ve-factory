// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Interfaces/IVeTokenFactory.sol";
import "../src/test/SampleToken.sol";
import "../src/VeTokenFactory.sol";

// import "../src/veToken.sol";

contract VeTokenFactoryTest is Test {
    IVeTokenFactory factory;
    SampleToken token;
    address tokenAddr;

    function setUp() public {
        // VeTokenFactoryの実装をデプロイし、IVeTokenFactoryインターフェースを介してアクセス
        factory = IVeTokenFactory(address(new VeTokenFactory()));
        token = new SampleToken(1e18);
        tokenAddr = address(token);
    }

    function testCreateVeToken() public {
        // Simulate the creation of a new veToken
        string memory name = "veTokenName";
        string memory symbol = "veTKN";

        // Start recording logs
        vm.recordLogs();

        // Create a new veToken
        address veTokenAddr = factory.createVeToken(tokenAddr, name, symbol);

        // Get the recorded logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Assertions to check the integrity of creation and emitted event
        assertEq(
            entries[0].topics[0],
            keccak256("VeTokenCreated(address,address,string,string)"),
            "Event signature mismatch"
        );
        assertEq(
            entries[0].topics[1],
            bytes32(uint256(uint160(tokenAddr))),
            "Token address topic mismatch"
        );
        assertEq(
            entries[0].topics[2],
            bytes32(uint256(uint160(veTokenAddr))),
            "VeToken address topic mismatch"
        );
        // Decode and assert the name and symbol from the event data if necessary

        // Access the mapping correctly
        // IVeTokenFactory.VeTokenInfo memory info = VeTokenFactory.getDeployedVeTokens(veTokenAddr);
        IVeTokenFactory.VeTokenInfo memory info = factory.getDeployedVeTokens(
            tokenAddr
        );

        // Additional assertions to check the integrity of creation
        assertEq(info.tokenAddr, tokenAddr);
        assertEq(info.name, name);
        assertEq(info.symbol, symbol);
        assertEq(info.veTokenAddr, veTokenAddr);
    }

    function testMultipleVeTokenCreation() public {
        SampleToken token2 = new SampleToken(1e19);
        SampleToken token3 = new SampleToken(1e20);

        // 3つのveTokenを作成
        address veTokenAddr1 = factory.createVeToken(
            tokenAddr,
            "veTokenName1",
            "veTKN1"
        );
        address veTokenAddr2 = factory.createVeToken(
            address(token2),
            "veTokenName2",
            "veTKN2"
        );
        address veTokenAddr3 = factory.createVeToken(
            address(token3),
            "veTokenName3",
            "veTKN3"
        );

        // それぞれのveTokenが正しく作成されたことを確認
        assertNotEq(veTokenAddr1, address(0));
        assertNotEq(veTokenAddr2, address(0));
        assertNotEq(veTokenAddr3, address(0));
        assertNotEq(veTokenAddr1, veTokenAddr2);
        assertNotEq(veTokenAddr1, veTokenAddr3);

        // それぞれのveTokenの情報を確認
        IVeTokenFactory.VeTokenInfo memory info1 = factory.getDeployedVeTokens(
            tokenAddr
        );
        IVeTokenFactory.VeTokenInfo memory info2 = factory.getDeployedVeTokens(
            address(token2)
        );
        IVeTokenFactory.VeTokenInfo memory info3 = factory.getDeployedVeTokens(
            address(token3)
        );

        assertEq(info1.name, "veTokenName1");
        assertEq(info2.name, "veTokenName2");
        assertEq(info3.name, "veTokenName3");
    }

    function testCreateVeTokenWithInvalidAddress() public {
        // 無効なアドレスでveTokenを作成しようとするテスト
        vm.expectRevert("Token address cannot be the zero address."); // 期待されるエラーメッセージを指定
        factory.createVeToken(address(0), "veTokenName", "veTKN");
    }

    function testCreateVeTokenWithEmptyName() public {
        // 名前が空の場合にリバートすることを確認
        vm.expectRevert("Name cannot be empty.");
        factory.createVeToken(tokenAddr, "", "veTKN");
    }

    function testCreateVeTokenWithEmptySymbol() public {
        // シンボルが空の場合にリバートすることを確認
        vm.expectRevert("Symbol cannot be empty.");
        factory.createVeToken(tokenAddr, "veTokenName", "");
    }

    function testCreateVeTokenWithExistingTokenAddr() public {
        // 最初のveTokenの作成
        string memory name1 = "veTokenName1";
        string memory symbol1 = "veTKN1";
        factory.createVeToken(tokenAddr, name1, symbol1);

        // 同じtokenAddrで再度veTokenを作成しようとする
        string memory name2 = "veTokenName2";
        string memory symbol2 = "veTKN2";
        vm.expectRevert("veToken for this token address already exists.");
        factory.createVeToken(tokenAddr, name2, symbol2);
    }

    function testGetDeployedVeTokensWithNonexistentAddress() public view {
        // 存在しないveTokenアドレスを指定した場合の挙動をテスト
        IVeTokenFactory.VeTokenInfo memory info = factory.getDeployedVeTokens(
            address(1)
        ); // 存在しないアドレスを指定
        assertEq(info.tokenAddr, address(0)); // 存在しない場合、tokenAddrはアドレスゼロであるべき
    }

    function testCreateVeTokenWithFuzzing(
        string memory _name,
        string memory _symbol
    ) public {
        // Fuzzテスト: 有効な入力でveTokenを作成
        // 無効な入力をフィルタリング
        vm.assume(bytes(_name).length > 0 && bytes(_symbol).length > 0);

        // Fuzzing入力でveTokenを作成
        address veTokenAddr = factory.createVeToken(tokenAddr, _name, _symbol);
        assertTrue(
            veTokenAddr != address(0),
            "veToken creation failed with valid inputs"
        );

        // 作成されたveTokenの情報を取得して検証
        IVeTokenFactory.VeTokenInfo memory info = factory.getDeployedVeTokens(
            tokenAddr
        );
        assertEq(info.tokenAddr, tokenAddr, "Token address mismatch");
        assertEq(info.name, _name, "Token name mismatch");
        assertEq(info.symbol, _symbol, "Token symbol mismatch");
    }
}

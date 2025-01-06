
## デプロイ手順

以下を.envに設定
```
DEPLOYER_PRIVATE_KEY=
RPC_URL=
ETHERSCAN_API_KEY=
CHAIN_ID=
```

ve factoryのデプロイ
- `sh script/sh/DeployVeFactory.sh`

作成したいveトークン情報を.envに設定
```
TOKEN_ADDRESS=
VE_TOKEN_NAME=
VE_TOKEN_SYMBOL=
```

veトークンを作成
- `sh script/sh/CreateVeToken.sh`

veトークンのVerify
- `sh script/sh/VerifyVeToken.sh`

以下を.envに設定
```
VOTING_ESCROW=
ADMIN=
EMERGENCY_RETURN=
```

複数トークンに対応したfee配布コントラクトデプロイ(初回のみ)
- `sh script/sh/DeployMultiTokenFeeDistributor.sh`

複数トークンに対応したfee配布コントラクトデプロイ(2回目以降)
- `sh script/sh/CloneMultiTokenFeeDistributor.sh`

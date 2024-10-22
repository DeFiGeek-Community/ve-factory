## VeFactory

`VeFactory` is a smart contract designed to create new `veToken` contracts. This contract generates `veTokens` that provide rewards to users through token locking.

## veToken

`veToken` is an ERC-20 compatible token obtained by locking tokens. However, this token does not have a `transfer()` function. It functions as a voting escrow token, where locked tokens are weighted based on the duration of the lock.

## FeeDistributor

`FeeDistributor` is a smart contract that distributes specific tokens to `veToken` holders. This contract calculates rewards based on the token lock period and distributes them to users.

## MultiTokenFeeDistributor

`MultiTokenFeeDistributor` is a smart contract that distributes multiple tokens to `veToken` holders. This contract calculates rewards based on the user's lock period and distributes them accordingly.

## Usage

### Environment Configuration

Before deploying or interacting with the contracts, ensure you have a `.env` file configured with the necessary environment variables. Below is an example of the required variables:

````plaintext:.env.example
DEPLOYER_PRIVATE_KEY= # Your private key for deploying contracts
RPC_URL= # The RPC URL of the Ethereum node
ETHERSCAN_API_KEY= # Your Etherscan API key for contract verification
CHAIN_ID= # The chain ID of the network you are deploying to

# FeeDistributor initial data
VOTING_ESCROW= # Address of the Voting Escrow contract
START_TIME= # Epoch time for fee distribution to start
TOKEN= # Address of the fee token
ADMIN= # Admin address for the contract
EMERGENCY_RETURN= # Address for emergency token return

# CreateVeToken
TOKEN_ADDRESS= # Address of the original token for veToken creation
VE_TOKEN_NAME= # Name of the veToken
VE_TOKEN_SYMBOL= # Symbol of the veToken
````


### Build

To build the project, use the following command:

```shell
$ forge build
```

### Test

To run tests, use the following command:

```shell
$ forge test
```

### Format

To format the code, use the following command:

```shell
$ forge fmt
```

### Anvil

To start a local Ethereum node, use the following command:

```shell
$ anvil
```

### Deploy

Deploy the proxy and implementation for `VeFactory`:

```shell
$ sh script/sh/DeployVeFactory.sh
```

Deploy the proxy, dictionary, and implementation for `FeeDistributor`:

```shell
$ sh script/sh/DeployFeeDistributor.sh
```

Deploy the proxy, dictionary, and implementation for `MultiTokenFeeDistributor`:

```shell
$ sh script/sh/DeployMultiTokenFeeDistributor.sh
```

### Script

Create a `veToken` using `VeFactory` by executing `createVeToken`:

```shell
$ sh script/sh/CreateVeToken.sh
```

Clone the proxy for `MultiTokenFeeDistributor`:

```shell
$ sh script/sh/CloneMultiTokenFeeDistributor.sh
```

### Verify

Verify the `veToken` deployed by `CreateVeToken`:

```shell
$ sh script/sh/VerifyVeToken.sh
```

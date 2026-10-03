# Deployment and integration boundaries

No public network deployment, address, transaction hash or contract verification is reported for this revision. Existing public address fields remain empty. Local development assets are valueless. Mainnet deployment is not authorized.

## Reproduce locally

Prerequisites: Node 24.19.0, npm 11.9.0, Foundry 1.7.1, Ruby 3.2 with Bundler 2.5.23 for Linguist. Clone with submodules; exact forge-std revision is recorded by the gitlink and dependency attribution.

```sh
git clone --recurse-submodules https://github.com/anon-coder-88/dynamica.git
cd dynamica
npm ci
npm ci --prefix chain
npm --prefix chain run build
npm run abi
forge fmt --check
forge test -vv
npm run check:sdk
npm run test:sdk
npm run journey
npm run build
```

`npm run journey` creates an ephemeral Local 31337 chain and completes setup, funding, constrained execution and final redemption through the typed SDK. It requires no external credential. Hardhat scripts are development tools, not a new runtime server.

For a persistent local chain, start `anvil --chain-id 31337`, then use the existing `npm --prefix chain run deploy:local` or the local-only Solidity script:

```sh
forge script chain/script/DeployLocal.s.sol:DeployLocal --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender <LOCAL_DEVELOPMENT_ACCOUNT>
```

The Solidity script compiled, but its optional broadcast check was blocked by automatic approval review after an unexpected Sourcify request. It has not been verified as a completed broadcast; the actual local setup is instead verified by the Hardhat/SDK journey. No Sourcify approval was requested or assumed.

No operator is authorized by deployment. Standard faucet token is included only for development. Logs/broadcast output are ignored; never commit signer material.

## Public testnet preparation

Copy `.env.example` and provide a funded testnet-only signer and reviewed parameters/asset. The established deploy script gates chain ID 46630 or explicitly local 31337. Testnet RPC is `https://rpc.testnet.chain.robinhood.com`; ETH pays gas. Deployment requires a separate explicit instruction, approved asset/policy decisions and a review. Merely setting configuration does not make the integration live. Store actual addresses only after confirmed receipts, then verify code and ABI on the intended explorer. SDK rejects mainnet writes.

## Website integration later

Keep static deployment and existing wallet/mode constraints. Public addresses and chain configuration are nonsecret; signer keys never enter the bundle. Import compiled ABIs/SDK; labels should say Local, Testnet, Live or Unavailable based on each action's actual configuration/evidence. No runtime server, database, oracle, venue or scheduler is needed for manual use of this vault. A production scheduler is a distinct infrastructure dependency with its own authority and recovery plan.

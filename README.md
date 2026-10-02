# Dynamica utility MVP

A Robinhood Chain testnet MVP derived from the Dynamica PRD: **capped strategy vaults with bounded operator permissions**.

Users claim valueless `dTEST`, approve an exact amount, deposit for ERC-4626 shares and withdraw. The owner can configure an operator's reserve target, per-call limit, window budget, cooldown and expiry; pause execution or deposits; or revoke the operator. Operators can move assets only between the vault and its fixed liquid reserve. Factory records and execution events provide onchain provenance.

This is a tested source MVP, not a deployed or audited production protocol. There is no investment yield, trading integration or background operator service. `dTEST` is a test fixture, not Dynamica's native token.

## Original website

The full existing website is preserved on [`website-source`](https://github.com/anon-coder-88/dynamica/tree/website-source). `main` extracts its existing wallet selector, provider logic, vault transaction component, brand assets and UI components into a focused utility app. The hosted marketing website has not been replaced.

## Install and verify

Use Node.js 24, npm and Python 3.10+.

```sh
npm ci
npm ci --prefix chain
npm run build
npm --prefix chain run build
npm run test:contracts
npm run check:languages
cd chain
npx hardhat run scripts/smoke.ts
cd ..
```

The Solidity suite has 94 tests, including five fuzz tests with 256 runs each. Solidity source, including its tests, exceeds 50% of authored code bytes; see [verification](docs/VERIFICATION.md). No language overrides, duplicated contracts or vendored Solidity are used to inflate that share.

## Deploy to Robinhood Testnet

1. Copy `.env.example` to `.env` and set `DEPLOYER_PRIVATE_KEY` for a testnet-only account. Never commit it. Fund that account with testnet ETH from the [official faucet](https://faucet.testnet.chain.robinhood.com).
2. Run `npm --prefix chain run deploy:testnet`. This creates the test asset, factory, strategy vault and reserve. No operator is enabled by deployment.
3. Copy the printed asset/vault addresses into the public address fields and `DYNAMICA_VAULT_ADDRESS` in `.env`.
4. Run `npm run dev`, open the printed local URL, connect a wallet, switch to Robinhood Testnet and claim test assets. Review approval, deposit and withdrawal separately.
5. Connect as the deployed vault owner to authorize an operator policy. Connect as that operator to review a rebalance. Pause/revoke remain owner actions. A scheduler must submit transactions for continuous execution.

Default network: chain ID **46630**, ETH gas, `https://rpc.testnet.chain.robinhood.com`. Mainnet deployment is blocked by the deployment script.

For CLI actions, set `DYNAMICA_ACTION` to `status`, `claim`, `deposit`, `withdraw` or `rebalance`, then run `npm --prefix chain run interact:testnet`. `DYNAMICA_AMOUNT` uses 18-decimal dTEST units in human-readable form.

## Read with Python

```sh
python -m venv .venv
. .venv/bin/activate
pip install -r python/requirements.txt
# Set DYNAMICA_VAULT_ADDRESS and optionally DYNAMICA_ACCOUNT_ADDRESS
python python/vault_status.py
```

The helper reads public state and never signs. It reads environment variables from your shell, not `.env` automatically. Outputs are raw integer units, not market prices. `DYNAMICA_LOCAL=1` permits an explicit local chain (31337) when `RH_TESTNET_RPC_URL` points to it.

## Files and limits

- `chain/contracts/`: original capped vault and test asset; new policy vault, fixed reserve and factory.
- `chain/test/`: accounting, operator policy, adversarial transfer and factory tests.
- `chain/scripts/`: TypeScript deploy, interaction and local integration scripts.
- `components/`, `web/`, `index.html`: reused React wallet/vault code plus the utility shell and operator controls.
- `python/`: web3.py read helper; `scripts/`: JavaScript ABI export and language-share checks.

Only standard, non-rebasing ERC-20 assets are supported. Transfer fees are rejected. Owners can replace policies immediately, which resets the budget. Targets are rebalancing goals, not a continuously enforced reserve ratio. The fixed reserve is fully liquid; operators cannot choose arbitrary calls or destinations. See [PRD scope mapping](docs/MVP.md).

MIT license. Third-party dependencies retain their own licenses; wallet marks identify their respective providers.

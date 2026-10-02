# Dynamica MVP · Robinhood Testnet

The existing Dynamica website is reused. The new live testnet section in **Strategy vaults** connects its existing EIP-6963 wallet selector to two contracts. A wallet can claim 100 valueless dTEST once, approve an exact amount, deposit into an ERC-4626 vault, receive shares, and withdraw assets. The owner can cap or pause deposits; withdrawals remain open. All other strategy cards are still local simulations. No yield, autonomous execution, fees, or production financial promise is implemented.

**Status:** source code MVP, not audited and not deployed by this repository. Do not use valuable assets. The existing Token Studio remains separate from the dTEST faucet token.

## Requirements

Node.js 22+, npm, pnpm (for the existing website), Python 3.10+, a browser EVM wallet, and Robinhood Testnet ETH for gas. Robinhood Testnet uses chain ID **46630**. Contract addresses are intentionally absent until you deploy.

## Contracts

```sh
cd chain
npm ci
npm run build
XDG_CACHE_HOME=/tmp/dynamica-hardhat-cache npx hardhat run scripts/smoke.ts
```

If the compiler cache is writable normally, omit `XDG_CACHE_HOME`. Deployment requires a throwaway funded testnet wallet. Copy `.env.example` to `.env` in the repository root, fill `DEPLOYER_PRIVATE_KEY` and optionally `RH_TESTNET_RPC_URL`, then load those variables into your shell. For example, use `set -a; source .env; set +a` in Bash, taking care that your shell history and environment are private. From `chain/`, run `npm run deploy:testnet`. Record both output addresses; set `NEXT_PUBLIC_DYNAMICA_ASSET_ADDRESS`, `NEXT_PUBLIC_DYNAMICA_VAULT_ADDRESS`, and `DYNAMICA_VAULT_ADDRESS` in `.env`. Do not commit `.env`.

Interaction example from `chain/` after environment variables are loaded: `DYNAMICA_ACTION=status npm run interact:testnet`. Other actions: `claim`, `deposit`, `withdraw`; set `DYNAMICA_AMOUNT` for the latter two. Each transaction requires gas.

## Website

Return to the repository root with `cd ..` after the contract commands.

```sh
pnpm install --frozen-lockfile
# Load .env or create .env.local with the public address variables
pnpm dev
```

Open `/app?view=vaults`. The live vault section appears above the original demo vault catalog. The deployment addresses must match the contracts on Robinhood Testnet. Confirm wallet requests and inspect receipts; an approval is a separate transaction. The build command is `pnpm build`. The original website code, assets, public pages, Token Studio, and demo workflows are retained. `public/contract-guide.html` is a plain HTML summary.

## Python read helper

```sh
python -m venv .venv
. .venv/bin/activate
pip install -r python/requirements.txt
# Export DYNAMICA_VAULT_ADDRESS and optionally DYNAMICA_ACCOUNT_ADDRESS
python python/vault_status.py
```

It reads public chain state and never signs. Values are raw integer units with the returned share decimals; do not interpret them as market prices.

## Notes

The vault holds a test ERC-20 and issues redeemable shares. There is no strategy executor, price oracle, return model, or automated yield. Admin capacity and deposit pause are limited controls, not a protocol security review. The dTEST faucet token is not Dynamica's native token. Review and audit contracts and product policies before any production or mainnet use.

## GitHub upload

Create an empty repository on GitHub without a generated README. From this folder: `git init`, `git add .`, `git commit -m "Initial Dynamica MVP"`, `git branch -M main`, `git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO.git`, then `git push -u origin main`. Check `git status` and confirm `.env` and `node_modules` are not staged before committing.

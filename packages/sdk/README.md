# Typed strategy vault SDK

Import `StrategyVaultClient` and `parseAssetAmount` from src/index.ts with a Viem PublicClient and WalletClient. Construct it with reviewed vault address and explicit chain ID (31337 Local or 46630 Testnet). No production addresses are bundled. Use exact human decimal parsing with asset decimals; snapshots provide pinned block, timestamp and mode.

Approve an exact amount, deposit with minimum shares, configure owner policy, prepare bounded execution, execute as operator, revoke as owner and redeem with minimum assets. Each write checks network/account, simulates, signs and returns a successful actual receipt. Exceptions are errors/unknown outcomes; do not translate them into completion or retry automatically. The runnable reference is chain/scripts/sdk-journey.ts and `npm run journey`.

Contracts enforce authority; SDK convenience checks are not the security boundary. The SDK consumes actual generated ABIs and uses the replay-resistant bounded entry point. It provides no keeper scheduling, market computation or HTTP application backend.

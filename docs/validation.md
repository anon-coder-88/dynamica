# Validation evidence

Date: 3 October 2026. Commands were executed in a fresh checkout of the existing repository, with lockfile installs. Environment: Linux x86_64; Node 24.19.0, npm 11.9.0; Foundry 1.7.1 (commit 4072e48705af9d93e3c0f6e29e93b5e9a40caed8), solc 0.8.37, Cancun EVM, optimizer 200; Hardhat 3.18.1; OpenZeppelin 5.6.1; forge-std 1.17.0; Viem 2.56.9; TypeScript 5.9.3.

The original baseline built and passed its 94 tests. That historical claim was independently rerun before changes. The suite now uses maintained forge-std rather than handwritten assertion and cheatcode declarations. Regression failures found while adding bounded tests were fixed: an intervening policy getter consumed an expected-revert check, and parameterized custom errors needed complete error matching. Assertions were retained and corrected, not suppressed.

| Command / check | Actual result and scope |
| --- | --- |
| npm ci; npm ci --prefix chain | Passed from exact lockfile dependencies |
| npm --prefix chain run build | Passed; actual compiler artifacts produced |
| Local Solidity deployment script | Compiled; broadcast validation blocked by automatic approval review because Foundry attempted to contact Sourcify. No completed broadcast is claimed. Local deployment/setup is verified through the SDK journey instead. |
| forge fmt --check | Passed for first-party Solidity |
| forge test -vv | 106 passed, 0 failed/skipped: 103 unit/fuzz cases and 3 invariants |
| Six testFuzz cases | 256 runs each, deterministic seed 0xd1a |
| Three invariants | 128 runs × 64 actions each = 8192 calls per invariant; zero unexpected reverts; fail_on_revert=true |
| npm run abi | Actual artifact-derived vault/reserve/factory/faucet ABI exports and Python read subset generated |
| npm run check:sdk | Passed strict SDK/ABI/test TypeScript checking |
| npm run test:sdk | Three Node tests passed: exact base units, invalid precision/input/range and uint256 boundaries |
| npx tsc -p chain/tsconfig.json --noEmit | Passed deployment/interaction/SDK journey script type checks |
| npm run journey | Passed actual local EVM setup through SDK approval, deposit, configuration, bounded movement, event reconciliation, rejection paths and full redemption |
| npm run build | Existing focused static frontend type check and Vite production build passed |
| python -m py_compile python/vault_status.py | Syntax passed; Python RPC runtime not retested in this revision |
| GitHub Linguist | See language-report.md for actual eligible byte measurement and revision |

## Financial coverage

Retained tests cover cap/balance/allowance failures, zero amounts, six- and eighteen-decimal units, ERC-4626 mint/withdraw rounding, donation/dust, multiple allocators, delegated redemption/share transfers, false-return and fee assets, reentrancy, fixed reserve authority, owner/operator permissions, CREATE2 salt replay/provenance, policy replacement, cooldown, expiry, fixed/skipped windows, budgeting, atomic revert and withdrawal recall under pause/revoke/expiry.

New tests cover bounded execution success, replay after cooldown, legacy execution invalidating a prepared sequence, upper-bound rollback including balances/allowance/budget/count, deadline boundary, invalid bounds, unauthorized and stale-policy requests, monotonic sequence across reconfiguration and fuzzed bounds. Invariant handlers exercise deposit/redeem, configuration, execution/time, pause and revocation; check underlying conservation across users/vault/reserve, deposited minus withdrawn accounting, total share attribution, capacity, zero lingering reserve approvals, budget and count. afterInvariant pauses and revokes then redeems all actors' shares to verify final recovery.

The SDK local journey uses an actual Hardhat 31337 EVM and actual contracts; ethers deploys fixtures, then Viem/SDK performs the financial workflow. It checks that 100 local dTEST becomes 100 shares, an 80 dTEST reserve move leaves 20 idle with total assets 100, one Rebalanced receipt event matches the movement, wrong-chain and nonoperator submissions reject, replay rejects after time advance, and final redemption returns 100 to the user with zero total supply/vault/reserve assets. Tests use valueless development assets, not a real venue or public deployment.

## Limits and unperformed checks

No Robinhood Testnet/mainnet deployment, transaction, funded wallet interaction, explorer verification or public provider integration was performed. No trading venue, oracle, AI execution, scheduler, lending, treasury category distribution, six-class strategy implementation or financial performance evidence is claimed. No independent security audit, static analyzer or economic review was completed.

The focused frontend was built and type-checked; real browser wallet signing, mobile wallets, responsive, accessibility, reduced motion, cross-browser and performance/HTTPS tests were not performed. The build emits an existing ineffective Viem dynamic-import warning and a >500 kB chunk warning (approximately 604 kB minified, 183 kB gzip); no warning suppression or field Web Vitals pass is claimed. Node's native TypeScript transform is explicitly experimental and pinned to the verified Node version. Continuous execution remains a missing external submitter.

CI reproduces compilation, generated-file consistency, formatting, Foundry tests, SDK checks/journey, frontend build, Python syntax and Linguist minimum. Hosted GitHub CI results and publication status must be checked separately; local passes are not hosted CI passes. Passing tests and language percentages do not establish production readiness.

# MVP verification — 2 October 2026

## Completed stages

1. Read the current Dynamica PRD and inspected the existing GitHub implementation.
2. Reused the capped ERC-4626 vault, test asset, wallet provider/selector and vault transaction interface. Added a fixed reserve, bounded operator policy, factory and policy controls.
3. Compiled and tested the MVP; verified portable frontend dependencies and source language share.
4. Prepared a normal descendant commit for `main`, with the complete original website preserved on `website-source`.

## Results

| Check | Result |
| --- | --- |
| Solidity compilation | Pass; solc 0.8.37, Cancun EVM; all project contracts use `pragma solidity ^0.8.20` |
| Solidity suite | 94 passing tests; five fuzz tests, 256 runs each |
| TypeScript integration | Factory → claim → approve → deposit → authorize → rebalance → revoke → withdraw passed locally |
| TypeScript checks | Frontend and Hardhat scripts pass `tsc --noEmit` |
| Utility frontend build | Pass from freshly installed declared dependencies; Vite production output generated |
| Local deployment script | Test asset, factory, vault and reserve deployed; no operator silently authorized |
| CLI interaction | Real local claim and deposit confirmed; 10 dTEST matched 10 shares and 10 withdrawable assets |
| Python helper | Read actual local vault totals, policy state, user shares and withdrawable assets with web3.py 7.16.0 |
| Tracked source review | No signer keys, dependency/build directories or local dependency symlinks included |
| Language share | Solidity 78,995 / 139,439 source bytes = **56.65%** |

Source byte counts include Solidity tests and their fixtures, plus all authored/reused TypeScript, JavaScript, Python, HTML and CSS. Generated build output, lockfiles, data, documentation and binary brand assets do not enter programming-language statistics. There are no `.gitattributes` language overrides, duplicated contracts or vendored Solidity. Re-run `npm run check:languages`; the full breakdown is in `language-share.json`. GitHub's language bar is processed asynchronously after a default-branch push.

## Practical limits

No deployment or transaction was submitted to Robinhood Testnet or mainnet during verification. The deployment script gates writes to Robinhood Testnet (46630) or an explicitly local chain (31337). The browser interface is configured for Robinhood Testnet and was build-checked; a real wallet signature flow on that network awaits deployment addresses and a funded testnet wallet.

The fixed reserve creates no yield. No scheduler, production trading venue or external strategy is present. Policies are immediately editable by the owner and reset execution budget/cooldown on replacement. Targets can differ from current holdings between operator transactions. Standard ERC-20 assets are required; rebasing assets are unsupported and transfer fees are rejected. Tests do not constitute an independent audit.

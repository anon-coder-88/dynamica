# Contract interface guide

| Contract | Responsibilities | Main methods |
| --- | --- | --- |
| DynamicaVault | Base ERC-4626, capacity and deposit pause | deposit/mint/withdraw/redeem, setAssetCap, setDepositsPaused |
| DynamicaStrategyVault | Guarded custody, operator constraints, preview and recovery | configurePolicy, revokeOperator, setExecutionPaused, previewRebalance, rebalance, rebalanceWithBounds, depositWithMinShares, redeemWithMinAssets |
| DynamicaReserve | Single asset and immutable vault custody | allocate, recall, totalAssets |
| DynamicaVaultFactory | CREATE2 and bounded provenance discovery | createVault, predictVault, vaultCount, vaultAt, listVaults |
| DynamicaTestAsset | Valueless local/testnet fixture, one faucet claim per address | claim; not an ecosystem token |

Generated ABI exports in `packages/abi/src/contracts.ts` are the interface authority. Run `npm --prefix chain run build && npm run abi`; CI rejects stale generated files. Python's smaller read ABI is generated in the same command. Build outputs/dependencies are excluded from version control.

Policy tuple order: operator address, reserveBps uint16, minInterval/windowDuration/expiresAt uint64, maxMove/windowLimit uint256. Durations/timestamps are seconds; amounts are asset base units. Preview returns (toReserve, amount, BlockReason). Reasons in numeric order: Ready 0, Paused 1, NoOperator 2, Expired 3, Cooldown 4, WindowExhausted 5, AtTarget 6.

`rebalanceWithBounds(expectedVersion, expectedSequence, minMoved, maxMoved, deadline)` preserves the existing execution event. A success increments executionCount once; a stale/replayed request reverts. The original `rebalance(expectedVersion,minMoved)` intentionally permits recurring keeper calls subject to cooldown/window/policy. Do not claim replay protection for the legacy entry point.

Events to index: VaultCreated, ERC-4626 Deposit/Withdraw, PolicyConfigured, OperatorRevoked, ExecutionPaused, Rebalanced and ReserveRecalledForWithdrawal. Only actual receipts/logs establish execution. Factory records establish creator/asset provenance, not endorsement. Share Transfer/Approval events describe ownership/delegation, not portfolio profit.

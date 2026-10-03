# Capped strategy vault MVP specification

## User problem and selected utility

Capital allocators need an explicit boundary between custody and operator authority. The MVP gives users redeemable shares in a capped vault and gives an operator only bounded movement between that vault and its own liquid reserve. It establishes enforceable permissions and inspectable execution without a venue or price oracle.

| Candidate | Relevance and workflow completeness | Dependencies and risk | Decision |
| --- | --- | --- | --- |
| Capped vault with constrained reserve rebalancing | Whitepaper §§2–5, 12, 15, 17, 20; PRD REQ-011–014, 034, 038, 042; complete funding/control/execution/exit workflow already present | ERC-20 plus external transaction submitter; low integration burden, share accounting and transfer risks require tests | Selected; preserve existing implementation and strengthen verification |
| Treasury category distribution | Whitepaper §11, REQ-031–034; coherent owner/operator allocation | Recipient/governance policy absent; no existing implementation; irreversible category payments need distinct custody model | Deferred rather than add a second utility |
| Lending or multi-venue trading vault | Whitepaper §§6–10; REQ-025–030 | Venues/oracles, collateral/risk and liquidation policies, provider proofs of concept missing; much larger scope | Deferred |

These are engineering proposals. A fixed reserve is a bounded allocation utility, not an implemented profitable trading strategy. The protocol is an explicit extension to the frontend-only website scope in PRD §3. It does not replace the website or assert full P0/P1 website acceptance.

## Users and complete workflow

1. Creator deploys an independent vault via the permissionless factory, selecting standard asset and positive capacity. Creator becomes its owner; no operator enabled.
2. Allocator reads chain, asset, capacity and policy, acquires local development assets, approves an exact amount and deposits for ERC-4626 shares. Review and signature are separate actions.
3. Owner authorizes an operator, reserve target, per-call movement, fixed-window budget, interval and expiry. Policy version increments; replacement explicitly resets budget and cooldown.
4. Operator observes contract state, obtains a bounded preview and submits a transaction. Contract rechecks authority, policy, expiry, cooldown, window credit and target. SDK uses an execution sequence, upper/lower amount bounds and deadline to reject stale/replayed previews.
5. Receipt and events establish actual local execution. Shares and total assets reconcile across idle and reserve custody.
6. Owner may pause deposits/execution independently or revoke the operator. Users can still redeem; the vault recalls reserve shortfall automatically. Full local journey ends with zero outstanding shares and custody assets.

Contracts do not observe offchain markets or schedule themselves. An external operator wallet or future scheduler submits transactions and pays gas. Owner authorization limits authority; it does not guarantee that the operator acts. AI and provider result attestations are absent.

## Requirements traceability

| Requirement | Included protocol acceptance | Boundary |
| --- | --- | --- |
| REQ-011 P1 | Reject zero asset/cap, unsupported asset contract, invalid target/interval/window/expiry/budget and conflicting limits | One fixed-reserve strategy only; UI schema is not every vault class |
| REQ-012 P1 | Deposit/mint respects balance, approval, capacity and asset precision; resulting shares/state checked | Local real EVM execution; public deployment absent |
| REQ-013 P1 | Withdrawal/redeem burns correct shares, handles reserve shortfall and share allowances; rejected action is atomic | Immediate liquid reserve, no queue or external venue |
| REQ-014 P1, REQ-034 P1, NFR-007 | Only owner changes policy/pauses/cap; only operator rebalances; withdrawals survive pause/revocation | Owner can replace policy immediately; no governance timelock |
| REQ-038 P1 | Factory, deposit/withdraw and policy/execution events provide actual chain records | No full history/indexer or UI filters |
| REQ-042 P0 | Asset identity by chain/address; exact integer units and documented rounding | No fiat valuations |
| REQ-002/005–007 P0, REQ-039 P0 | SDK local/testnet restriction, wrong-chain rejection, separate simulation/submission/receipt, development fixture distinction | Focused frontend build only; not complete browser acceptance |

Deferred: REQ-010 six-class discovery; liquidity 015–017; Token Studio 018–021; native token/economics 022; full content/market data 023–024; trading/credit 025–030; treasury category distribution 031–032; full operator registry 033; laboratory 035–037; website persistence/provider failures 040–041. Website P0 and P1 priorities are preserved; deferral applies to this separate protocol MVP only.

## Contract responsibilities and asset accounting

`DynamicaVault`: standard ERC-4626 shares, owner-controlled asset capacity and deposit pause. Legacy base vault retained for source compatibility; guarded strategy vault is the intended MVP factory product.

`DynamicaStrategyVault`: ReentrancyGuard for all ERC-4626 entry points and execution; complete `totalAssets = idle balance + fixed reserve balance`; operator policy; safe transfer checks; withdrawal recall; optional deposit/redeem minimums; bounded execution wrapper.

`DynamicaReserve`: immutable asset and creating vault, allocate from or recall to that vault only. No owner or arbitrary destination. `DynamicaVaultFactory`: permissionless CREATE2 deployment, creator-scoped salts, provenance records, pagination ≤100. Registration does not approve an asset or strategy owner.

Asset amounts and budgets use uint256 base units; share units follow OpenZeppelin ERC-4626 metadata. Local dTEST has 18 decimals; tests also use six decimals. No fee, yield, native ecosystem token, price, APR or approved allocation is invented. Only non-rebasing standard ERC-20 assets with exact transfers are supported. Transfer-tax behavior reverts atomically when detected; arbitrary malicious asset semantics cannot be made safe by balance checks. Production assets require review. Donations change share value and can close capacity; users must use preview bounds where appropriate.

ERC-4626 conversion uses OpenZeppelin virtual asset/share offsets. Deposit and redeem round down; mint and withdraw round up. Reserve target is floor(totalAssets × reserveBps / 10000), using mulDiv. Movement is min(target difference, maxMove, remaining window credit). No floating-point math affects execution. SDK rejects excessive human decimal precision and uint256 overflow rather than rounding.

## Limits and permissions

| Parameter | Contract rule | Local journey example, not production approval |
| --- | --- | --- |
| Capacity | Initially positive; owner update ≥current assets; empty vault may close at zero | 200 dTEST in SDK journey; 1000 dTEST in Solidity local script |
| Reserve target | 0–8000 basis points | 8000 |
| Interval | Positive and ≤window duration | 60 seconds |
| Window duration | 1 hour–30 days | 1 hour |
| Expiry | Future on configuration; execution blocked at exact expiry | Seven days |
| maxMove/windowLimit | Positive maxMove, budget ≥maxMove | 100 dTEST each in SDK journey |
| Bounded request | Positive minimum, maximum ≥minimum, expected version/sequence current; valid through deadline inclusive | Exact preview amount, 120-second SDK lifetime |

Owner may transfer or renounce ownership through inherited Ownable, change cap, pause deposits/execution, replace/revoke operator and reset policy budget. There is no upgrade, arbitrary withdrawal of user shares, external call router or fee role. Owner policy changes are immediate and not subject to timelock; future governance must resolve this trust boundary. Reserve authority never belongs to the operator or owner directly.

## State transitions and failures

| Transition | Required state and events | Rejected conditions |
| --- | --- | --- |
| Create | New creator/salt; VaultCreated and provenance record | No asset code, zero cap, reused creator/salt |
| Fund | Shares minted, exact custody receipt; ERC-4626 Deposit | Zero/dust shares, cap/pause, balance/approval, tax/false return, minimum shares |
| Configure | PolicyConfigured, version+1, budget/cooldown reset | Nonowner, invalid limits or expiry |
| Execute | Rebalanced sequence+1, budget/lastExecution update, custody transfer | Nonoperator, stale policy/sequence, expired request/policy, cooldown, pause, exhausted budget, at-target, amount bounds or token failure |
| Revoke/pause | OperatorRevoked or ExecutionPaused; version increments on revoke | Nonowner |
| Exit | Shares burned, reserve recall if needed, Withdraw/ReserveRecalledForWithdrawal | Excess shares/balance, unauthorized delegation, minimum assets, zero/dust or unsupported transfer |

Fixed windows are anchored to policy creation, skipped windows grant no accumulated credit. Withdrawal recall bypasses operator budgets because the reserve is fully liquid. Revert restores token, share, allowance, sequence and budget changes. `rebalance(version,minMoved)` remains the established recurring-call interface; repeat calls after cooldown are intentional. `rebalanceWithBounds` prevents replay of an accepted sequence even after cooldown and across policy changes.

## Acceptance and unresolved production decisions

Compile and format; retained unit/fuzz tests plus new bounded-request rejection tests; stateful campaigns verify custody conservation, attribution, budget/sequence consistency and full exit after pause/revoke. SDK must perform actual local deposits/configuration/execution/redemption with receipt/event checks, reject wrong chain/unauthorized execution/replay, and end at the expected balances. See actual results in validation.md.

Unresolved production decisions: D1 release chain/write policy, D2 deployments, D7 approved assets/caps/withdrawal/governance/emergency behavior, D8 scheduler and availability, independent security review. D3/D4 token economics are not needed here. Local success is not testnet evidence, an audit, investment performance, or production readiness.

# Derived MVP and staged implementation

Source: `Dynamica-Website-PRD(2).docx`, version 1.0, 2 October 2026. Its original website scope excluded new production financial contracts. The user's current instruction explicitly requests a derived contract utility; this repository is that separate testnet MVP scope.

## Stage 1 — Extract

The existing implementation had an ERC-4626 vault with capacity and deposit pause controls. The PRD's vault, operator permissions and execution records make a bounded reserve vault a coherent first utility. It proves real deposits, redeemable ownership and limited execution without inventing yield, token economics, oracle pricing or trading venues.

## Stage 2 — Implement

| PRD requirement | MVP implementation |
| --- | --- |
| REQ-004–007 | Existing real wallet selector, network gating, review, signature and receipt states |
| REQ-011–014 | Asset cap, deposit/withdraw, owner controls and policy validation |
| REQ-032, 034 | Narrow reserve allocation, target, per-call cap, time-window budget, expiry, cooldown, pause and revocation |
| REQ-035 | Real bounded `rebalance` transaction; scheduling remains an external dependency |
| REQ-038 | Factory provenance and `Rebalanced` events; explorer links for actual transactions |
| REQ-039, 042 | Explicit testnet mode, integer token arithmetic and separate test asset |

`DynamicaVault` and `DynamicaTestAsset` are reused. `DynamicaStrategyVault` extends the existing vault. `DynamicaReserve` is constructed by each policy vault and has no independent owner. `DynamicaVaultFactory` creates independent vaults and provides paginated discovery. The frontend retains the existing wallet and vault transaction components and adds owner/operator policy controls.

## Stage 3 — Verify

Compile the contracts and frontend. Exercise accounting, authorization, cap, pause, expiry, window boundaries, delegated redemption, fee rejection, reentrancy and factory isolation in Solidity. Run the TypeScript factory-to-withdraw integration. Check the Python helper against a local deployed instance. Measure source bytes including Solidity tests, with no language overrides.

## Stage 4 — Deliver

Preserve the complete previous website on `website-source`; make `main` the focused MVP source. Push a normal descendant commit, preserving Git history. Include reproducible scripts and CI.

## Explicit implementation boundaries

The reserve is a second liquid custody location, not an external yield strategy. No swaps, leverage, lending, production treasury, price oracle or automatic executor is introduced. No keeper receives user funds. Asset balance rebasing is unsupported. Owner changes are immediate and can reset budget/cooldown; observers can see version and configuration events. Withdrawals recall reserve liquidity without operator authority or execution-budget consumption.

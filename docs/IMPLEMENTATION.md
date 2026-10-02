# Dynamica — explorer release

Implemented from the supplied Dynamica PRD, its linked whitepaper, and the approved-for-exploration visual identity. This is a privately published explorer implementation, not evidence of production financial readiness.

## Delivered surfaces

- Static public routes: Overview, Ecosystem, Token, Documentation, Risks.
- Application workspaces: Overview, all six whitepaper vault classes, Markets, Liquidity, Token Studio, Asset Credit, Treasury, Operators, Strategy Laboratory, Activity.
- Canonical mark and generated hero artwork, ink/citron visual system, responsive layouts, reduced-motion support, semantic forms, accessible dialog primitives, skip navigation, explicit demo/testnet labels.
- Separate browser-local demo ledger, scoped by connected wallet and chain; review dialogs; balance/permission validation; activity export; reset confirmation.
- Real injected EVM wallet connection and chain change listeners; Robinhood Testnet network switching; native and user-configured ERC-20 balance reads.
- Public CoinGecko prices/history and Robinhood Lighter market registry. Failed reads remain unavailable rather than displaying fabricated values.
- Real testnet-only deployment adapter for a fixed-supply ERC-20. Parameter and chain validation, exact 18-decimal scaling, gas estimate, two-minute review freshness, pending-hash persistence, receipt reconciliation, metadata verification. No real transaction was sent during implementation.
- Read/navigate WebMCP tools, feature-detected and AbortSignal-scoped. No live financial execution tool is registered.

## Simulation boundaries

Demo ledger starts with 10,000 nonredeemable example USD units. Vault and pool positions track notional only; they accrue no yield. Paper spot/perpetual positions use explicitly fixed example prices and 1× notional, without funding, P&L, liquidation, fees, partial fills, or real orders. Credit uses 50% maximum LTV, fixed example USD collateral, and no interest/oracle movements. Treasury saves a seven-category policy totaling exactly 100%; it does not move capital. The example operator advances manually through the six whitepaper stages; execution requires a separate confirmed demo review. Nothing runs after the browser closes. The laboratory is a documented deterministic sinusoidal model, not a historical backtest.

## Integration disposition

| Capability | Implemented state | Evidence / next dependency |
|---|---|---|
| Public pages, navigation, demo accounting | Implemented | Static build, types, lint, domain tests; browser interactions remain unverified |
| EVM wallet and testnet balances | Implemented adapter | No injected wallet was available to verify a session |
| ERC-20 testnet deployment | Implemented adapter | Compiled OpenZeppelin 5.6.1 / Solidity 0.8.37 template; no wallet-backed deployment performed; AP/template review pending |
| CoinGecko price list | Public data adapter | Server-side probe returned HTTP 200; browser CORS and history requests not verified |
| Robinhood Lighter market registry | Public data adapter | Server-side orderBooks probe returned HTTP 200; browser CORS not verified |
| Robinhood testnet RPC | Configured official endpoint | Server-side POST probe returned HTTP 405; browser/wallet RPC behavior unverified |
| Lighter trading | Blocked; paper model supplied | Official TS package requires host-injected signer, account setup and clients. Browser signer, Robinhood signing-domain compatibility, API-key lifecycle and venue reconciliation have not been verified. No assumption that a backend is required. Mainnet writes remain disabled. |
| Vault, pool, credit, treasury writes | Blocked; demo models supplied | Verified deployment addresses, ABIs, assets, permission policies and product approval not supplied |
| Autonomous operators | Local manual model only | Registry contracts, delegated permissions and persistent executor not supplied |
| Native Dynamica token | Informational only | Ticker, economics, sale contract and distributions unresolved; none invented |
| WebMCP | Implemented, unverified | No permitted supported browser context was available |

Read-only public venue metadata does not constitute a executable quote or evidence of live trading readiness. EVM chain IDs are not used as Lighter signing domains. The implementation stores no private keys, seed phrases, or API signing secrets.

## Network / contract configuration

- EVM testnet: Robinhood Testnet, chain 46630, ETH gas.
- RPC: https://rpc.testnet.chain.robinhood.com
- Explorer: https://explorer.testnet.chain.robinhood.com
- Production venue public API: https://api.rh.lighter.xyz/api/v1/orderBooks
- Official venue UI: https://robinhoodchain.lighter.xyz
- Fixed supply token source: `contracts/DynamicaToken.sol`; checked artifact: `lib/token-artifact.json`.
- Exact resolved compiler/library versions are recorded in `pnpm-lock.yaml` and artifact metadata.

## Verification and release conditions

Nine domain tests pass: scaled amounts/malformed input; conservation/overdraft; pause/withdraw; credit limits/repayment; odd-cent credit limits; treasury totals; deterministic returns/drawdown; storage validation; repeated cent accounting. TypeScript and scoped ESLint checks pass. ABI inspection confirms standard ERC-20 functions and no mint/owner/tax/blacklist/upgrade methods. Static routes build successfully.

Browser rendering at 360/768/1440, keyboard/focus behavior, screen-reader output, browser storage edge cases, wallet approval/rejection/account-switch races, real fee estimation/deployment, venue browser signing, and cross-browser compatibility have not been verified. The required control-browser skill was unavailable; no alternative browser-control path was used. These gaps prevent a production financial readiness claim. No audit, WCAG certification, or performance certification is claimed.

## Sources

- Supplied Dynamica Website PRD.
- Whitepaper: https://docs.google.com/document/d/1ZPO5adtfucvu6fNY9FMBmxDLlbmICWl8FAoHKZ75L-M/edit
- Robinhood network configuration: https://docs.robinhood.com/chain/add-network-to-wallet/
- Robinhood Lighter domain: https://docs.robinhood.com/chain/lighter-domains/
- Official Lighter TypeScript core: https://github.com/elliottech/lighter-ts

## Development

Use the installed package manager and Sites managed runtime. Product source is in `app/`, `components/dynamica/`, and `lib/`. UI primitives in `components/ui` are reused without edits. Native anchors intentionally support static clean-URL hosting. External-state hydration effects have scoped lint exceptions; no broad lint rules are disabled.

- `node --experimental-strip-types --test tests/domain.test.mjs`
- `node node_modules/typescript/bin/tsc --noEmit`
- `node node_modules/eslint/bin/eslint.js app components/dynamica lib/domain.ts`
- `node scripts/compile-token.mjs`
- Build via the Sites `build-site.mjs` helper. The static bundle is `dist/client`.

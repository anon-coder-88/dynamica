# Dynamica source analysis

Analysis date: 3 October 2026. The attached **Dynamica Website Product Requirements Document**, Team AP, v1.0, 2 October 2026, draft for review, was extracted in document order, including every table. Its priorities remain proposals: P0 is trustworthy operation and release, P1 is requested product workflows, P2 is optional enhancement. Acceptance criteria are planned checks, not recorded passes. No stakeholder approval was supplied.

## Sources and their authority

| Source | Evidence and use |
| --- | --- |
| Attached Dynamica-Website-PRD.docx | Sections 1–15, REQ-001–042, NFR-001–008, J1–J5, D1–D10, R1–R5; authoritative website planning input |
| [Dynamica whitepaper](https://docs.google.com/document/d/1ZPO5adtfucvu6fNY9FMBmxDLlbmICWl8FAoHKZ75L-M/edit) | Read all 27 sections through Google Drive on 3 October; intended capabilities, conditional on implementation; no deployment evidence |
| [Existing repository](https://github.com/anon-coder-88/dynamica/tree/d3449530ebe286ea505f3e6c7bb567727dfc0d4a) | Default main baseline inspected and built; focused protocol and frontend source actually available |
| [Historical website source](https://github.com/anon-coder-88/dynamica/tree/website-source) | Available separate branch; inspected package manifest, application source and route inventory; preserved without reorganization or republishing |
| [Hosted website](https://dynamica-finance.raisatunjangpacok.chatgpt.site/docs) | Conversation context only; not a complete source tree or evidence that integrations work |
| [Kerberos](https://github.com/kerberos-dev/kerberos) and [ZeroKnow](https://github.com/zeroknow-dev/zeroknow) | Both current root directories and recursive trees inspected on 3 October; useful separation of contracts/tests/scripts, SDK/ABI packages and docs. Their proof, market, oracle and indexer mechanics are not adopted. No reference access failure. |

The established `chain/contracts`, `chain/test`, `chain/scripts`, `components` and `web` paths are retained. This change includes all source already on main. The larger historical marketing application remains on its existing branch; it is not silently deleted, represented as newly imported, or included in this default-branch language calculation. The focused application already on main is the frontend measured and delivered here. No change to the hosted deployment is authorized or performed.

## Confirmed boundaries and engineering proposals

Confirmed brief constraints: Dynamica, AP team, Robinhood Chain, responsive website, no required custom backend/database, unspecified native ticker. PRD detailed requirements and exclusions are proposed. PRD Section 3 excludes new proprietary financial contracts from website scope; this user request explicitly authorizes a separate local protocol extension. The extension does not claim to complete the entire website release.

Selected proposal: a single standard ERC-20 asset per capped ERC-4626 vault, with a fixed fully liquid reserve and narrowly authorized operator. The reserve holds the same asset; moving funds between two custody locations is real local-chain accounting, not investment execution or yield. Policy constants and local asset amounts are engineering parameters, not approved economics. See [MVP specification](mvp-spec.md).

## Feature inventory and action-level status

“Observed source” means code inspected. “Verified locally” means the specific checks in validation.md executed. Neither means a public testnet deployment. No external financial action has newly verified Live status.

| PRD area / IDs | Existing source and observed behavior | Delivered protocol status / missing dependencies |
| --- | --- | --- |
| Discovery and public content, REQ-008, 022–024; J1 | Historical website routes for overview, ecosystem, token, docs, risks; current focused app shell | Native ticker/economics unconfirmed (D3). Website discovery, content completeness and external data remain outside this extension. |
| Wallet/network/review/status, REQ-002, 004–007 | Existing wallet selector/provider and vault transaction review; configuration defaults to Testnet 46630 | Focused frontend build verified; browser wallet journey not runtime verified. Empty deployed addresses mean action is not configured. SDK writes tested on Local 31337 only. |
| Balances/provenance, REQ-003, 009, 038, 041 | RPC reads and event-producing contracts; Python read helper | Snapshot pins reads to one block and carries timestamp/network/mode; no complete portfolio history, TVL or indexer claimed. |
| Vault catalog/configuration, REQ-010–011 | One concrete reserve strategy; historical application contains broader product/demo screens | Asset restriction, cap and operator parameters enforced locally. Six catalog classes and financial algorithms are not all implemented. |
| Deposit/withdrawal/controls, REQ-012–014; J2 | ERC-4626 custody, share allowances, cap, pauses; isolated Solidity fixtures | Verified locally, including precision/rounding, transfers and withdrawal recovery. Public deployment and asset approval still missing (D1, D2, D7). |
| Liquidity, REQ-015–017 | Historical product/demo interface, no compatible LP venue in this MVP | Deferred, not reported as live or universally unavailable. Requires pool/position-manager assets, ABI and integration checks (D2, D5). |
| Token Studio, REQ-018–021; J4 | dTEST faucet exists strictly for development; not a Token Studio implementation | Template decision D4 and actual creator deployment workflow deferred; native ticker not invented. |
| Spot/perpetual markets, REQ-024–028; J3 | No venue execution adapter in focused default-branch application | Deferred; Lighter browser capability in PRD remains a documented candidate, not rejected for lack of backend. D5/D6 proof of concept unperformed. |
| Credit, REQ-029–030 | No lending accounting/oracle in this protocol | Deferred, requires collateral/oracle/interest/liquidation policy and compatible deployment. |
| Treasury, REQ-031–032 | Fixed vault reserve is not treasury category distribution | Deferred; no claim that reserve target is a 100% treasury allocation editor. |
| Operators/registry, REQ-033–034 | Owner-authorized fixed-route operator policy; permissionless vault factory discovery | Verified local policy enforcement, expiry/cooldown/budget and provenance; factory registry is not a full operator marketplace. |
| Simulation/laboratory, REQ-035–037; J5 | Historical local scenario UI; test fixtures isolated from protocol state | Not implemented or verified by this extension; Solidity tests are not financial backtests. |
| Demo isolation/persistence, REQ-039–040 | Historical demo data and current valueless test asset are separate concepts | Local-chain transactions move local assets; not a browser demo ledger. Browser persistence/mode isolation not audited. |
| Static hosting and quality, REQ-001, NFR-001–008 | Focused Vite static build; historical website framework retained elsewhere | Build and type checks pass; no new runtime server or DB. Responsive, accessibility, real-browser, transport and field performance checks unperformed. Contract authorization tested (NFR-007), not complete website acceptance. |

Development mocks in `chain/test/TestSupport.sol` intentionally exercise hostile tokens. `DynamicaTestAsset.sol` is a one-claim valueless faucet, not Dynamica's ecosystem token. Mock results never establish venue, provider, oracle, deployed scheduler or public-network functionality.

## Dependencies, risks and unresolved decisions

D1 release network/writes, D2 known deployments, D3 token economics, D4 token template, D5 provider compatibility, D6 Lighter lifecycle, D7 financial policies, D8 continuous executor, D9 brand/content and D10 staffing/timing/metrics remain unresolved for a financial release. None blocks this local fixed-reserve workflow. A real operator must run an external wallet or scheduler and submit transactions; contracts do not schedule themselves. No scheduler, oracle, confidential credential, database or AI computation is implemented.

R1 mode confusion is addressed through explicit local/testnet/unconfigured documentation, not by claiming a completed website QA. R2 provider usability and R3 financial preview divergence remain for future integrations; bounded execution protects this local preview from sequence/policy/time/amount changes. R4 continuous operation requires an executor. R5 ecosystem scope is narrowed explicitly. NFR targets and 30-day metrics remain proposals, without baseline or analytics service.

## Primary configuration and interface checks

[Robinhood official wallet configuration](https://docs.robinhood.com/chain/add-network-to-wallet/) rechecked 3 October: mainnet 4663, testnet 46630, ETH gas, testnet RPC `https://rpc.testnet.chain.robinhood.com`, testnet explorer `https://explorer.testnet.chain.robinhood.com`. This documents configuration, not RPC uptime or deployment. Local writes use 31337. Mainnet writes are excluded by development tooling. Lighter signing domains are a different layer and are not used.

OpenZeppelin [ERC-20/ERC-4626 API](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20), [security utilities](https://docs.openzeppelin.com/contracts/5.x/api/utils), installed 5.6.1 sources, and compiled ABI verify the interfaces actually used: SafeERC20, Math.mulDiv, ERC4626 and ReentrancyGuard. Viem 2.56.9 installed types/build and the actual local journey verify SDK compatibility. [Hardhat Solidity tests](https://hardhat.org/docs/guides/testing/using-solidity) and real Foundry/forge-std support the test approach; no assertion shim remains.

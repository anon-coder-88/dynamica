# Dynamica

Dynamica explores programmable onchain finance with explicit capital and execution boundaries. This repository implements **capped ERC-4626 strategy vaults with constrained reserve operators**, grounded in the Dynamica whitepaper and website PRD. It is a local protocol extension to the website scope, with a focused static interface and typed SDK.

An allocator approves and deposits a standard asset, receives redeemable shares, and can exit immediately. An owner authorizes an operator's fixed-reserve target, per-call limit, window budget, cooldown and expiry. The operator can move assets only between the vault and its immutable liquid reserve. Bounded requests reject stale policy, replayed execution, expired previews and changed amounts. Pause and revocation preserve user withdrawals.

This utility performs real EVM custody and accounting locally. The reserve generates no yield and executes no trade. No public deployment or independent audit is claimed. `dTEST` is a valueless development faucet, not Dynamica's native token; its native ticker and economics remain unconfirmed. No scheduler is bundled: an external operator must submit transactions.

## Source and scope

The existing default-branch frontend and protocol are retained and strengthened. The full historical marketing website remains on [website-source](https://github.com/anon-coder-88/dynamica/tree/website-source); no hosted deployment was changed. The focused frontend here uses generated ABIs and remains static. This repository does not claim to complete all PRD website features or to integrate trading, lending, liquidity venues or AI.

See [source inventory](docs/source-analysis.md) for confirmed constraints, proposed design, observed code, local demonstration behavior, infrastructure gaps and reference inspections. [MVP specification](docs/mvp-spec.md) compares candidates and defines the workflow, requirements, accounting, permissions and acceptance criteria.

## Setup and verification

Use Node **24.19.0**, npm **11.9.0** and Foundry **1.7.1**. All npm dependencies use exact versions and lockfiles; forge-std **1.17.0** is pinned by git submodule. No signing key is needed for local tests or the SDK journey.

```sh
git submodule update --init --recursive
npm ci
npm ci --prefix chain
npm --prefix chain run build
npm run abi
forge fmt --check
npm run test:contracts
npm run check:sdk
npm run test:sdk
npx tsc -p chain/tsconfig.json --noEmit
npm run journey
npm run build
```

`npm run journey` executes factory creation → faucet claim → exact approval → deposit → owner authorization → bounded rebalance → replay rejection → revoke/pause → full redemption on an ephemeral Local 31337 chain. It verifies receipt events, permissions, network rejection and final asset conservation through the typed SDK. It is a genuine local demonstration, not a public transaction record.

Actual results and limitations are in [validation](docs/validation.md). The canonical Foundry suite includes unit, fuzz and stateful invariant tests using maintained forge-std. Build output and fixtures do not establish production readiness.

For language measurement, use Ruby 3.2 and Bundler 2.5.23:

```sh
bundle install
npm run check:languages
```

This invokes actual GitHub Linguist 9.3.0. [Language report](docs/language-report.md) separates first-party protocol, tests/scripts, other languages and exclusions. Compiler-generated ABI declarations are honestly marked generated. Genuine frontend/SDK code is not overridden or hidden. GitHub's language statistics concern its default branch; a review branch does not establish default-branch acceptance for this revision.

## Repository layout

| Path | Purpose |
| --- | --- |
| chain/contracts | Protocol vault/reserve/factory; explicitly named development faucet |
| chain/test | Unit/fuzz/invariant tests and isolated hostile token fixtures |
| chain/script, chain/scripts | Local Solidity deployment, established CLI/deployment and SDK journey |
| web, components, public | Existing focused React/Vite interface and assets |
| packages/sdk | Typed Viem interactions, strict amount parser and tests |
| packages/abi | Actual generated contract ABIs |
| python | Existing read-only status helper |
| docs | Source analysis, MVP, architecture, contracts, deployment, security and validation |
| .github/workflows | Build, ABI consistency, formatting, tests and language checks |

## Integration and trust boundaries

Only standard non-rebasing exact-transfer ERC-20 assets are supported; transfer taxes are rejected where detected. The owner can replace policy immediately, resetting its budget and cooldown, and change capacity or pauses. There is no governance timelock, upgrade, fee or arbitrary execution router. The fixed liquid reserve is recoverable during withdrawals; external investment venues would need a separate withdrawal/risk design. Targets are per-execution rebalancing goals, not continuous ratio guarantees. The legacy recurring `rebalance` entry point retains its deliberate recurring semantics; the SDK and focused operator UI use `rebalanceWithBounds`.

Public network decisions, approved assets/risk parameters, funded signer, deployment, executor operation and independent review remain open. [Deployment guide](docs/deployment.md) documents reproducible local commands and future testnet preparation; this request does not authorize public deployment. Browser wallet journeys, accessibility, responsive behavior and public provider reliability have not been runtime validated here. No database or runtime server was added.

Read [architecture](docs/architecture.md), [contract interfaces](docs/contracts.md) and [security model](docs/security.md) before integration. Contribute through reviewable pull requests using [Conventional Commits](CONTRIBUTING.md). MIT license; upstream licenses and existing provider marks retain their rights; see [attribution](NOTICE.md) and [security reporting](SECURITY.md).

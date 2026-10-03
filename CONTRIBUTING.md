# Contributing

Keep changes specific to the capped vault utility. Read docs/mvp-spec.md and docs/security.md before changing accounting, privileges, assets, rounding or withdrawal behavior. Production integrations require their own verified source, permissions and risk proposal.

Clone with submodules and install exact lockfile dependencies. Run the compilation, Foundry formatting/tests, SDK type/unit/local journey and frontend build commands in README.md. Regenerate ABIs from compiled artifacts; do not edit generated declarations. Include targeted regressions and invariants for changed financial behavior. Keep mocks in development fixtures, secrets/build output out of commits, and dependency attribution intact.

Use Conventional Commits: `feat(protocol): ...`, `test(vault): ...`, `feat(sdk): ...`, `docs(mvp): ...`, `ci(protocol): ...`. Explain the concrete behavior, relevant test results and material limitations in a pull request. Do not merge or force-push around protections. Preserve existing source/history and the separate historical website branch.

Language checks use actual GitHub Linguist bytes. Never pad Solidity, copy dependencies into eligible source, hide genuine frontend code, or call an extension-only estimate GitHub's result. Generated ABI declarations are excluded because they are actual compiler output. Public-network writes and hosted deployment changes need their own authorization.

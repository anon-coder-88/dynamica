# Language statistics report

Measured with **actual GitHub Linguist 9.3.0**, using its published file classification/exclusion rules and eligible byte sizes. This is not a file count, line count or extension-only estimate. Source rules: [Linguist](https://github.com/github-linguist/linguist) and [how it works](https://github.com/github-linguist/linguist/blob/main/docs/how-linguist-works.md).

Measured immutable code revision: **fabd6e8ad373495c75de8db3bbdbf491e2aaff27**, tree **15abec5026c3a82df8a4de35795a3bcad5a2f304**. Local corresponding commit is 1ec2a2483fb17fe26d48bad1dae5e079ce4db5a5; connector-created commits retain the identical Git tree and source content. The final follow-up adds only prose/data documentation, so eligible language bytes do not change. The measurement covers the actual delivered repository, including its existing focused frontend, SDK, scripts, Python helper and all meaningful Solidity tests.

## Eligible language bytes

| Language | Bytes | Share |
| --- | ---: | ---: |
| Solidity | 92,426 | 56.3247% |
| TypeScript | 59,652 | 36.3521% |
| CSS | 7,683 | 4.6820% |
| Python | 2,079 | 1.2670% |
| JavaScript | 1,747 | 1.0646% |
| HTML | 447 | 0.2724% |
| Ruby | 61 | 0.0372% |
| Total | 164,095 | 100% |

**Solidity share = 92,426 / 164,095 × 100 = 56.32%.** The approximately 55–60% margin is met without adding unrelated financial modules or padding source.

## Solidity composition

| Category | Eligible bytes |
| --- | ---: |
| First-party protocol vault/reserve/factory, including retained base vault | 17,582 |
| Clearly named valueless development faucet | 578 |
| Solidity unit/fuzz/invariant tests and isolated hostile-asset fixtures | 73,382 |
| Local Solidity deployment script | 884 |
| Total Solidity | 92,426 |

The majority figure includes tests and scripts, as requested; production contract source alone is not 50% of this repository. Test volume validates specific accounting, permission, precision, transfer failure, replay and recovery behavior. No copied dependency implementation, assertion shim, duplicate contract or unrelated module contributes to the numerator. Maintained forge-std is a git submodule and is not first-party eligible Solidity.

## Exclusions and stylesheet correction

The only explicit .gitattributes exclusion is **packages/abi/src/contracts.ts**, 44,606 bytes of actual compiler-generated TypeScript ABI declarations. Regeneration uses real compiled artifacts and is checked in CI. Python's generated ABI JSON and JSON manifests/lockfiles are data under Linguist; dependency installations, compiled artifacts, caches and broadcasts are untracked. Markdown is prose, binary provider assets are binary/data, and forge-std is a gitlink rather than copied eligible source. No language override or exclusion applies to handwritten frontend, SDK, protocol or tests.

Linguist initially recognized the existing compressed handwritten web/style.css as generated/minified and omitted it, yielding 59.09%. The stylesheet was formatted with Prettier 3.6.2 for readability, retaining its styling and making it eligible CSS. The final measurement **includes all 7,683 CSS bytes** and is lower at 56.32%; the earlier 59.09% is not the final result. The frontend build passed again after formatting.

## Reproduce

```sh
bundle install
bundle exec github-linguist --version
bundle exec github-linguist --json
bundle exec github-linguist --breakdown --json
npm run check:languages
```

Ruby 3.2, Bundler 2.5.23 and Gemfile.lock pin the measurement environment. Linguist analyzes committed trees; commit your intended deliverable rather than measuring unrelated scratch or ignored build content. scripts/language-share.mjs invokes Linguist and fails below 50%. Detailed bytes are also in language-share.json.

## Default-branch verification

On 3 October 2026, the GitHub REST languages endpoint for anon-coder-88/dynamica returned **main baseline** d3449530ebe286ea505f3e6c7bb567727dfc0d4a: Solidity 78,995; TypeScript 49,902; Python 2,079; JavaScript 1,869; HTML 447; total 133,292; **59.2646% Solidity**. Main already satisfies 50% for its existing content. This is GitHub's actual default-branch distribution, distinct from the new review branch measurement. The compressed original CSS was not counted by GitHub for that baseline.

The new revision is prepared on feat/verified-strategy-vault through a pull request. It has **not been merged into main**, so new-revision default-branch processing is pending. No feature-branch estimate is represented as GitHub's updated main result. After reviewed merge, verify main's resulting commit and requery https://api.github.com/repos/anon-coder-88/dynamica/languages after asynchronous processing; compare actual eligible bytes against the delivered tree. GitHub may run a different Linguist version. If processing or classification differs, investigate before claiming acceptance.

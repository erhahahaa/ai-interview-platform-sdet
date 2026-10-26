# Scoreboard — evidence

Every number is backed by a command + saved output (see `evidence/`). A number without that does not count.

## Baseline (Wave 0)

| Measure | Baseline value | How measured | Pass condition | Status |
|---|---|---|---|---|
| Findings by severity & class | P0=0, P1=4, P2=5, P3=3; SPEC-GAP=1, BUILT-WRONG=11 | counted from `01-audit.md` ledger | every P0/P1 has a repro + V1 CONFIRMED | pending repros |
| Detection recall | n/a | audited P0/P1 caught by CI ÷ all P0/P1 | all caught or each miss has a reason/new check | net not built |
| Red for the right reason | n/a | red jobs at G2 mapped to a finding ÷ all red jobs | all of them | net not built |
| Gate precision on fixtures | n/a | 6 fixtures (3 block / 3 pass) | 6/6 | net not built |
| Revert test | n/a | fixes whose regression goes red again when fix reverted | every fix | net not built |
| Flake rate | n/a | same commit × 3 runs | identical verdicts | net not built |
| Risk-path coverage | 0% (no test suite) | line/branch on the `risk-paths` list only | ≥ baseline, threshold stated | no tests |
| Mutation score | n/a (optional) | mutant / Stryker on 2-3 critical modules | reported, survivors triaged | not run |
| Gate lead time | n/a (no CI) | minutes PR-open → verdict; total CI wall time | recorded, threshold from baseline | no CI |
| Open P0/P1 at release | 4 (F-1, F-2, F-3, F-13) | ledger count at tag | zero, or accepted risk with owner+mitigation+expiry | n/a yet |

Notes:
- DORA's five delivery metrics are not honestly producible in one day; gate lead time + the revert test are recorded as proxies.
- Baseline captured 2026-10-26 (Wave 0), before any fix. After-values at G3 and G5.

## After (G3)

| Measure | After value | How measured |
|---|---|---|
| Findings by severity & class | P0=0, P1=4, P2=5, P3=3; SPEC-GAP=1 | `01-audit.md` ledger |
| Detection recall | 3/3 code-level P1s caught by CI (F-1, F-2, F-3); F-13 (dependency) → `dependency-audit` planned, not yet wired | red→green CI history |
| Red for the right reason | all red jobs at G2 mapped to findings (api-tests/web-tests) | CI run list |
| Gate precision on fixtures | 6/6 | `tools/dor-check/test_fixtures.sh` |
| Revert test | not run as a separate branch (fixes committed with red→green; regression specs would re-red on revert) | — |
| Flake rate | 3 identical runs (10 examples, 0 failures each) | `bundle exec rspec` × 3 |
| Risk-path coverage | **58.1% line** (129/222) on the 6-file `risk-paths` list | SimpleCov, `coverage/.resultset.json` |
| Mutation score | not run (cut) | — |
| Gate lead time | PR open→verdict ~1 min (blocked PR dor-gate red in 7s) | CI runs |
| Open P0/P1 at release | 1 (F-13, accepted risk) | ledger at `v1.0.0-rc.1` |

Risk-path per-file line coverage: `authentication_controller` 100%, `user` 100%, `tenant_scoped` 100%, `fit_gap/engine` 79.4%, `portfolio_skills_controller` 41.9%, `portfolios_controller` 32.6%.

# 02 — Quality System (the net)

## One command

```bash
make net
```

runs: `dor-check` (6 self-test fixtures) → `api-test` (RSpec) → `web-test` (Vitest + `tsc` + `vite build`). CI runs the same checks plus `secret-scan`.

## What each check protects (and deliberately does not cover)

| Check | Protects | Does NOT cover |
|---|---|---|
| `tools/dor-check` (PR gate) | Work moving without its inputs: linked spec/PRD, Given/When/Then acceptance criteria, design plan (approach/data impact/risks/test plan), and a test for any `api/`/`web/` source change. | The *quality* of the spec — a linked-but-wrong spec passes. |
| `spec/requests/tenant_isolation_spec.rb` | F-001: login cannot self-select another tenant via `X-Tenant-Scheme`. | Tenant isolation on WebSocket endpoints (separate auth path). |
| `spec/requests/portfolio_authorization_spec.rb` | F-002: portfolio/portfolio-skill lookups are tenant-scoped. | `fit_gap_reports`, `coverage_maps`, `transcript_turns` (reached only via scoped parents today). |
| `spec/requests/fit_gap_contract_spec.rb` | F-003 (contract side): fit/gap comparisons emit `expected_level`, not `required_level`. | The web rendering of that field (covered by the Vitest test). |
| `spec/services/fit_gap_engine_spec.rb` | F-003 (engine side): `expected_level`, `is_override`, and the override applied (candidate level). | Gemini narratives (stubbed here). |
| `spec/requests/error_handling_spec.rb` | error/edge: 401 unauth, 422 invalid, 404 missing/cross-tenant. | Unknown routes (raise in request specs). |
| `web/src/components/fitgap/ComparisonTable.test.tsx` | F-003 (render side): the "Required" column actually shows the level. | Other tables/columns. |
| `secret-scan` (gitleaks) | Secrets/forbidden names in full git history. | Secrets not matching gitleaks rules. |
| `tsc && vite build` | Type errors and build breakage. | Runtime-only errors. |

## Red-to-green table

| Finding | Check that was red | Red run | Fix commit | Green run |
|---|---|---|---|---|
| F-001 | `tenant_isolation_spec.rb` | rspec local + CI `api-tests` run 40246874068 | `3300aa2` | CI `api-tests` (fix push) |
| F-002 | `portfolio_authorization_spec.rb` | rspec local + CI `api-tests` run 40246874068 | `908a9b5` | CI `api-tests` (fix push) |
| F-003 | `ComparisonTable.test.tsx` (web) + `fit_gap_contract_spec.rb` | vitest local + CI `web-tests` run 40246873994 | `9ba3876` | CI `web-tests` (fix push) |

Local results at fix time: RSpec 3/3 green, Vitest 1/1 green, `make net` green.

## How to extend

- **Add a spec folder** for a feature: copy `specs/_template/` → `specs/<feature>/` and fill `prd.md`, `acceptance.md` (Given/When/Then), `design.md` (the four headings). Link them from the PR body.
- **Add a check**: put a test under `api/spec/` (RSpec) or `web/src/**/*.test.tsx` (Vitest), then add it to the `make net` / CI job list. Name it with its finding ID if it is a regression test.
- **Add a CI job**: `.github/workflows/*.yml`, keep the job name stable (required checks bind to job names).

## Tests changed and why

- The three regression specs were updated to assign the test user a home `organization` (required by the F-001 fix, which now derives the scheme from the user's org). This is a justified edit to reflect the corrected contract — not a weakening. No assertion was loosened or removed; `guard-no-weakening` is planned to enforce this going forward.

## Decisions and scope cuts (one-day compression)

- **Cut**: mutation testing, Schemathesis, Playwright (beyond the component tests), and the P2/P3 fixes (F-4, F-5, F-6, F-8, F-9, F-10, F-11, F-12 remain open — see `01-audit.md`).
- **Deferred with accepted risk**: F-13 (Rails 7.0 EOL) — see `03-release-decision.md`.
- **Approach**: hand-written JSON + loose `any` types were the seam bug's root cause (P-α); the fix pins the field name on both sides and adds a contract test. Tenant isolation is enforced at the controller for child records (P-β) pending a denormalized `tenant_id` migration if scope grows.

## Tool versions (resolved at run time, 2026-10-26)

- Ruby 3.3.2, Rails 7.0.10 (EOL — see F-13), rspec-rails 6.1.5 (6.x is required for Rails 7.0; 8.x targets 7.2+).
- Vitest 4.1.12 (Vite 6.4.5; Node 25), @testing-library/react + jest-dom, jsdom.
- gitleaks 8.30.1 (clean scan: no secrets).
- PostgreSQL 16 (Docker), Redis 7 (Docker).
- `npm audit`: 3 moderate (tailwindcss/postcss chain) — tracked in F-13.

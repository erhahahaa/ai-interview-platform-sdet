# 01 — Platform Audit (draft, pre-fix baseline)

Status: **draft** — severities and impact are from static analysis + read-only maps. F-1 and F-2 are **confirmed live** (see `evidence/findings/F-001.md`, `F-002.md`); F-3 and F-13 are evidenced statically. Remaining repros to be confirmed by the Wave-1 verifier (V1) from a clean checkout.

## Five-minute summary

The platform is a two-service, multi-tenant "AI interview" product: a Rails 7.0 API (Postgres + Redis/Sidekiq + Gemini + WebSocket) and a React 18 + TypeScript + Vite web app. The happy path is genuinely there — assessments, vacancies, candidate invite links, a Gemini voice interview with live coverage tracking, portfolio generation, assessor overrides, fit/gap reporting, and PDF export all exist end-to-end.

What is **not** there is everything the case study is actually about:

- **No workflow inputs.** No PRD, no Given/When/Then acceptance criteria, no design plan, no tests, no CI, no lint config, no API contract. Every feature is a "ghost spec" (the only spec is an external wiki, not in the repo).
- **The tenant boundary leaks.** Login mints a cross-tenant JWT from an attacker-controllable header, and child records (portfolios, portfolio skills) are reachable by global integer ID with no tenant check. Two separate holes, same root cause: tenant scoping is enforced only at parent models, and auth trusts unauthenticated input.
- **The seam between web and API drifts.** Hand-written JSON + loose `any` types let field names diverge: the fit/gap "Required" column renders blank because the API sends `expected_level` and the web reads `required_level`. It looks fine; the data is wrong.
- **The stack is out of support.** Rails 7.0 is EOL (security support ended 2025-04-01).

If this went in front of a client tomorrow I would worry most about: (1) one tenant being able to read or write another tenant's data, and (2) a report whose required-level column silently shows nothing. Both are invisible on the happy path.

## Ship / do-not-ship line

**DO NOT SHIP.** Before a client sees this, close the tenant holes (F-1, F-2), fix the fit/gap field drift (F-3), stand up the Definition-of-Ready gate and CI net, and record the Rails-7.0 EOL as an accepted risk with a named owner and an upgrade path (F-13).

## Ranked findings

| ID | Sev | Class | Area | Impact (who/what is hurt) | How found | Caught by (net) | Final status |
|---|---|---|---|---|---|---|---|
| F-1 | P1 | BUILT-WRONG | auth / tenant | An admin of tenant A can mint a JWT for tenant B via the `X-Tenant-Scheme` header at login and read/write B's data | **Live repro (confirmed)** — `evidence/findings/F-001.md` | `tenant_isolation_spec.rb` | fixed in `3300aa2` |
| F-2 | P1 | BUILT-WRONG | authz / tenant | An assessor can export/override another tenant's portfolio by guessing an integer ID (`Portfolio.find`, `PortfolioSkill.joins(:portfolio).find`) | **Live repro (confirmed)** — `evidence/findings/F-002.md` | `portfolio_authorization_spec.rb` | fixed in `908a9b5` |
| F-3 | P1 | BUILT-WRONG | seam / data | Fit/gap "Required" column renders blank (API `expected_level` vs web `required_level`); `is_override` badge never shows | Seam map: `fit_gap/engine.rb` vs `ComparisonTable.tsx` | `fit_gap_contract_spec.rb` + `ComparisonTable.test.tsx` | fixed in `9ba3876` |
| F-13 | P1 | SPEC-GAP→risk | dependency | Rails 7.0.8 EOL — unpatched CVEs in production | `bundle audit` / advisory DB + endoflife.date | planned: `dependency-audit` job | accepted risk (see below) |
| F-4 | P2 | BUILT-WRONG | api | `system_prompt_generated: true` returned before the async job runs; a stopped Sidekiq leaves a nil prompt | Static: `assessments_controller.rb` | planned: request spec | remaining |
| F-5 | P2 | BUILT-WRONG | api | Transcript `total` is the filtered count, not the total | Static: `sessions_controller.rb` | planned: request spec | remaining |
| F-6 | P2 | BUILT-WRONG | web | Signup is dead — `/signup` has no route; `SignupPage` is not mounted | Seam map: `auth.ts` vs `routes.rb` | planned: contract spec | remaining |
| F-9 | P2 | BUILT-WRONG | security | Wildcard `ALLOWED_ORIGINS: "*"` + `expose: Authorization` in sample config | Static: `application.yml.sample`, `cors.rb` | planned: config check | remaining |
| F-11 | P2 | BUILT-WRONG | perf | Assessment list N+1 — `max_by(&:created_at)` loads every session per row | Static: `assessments_controller.rb` | planned: query-count spec | remaining |
| F-7 | SPEC-GAP | — | inputs | No PRD / acceptance criteria / design plan / tests / CI / contract anywhere | input-gaps matrix | planned: `dor-gate` + `tools/trace` | remaining |
| F-8 | P3 | BUILT-WRONG | docs | Port / folder / model drift across READMEs, `.env.example`, k8s | hygiene map | — | remaining |
| F-10 | P3 | BUILT-WRONG | api | `Organization.default_organization` returns `where(id: 0)` (dead fallback) | Static: `organization.rb` | — | remaining |
| F-12 | P3 | BUILT-WRONG | web | `PortfolioSkill.ai_level` typed string but API returns integer | Seam map: `types/index.ts` vs `portfolio_skill_json` | — | remaining |

Severity counts: P0 = 0, P1 = 4, P2 = 5, P3 = 3, SPEC-GAP = 1.

## Systemic patterns

- **P-α "two sources of truth for a value."** No serializers + `any` on the web ⇒ field names drift (`expected_level` vs `required_level`, `ai_level` int vs string, `is_override` never emitted). Behind F-3, F-12, and the dead axios `data`-unwrap (seam map #5).
- **P-β "tenant boundary only on parent models."** `TenantScoped` is column-driven; child records (`portfolio`, `portfolio_skill`, `fit_gap_report`, `coverage_map`, `transcript_turn`) have no tenant column and are reached by global `find`. Behind F-1, F-2.
- **P-γ "auth trusts attacker-controlled input."** Login takes `scheme` from an unauthenticated header; the tenant resolver reads `scheme` from an *unverified* JWT. Behind F-1.

## Error & edge states (covered)

Probed by `api/spec/requests/error_handling_spec.rb` plus the cross-tenant specs:

- Unauthenticated (no token) → **401** (was 403 "tenant not found"; fixed by running auth before tenant resolution in `application_controller.rb`).
- Unsupported `time_limit_min` (42) → 422 · missing `name` → 422.
- Missing record (`/assessments/999999`) → 404.
- Cross-tenant record (assessment / portfolio / portfolio-skill) → 404.
- Unknown route → 404 in production (Rails `show_exceptions`); raises in request specs, so not asserted there.

## Not examined (honest coverage)

- Live Gemini/Sidekiq/Redis behavior, WebSocket reconnect races, and the audio/interview UI flow (`useAudioWebSocket`, `InterviewPage`, `HardwareCheck`) — need a running instance + Playwright.
- OWASP fuzzing (Schemathesis) and mutation testing — not run.
- `bundle audit` / `osv-scanner` — not run; F-13 severity is from the EOL advisory DB.
- The k8s "client infra" nodepool name was scrubbed; nothing further to confirm.

## Final status per item

- F-1, F-2, F-3 → **fixed** (`3300aa2`, `908a9b5`, `9ba3876`).
- F-13 → **accepted risk** (owner: Rahmat Hidayatullah; expires before the next GA release).
- F-4, F-5, F-6, F-7, F-8, F-9, F-10, F-11, F-12 → **remaining** (P2/P3/SPEC-GAP — consciously out of scope for this pass).

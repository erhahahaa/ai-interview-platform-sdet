# 01 — Platform Audit (draft, pre-fix baseline)

Status: **draft** — severities and impact are from static analysis + read-only maps; each P0/P1 repro is written as a target command to be confirmed against a running local instance in Wave 1 (verifier V1 re-runs them from a clean checkout).

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
| F-1 | P1 | BUILT-WRONG | auth / tenant | An admin of tenant A can mint a JWT for tenant B via the `X-Tenant-Scheme` header at login and read/write B's data | Static: `authentication_controller.rb` + `tenant_resolver_middleware.rb` | planned: contract + authz spec | open |
| F-2 | P1 | BUILT-WRONG | authz / tenant | An assessor can export/override another tenant's portfolio by guessing an integer ID (`Portfolio.find`, `PortfolioSkill.joins(:portfolio).find`) | Static: `portfolios_controller.rb`, `portfolio_skills_controller.rb` | planned: object-level authz spec | open |
| F-3 | P1 | BUILT-WRONG | seam / data | Fit/gap "Required" column renders blank (API `expected_level` vs web `required_level`); `is_override` badge never shows | Seam map: `fit_gap/engine.rb` vs `ComparisonTable.tsx` | planned: contract + component spec | open |
| F-13 | P1 | SPEC-GAP→risk | dependency | Rails 7.0.8 EOL — unpatched CVEs in production | `bundle audit` / advisory DB + endoflife.date | planned: `dependency-audit` job | accepted risk (see below) |
| F-4 | P2 | BUILT-WRONG | api | `system_prompt_generated: true` returned before the async job runs; a stopped Sidekiq leaves a nil prompt | Static: `assessments_controller.rb` | planned: request spec | open |
| F-5 | P2 | BUILT-WRONG | api | Transcript `total` is the filtered count, not the total | Static: `sessions_controller.rb` | planned: request spec | open |
| F-6 | P2 | BUILT-WRONG | web | Signup is dead — `/signup` has no route; `SignupPage` is not mounted | Seam map: `auth.ts` vs `routes.rb` | planned: contract spec | open |
| F-9 | P2 | BUILT-WRONG | security | Wildcard `ALLOWED_ORIGINS: "*"` + `expose: Authorization` in sample config | Static: `application.yml.sample`, `cors.rb` | planned: config check | open |
| F-11 | P2 | BUILT-WRONG | perf | Assessment list N+1 — `max_by(&:created_at)` loads every session per row | Static: `assessments_controller.rb` | planned: query-count spec | open |
| F-7 | SPEC-GAP | — | inputs | No PRD / acceptance criteria / design plan / tests / CI / contract anywhere | input-gaps matrix | planned: `dor-gate` + `tools/trace` | open |
| F-8 | P3 | BUILT-WRONG | docs | Port / folder / model drift across READMEs, `.env.example`, k8s | hygiene map | — | open |
| F-10 | P3 | BUILT-WRONG | api | `Organization.default_organization` returns `where(id: 0)` (dead fallback) | Static: `organization.rb` | — | open |
| F-12 | P3 | BUILT-WRONG | web | `PortfolioSkill.ai_level` typed string but API returns integer | Seam map: `types/index.ts` vs `portfolio_skill_json` | — | open |

Severity counts: P0 = 0, P1 = 4, P2 = 5, P3 = 3, SPEC-GAP = 1.

## Systemic patterns

- **P-α "two sources of truth for a value."** No serializers + `any` on the web ⇒ field names drift (`expected_level` vs `required_level`, `ai_level` int vs string, `is_override` never emitted). Behind F-3, F-12, and the dead axios `data`-unwrap (seam map #5).
- **P-β "tenant boundary only on parent models."** `TenantScoped` is column-driven; child records (`portfolio`, `portfolio_skill`, `fit_gap_report`, `coverage_map`, `transcript_turn`) have no tenant column and are reached by global `find`. Behind F-1, F-2.
- **P-γ "auth trusts attacker-controlled input."** Login takes `scheme` from an unauthenticated header; the tenant resolver reads `scheme` from an *unverified* JWT. Behind F-1.

## Not examined (honest coverage)

- No live run yet: Gemini/Sidekiq/Redis behavior, WebSocket reconnect races, and the audio/interview flow (`useAudioWebSocket`, `InterviewPage`, `HardwareCheck`) are not yet exercised; they need a running instance + Playwright.
- No OWASP fuzzing (Schemathesis) or mutation testing yet.
- Dependency audit (`bundle audit` / `osv-scanner` / `npm audit`) is planned but not yet run — F-13 severity is from the EOL advisory DB, to be confirmed by `bundle audit`.
- The k8s "client infra" nodepool name (see hygiene) is a candidate forbidden name to confirm with the owner.

## Final status per item

To be filled at Wave 5 with `fixed in <sha>` / `remaining (owner: …, expires: …)`.

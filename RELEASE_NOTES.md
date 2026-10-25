# Release Notes — v1.0.0-rc.1

Release candidate. **Blocked for GA** (see `assessment/03-release-decision.md`).

## What this version claims to deliver

- A multi-tenant AI-interview platform (Rails API + React web) that runs end-to-end: assessments, vacancies, candidate invite links, live coverage tracking, portfolio generation, assessor overrides, fit/gap reports, and PDF export.
- **Tenant isolation hardened:** login can no longer self-select another tenant (`X-Tenant-Scheme` is ignored), and portfolio/portfolio-skill lookups are tenant-scoped.
- **Correct fit/gap data:** the report's "Required" column renders the expected level, and overrides are surfaced.
- **A quality net:** a Definition-of-Ready PR gate, RSpec request specs, a Vitest component test, CI (api-tests, web-tests, secret-scan, dor-gate), and `make net` to run it all locally.

## Known and not fixed (disclosed)

- **Rails 7.0 is end-of-life** (security support ended 2025-04-01) — the single reason this is an RC, not GA. Upgrade path documented in the release decision.
- 3 moderate `npm audit` findings (tailwindcss/postcss chain).
- P2/P3 findings F-4 through F-12 remain open (see `assessment/01-audit.md`).

## Evidence

- Audit: `assessment/01-audit.md` · Quality system: `assessment/02-quality-system.md` · Release decision: `assessment/03-release-decision.md`.
- Red→green history is in the commit log (`test(F-nnn)` → `fix(F-nnn)`).

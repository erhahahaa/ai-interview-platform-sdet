# 03 — Release Decision

BLOCKED for a full `v1.0.0`. The three code-level P1 defects are fixed, but one P1 remains open: **F-13 (Rails 7.0.8 is end-of-life — security support ended 2025-04-01)**. This version is tagged `v1.0.0-rc.1`; ship the release candidate only with F-13 formally accepted.

## What the gate checked

- `make net` (DoR gate fixtures 6/6, RSpec 3/3, Vitest 1/1, `tsc` + `vite build`).
- CI on `main`: `api-tests` and `web-tests` went red on the audited defects, then green after the fixes (red→green history in `git log`).
- `secret-scan` (gitleaks): clean — no secrets or forbidden names in full history.
- Findings ledger: F-1, F-2, F-3 fixed; F-13 open; F-4–F-12 open (P2/P3, out of scope for this pass).

## What it found

- **Fixed:** F-1 (cross-tenant JWT via login header), F-2 (cross-tenant portfolio export), F-3 (fit/gap field drift) — each with a regression test that was red before and green after.
- **Open P1:** F-13 — Rails 7.0 EOL (no upstream security patches). Also 3 moderate `npm audit` findings in the tailwindcss/postcss chain (fix requires a tailwindcss 4 major bump).

## Recommendation

**Ship `v1.0.0-rc.1` with accepted risk** (blocked for GA). The product logic and data integrity are sound for the audited paths. The only blocker to a GA `v1.0.0` is the EOL framework.

## Risk owner, mitigation, expiry

- **Risk:** unpatched Rails 7.0 (and legacy puma 5.x / rack 2.x).
- **Owner:** Rahmat Hidayatullah (case-study author).
- **Mitigation:** upgrade Rails to 8.x (and puma/rack to current) before any client go-live; keep the `dependency-audit` CI job on every change; do not expose the service publicly beyond the review window.
- **Expiry / re-check:** re-evaluate before the next release; a GA tag must not be cut while F-13 is open.

## What the gate does NOT cover

- Live Gemini/Sidekiq/WebSocket behavior under real audio (no live audio E2E yet).
- The P2/P3 findings (F-4, F-5, F-6, F-8, F-9, F-10, F-11, F-12) — consciously left open, listed in `01-audit.md`.
- Security beyond the OWASP categories probed statically (no dynamic fuzzing).

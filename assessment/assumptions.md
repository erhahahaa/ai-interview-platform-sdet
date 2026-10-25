# Assumptions

Each assumption: `ASSUMPTION-n` — statement, reason, and how it could be verified.

- `ASSUMPTION-1` — The platform is multi-tenant and tenant isolation is a correctness/security requirement.
  - Reason: `TenantScoped` concern, `Organization` model, per-tenant routes, tenant-resolver middleware.
  - Verify: external wiki/spec (referenced by root README; not in repo).

- `ASSUMPTION-2` — The fit/gap "Required" column is meant to show the vacancy's expected level.
  - Reason: web table header "Required" + API returns `expected_level` per comparison.
  - Verify: PRD/acceptance criteria (missing from repo — see input-gaps).

- `ASSUMPTION-3` — Missing inputs (no PRD/acceptance/design/tests/CI) default to P2 as findings; P1 when the feature persists or computes data.
  - Reason: brief's guidance "a feature with no PRD ... is a risk in its own right".
  - Verify: input-gaps matrix.

More assumptions are added as each wave runs.

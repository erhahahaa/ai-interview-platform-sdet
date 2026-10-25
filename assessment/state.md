# Quality-Net Case Study — State

## Now
- Wave: 0 (bootstrap / sanitize / baseline) + 1 (audit) read-only mapping, running in parallel
- Plan: `~/.opencode/plan/quality-net-case-study-plan.md`

## Repo
- Local: this repository root
- De-linked, single commit, branch `main`
- `prompts/` git-excluded — never commit

## Gates
- G0 (baseline proven): not passed
- G1 (audit proven): not passed
- G2 (net red): not started
- G3 (green earned): not started
- G4 (release call): not started
- G5 (submit ready): not started

## Open decisions
- Rename public repo (current name echoes the source repo) — HUMAN
- Confirm `gh` auth + PR flow (needed for Wave 2+ worktree/PR model)
- Confirm local services (Ruby / Node / Postgres / Redis) runnable for baseline + repros
- Sanitize forbidden names (source org/company) found in source before any public push

## Time used
- tbd

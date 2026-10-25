# Changelog

All notable changes to this project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/).

## [v1.0.0-rc.1] - 2026-10-26

### Added
- Definition-of-Ready PR gate (`tools/dor-check`) with six self-test fixtures.
- RSpec request spec net (tenant isolation, portfolio authorization, fit/gap contract).
- Vitest component test net for the fit/gap table.
- CI workflows: `api-tests`, `web-tests`, `dor-gate`, `secret-scan`.
- `make net` one-command net.
- `/assessment` audit, quality-system, and release-decision documents.

### Fixed
- Cross-tenant JWT minting via the `X-Tenant-Scheme` login header (F-001).
- Cross-tenant portfolio/portfolio-skill access by integer id (F-002).
- Fit/gap "Required" column field drift (`expected_level` vs `required_level`) and missing override flag (F-003).

### Security
- Scrubbed source-company / client identifiers from code, config, and manifests before publication.

### Known issues
- Rails 7.0 end-of-life (security support ended 2025-04-01) — see `assessment/03-release-decision.md`.

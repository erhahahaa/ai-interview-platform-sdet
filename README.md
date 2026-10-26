# The Product
Please refer to the product wiki for the initial product specification (not included in this repository).

# The Platform

A two-service application used for the Product Engineer case study. It is provided as a single repository so the whole thing clones, runs, and releases as one unit.

```
.
├── api/    # Backend service (Ruby on Rails, PostgreSQL, Redis/Sidekiq)
└── web/    # Frontend web app (React 18 + TypeScript, Vite, Tailwind)
```

The two services run together: the web app talks to the API over REST and WebSocket.

## Running it locally

Each service has its own setup guide. Run the API first, then the web app pointed at it.

1. **API** — see [`api/README.md`](api/README.md). Rails app; needs Ruby (see `api/.ruby-version`), PostgreSQL, and Redis. It serves on `http://localhost:3001`.
2. **Web** — see [`web/README.md`](web/README.md). Vite app; `npm install`, copy `.env.example` to `.env`, point `VITE_API_BASE_URL` at the API, then `npm run dev`. It serves on `http://localhost:5173`.

## Quality net

Run the full net (Definition-of-Ready gate fixtures + API specs + web tests + type-check/build) with:

```bash
make net
```

- **Workflow gate** — `tools/dor-check`: a change must link a spec/PRD, Given/When/Then acceptance criteria, and a design plan, and any `api/`/`web/` source change must also change a test. Docs-only and `/assessment` changes are exempt.
- **API specs** — `cd api && bundle exec rspec` (request + regression specs).
- **Web tests** — `cd web && npm test` (Vitest) and `npm run build` (`tsc` + Vite).
- **CI** — `.github/workflows/` runs `api-tests`, `web-tests`, `dor-gate`, `secret-scan`, and a `release` gate on tags.

To add a feature's inputs, copy `specs/_template/` to `specs/<feature>/` and fill `prd.md`, `acceptance.md`, and `design.md`. See `/assessment/` for the audit, quality-system, and release-decision documents.

## Notes for the case study

- This is the codebase you assess, harden, and release. Treat it as a version about to ship to a client.
- Work in the `/assessment` folder at the repo root for your written deliverables; code changes go in `api/` or `web/`.
- See the case-study brief you were given for what to produce and how it is evaluated.

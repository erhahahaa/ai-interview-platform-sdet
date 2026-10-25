# Repository Hygiene Review — evidence

Read-only review. No source was modified. Values are described generically (forbidden name / secret literals are intentionally NOT reproduced here).

## 1. Forbidden names (source company / product / original repo owner)

The source company handle (a short distinctive handle) and the original repo owner handle appear in code comments, config, k8s manifests, docs, and UI. Locations (file:line, category):

- `README.md:2` — forbidden-name: original repo owner (wiki URL)
- `api/README.md:22` — forbidden-name: company (shared-service reference)
- `api/app/auth/authorize_api_request.rb:5,11` — forbidden-name: company (comment)
- `api/app/controllers/application_controller.rb:9` — forbidden-name: company (comment)
- `api/app/controllers/concerns/exception_handler.rb:3,7` — forbidden-name: company (comment)
- `api/app/controllers/concerns/response.rb:3` — forbidden-name: company (comment)
- `api/app/lib/json_web_token.rb:3,4` — forbidden-name: company (comment)
- `api/app/lib/message.rb:3` — forbidden-name: company (comment)
- `api/app/middlewares/application_middleware.rb:3` — forbidden-name: company (comment)
- `api/app/middlewares/auth_token_middleware.rb:3` — forbidden-name: company (comment)
- `api/app/middlewares/tenant_resolver_middleware.rb:3,12` — forbidden-name: company (comment)
- `api/app/models/current.rb:3,40` — forbidden-name: company (comment)
- `api/app/models/organization.rb:3,4,11` — forbidden-name: company (comment)
- `api/config/application.yml.sample:4,7,10,23` — forbidden-name: company (comment / DB name value)
- `api/config/database.yml:1,19,23` — forbidden-name: company (comment / DB name values)
- `api/db/migrate/20240101000000_create_ai_interview_schema.rb:96` — forbidden-name: company (column comment)
- `api/db/seeds.rb:18,19,22,30` — forbidden-name: company (comment)
- `api/k8s/configmap.yaml:20` — forbidden-name: company (APP_BASE_URL domain)
- `api/k8s/deployment.yaml:62` — forbidden-name: company (image registry)
- `api/k8s/deploy-sidekiq.yaml:58` — forbidden-name: company (image registry)
- `api/k8s/ingress.yml:23` — forbidden-name: company (ingress host domain)
- `web/README.md:28` — forbidden-name: company (comment)
- `web/src/components/layout/AssessorLayout.tsx:35` — forbidden-name: company (UI brand label)
- `web/src/index.css:16,20` — forbidden-name: company (brand color comments)
- `web/vercel.json:14` — forbidden-name: company (CSP connect-src domain, http+ws)
- `prompts/[Brief - Case Study] Job Vacancy Detail · fullstack-sdet-candidate.md:47,54` — forbidden-name: company (stray doc)
- `prompts/One-Day Orchestrated Plan Quality-Net Case Study (AI Agent Prompt).md:9` — forbidden-name: company (stray doc)
- `assessment/state.md:8` — forbidden-name: company (untracked working doc)

Third-party / client infra name ("paragon") in k8s GKE nodepool + compute-class labels — verify whether this must also be scrubbed:
- `api/k8s/deployment.yaml:3,4,37,42` — potential forbidden-name: client infra
- `api/k8s/deploy-sidekiq.yaml:26,31` — potential forbidden-name: client infra
- `api/k8s/nodepool.yaml:1,18,22` — potential forbidden-name: client infra

## 2. Secrets / credentials

No real secret found. All committed values are placeholders or ENV indirection.

- `api/config/application.yml.sample:5` — potential-secret: SECRET_KEY_BASE (placeholder literal)
- `api/config/application.yml.sample:12` — potential-secret: DB_PASSWORD (empty placeholder)
- `api/config/application.yml.sample:15` — potential-secret: GEMINI_API_KEY (placeholder literal)
- `api/config/database.yml` — no hardcoded credentials (uses ENV vars only) — OK
- `api/k8s/configmap.yaml:7,8,21` — potential-secret: DB_HOST/DB_NAME/ALLOWED_ORIGINS (placeholder literals)
- `web/.env.example:8,11,12` — potential-secret: dev token / speed-test URLs (empty/placeholder)
- No committed `.env`, `.env.local`, `*.key`, `*.pem`, `master.key`, `credentials.yml.enc`, or `vertex_ai_credentials.json` — OK
- Note: `api/.gitignore` ignores `config/master.key` and `vertex_ai_credentials.json` (real files may exist locally but are untracked) — OK

## 3. Personal data

- No email addresses found anywhere in tracked files.
- `api/db/seeds.rb:32-37` — sample/test data only ("Test Corp", "test-corp" scheme, "localhost") — not real PII.
- `web/.env.example:16` — sample tenant name ("Demo Tenant") — not real PII.
- No real names, phone numbers, or addresses found.

## 4. Stray notes / tickets / release notes / requests

- `prompts/` — two internal case-study documents (24 KB and 45 KB): a job-vacancy brief and an "AI Agent Prompt" orchestration plan. Internal assessment artifacts, not product code; contain the forbidden name and internal case-study content. Remove before going public.
- `README.md:23-27` — "Notes for the case study" section (internal instructions).
- `api/k8s/ingress.yml:1-7` — operational "DO NOT apply directly" notes (benign, but internal infra detail).
- No TODO/FIXME markers, ticket IDs, or release notes found in source.

## 5. Committed build output / large binaries

- `api/log/` contains only `.keep`; no `*.log` files committed — OK
- No `web/dist/`, `node_modules/`, `tmp/`, or `storage/` committed — OK
- No file over 1 MB in the working tree (largest is ~36 KB source file) — OK
- `.gitignore` (root) correctly excludes node_modules, dist, logs, tmp, env files — OK

## 6. Vulnerable / outdated dependencies

- `api/Gemfile:9` (`~> 7.0.8`) + `api/Gemfile.lock:245` → Rails **7.0.10** — Rails 7.0 series is **EOL** (no longer receiving security patches).
- `api/Gemfile.lock:235` — puma 5.6.9 (5.x is legacy; 6.x is current).
- `api/Gemfile.lock:238` — rack 2.2.22 (2.x legacy; 3.x current).
- `api/.ruby-version` → Ruby 3.3.2.
- `web/package.json:33-34` — React 18.3.1 (maintenance mode; 19.x current).
- `web/package.json:49` — vite ^6.4.2 (a major behind current).
- **Missing lockfile:** no `web/package-lock.json` (or yarn/pnpm lock) committed → non-reproducible installs + dependency supply-chain risk. `api/Gemfile.lock` IS present.

## 7. License

- **No** LICENSE file at repo root (or in `api/` / `web/`).

---

## Prioritized scrub checklist (risk-ordered, for the sanitize step)

1. **Forbidden name — highest blast radius:** purge/rename the source-company handle across all code comments, config, DB names, k8s image registry + ingress host + configmap APP_BASE_URL, `web/vercel.json` CSP connect-src, both READMEs + wiki link, and the UI brand label/color comments in `AssessorLayout.tsx` / `index.css`. Re-point image registry + domains to placeholder values.
2. **Remove stray internal docs:** delete `prompts/` (case-study brief + orchestration prompt) and the root README "Notes for the case study" section.
3. **Verify client infra name** ("paragon") in k8s nodepool/compute-class labels — scrub if it identifies the client.
4. **Confirm no real secrets** were ever committed into history (git log/`git grep` on history for keys/tokens/ENV), not just the current tree; rotate any that were.
5. **Address EOL Rails 7.0** (upgrade path or document accepted risk) and the missing `web` lockfile (generate + commit `package-lock.json`).
6. **Add a LICENSE file** (or remove nothing and accept "all rights reserved", explicitly stated).
7. **Low risk:** de-brand the sample seeds / `.env.example` tenant name if brand-neutral output is desired.

Blockers: none for review; the forbidden-name leakage (item 1) and missing license (item 6) are the mandatory pre-public fixes.

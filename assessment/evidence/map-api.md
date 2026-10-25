# API Map — Rails half of the monorepo (`/api`)

Source root: `api/`. Rails 7.0 API-only app, module `AiInterview`, UUID-primary-key generator configured but schema uses `bigint` PKs. The app shares a PostgreSQL database with `parent-api`; its tables live in the `ai_interview` schema and tenant resolution reads the `public.organizations` table.

---

## 1. Routes — `api/config/routes.rb`

| Method | Path | Controller#action | Line |
|---|---|---|---|
| GET | `/health` | inline `proc` → `{ status: 'ok' }`, 200 | routes.rb:4 |
| POST | `/api/v1/auth/login` | `authentication#authenticate` | routes.rb:9 |
| GET | `/api/v1/health` | inline `proc` → `{ status: 'ok' }`, 200 | routes.rb:11 |
| POST | `/api/v1/speed_test` | inline `proc` — reads `CONTENT_LENGTH`, returns `{ received_bytes: bytes }`, 200 | routes.rb:14-17 |
| * | `/api/v1/assessments` (resources) | `assessments#index/show/create/update/destroy` | routes.rb:20 |
| GET | `/api/v1/assessments/:assessment_id/sessions` | `sessions#index` | routes.rb:20-21 |
| POST | `/api/v1/assessments/:assessment_id/sessions` | `sessions#create` | routes.rb:20-21 |
| GET | `/api/v1/sessions/:id` | `sessions#show` | routes.rb:25 |
| POST | `/api/v1/sessions/:id/end_session` | `sessions#end_session` | routes.rb:27 |
| GET | `/api/v1/sessions/:id/coverage` | `sessions#coverage` | routes.rb:28 |
| GET | `/api/v1/sessions/:id/transcript` | `sessions#transcript` | routes.rb:29 |
| GET | `/api/v1/sessions/:id/portfolio` | `portfolios#show` | routes.rb:30 |
| POST | `/api/v1/sessions/:id/portfolio/regenerate` | `portfolios#regenerate` | routes.rb:31 |
| GET | `/api/v1/sessions/:token/candidate` | `sessions#candidate_info` | routes.rb:36 |
| POST | `/api/v1/sessions/:token/audio_complete` | `sessions#audio_complete` | routes.rb:37 |
| POST | `/api/v1/portfolio_skills/:id/override` | `portfolio_skills#override` | routes.rb:40-44 |
| GET | `/api/v1/skill_taxonomies` | `skill_taxonomies#index` | routes.rb:47 |
| GET | `/api/v1/skill_taxonomies/:skill_id` | `skill_taxonomies#show` (`as: :skill_taxonomy`) | routes.rb:48 |
| * | `/api/v1/vacancies` (resources) | `vacancies#index/show/create/update/destroy` | routes.rb:51 |
| POST | `/api/v1/portfolios/:id/fitgap` | `portfolios#fitgap` | routes.rb:56 |
| POST | `/api/v1/portfolios/:id/regenerate_fitgap` | `portfolios#regenerate_fitgap` | routes.rb:57 |
| GET | `/api/v1/portfolios/:id/fitgap/:vacancy_id` | `portfolios#show_fitgap` (`as: :fitgap_vacancy`) | routes.rb:58 |
| GET | `/api/v1/portfolios/:id/export` | `portfolios#export` | routes.rb:59 |

Special auth/tenant behavior in routes:
- The two candidate-facing routes (`sessions/:token/candidate`, `sessions/:token/audio_complete`) are explicitly "no JWT — invite token only" (routes.rb:35). They are declared *after* the `resources :sessions, only: [:show]` block (routes.rb:25 vs 36-37) but do not collide because `show` only matches a single `:id` segment.
- `speed_test` "accepts any payload, discards it, returns bytes received" (routes.rb:13-14).
- `health` is duplicated at root and under the API namespace (routes.rb:4, 11). K8s probes hit `/health` (see §7).
- There is **no** `member :end` route — session termination over REST is `end_session` (routes.rb:27) plus the candidate `audio_complete` (routes.rb:37).

---

## 2. Request/response shapes — `api/app/controllers/api/v1/*.rb`

### Common base (`api_controller.rb`)
- `ApiController < ApplicationController` is empty (api_controller.rb:5-6). All V1 controllers inherit auth/tenant behavior from `ApplicationController` (§5).

### `authentication_controller.rb`
- No strong params; reads raw `params[:email]`, `params[:password]` (authentication_controller.rb:10-12).
- Auth flow: find user by downcased email → `user.authenticate(password)` → **must** be `role == 'admin'` → resolve scheme → encode JWT (authentication_controller.rb:10-19).
- Returns 200 `{ token:, user: { id:, email:, role: } }` (authentication_controller.rb:19).
- On bad credentials / non-admin: `json_error('Invalid email or password', :unauthorized)` → 401 (authentication_controller.rb:12, 14).
- `resolve_scheme` priority: `X-Tenant-Scheme` header → `SELECT scheme FROM organizations LIMIT 1` → `'test-corp'` (authentication_controller.rb:24-29).
- `skip_before_action :require_tenant!` (authentication_controller.rb:6).

### `assessments_controller.rb`
- Auth: `authorize_auth_token! :assessor` (assessments_controller.rb:6).
- Strong params `assessment_params`: `name, time_limit_min, language` + nested `assessment_skills_attributes: [id, skill_id, skill_label, is_custom, scope_include, scope_exclude, l1..l5_anchor, expected_level, display_order, _destroy]` (assessments_controller.rb:64-76).
- `index`: paginated (`paginate` from ApplicationController), returns `{ assessments: [...], meta: { current_page, total_pages, total_count, per_page } }` (assessments_controller.rb:12-19, 120-127). `assessment_json` includes `latest_session` (max by `created_at`) with `id/status/end_reason` (assessments_controller.rb:78-96).
- `show`: `{ assessment: assessment_with_skills_json }` — merges base fields with `skills: [...]` ordered by `display_order` (assessments_controller.rb:24, 98-118).
- `create`: sets `created_by = current_user.id`, saves, enqueues `SystemPromptGeneratorWorker`, returns 201 `{ assessment:, system_prompt_generated: true }` (assessments_controller.rb:28-38). Failure → 422 `json_error` with first full error (line 36).
- `update`: same worker enqueue, returns 200 `{ assessment: ..., system_prompt_generated: true }` (assessments_controller.rb:41-48).
- `destroy`: `{ message: "Assessment deleted" }` (assessments_controller.rb:52-53).
- `set_assessment` rescues `RecordNotFound` → 404 (assessments_controller.rb:58-62).

### `sessions_controller.rb`
- Auth: `authorize_auth_token! :assessor, except: %i[candidate_info audio_complete]`; `skip_before_action :require_tenant!, only: %i[candidate_info audio_complete]` (sessions_controller.rb:6-7).
- `index`: `{ sessions: [session_json...] }` (no pagination) (sessions_controller.rb:12-16).
- `create`: reads `params.dig(:session, :candidate_id)` and `:candidate_name`, sets `tenant_id: current_tenant_id`; returns 201 `{ session: session_json, invite_url: }` (sessions_controller.rb:22-38).
- `show`: `session_json` merged with `assessment: { id, name, time_limit_min }` (sessions_controller.rb:47-57).
- `end_session`: rejects if already ended (422); validates `reason` against `Session::END_REASONS` (422); delegates to `Sessions::EndHandler`; returns `{ session: session_json(@session.reload) }` (sessions_controller.rb:60-78).
- `coverage`: `{ skills: [coverage_map_json...], discovered: [...], updated_at: max(updated_at) }` (sessions_controller.rb:81-90).
- `transcript`: `params[:from_turn]` filters `turn_number >=`; returns `{ turns: [{id, turn_number, speaker, text, audio_start_ms, audio_end_ms, created_at}], total: }` (sessions_controller.rb:93-113).
- `audio_complete` (no JWT): `Session.unscoped.find_by(invite_token:)`; idempotent if already ended; calls `EndHandler(reason: 'all_covered')`; returns `{ ended: true, message: }` (sessions_controller.rb:118-129). Explicitly skips a coverage re-check (comment lines 124-126).
- `candidate_info` (no JWT): `Session.unscoped` then `Assessment.unscoped.where(tenant_id:).find_by(id:)`; returns `{ session_id, role_title: assessment.name, time_limit_min, session_status }` (sessions_controller.rb:132-154).
- `session_json` keys (sessions_controller.rb:164-180): `id, assessment_id, tenant_id, candidate_id, candidate_name, invite_token, invite_url, status, end_reason, started_at, ended_at, duration_seconds, created_at`.

### `portfolios_controller.rb`
- Auth: `authorize_auth_token! :assessor` (portfolios_controller.rb:6).
- `show`: if portfolio nil or `generating?` → 202 `{ status: "generating" }`; if `failed?` → `{ portfolio:, error: generation_error }`; else `{ portfolio: portfolio_json }` (portfolios_controller.rb:12-25).
- `regenerate`: 404 if no portfolio; 422 unless `failed?`; sets `generation_status: "pending"`, clears error, enqueues worker; returns `{ message:, portfolio: }` (portfolios_controller.rb:28-46).
- `export`: `format` param must be `pdf` or `json` (422 otherwise); requires `portfolio.complete?` (422 otherwise); PDF path calls `Exports::PdfGenerator` and `send_data` as attachment; JSON path `send_data build_export_json.to_json` (portfolios_controller.rb:49-78).
- `fitgap` / `regenerate_fitgap`: require `vacancy_id` (422), find vacancy (404), require `complete?` (422); regenerate destroys existing report first; both enqueue `FitGapGeneratorWorker` and return 202 `{ status: "generating", message: }`. `fitgap` returns cached report via `{ report: fit_gap_json }` if present (portfolios_controller.rb:81-126).
- `show_fitgap`: `{ report: fit_gap_json }` or 404 (portfolios_controller.rb:129-140).
- JSON shapes: `portfolio_json` (162-173), `portfolio_skill_json` uses `evidence_quotes` (175-186), `override_json` (188-198), `fit_gap_json` (200-210), `build_export_json` includes `exported_at` + optional `fit_gap_report` (212-224).

### `portfolio_skills_controller.rb`
- Auth: `authorize_auth_token! :assessor` (portfolio_skills_controller.rb:6).
- Strong params `override_params`: `require(:override).permit(:override_level, :assessor_notes)` (portfolio_skills_controller.rb:57-59).
- `override`: upserts `assessor_override` (creates with `ai_level` copied from `portfolio_skill.ai_level`; updates with `overridden_by`/`overridden_at`); on change calls `regenerate_stale_fitgap_reports` (destroys all that portfolio's reports and re-enqueues workers); returns 200 `{ override: }` on update / 201 on create (portfolio_skills_controller.rb:11-37).
- Lookup via `PortfolioSkill.joins(:portfolio).find(params[:id])` (portfolio_skills_controller.rb:51-52) — NOT tenant-scoped (see §5).

### `skill_taxonomies_controller.rb`
- Auth: `authorize_auth_token! :assessor` (skill_taxonomies_controller.rb:6).
- `index`: optional `params[:category]` filter; `{ skill_taxonomies: [skill_json...] }` (skill_taxonomies_controller.rb:9-14).
- `show`: `find_by!(skill_id:)`; `{ skill: skill_json }`; 404 rescue (skill_taxonomies_controller.rb:17-22).
- `skill_json` keys: `skill_id, skill_label, category, scope_include, scope_exclude, l1..l5_anchor` (skill_taxonomies_controller.rb:26-39).

### `vacancies_controller.rb`
- Auth: `authorize_auth_token! :assessor` (vacancies_controller.rb:6).
- Strong params `vacancy_params`: `role_title, culture_dimensions, competency_expectations` + nested `vacancy_skills_attributes: [id, skill_id, skill_label, expected_level, _destroy]` (vacancies_controller.rb:60-69).
- `index`: paginated `{ vacancies: [...], meta: }` (vacancies_controller.rb:11-18).
- `create` sets `created_by = current_user.id` → 201 `{ vacancy: vacancy_with_skills_json }` (vacancies_controller.rb:26-35).
- `show`/`update` return `{ vacancy: vacancy_with_skills_json }` (vacancies_controller.rb:21-44).
- `destroy`: `{ message: "Vacancy deleted" }` (vacancies_controller.rb:47-50).
- `vacancy_with_skills_json` preloads taxonomy anchors via `SkillTaxonomy.where(skill_id: ...).index_by(&:skill_id)` to avoid N+1, merging `l1..l5_anchor` into each skill (vacancies_controller.rb:83-107).

---

## 3. Validation & persistence — `api/db/schema.rb` + `api/app/models/*.rb`

### Postgres extensions & enums (schema.rb:14-26)
- Extensions: `pgcrypto`, `plpgsql` (schema.rb:15-16).
- Enums: `confidence_level` (high/medium/low), `coverage_state` (not_yet/initiated/partial/covered), `end_reason` (manual_candidate/manual_assessor/all_covered/time_ceiling/error), `fit_result` (match/gap/exceed/not_assessed), `generation_status` (pending/generating/complete/failed), `session_status` (pending/active/ended/failed), `speaker_type` (ai/candidate) — schema.rb:20-26.
- Note: `fit_result` enum is **defined but unused** — no column references it (schema.rb:23; only match is the enum definition and migration create_ai_interview_schema.rb:44).

### Tables (constraints / indexes / FKs)

| Table | Notable constraints / columns | Indexes | FK |
|---|---|---|---|
| `assessment_skills` | `expected_level` check `>=1 AND <=5`; non-null `l1..l5_anchor`, `skill_label`; `display_order` default 0 | `assessment_id` | `assessments` (schema.rb:28-44, 208) |
| `assessments` | `tenant_id`/`created_by`/`name`/`time_limit_min` non-null; `time_limit_min` check `= ANY(ARRAY[10,30,45,60,90])`; `language` default 'en' | `tenant_id` | — (schema.rb:46-57) |
| `assessor_overrides` | `ai_level`,`override_level` checks `>=1 AND <=5`; unique `portfolio_skill_id` | `portfolio_skill_id` unique | `portfolio_skills` (schema.rb:59-69, 209) |
| `coverage_maps` | `state` enum default `not_yet`; `probe_count` default 0; unique `(session_id, skill_label)` | `session_id`, `(session_id, skill_label)` unique | `sessions` (schema.rb:71-83, 210) |
| `fit_gap_reports` | `skill_comparisons` jsonb non-null; unique `(portfolio_id, vacancy_id)` | `portfolio_id`, `vacancy_id`, composite unique | `portfolios`, `vacancies` (schema.rb:85-95, 211-212) |
| `organizations` | `name/scheme/identifier/host` non-null; `alias_hosts` varchar array; `config` jsonb | `host`, `scheme` unique | — (schema.rb:97-108) |
| `portfolio_skills` | `ai_level` check `>=1 AND <=5`; `ai_confidence` enum non-null; `evidence` jsonb default []; `competency_summary` non-null | `portfolio_id` | `portfolios` (schema.rb:110-121, 213) |
| `portfolios` | `generation_status` enum default `pending`; unique `session_id` | `session_id` unique, `candidate_id` | `sessions` (schema.rb:123-131, 214) |
| `sessions` | `tenant_id`/`assessment_id`/`invite_token`(limit 64)/`status` non-null; `status` enum default `pending`; `end_reason` enum nullable | `assessment_id`, `candidate_id`, `invite_token` unique, `(tenant_id, status)` | `assessments` (schema.rb:133-150, 215) |
| `skill_taxonomies` | `skill_id`(50)/`skill_label`(255)/`category`(50)/`l1..l5_anchor` non-null | `category`, `skill_id` unique | — (schema.rb:152-165) |
| `transcript_turns` | `turn_number`/`speaker`/`text` non-null; `speaker` enum | `(session_id, turn_number)` unique, `session_id` | `sessions` (schema.rb:167-177, 216) |
| `users` | `email`/`password_digest` non-null; `role` default 'user' limit 20 | `email` unique | — (schema.rb:179-186) |
| `vacancies` | `tenant_id`/`created_by`/`role_title` non-null | `tenant_id` | — (schema.rb:188-197) |
| `vacancy_skills` | `expected_level` check `>=1 AND <=5`, non-null | `vacancy_id` | `vacancies` (schema.rb:199-206, 217) |

FK list (schema.rb:208-217): assessment_skills→assessments, assessor_overrides→portfolio_skills, coverage_maps→sessions, fit_gap_reports→{portfolios, vacancies}, portfolio_skills→portfolios, portfolios→sessions, sessions→assessments, transcript_turns→sessions, vacancy_skills→vacancies.

**No FK constraints exist** for the soft/tenant columns: `assessments.tenant_id`, `sessions.tenant_id`, `vacancies.tenant_id`, `*.created_by`, `assessor_overrides.overridden_by`, `portfolios.candidate_id`, `sessions.candidate_id`. The migration comment states `tenant_id references public.organizations.id` (create_ai_interview_schema.rb:51) but no FK is emitted. ASSUMPTION: cross-table integrity for these is application-level only.

### Model validations & callbacks (`app/models/*.rb`)
- `Assessment` (assessment.rb): includes `TenantScoped`; `has_many :assessment_skills dependent: :destroy`, `has_many :sessions dependent: :restrict_with_error`; `SUPPORTED_LANGUAGES = {en,id}`; validates `name` presence, `time_limit_min` inclusion `[10,30,45,60,90]`, `language` inclusion allow_nil; `accepts_nested_attributes_for :assessment_skills, allow_destroy: true, reject_if: :all_blank` (assessment.rb:4-18).
- `AssessmentSkill` (assessment_skill.rb): validates `skill_label`, `l1..l5_anchor`, `display_order` presence; `expected_level` integer `in: 1..5` allow_nil (assessment_skill.rb:6-11).
- `AssessorOverride` (assessor_override.rb): `ai_level`/`override_level` integer `in: 1..5`; `overridden_by` presence (assessor_override.rb:6-8).
- `CoverageMap` (coverage_map.rb): `STATES = %w[not_yet initiated partial covered]`; validates `skill_label` presence, `state` inclusion, `probe_count` `>= 0`; scopes `configured` (`is_discovered: false`), `discovered` (`is_discovered: true`) (coverage_map.rb:4-13).
- `FitGapReport` (fit_gap_report.rb): `FIT_RESULTS` constant; `validates :skill_comparisons presence` (fit_gap_report.rb:4-9).
- `Organization` (organization.rb): `table_name = 'organizations'` (public schema, read-only); `self.identify` matches `identifier/name/scheme/host` or `alias_hosts`, falls back to `default_organization` (id 0) (organization.rb:9-27).
- `Portfolio` (portfolio.rb): `GENERATION_STATUSES`; `has_many :portfolio_skills dependent: :destroy`, `has_many :assessor_overrides through: :portfolio_skills`; validates `generation_status` inclusion; scopes `complete/failed/generating`; predicate helpers (portfolio.rb:4-18).
- `PortfolioSkill` (portfolio_skill.rb): `CONFIDENCE_LEVELS`; `has_one :assessor_override dependent: :destroy`; validates `skill_label` presence, `ai_level` `1..5`, `ai_confidence` inclusion, `competency_summary` presence; `evidence_quotes = Array(evidence)` (portfolio_skill.rb:4-17).
- `Session` (session.rb): includes `TenantScoped`; `STATUSES`, `END_REASONS`; `has_many :transcript_turns / :coverage_maps dependent: :destroy`, `has_one :portfolio dependent: :destroy`; validates `invite_token` presence+uniqueness, `status` inclusion, `end_reason` inclusion allow_nil; `before_validation :generate_invite_token on: :create` (session.rb:6-18); `generate_invite_token = SecureRandom.hex(32)` (session.rb:35-37); `invite_url = "#{APP_BASE_URL}/interview/#{invite_token}"` (session.rb:28-31).
- `SkillTaxonomy` (skill_taxonomy.rb): validates `skill_id`(presence/uniqueness/max 50), `skill_label`(max 255), `category`(max 50), `l1..l5_anchor` presence; `CATEGORIES = %w[engineering soft_skills product_process]` (skill_taxonomy.rb:4-13).
- `TranscriptTurn` (transcript_turn.rb): `SPEAKERS = %w[ai candidate]`; validates `turn_number` integer `> 0`, `speaker` inclusion, `text` presence; `scope :ordered -> order(:turn_number)` (transcript_turn.rb:4-13).
- `User` (user.rb): `has_secure_password`; `ROLES = %w[admin user]`; validates `email` presence/uniqueness(case-insensitive)/URI email format, `role` inclusion; `before_save :downcase_email` (user.rb:4-19).
- `Vacancy` (vacancy.rb): includes `TenantScoped`; `has_many :vacancy_skills dependent: :destroy`, `has_many :fit_gap_reports dependent: :destroy`; validates `role_title` presence; nested attrs for `vacancy_skills` (vacancy.rb:4-14).
- `VacancySkill` (vacancy_skill.rb): validates `skill_label` presence, `expected_level` `1..5` (vacancy_skill.rb:6-7).

---

## 4. Computed fields (values derived, not stored)

- **Session `duration_seconds`** — computed in `EndHandler`: `duration = @session.started_at ? (Time.current - @session.started_at).to_i : nil` (end_handler.rb:27), persisted on the `sessions` record (end_handler.rb:29-34).
- **Fit/gap `delta` + `result`** — `FitGap::Engine#build_skill_comparisons`: `delta = candidate_level - expected_level`; `result = delta == 0 ? 'match' : (delta > 0 ? 'exceed' : 'gap')`; no portfolio skill → `delta=nil, result='not_assessed'` (engine.rb:47-56). `candidate_level`/`effective_level` = override level if present else `ai_level` (engine.rb:81).
- **Coverage state transitions** — `Coverage::StateEngine`: forward-only transition map (state_engine.rb:9-14); `valid_transition?` blocks `partial`/`covered` unless `probe_count >= 2` (state_engine.rb:17-26); `resolve_state` walks forward one step at a time applying the probe gate (state_engine.rb:33-52).
- **Coverage probe-count clamp** — `Coverage::Analyzer#parse_skill_updates`: `safe_probe = [[raw_probe_count, map.probe_count + 1].min, map.probe_count].max` (caps increment at +1 per run, analyzer.rb:138), then `StateEngine.resolve_state(... probe_count: safe_probe)` (analyzer.rb:141-145). Frozen skills skipped: `next if map.state == 'covered'` (analyzer.rb:127).
- **Stale-partial auto-advance** — worker promotes `state='partial' AND probe_count >= 4` → `covered` outside the analyzer window (coverage_analyzer_worker.rb:91-101).
- **Coverage pacing / time remaining** — `Coverage::MapInjector`:
  - `time_remaining_minutes`: `remaining = limit - elapsed`, then `[(remaining / 60.0).ceil, 0].max` (rounds *up* and clamps to ≥ 0, map_injector.rb:92-100).
  - `skills_remaining`: count of non-`covered` configured maps (map_injector.rb:71-73).
  - `avg_minutes_per_remaining_skill`: `(remaining_min.to_f / skills_left).round(1)` (map_injector.rb:75-80).
  - `pacing_bucket`: `>=5.0 'ahead'`, `>=3.0 'on_track'`, `>=1.5 'behind'`, else `'critical'` (map_injector.rb:82-90).
  - `priority_next`: min by `%w[not_yet initiated partial covered]` index among uncovered (map_injector.rb:104-114).
  - `coverage_fingerprint`: `Digest::MD5.hexdigest` of `id:state:probe_count` (map_injector.rb:15-18).
  - `all_covered?`: all configured `covered` AND no discovered still `initiated` (map_injector.rb:48-58).
- **PDF level/confidence/result labels** — `Exports::PdfGenerator`: `LEVEL_LABELS {1..5 => 'L1'..'L5'}` (pdf_generator.rb:10), `CONFIDENCE_LABELS` (11), `RESULT_LABELS` (12-17); `effective_level = override ? override.override_level : skill.ai_level` (pdf_generator.rb:79); `format_duration` `mins = seconds / 60; secs = seconds % 60` (pdf_generator.rb:166-171).
- **Portfolio `ai_level` clamp** — `Portfolios::Generator#save_skills`: `skill_data['level'].to_i.clamp(1, 5)` for both configured and discovered skills (generator.rb:161, 173); `evidence` truncated to `first(3)` (generator.rb:163, 175).
- **Session `invite_token`** — generated (not client-supplied): `SecureRandom.hex(32)` (session.rb:36).
- **`invite_url`** — derived from `ENV['APP_BASE_URL']` + token (session.rb:28-31).
- **JWT `exp`** — `JsonWebToken.encode` defaults `exp` to now + `TOKEN_EXPIRATION_TIME` or 3 days (json_web_token.rb:6-12).
- **System prompt** — `SystemPromptCompiler` is "pure string interpolation — no LLM call" (system_prompt_compiler.rb:5-6); it is computed/regenerated by `SystemPromptGeneratorWorker` and cached into `assessments.system_prompt`.
- **`assessment_json` `latest_session`** — derived in controller via `sessions.max_by(&:created_at)` (assessments_controller.rb:79).

Rounding/clamping summary: `.round(1)` (map_injector.rb:79), `.ceil` + `.max` (map_injector.rb:99), `.clamp(1,5)` (generator.rb:161,173), `[min,max].min/.max` probe clamp (analyzer.rb:138), `.to_i` truncation (end_handler.rb:27).

---

## 5. Auth & tenant isolation

### Resolution order (request lifecycle)
1. `TenantResolverMiddleware` (tenant_resolver_middleware.rb:16-29) resolves scheme by priority: **JWT Bearer `scheme` claim → `X-Tenant-Scheme` header → `Referer` host** (tenant_resolver_middleware.rb:33-40). `scheme_from_jwt` decodes **without verification** via `JsonWebToken.decode_without_verification` (tenant_resolver_middleware.rb:42-51); `scheme_from_referer` parses host (53-61).
2. `find_organization(scheme)` → `Organization.identify(scheme)`; on match sets `Current.organization` and `Current.tenant_id = organization.id` (tenant_resolver_middleware.rb:21-26, 63-69). `Organization.identify` matches `identifier/name/scheme/host` or `alias_hosts`, else falls back to `default_organization` (id 0) (organization.rb:13-27). If no scheme/organization, request continues **with no tenant set** (tenant_resolver_middleware.rb:14).
3. `ApplicationController#require_tenant!` (before_action, application_controller.rb:7, 24-28) raises `ExceptionHandler::TenantNotFound` (→ 403) unless `Current.organization` present and `RequestStore.store.key?(:organization)` (application_controller.rb:30-34). Controllers can skip it (`authentication_controller.rb:6`; `sessions_controller.rb:7`).
4. `Current` is a RequestStore-backed per-request global with accessors `user`, `organization`, `tenant_id` (current.rb:38-44). `Current.clear` wipes RequestStore (current.rb:28-31).

### Token auth
- `ApplicationController.authorize_auth_token!(*roles)` adds a `before_action` that calls `authenticate_with_roles!` (application_controller.rb:14-16, 54-58), which invokes `AuthorizeApiRequest.new(request.headers, roles).call` and sets `Current.user = result[:user]`.
- `AuthorizeApiRequest` (authorize_api_request.rb): Bearer-only, no DB lookup — trusts JWT claims (authorize_api_request.rb:8, 19-27). Builds an `OpenStruct {id, role, scheme}` (authorize_api_request.rb:33-39). `check_role!` allows `:any`, maps `:assessor` to `ASSESSOR_ROLES = %w[admin assessor]` (authorize_api_request.rb:12, 41-57). Missing header → `MissingToken` (65-69); decode error → `InvalidToken` (59-63).
- `JsonWebToken` (json_web_token.rb): HS256, secret from `ENV['SECRET_KEY_BASE']` (31-33); `decode` verifies signature (17-22); `decode_without_verification` (24-29). Comment: "tokens issued by the parent platform are accepted here" (json_web_token.rb:3-4).
- `AuthTokenMiddleware` (auth_token_middleware.rb) exists and wraps `AuthorizeApiRequest`, but is **NOT inserted into the middleware stack** — `config/application.rb` only mounts `Rack::Attack` and `TenantResolverMiddleware` (application.rb:49-50) and comments that `AuthTokenMiddleware` is not global (application.rb:46-47). Controllers use the `authorize_auth_token!` before_action path instead. UNVERIFIED: `AuthTokenMiddleware` appears effectively dead code.

### Tenant scoping (`app/models/concerns/tenant_scoped.rb`)
- `default_scope` filters `where(tenant_id: Current.tenant_id)` **only when** `RequestStore.store.key?(:tenant_id)`; otherwise `all` (tenant_scoped.rb:18-24).
- `before_validation :assign_tenant_id on: :create` (tenant_scoped.rb:27) sets `self.tenant_id ||= Current.tenant_id` (tenant_scoped.rb:34-36); `validates :tenant_id presence` (tenant_scoped.rb:29).
- Models including `TenantScoped`: **`Assessment` (assessment.rb:4), `Session` (session.rb:4), `Vacancy` (vacancy.rb:4)** — only these three.

### Where tenant scoping does NOT apply
- Models **without** `tenant_id` and without `TenantScoped`: `Organization` (public schema), `User`, `SkillTaxonomy`, `Portfolio`, `PortfolioSkill`, `AssessorOverride`, `CoverageMap`, `TranscriptTurn`, `FitGapReport`, `AssessmentSkill`, `VacancySkill`. These are isolated indirectly via their tenant-scoped parent associations, but **direct lookups are not tenant-filtered**:
  - `PortfoliosController#set_portfolio` → `Portfolio.find(params[:id])` (portfolios_controller.rb:156) and `set_session` → `Session.find(params[:id])` (portfolios_controller.rb:145) — `Session` is tenant-scoped, `Portfolio` is not.
  - `PortfolioSkillsController` → `PortfolioSkill.joins(:portfolio).find(params[:id])` (portfolio_skills_controller.rb:51).
  - Candidate token routes use `.unscoped` deliberately: `Session.unscoped.find_by(invite_token:)` (sessions_controller.rb:119, 133), `Assessment.unscoped.where(tenant_id:)` (sessions_controller.rb:140-142).
  - `FitGapGeneratorWorker` uses `Vacancy.unscoped.find` (fit_gap_generator_worker.rb:10) because Sidekiq has no per-request tenant.

---

## 6. Error handling — `exception_handler.rb` + `response.rb`

### `ExceptionHandler` (exception_handler.rb)
Error classes (exception_handler.rb:8-13): `AuthenticationError`, `Unauthorized`, `MissingToken`, `InvalidToken`, `NotFound`, `TenantNotFound`.

Rescue mappings (exception_handler.rb:15-36):
- `ActiveRecord::RecordNotFound` → `{ errors: [{ status: 404, message: e.message }] }`, 404 (line 20-22).
- `ExceptionHandler::Unauthorized` → `{ errors: [{ status: 403, message }] }`, 403 (24-26).
- `MissingToken` / `InvalidToken` → `{ errors: [{ status: 401, message }] }`, 401 (28-31).
- `TenantNotFound` → `{ errors: [{ status: 403, message }] }`, 403 (33-35).
- `StandardError` → `render_exception` (16-18).

`render_exception` (exception_handler.rb:40-51): status from `exception_status`; message is `human_message` in production else raw `e.message`; `backtrace` only in development (first 10). `exception_status` (53-64): `RecordInvalid`/`StrictValidationFailed`/`ParameterMissing` → 422; `Unauthorized` → 403; `MissingToken`/`InvalidToken` → 401; `RecordNotFound` → 404; else 500. `human_message` (66-71): first full error for `RecordInvalid`, else `"An unexpected error occurred."`.

### `Response` helper (response.rb)
- `json_response(object, status=:ok)` → `render json:` (response.rb:7-9).
- `json_error(message, status=:unprocessable_entity, details:)` → `{ errors: [{ status: Rack::Utils.status_code(status), message: }] }`, plus `errors[0][:detail]` if `details` (response.rb:11-15).
- `paginated_response(collection, serializer:, **extra)` → `{ data:, meta: { current_page, total_pages, total_count, per_page } }.merge(extra)` (response.rb:17-27). NOTE: controllers mostly build `meta` manually via `pagination_meta` and pass to `json_response` rather than using this helper.

### Middleware-level error shape
- `ApplicationMiddleware#error` → `{ errors: [{ status:, message: }] }` with JSON content-type (application_middleware.rb:15-25).
- `Rack::Attack` throttled responder → 429 `{ error: 'Too many requests. Please try again later.' }` (rack_attack.rb:20-26).

---

## 7. Config & infra

### Initializers (`config/initializers/`)
- `cors.rb`: `Rack::Cors` inserted before index 0; origins from `ENV['ALLOWED_ORIGINS'].split(',')`; `resource '*'` all methods `get post put patch delete options head`; `expose: ['Authorization']`; `credentials: false` (cors.rb:3-11).
- `rack_attack.rb`: Redis cache store (`REDIS_URL`, db 1) (rack_attack.rb:5-7); throttle `auth/login` 5/min/IP (9-12); candidate endpoints (`/api/v1/sessions/:token/(candidate|audio_complete)`) 30/min/IP (14-17); JSON 429 responder (19-26).
- `sidekiq.rb`: server + client Redis `REDIS_URL` (sidekiq.rb:5-6, 20-22); writes `tmp/sidekiq_status` = `"READY: 1"` on startup and deletes on shutdown (sidekiq.rb:8-17).
- `gemini.rb`: production boot validation that `GEMINI_API_KEY`, `GEMINI_LIVE_MODEL`, `GEMINI_FLASH_MODEL`, `GEMINI_PRO_MODEL` are present (gemini.rb:5-13).
- `eventmachine.rb`: starts EventMachine in a background thread if not already running; blocks until ready (eventmachine.rb:5-17).
- `request_store.rb`: forces `RequestStore::Middleware` autoload (request_store.rb:4).
- `websocket.rb`: mounts `AudioWebSocketMiddleware` and `CoverageWebSocketMiddleware` **before** `TenantResolverMiddleware` so WS upgrades bypass Rails routing (websocket.rb:11-15). Paths: `/ws/sessions/:id/audio` and `/ws/sessions/:id/coverage` (websocket.rb:8-9).

### `config/application.rb`
- `config.api_only = true` (application.rb:20); autoload paths add `app/{auth,lib,middlewares,services,channels,clients,workers}` (application.rb:23-31); generator primary_key_type `:uuid` (application.rb:33-36); middleware stack = `Rack::Attack` then `TenantResolverMiddleware` (application.rb:49-50).

### `config/sidekiq.yml`
- `concurrency: 10`; queues `coverage` (weight 6), `portfolio` (3), `default` (1); `timeout: 300` (sidekiq.yml:1-8).

### `config/database.yml`
- PostgreSQL; `schema_search_path: "ai_interview,public"` (database.yml:15); pool = `DB_POOL` or `RAILS_MAX_THREADS + 10` (database.yml:13). Comment: AI tables in `ai_interview`, organizations in `public` (database.yml:1-3).

### `config/puma.rb`
- threads `RAILS_MAX_THREADS` (default 16) / `RAILS_MIN_THREADS` (puma.rb:6-8); workers `WEB_CONCURRENCY` default 2 (puma.rb:10); `persistent_timeout` 300, `first_data_timeout` 30 (puma.rb:16-17); port 3001 (puma.rb:19); `preload_app!` (puma.rb:25); `on_worker_boot` restarts EventMachine per forked worker (puma.rb:27-38).

### `Dockerfile`
- Multi-stage, `ruby:3.3.2` (Dockerfile:1, 21); installs `libpq-dev`, `tzdata`, `libjemalloc2` (Dockerfile:3-9, 23-27); `bundle install --deployment --frozen` without dev/test (Dockerfile:14-15); `ENV LD_PRELOAD=...libjemalloc.so.2` (Dockerfile:34); `EXPOSE 3001` (Dockerfile:38); CMD puma (Dockerfile:40).

### K8s (`k8s/*.yaml`)
- `configmap.yaml`: DB config, `DB_POOL 26`, `WEB_CONCURRENCY 2`, `RAILS_MAX_THREADS 16`, Gemini models (`gemini-2.0-flash-live-preview`, `gemini-2.5-flash`, `gemini-2.5-pro`), `PROACTIVE_RECONNECT_AFTER 510`, `APP_BASE_URL`, `ALLOWED_ORIGINS` (configmap.yaml:6-21).
- `deployment.yaml`: replicas 1; nodeSelector `example-t2d-tau-pool` + toleration (deployment.yaml:36-43); `podAntiAffinity` required (1 API pod/node) (deployment.yaml:45-53); `terminationGracePeriodSeconds: 90` + preStop `sleep 30` (deployment.yaml:57, 124-128); startup/readiness/liveness probes all hit `/health:3001` (deployment.yaml:99-122); YJIT + jemalloc env (deployment.yaml:89-96); resources request 500m/512Mi, limit 2000m/2Gi (deployment.yaml:130-136).
- `deploy-sidekiq.yaml`: replicas 1; `podAffinity` required to co-locate with an `ai-interview-api` pod + anti-affinity (deploy-sidekiq.yaml:34-51); `command: sidekiq -e staging` (deploy-sidekiq.yaml:61); readiness/liveness via `grep "READY: 1" /ai-interview/tmp/sidekiq_status` (deploy-sidekiq.yaml:91-113); YJIT disabled (deploy-sidekiq.yaml:81-82).
- `ingress.yml`: **do not apply directly** — merge into shared `ingress-haproxy` (ingress.yml:1-7); sticky-session cookie affinity `AI_INTERVIEW_ROUTE` (ingress.yml:14-17); `timeout-tunnel: 5400s` (90 min) (ingress.yml:19); host `ai-interview-api.example.com` → service `ai-interview-app:3001` (ingress.yml:23-32).
- `nodepool.yaml`: documentation for `example-t2d-tau-pool`; 1 API + 1 Sidekiq pod per node; resource budget table (nodepool.yaml:1-31).
- `service.yaml`: ClusterIP `ai-interview-app`, selector `app: ai-interview-api`, port 3001→3001 (service.yaml:1-14).

### `Procfile`
- `web: bundle exec puma -C config/puma.rb`; `worker: bundle exec sidekiq -r ./config/environment.rb` (Procfile:1-2).

---

## 8. Gemini clients + workers + WebSocket middlewares

### Gemini clients (`app/clients/gemini/`)
- `http_client.rb` — REST `generateContent` via Faraday; `BASE_URL = generativelanguage.googleapis.com/v1` (http_client.rb:5); API key from `ENV['GEMINI_API_KEY']`, passed as `x-goog-api-key` header (http_client.rb:22, 45); retries 3× on 429/500/502/503 with exponential backoff and honors `retry-after` (http_client.rb:57-68); `parse_response` extracts `candidates[0].content.parts[0].text`, strips markdown code fences, then `JSON.parse` (falls back to raw string) (http_client.rb:75-95); custom errors `ApiError`/`RateLimitError`/`TimeoutError` (http_client.rb:7-18).
- `live_client.rb` — persistent WebSocket to Gemini Live (`BidiGenerateContent`) using `faye/websocket` (live_client.rb:10, 66-70); default model `gemini-3.1-flash-live-preview` (live_client.rb:40). Responsibilities: setup with system instruction, audio modality, `contextWindowCompression.slidingWindow`, session resumption (live_client.rb:306-333); sends PCM16/16k audio + `realtimeInput.text` context injection (live_client.rb:81-97); **silence pump** (synthetic silent PCM at 30ms interval after 1s of silence) so VAD detects end-of-speech (live_client.rb:15-19, 186-248); **inactivity watchdog** (reconnect after 30s idle while silence-pumping) (live_client.rb:12, 251-268); gate delay `GATE_OPEN_DELAY 0.8` to avoid echo (live_client.rb:13, 390-411); GoAway / resumption-token handling + `supersede!` to mute replaced clients (live_client.rb:126-131, 445-472); activity bookkeeping excludes token-only updates (live_client.rb:340-341).

### Workers (`app/workers/`)
- `coverage_analyzer_worker.rb` — queue `coverage`, `retry: 0`; runs `Coverage::Analyzer`, applies skill updates, creates discovered skills (max 10, coverage_analyzer_worker.rb:51-65), advances stale partials, publishes Redis `coverage_update` via `Sidekiq.redis` (coverage_analyzer_worker.rb:8-101). Explicit note that session-end detection was removed from the worker to the middleware (coverage_analyzer_worker.rb:24-27).
- `portfolio_generator_worker.rb` — queue `portfolio`, `retry: 3`; runs `Portfolios::Generator`; `sidekiq_retries_exhausted` marks portfolio `failed` (portfolio_generator_worker.rb:6-16).
- `fit_gap_generator_worker.rb` — queue `default`, `retry: 2`; `Vacancy.unscoped.find` then `FitGap::Engine` (fit_gap_generator_worker.rb:8-12).
- `system_prompt_generator_worker.rb` — queue `default`, `retry: 3`; compiles + persists `assessments.system_prompt` (system_prompt_generator_worker.rb:8-12).

### WebSocket middlewares (`app/channels/`)
- `audio_websocket_middleware.rb` — Rack middleware proxying `/ws/sessions/:id/audio` between browser (16kHz PCM) and Gemini Live (audio_websocket_middleware.rb:5-8). Key state machine (`ConnectionState`, audio_websocket_middleware.rb:772-802) with per-connection fields. Responsibilities: auth (invite token or JWT, audio_websocket_middleware.rb:733-761); start session via `Sessions::StartHandler` (audio_websocket_middleware.rb:114); coverage cache pre-compute + digest-based re-injection (audio_websocket_middleware.rb:119-121, 203-223, 622-647); wrap-up injection with `SYSTEM_SIGNAL_TOKEN = 'SYS-TC-7x9k'` (audio_websocket_middleware.rb:16-21); coverage auto-end branching (audio_websocket_middleware.rb:537-594); time-ceiling enforcement with 60/120s warnings (audio_websocket_middleware.rb:661-706); proactive reconnect ~510s ± 30s jitter (audio_websocket_middleware.rb:443-498); GoAway / unexpected-close reconnect with backoff [1,2,4], max 3 (audio_websocket_middleware.rb:10-11, 348-416); browser-disconnect grace period 120s (audio_websocket_middleware.rb:12, 501-517). Transcript turns persisted off the EM thread via `Thread.new` + connection pool (audio_websocket_middleware.rb:184-192). Output transcription sanitized against metadata echo (audio_websocket_middleware.rb:272-283). Concurrency/state logic is extensive and is the single most stateful component.
- `coverage_websocket_middleware.rb` — server-push assessor monitor at `/ws/sessions/:id/coverage` (coverage_websocket_middleware.rb:5-8). Auth via header JWT or `{type:"auth", token}` message (coverage_websocket_middleware.rb:32-63); subscribes a background thread to Redis channel `coverage:<session_id>` and forwards messages; unsubscribes on close to avoid a hanging thread (coverage_websocket_middleware.rb:65-116).

---

## 9. OpenAPI / rswag schema

**None exists — confirmed.** There is no `swagger/`, `openapi/`, or `spec/` directory, no rswag/rspec API-spec files, and no `rswag`/`openapi` gem in `Gemfile` (Gemfile has only `rspec-rails` and `factory_bot_rails` in the test group). The only textual matches for "OpenAPI/Swagger" are inside `db/seeds.rb:136,139` (a skill taxonomy anchor string describing API design), unrelated to any API schema.

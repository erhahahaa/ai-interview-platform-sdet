# Web (React/TypeScript) — Code Map

Scope: `web/`. Read-only factual map. All citations are `file:line` relative to `web/`.

Stack: React 18 + TypeScript + Vite (`web/package.json:33,48-49`), `react-router-dom` v7 (`package.json:36`), `axios` (`package.json:28`), `jotai` state (`package.json:31`), `react-hook-form` + `zod` (`package.json:35,38`). Path alias `@` → `./src` (`web/vite.config.ts:8-10`). App entry `web/src/main.tsx:8-16` wraps `<ErrorBoundary><JotaiProvider><BrowserRouter><App/>`.

---

## 1. Routing — `web/src/App.tsx`

All routes defined in `web/src/App.tsx:21-58`:

| Route | Element | Protection |
|---|---|---|
| `/login` | `LoginPage` | public (`App.tsx:23`) |
| `/` | `Navigate to /assessments` | protected (`App.tsx:28`) |
| `/assessments` | `AssessmentListPage` | protected (`App.tsx:29`) |
| `/assessments/new` | `AssessmentNewPage` | protected (`App.tsx:30`) |
| `/assessments/:id/edit` | `AssessmentEditPage` | protected (`App.tsx:31`) |
| `/assessments/:id/invite` | `AssessmentInvitePage` | protected (`App.tsx:32`) |
| `/assessments/:id/sessions/:sessionId/monitor` | `LiveMonitorPage` | protected (`App.tsx:33-36`) |
| `/assessments/:id/sessions/:sessionId/portfolio` | `PortfolioPage` | protected (`App.tsx:37-40`) |
| `/assessments/:id/sessions/:sessionId/transcript` | `TranscriptPage` | protected (`App.tsx:41-44`) |
| `/assessments/:id/sessions/:sessionId/fitgap/:vacancyId` | `FitGapReportPage` | protected (`App.tsx:45-48`) |
| `/vacancies` | `VacancyListPage` | protected (`App.tsx:49`) |
| `/vacancies/new` | `VacancyNewPage` | protected (`App.tsx:50`) |
| `/vacancies/:id/edit` | `VacancyEditPage` | protected (`App.tsx:51`) |
| `/interview/:token` | `InterviewPage` | public (`App.tsx:57`) |

Details:
- Protection is applied via a single layout route `<Route element={<ProtectedRoute />}>` wrapping `<Route element={<AssessorLayout />}>` (`App.tsx:26-27`). Every assessor page is nested under this pair, so all are protected (no per-route guard flag).
- Candidate route is public: `<Route element={<CandidateLayout />}>` wrapping `/interview/:token` (`App.tsx:56-57`). The `:token` is the session invite token (`App.tsx:57`).
- `ProtectedRoute` reads `authAtom.token`; if falsy returns `<Navigate to="/login" replace />`, else `<Outlet />` (`web/src/components/ProtectedRoute.tsx:5-8`).
- **SignupPage is NOT routed**: `web/src/pages/auth/SignupPage.tsx` exists and exports `SignupPage` (`SignupPage.tsx:12`) but is never imported in `App.tsx` (no `import` line, `App.tsx:1-17`) and has no `<Route>`. It is only reachable if code is added. (Its own "Already have an account?" link points to `/login`, `SignupPage.tsx:97-101`.)
- No `*`/404 catch-all route and no `Navigate` fallback for unknown paths (`App.tsx:21-58`); unknown URLs render nothing under `Routes`. UNVERIFIED behavior for unmatched paths (react-router default is no match → blank).
- `ErrorBoundary` (class component) is the global crash fallback, wrapping everything (`main.tsx:9`; `web/src/components/ErrorBoundary.tsx:11-39`).

---

## 2. Screens / Pages — `web/src/pages/*`

### auth/LoginPage.tsx
- Renders a centered card "AI Interview / Sign in to your account" with email + password inputs (`LoginPage.tsx:37-75`).
- Form: `email` (type=email, required) and `password` (type=password, required) via controlled `useState` (`LoginPage.tsx:14-15,47-66`).
- States: `loading` (spinner on submit button, `LoginPage.tsx:71-72`), `error` string → "Invalid email or password." shown on any catch (`LoginPage.tsx:29-30,69`).
- On success: `saveToken(token)` + `setAuth({ token })` + `navigate("/assessments")` (`LoginPage.tsx:24-28`).

### auth/SignupPage.tsx (NOT routed)
- Renders email + password + role radio (`"admin" | "user"`, default `"user"`) (`SignupPage.tsx:15-17,71-87`).
- Calls `authApi.signup` (`SignupPage.tsx:26`), on success saves token and navigates `/assessments` (`SignupPage.tsx:27-30`); catch → "Signup failed. Please try again." (`SignupPage.tsx:31-32`).
- Loading spinner state (`SignupPage.tsx:91-92`). Never reachable from routing (see §1).

### assessments/AssessmentListPage.tsx
- Lists assessments. `loading` (3 skeletons), `error` ("Failed to load assessments…"), empty ("No assessments yet." + CTA), and populated list (`AssessmentListPage.tsx:53-99`).
- `SessionSummary` subcomponent derives status pill from `assessment.latest_session.status`: `active`→"Live now", `ended`+`end_reason==="error"`→"Last: failed", `ended`→"Last: completed", else "Awaiting candidate" (`AssessmentListPage.tsx:10-28`).
- Card click navigates to `/assessments/:id/invite` (`AssessmentListPage.tsx:76`).

### assessments/AssessmentNewPage.tsx
- `react-hook-form` + `useFieldArray` form (`AssessmentNewPage.tsx:44-54`); drag-and-drop sortable skills via dnd-kit (`AssessmentNewPage.tsx:56-68`).
- Fields: `name` (required), `time_limit_min` (Select from `TIME_LIMIT_OPTIONS`, default 45), `language` (`"en"|"id"`, default en), `skills[]` (`AssessmentNewPage.tsx:44-51,122-174`).
- Empty-skills block (`AssessmentNewPage.tsx:182-186`); error banner (`:236-238`).
- Validation: blocks submit if 0 skills — "Add at least one skill to continue." (`AssessmentNewPage.tsx:84-87`).
- Submit maps skills to `assessment_skills_attributes` with `display_order: i` and POSTs (`AssessmentNewPage.tsx:91-100`); navigates to `/assessments/:id/invite` on success (`:101`); error from `e.response.data.errors[0].message` (`:103`).
- SkillPicker dialog + "Add custom skill" append default `{ skill_label:"", is_custom:true, expected_level:3 }` (`AssessmentNewPage.tsx:70-81,212-231,256-260`).

### assessments/AssessmentEditPage.tsx
- Loads assessment via `get(id)` and `reset()` into the same form shape (`AssessmentEditPage.tsx:47-56`).
- Loading → skeleton block (`AssessmentEditPage.tsx:90-99`). Empty-skills and error states (`:137-141,163`).
- Same fields as New but `language` is NOT editable here (no language Select in render; form default omits it) — `AssessmentEditPage.tsx:40-42,112-131`. ASSUMPTION: `update` payload therefore omits `language`, which the backend may retain/overwrite. UNVERIFIED.
- Submit PUTs and navigates `/assessments/:id/invite` (`AssessmentEditPage.tsx:72-82`).
- Note: on load failure the `.catch(() => {})` swallows the error (`AssessmentEditPage.tsx:54`) — no error UI for load failure.

### assessments/AssessmentInvitePage.tsx
- Loads assessment + sessions in parallel (`AssessmentInvitePage.tsx:141-149`).
- `SessionRow` subcomponent: shows candidate name (or `Candidate ${index}`), started date, and status badges (`pending`→"Awaiting candidate", `active`→"Live", `ended`+error→"Failed", `ended`→"Completed") with actions Copy link / Monitor / Results (`AssessmentInvitePage.tsx:21-121`).
- Invite dialog collects optional candidate name (`:230-252`); `createSession` → prepends new session and shows invite link card with copy-to-clipboard (`:164-189,255-277`).
- Polling: `setInterval(loadSessions, 5000)` while any session `status !== "ended"` (`AssessmentInvitePage.tsx:152-157`).
- Loading skeleton (`:191-199`); empty candidates block (`:292-301`); "Skills assessed" list uses `LEVEL_LABELS[expected_level]` (`:324-340`).
- Copy uses `navigator.clipboard.writeText(session.invite_url)` (`:178-182,184-189`).

### monitor/LiveMonitorPage.tsx
- Loads session + transcript (`LiveMonitorPage.tsx:78-95`); keeps last 10 turns (`:89`).
- `ElapsedTimer` (inline) computes `elapsed = floor((Date.now()-start)/1000)` ticking 1s, formats `MM:SS` (`LiveMonitorPage.tsx:31-50`).
- Coverage comes from `useCoverageWebSocket` (not REST) (`:65-66`); renders configured + discovered skill progress bars using `COVERAGE_STATE_LABELS/WIDTH/COLOR` (`:200-264`).
- Polls transcript every 3s while active via `getTranscript(sessionId, lastTurn+1)` (`:98-117`).
- "Session ended" banner shows reason with `_`→space (`:172-192`).
- End session via AlertDialog → `endSession` then navigate to portfolio (`:119-128,294-321`); `endError` banner on failure (`:286-290`).

### portfolio/PortfolioPage.tsx
- Loads portfolio + vacancies + session in parallel (`PortfolioPage.tsx:44-52`).
- `fetchPortfolio` inspects `data.status`/`data.portfolio.generation_status`: sets `generating` for `"generating"`/`"pending"`, else sets portfolio + builds `overrides` map keyed by `portfolio_skill_id` (`:27-42`).
- Polls every 5s while `generating` (`usePolling`, `:55`).
- States: loading skeleton (`:97-105`), generating spinner ("takes about 2 minutes", `:156-167`), failed + Retry → `regeneratePortfolio` (`:169-184`), complete → configured/discovered skill cards + vacancy Select + "Run Fit/Gap Analysis" (`:186-253`).
- Export PDF/JSON via `exportPortfolio` and blob download (`:66-95`).

### fitgap/FitGapReportPage.tsx
- Loads portfolio first, then `getFitGap`; on 404 triggers `triggerFitGap` and sets `generating` (`FitGapReportPage.tsx:28-44`).
- Polls 5s while generating (`:62`).
- States: loading skeleton (`:96-103`), generating (`:143-149`), report ready (skill `ComparisonTable`, culture/competency narrative, discovered skills) (`:151-205`).
- Regenerate → `regenerateFitGap`, clears report, sets generating (`:64-74`).
- Export PDF/JSON blob download named `fitgap-{sessionId}-{vacancyId}.{ext}` (`:76-94`).

### transcript/TranscriptPage.tsx
- Loads transcript + session (`TranscriptPage.tsx:16-27`).
- States: loading (6 skeletons), error ("Failed to load transcript."), empty ("No transcript available."), list (`:68-113`).
- Renders AI vs Candidate bubbles; speaker label "AI Interviewer"/"Candidate" (`:90-111`).
- Download `.txt` built client-side from turns (`:29-41`).

### vacancies/VacancyListPage.tsx
- List with loading (2 skeletons), error, empty ("No vacancies yet."), populated (`VacancyListPage.tsx:32-67`). Card click → `/vacancies/:id/edit` (`:55`).

### vacancies/VacancyNewPage.tsx
- Form: `role_title` (required), `culture_dimensions` (textarea), `competency_expectations` (textarea), `skills[]` via `useFieldArray` (`VacancyNewPage.tsx:28-32,63-126`).
- Skill rows show `skill_label` + `LevelRadio` (default 3) with remove (`:81-98`).
- Submit → `create` with `vacancy_skills_attributes` (`:38-43`); navigate `/vacancies` (`:44`); error from `errors[0].message` (`:46`).
- SkillPicker onSelect appends `{ skill_id, skill_label, expected_level: 3 }` (`:139-143`).

### vacancies/VacancyEditPage.tsx
- Loads vacancy, `reset()` (`VacancyEditPage.tsx:35-40`). Loading skeleton (`:57`).
- Same fields as New (`:66-95`); submit → `update`, navigate `/vacancies` (`:42-51`). No error UI on submit failure (no catch; `finally` only, `:52-53`). Load failure swallowed (`:39`).

### interview/InterviewPage.tsx
- Public candidate page. Fetches `getCandidateInfo(token)`; sets `sessionId`; if `session_status==="ended"` → state "complete"; catch → "complete" (`InterviewPage.tsx:43-52`).
- Interview states (from `InterviewState` union): `idle` (pre-start hardware check + instructions, `:191-227`), `connecting` (`:287-288`), `active`, `reconnecting`, `draining_audio` (`:289-293`), `complete` (`:229-242`).
- Audio pipeline: `useAudioCapture` (mic → PCM), `useAudioWebSocket` (WS), `useAudioPlayback` (AI speech) (`:97-145`).
- `callAudioComplete` retries with exponential backoff `delay*2` capped 8s, initial 2s (`:101-119`). Comment notes `ended:false` is no longer valid (`:109-110`).
- Mic mute toggle (`:150-160`); start muted to avoid echo (`:162-171`); end interview sends `{type:"end_session"}` (`:173-181`).
- Reconnecting / reconnected banners; 60s threshold marks connection "lost" (`:72-76,183-188,263-283`).
- DEV-only "Force reconnect" button (`:356-361`).
- Timer: `InterviewTimer totalSeconds={time_limit_min*60}` runs when state `active`, `onExpired=endInterview` (`:253-259`).

---

## 3. API calls — `web/src/services/*.ts`

Base URL: `import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000/api/v1"` (`web/src/services/api.ts:4`). All calls go through the shared `api` axios instance (`api.ts:9-12`).

### auth.ts (`web/src/services/auth.ts`)
- `authApi.login` — POST `/auth/login`, payload `{ email, password }`, typed response `{ token }` (`auth.ts:13-14`).
- `authApi.signup` — POST `/signup`, payload `{ email, password, role: "admin"|"user" }`, typed response `{ token }` (`auth.ts:16-17`). NOTE: endpoint is `/signup`, not `/auth/signup`. Called only from unrouted `SignupPage` (`SignupPage.tsx:26`).

### assessments.ts (`web/src/services/assessments.ts`)
- `list(page=1)` — GET `/assessments?page=`, expects `{ assessments: Assessment[], meta: PaginationMeta }` (`assessments.ts:12-15`).
- `get(id)` — GET `/assessments/:id`, expects `{ assessment }` (`:17-18`).
- `create(data)` — POST `/assessments`, body `{ assessment: data }` where `data` = `{ name, time_limit_min, language?, assessment_skills_attributes[] }`, expects `{ assessment, system_prompt_generated }` (`:20-24`).
- `update(id,data)` — PUT `/assessments/:id`, same body/response shape (`:26-30`).
- `delete(id)` — DELETE `/assessments/:id` (`:32`). **Unused** (no caller).
- `getSessions(assessmentId)` — GET `/assessments/:id/sessions`, expects `{ sessions: Session[] }` (`:34-35`).
- `createSession(assessmentId, candidateName?, candidateId?)` — POST `/assessments/:id/sessions`, body `{ session: { candidate_name, candidate_id } }`, expects `{ session: Session, invite_url: string }` (`:37-41`). Callers read `res.data.session` and `session.invite_url` (`AssessmentInvitePage.tsx:169-171`); the sibling top-level `invite_url` in the type is unused — UNVERIFIED which is authoritative.

### sessions.ts (`web/src/services/sessions.ts`)
- `get(id)` — GET `/sessions/:id`, expects `{ session, assessment: { id, name, time_limit_min } }` (`sessions.ts:5-8`).
- `endSession(id, reason="manual_assessor")` — POST `/sessions/:id/end_session`, body `{ session: { reason } }`, expects `{ session }` (`:10-13`). Response ignored by caller (`LiveMonitorPage.tsx:122`).
- `getCoverage(id)` — GET `/sessions/:id/coverage`, expects `CoverageMap` (`:15-16`). **Unused** — coverage is delivered over WebSocket instead (`useCoverageWebSocket.ts:42-43`). UNVERIFIED response shape at runtime.
- `getTranscript(id, fromTurn?)` — GET `/sessions/:id/transcript?from_turn=`, expects `{ turns: TranscriptTurn[], total }` (`:18-21`).
- `getPortfolio(id)` — GET `/sessions/:id/portfolio`, expects `{ portfolio } | { status: string }` (`:23-24`). Caller branches on `status === "generating"` or `portfolio.generation_status` (`PortfolioPage.tsx:30`).
- `regeneratePortfolio(id)` — POST `/sessions/:id/portfolio/regenerate`, expects `{ message, portfolio }` (`:26-27`). Response ignored (`PortfolioPage.tsx:177`).
- `getCandidateInfo(token)` — GET `/sessions/:token/candidate`, expects `CandidateInfo` = `{ session_id, role_title, time_limit_min, session_status }` (`:29-30`, `types/index.ts:162-167`). Caller reads these fields directly off `res.data` (`InterviewPage.tsx:47-49`).
- `audioComplete(token)` — POST `/sessions/:token/audio_complete`, expects `{ ended, message }` (`:32-33`). Response ignored; caller only cares success/throw (`InterviewPage.tsx:113`).

### portfolios.ts (`web/src/services/portfolios.ts`)
- `getOverride(portfolioSkillId, { override_level, assessor_notes })` — POST `/portfolio_skills/:id/override`, body `{ override: {...} }`, expects `{ override: AssessorOverride }` (`portfolios.ts:5-8`). Caller reads `res.data.override` (`OverridePanel.tsx:35`).
- `triggerFitGap(portfolioId, vacancyId)` — POST `/portfolios/:id/fitgap`, body `{ fitgap: { vacancy_id } }`, expects `{ report } | { status, message }` (`:10-13`). Response ignored (`FitGapReportPage.tsx:37`).
- `getFitGap(portfolioId, vacancyId)` — GET `/portfolios/:id/fitgap/:vacancyId`, expects `{ report: FitGapReport }` (`:15-16`).
- `regenerateFitGap(portfolioId, vacancyId)` — POST `/portfolios/:id/regenerate_fitgap`, body `{ vacancy_id }`, expects `{ status, message }` (`:18-21`). Response ignored.
- `exportPortfolio(portfolioId, format, vacancyId?)` — GET `/portfolios/:id/export?format=&vacancy_id=`, `responseType` = `"blob"` for pdf else `"json"` (`:23-27`).

### vacancies.ts (`web/src/services/vacancies.ts`)
- `list(page=1)` — GET `/vacancies?page=`, expects `{ vacancies, meta }` (`vacancies.ts:12-15`).
- `get(id)` — GET `/vacancies/:id`, expects `{ vacancy }` (`:17-18`).
- `create(data)` — POST `/vacancies`, body `{ vacancy: data }` (`data` = `{ role_title, culture_dimensions, competency_expectations, vacancy_skills_attributes[] }`), expects `{ vacancy }` (`:20-21`).
- `update(id,data)` — PUT `/vacancies/:id`, same (`:23-24`).
- `delete(id)` — DELETE `/vacancies/:id` (`:26`). **Unused** (no caller).

### skillTaxonomies.ts (`web/src/services/skillTaxonomies.ts`)
- `list()` — GET `/skill_taxonomies`, expects `{ skill_taxonomies: SkillTaxonomy[] }` (`skillTaxonomies.ts:5-6`).
- `get(skillId)` — GET `/skill_taxonomies/:skillId`, expects `{ skill_taxonomy }` (`:8-9`). **Unused** (only `list` used by `SkillPicker.tsx:28`).

---

## 4. Client-side derived / formatting logic

### utils/constants.ts
- `TIME_LIMIT_OPTIONS = [10,30,45,60,90]` (minutes) (`constants.ts:1`).
- `parseLevel(level)`: number passthrough; else strips non-digits via `parseInt(level.replace(/\D/g,""))`; NaN → 1 (`constants.ts:4-8`). Used to parse string `"L3"` → 3 (`SkillPortfolioCard.tsx:20`, `OverridePanel.tsx:20`).
- `LEVEL_LABELS`: `{1:"L1",2:"L2",3:"L3",4:"L4",5:"L5"}` (`constants.ts:10-16`).
- `LEVEL_DESCRIPTIONS`: Foundational/Functional/Proficient/Advanced/Expert (`:18-24`).
- `LEVEL_BADGE_CLASSES`: per-level Tailwind color classes (`:27-33`).
- `COVERAGE_STATE_LABELS` (`not_yet/initiated/partial/covered` → display text) (`:36-41`).
- `COVERAGE_STATE_WIDTH` (`{0,25,60,100}`) used as progress bar value (`:43-48`).
- `COVERAGE_STATE_COLOR` (`neutral/blue/teal/teal-600`) (`:50-55`).
- `FIT_GAP_RESULT_LABELS`: `match→Match, gap→Gap, exceed→Exceeds, not_assessed→Not assessed` (`:58-63`).
- `FIT_GAP_RESULT_CLASSES`: color classes; `exceed` uses same green as `match` (`:65-70`).

### utils/internetSpeedTest.ts
- `DEFAULT_THRESHOLDS`: min download 8 Mbps, min upload 4 Mbps, max ping 300 ms (`internetSpeedTest.ts:19-23`).
- `measurePing`: uses env `VITE_SPEED_TEST_PING_URL` if set (`:28-37`); else tries google/favicon, jsdelivr, unpkg with `mode:"no-cors"` (`:38-52`); fallback `999` ms (`:52`).
- `measureDownloadSpeed`: downloads 3 test files, computes `sizeMB / seconds` (MB/s) (`:55-83`); rough fallback maps duration→2/1/0.5 (`:74-82`); 0 on total failure (`:81`).
- `measureUploadSpeed`: POSTs a 0.5 MB blob to env `VITE_SPEED_TEST_UPLOAD_URL` or httpbin/postman-echo (`:85-105`); returns `uploadSizeMB/seconds`; fallback `0.5` (`:105`).
- `runMultipleTests(fn, count=3)`: 3 attempts, 100ms gap (`:108-119`).
- `average`: 0 if empty; mean; if >2 values, trimmed mean dropping min+max (`:121-127`).
- `testInternetSpeed`: runs 3 download/upload/ping tests in parallel; **multiplies MB/s × 8 → Mbps** (`:139-140`); `passed = download≥8 && upload≥4 && ping≤300` (`:143-146`); rounds download/upload to 2 decimals, ping to int (`:148-156`). Catch-all returns `{0,0,999,false,[]×3}` (`:157-158`).
- Note units: download/upload raw values are MB/s; result field is Mbps. The `downloadTests`/`uploadTests` arrays are also converted ×8 (`:153-154`).

### utils/hardwareUtils.ts
- `ProctoringState` enum: WAITING/LOADING/PASSED/ERROR (`hardwareUtils.ts:3-8`).
- `getBrowserInfo`: UA regex → Chrome/Firefox/Safari/Edge + version (`:18-36`).
- `getOSInfo`: from `navigator.platform`/UA → Windows/MacOS/Linux/Android/iOS (`:38-48`).
- `checkCamera`: `getUserMedia` video max 640×480, max 20fps, `facingMode:"user"`, `audio:true`; returns stream or null (`:50-65`).
- `getCurrentTime`: `toLocaleTimeString("en-US",{hour/minute/second:"2-digit"})` (`:67-74`).
- `getCurrentDate`: long date format (`:76-83`).

### Inline derived values in components
- **ElapsedTimer** (LiveMonitorPage inline): `elapsed = floor((Date.now()-start)/1000)`, tick 1s, format `MM:SS` padded (`LiveMonitorPage.tsx:31-50`).
- **Effective level** (SkillPortfolioCard): `override?.override_level ?? parseLevel(skill.ai_level)` (`SkillPortfolioCard.tsx:20`).
- **OverridePanel initial level**: `existingOverride?.override_level ?? parseLevel(skill.ai_level)` (`OverridePanel.tsx:20`).
- **ComparisonTable** (fitgap): columns Required (from `required_level`) / Candidate (from `candidate_level`, `—` if null, `✏` if `is_override`) / Result. `ResultBadge` derives icon+suffix: match `✅`, exceed `⭐ +delta`, gap `⚠ -|delta|`, else `—` (`ComparisonTable.tsx:9-25,37-66`). Summary counts match/gap/exceed (`:29-31,72-77`).
- **InterviewTimer**: `formatTime` MM:SS; warning ≤300s amber, urgent ≤60s red (`InterviewTimer.tsx:10-14,30-37`).
- **ConfidenceIndicator**: normalizes to HIGH/MEDIUM/LOW (default LOW) (`ConfidenceIndicator.tsx:5-10`).
- **LevelBadge**: shows `LEVEL_LABELS[level]` + description (md size only) (`LevelBadge.tsx:20-23`).
- **VoiceBars**: 5 bars, per-bar `animationDelay = i*0.1s`, `animationDuration = 0.6 + (i%3)*0.2s` (`VoiceBars.tsx:11-34`).
- **SessionSummary / SessionRow** status derivation (see §2).

---

## 5. Auth / token handling

### stores/authAtom.ts
- `AuthState = { token: string | null }` (`authAtom.ts:3-5`).
- Storage key `"auth_token"` (`authAtom.ts:7`).
- `getStoredToken()`: `localStorage.getItem("auth_token") ?? import.meta.env.VITE_DEV_TOKEN ?? null` (`authAtom.ts:9-11`). So env dev token is a fallback when localStorage is empty.
- `saveToken` → `localStorage.setItem` (`:13-15`); `clearToken` → `localStorage.removeItem` (`:17-19`).
- `authAtom = atom({ token: getStoredToken() })` (`:21-23`). Jotai atom, not a persisted atom — reads storage once at init.

### axios interceptor (services/api.ts)
- Request interceptor: attaches `Authorization: Bearer ${token}` when token present (`api.ts:14-18`).
- Response interceptor (success): unwraps `{ data: ... }` → `...` (`api.ts:22-27`); see §6.
- Response interceptor (error): on HTTP 401 or 403 → `clearToken()` + `window.location.href = "/login"` (hard redirect, not router navigate) (`api.ts:29-35`).

### tenantAtom.ts (context, not auth)
- `tenantAtom` seeded from `VITE_DEV_TENANT_ID` / `VITE_DEV_TENANT_NAME ?? "Demo Tenant"` (`tenantAtom.ts:9-12`); displayed as "Tenant: {name}" badge in AssessorLayout (`AssessorLayout.tsx:56-59`).

---

## 6. Axios response interceptor `data` unwrapping — interaction with endpoint shapes

The interceptor (`api.ts:22-27`) does: if `response.data` is an object and has own key `"data"`, replace `response.data` with `response.data.data`. It applies to **every** response, including typed ones. Consequently, every `api.get<T>/post<T>` type T in the service layer describes the **post-unwrap** payload, and callers access `res.data.<field>` directly.

| Endpoint | Backend envelope assumed | Post-unwrap `res.data` | Caller reads |
|---|---|---|---|
| `GET /assessments` | `{ data: { assessments, meta } }` | `{ assessments, meta }` | `.assessments` (`AssessmentListPage.tsx:39`) |
| `GET /assessments/:id` | `{ data: { assessment } }` | `{ assessment }` | `.assessment` (`AssessmentInvitePage.tsx:146`) |
| `POST /assessments` | `{ data: { assessment, system_prompt_generated } }` | `{ assessment, … }` | `.assessment.id` (`AssessmentNewPage.tsx:101`) |
| `GET /assessments/:id/sessions` | `{ data: { sessions } }` | `{ sessions }` | `.sessions` (`AssessmentInvitePage.tsx:138`) |
| `POST /assessments/:id/sessions` | `{ data: { session, invite_url } }` | `{ session, invite_url }` | `.session` (`AssessmentInvitePage.tsx:170`) |
| `GET /sessions/:id` | `{ data: { session, assessment } }` | `{ session, assessment }` | `.session`, `.session.assessment?.name` (`LiveMonitorPage.tsx:83-85`) |
| `GET /sessions/:id/transcript` | `{ data: { turns, total } }` | `{ turns, total }` | `.turns` (`TranscriptPage.tsx:22`) |
| `GET /sessions/:id/portfolio` | `{ data: { portfolio } }` or `{ data: { status } }` | `{ portfolio }` / `{ status }` | `.status` / `.portfolio` (`PortfolioPage.tsx:29-33`) |
| `GET /sessions/:token/candidate` | `{ data: { session_id, role_title, time_limit_min, session_status } }` | `CandidateInfo` | `.session_id` etc (`InterviewPage.tsx:47-49`) |
| `POST /portfolio_skills/:id/override` | `{ data: { override } }` | `{ override }` | `.override` (`OverridePanel.tsx:35`) |
| `GET /portfolios/:id/fitgap/:vacancyId` | `{ data: { report } }` | `{ report }` | `.report` (`FitGapReportPage.tsx:32`) |
| `GET /vacancies` | `{ data: { vacancies, meta } }` | `{ vacancies, meta }` | `.vacancies` (`VacancyListPage.tsx:18`) |
| `GET /vacancies/:id` | `{ data: { vacancy } }` | `{ vacancy }` | `.vacancy` (`VacancyEditPage.tsx:37`) |
| `POST/PUT /vacancies` | `{ data: { vacancy } }` | `{ vacancy }` | (ignored) |
| `GET /skill_taxonomies` | `{ data: { skill_taxonomies } }` | `{ skill_taxonomies }` | `.skill_taxonomies ?? []` (`SkillPicker.tsx:30`) |
| `POST /auth/login`, `/signup` | `{ data: { token } }` | `{ token }` | `.token` (`LoginPage.tsx:25`) |

Important interactions / edge cases:
- **Login token**: the type is `{ token }` (`auth.ts:9-10`); the interceptor unwraps `{ data: { token } }` → `{ token }`, so `res.data.token` works either with or without an envelope. Exact backend envelope for `/auth/login` and `/signup` is therefore UNVERIFIED (works both ways).
- **Export (blob/pdf)**: for `format === "pdf"` the request uses `responseType: "blob"` (`portfolios.ts:26`). A Blob response is not an object with a `"data"` key, so the interceptor leaves it untouched (`api.ts:24`). For JSON export, if the backend wraps `{ data: … }`, the interceptor unwraps it, and the caller stringifies `res.data` (`PortfolioPage.tsx:76`, `FitGapReportPage.tsx:84`) — so the exported JSON may be the inner object, not the raw envelope. UNVERIFIED which shape the backend returns for export.
- **Error responses are NOT unwrapped**: only the fulfilled handler rewrites `response.data`; the rejected handler returns `Promise.reject(error)` untouched (`api.ts:29-35`). So callers reading `e.response.data.errors[0].message` (`AssessmentNewPage.tsx:103`, `AssessmentEditPage.tsx:84`, `VacancyNewPage.tsx:46`) read the raw backend error envelope `{ errors: [{ message }] }`. ASSUMPTION about error envelope shape (only observed from these reads; no explicit error typing).
- **`getCandidateInfo` inconsistency**: typed `api.get<CandidateInfo>` (no `{ data }` wrapper in type) — but the interceptor would still unwrap if the backend sends `{ data: { … } }`; the caller then reads fields off `res.data` directly, consistent with an envelope on the wire (`InterviewPage.tsx:47`).

---

## 7. `.env.example` variables and defaults

File `web/.env.example` (Vite `import.meta.env.VITE_*`):

| Variable | Example value | Default in code (when unset) | Used at |
|---|---|---|---|
| `VITE_API_BASE_URL` | `http://localhost:3000/api/v1` | `"http://localhost:3000/api/v1"` | `api.ts:4` |
| `VITE_WS_BASE_URL` | `ws://localhost:3000` | `"ws://localhost:3000"` | `api.ts:5` |
| `VITE_DEV_TOKEN` | (empty) | `null` (falls back to localStorage) | `authAtom.ts:10` |
| `VITE_SPEED_TEST_PING_URL` | (empty) | external CDN URLs | `internetSpeedTest.ts:25,29` |
| `VITE_SPEED_TEST_UPLOAD_URL` | (empty) | httpbin/postman-echo | `internetSpeedTest.ts:26,90-92` |
| `VITE_DEV_TENANT_ID` | `1` | `null` | `tenantAtom.ts:10` |
| `VITE_DEV_TENANT_NAME` | `Demo Tenant` | `"Demo Tenant"` | `tenantAtom.ts:11` |

- **Default API port is 3000** (`http://localhost:3000/api/v1`, `api.ts:4`; ws `ws://localhost:3000`, `api.ts:5`). `.env.example:2,5`.
- Additional code-referenced env var NOT in `.env.example`: `VITE_REQUIRE_CAMERA` (truthy check `=== "true"`, `HardwareCheck.tsx:35`) — gates the camera step vs microphone-only. UNVERIFIED/absent from `.env.example`.
- `import.meta.env.DEV` gates the "Force reconnect" debug button (`InterviewPage.tsx:356`).

### WebSocket endpoints (from `WS_URL` base, `api.ts:5`)
- Coverage: `WS_URL/ws/sessions/:sessionId/coverage`, sends `{type:"auth", token}` on open, receives `coverage_update` (`{skills,discovered}`) and `session_status` (`status:"ended"`, `end_reason`) (`useCoverageWebSocket.ts:30,36,42-51`).
- Audio: `WS_URL/ws/sessions/:sessionId/audio?token=…` (or without `?token`), binaryType arraybuffer; sends auth on open; binary frames → AI audio chunks; JSON control frames handled per `WsControlMessage` type (`useAudioWebSocket.ts:39-49,56-108`; `types/index.ts:189-207`). Reconnect delays `[1000,2000,4000]` ms in both WS hooks (`useCoverageWebSocket.ts:6`, `useAudioWebSocket.ts:15`).
- Candidate audio is Int16 PCM @16kHz mono (`useAudioCapture.ts:21-26`); AI playback decodes Int16 @24kHz (`useAudioPlayback.ts:3,23-31`); silence gating in `public/audio-worklet-processor.js:1-2,20-29`.

---

## Notes / flags
- `sessionsApi.getCoverage` (`sessions.ts:15`) and `skillTaxonomiesApi.get` (`skillTaxonomies.ts:8`), and both `delete` methods (`assessments.ts:32`, `vacancies.ts:26`) are defined but never called anywhere in `web/src`. UNVERIFIED live shapes.
- `AssessmentEditPage` does not render a language field, so `update` omits `language` (`AssessmentEditPage.tsx:72-88`) while `create` includes it (`AssessmentNewPage.tsx:94`). ASSUMPTION on backend persistence.
- `SignupPage` is dead code from the routing perspective (see §1).

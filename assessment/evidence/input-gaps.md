# Input Gaps — Feature × Definition-of-Ready Matrix

Source-of-truth check: the root `README.md:2` points to an **external wiki** as "the initial product
specification". No spec/wiki/PRD/Gherkin/ADRs/design docs are committed to this repo
(the only Markdown files are setup READMEs and `assessment/*`). `prompts/` is
git-excluded and holds only the case-study brief (not a product spec), so it is out of
scope per instructions. No `.feature` files, no `spec/`/`test/`/`__tests__` directories,
no `Given/When/Then` text, and no acceptance-criteria lists exist anywhere in `api/` or `web/`.

Legend: every cell below is **missing** unless a `path:line` is cited. The right-hand
column records the only in-repo "spec-like" evidence: code comments and constants that
reference an out-of-repo PRD node graph (N2/N5/N7/N9/N10/N13) or encode rules inline.

| Feature / module | PRD / spec | Given/When/Then AC | Design / solution plan | Spec-like code comments (partial substitute) |
|---|---|---|---|---|
| Authentication / login | missing | missing | missing | none found |
| Assessments (CRUD + skills + system prompt) | missing | missing | missing | `api/app/services/assessments/system_prompt_compiler.rb:6` "Template follows PRD 01 Section 2 exactly."; `:122` wrap-up wording; worker tags `[N2]` `api/app/workers/system_prompt_generator_worker.rb:12,14,16` |
| Sessions (invite token, candidate flow, end/auto-end, coverage) | missing | missing | missing | `api/app/models/session.rb:6-7` STATUSES/END_REASONS enums (inline rule); `api/app/services/sessions/start_handler.rb:4-6` (N5); `end_handler.rb:4-6,41,72` (N9 → N10) |
| Vacancies | missing | missing | missing | none found |
| Skill taxonomy | missing | missing | missing | level-anchor prose lives only as seed data `api/db/seeds.rb:138,260-261,344,348` (not a spec) |
| Portfolios (generation, overrides) | missing | missing | missing | `api/app/services/portfolios/generator.rb:4-5` (N10); `api/app/workers/portfolio_generator_worker.rb:15,22` |
| Fit/gap reports | missing | missing | missing | `api/app/services/fit_gap/engine.rb:5` rule-based + Gemini Flash; `:146` narrative template; `[N13]` `api/app/workers/fit_gap_generator_worker.rb:14,16` |
| Transcript | missing | missing | missing | none found |
| Audio WebSocket interview | missing | missing | missing | `api/app/channels/audio_websocket_middleware.rb:5-6,12,16-21,73,202,305,443` (grace period, wrap-up signal, VAD/reconnect rules) |
| Live coverage monitor | missing | missing | missing | `api/app/channels/coverage_websocket_middleware.rb:5-6`; `api/app/services/coverage/state_engine.rb:7-14,20-23,28-32` hard transition/probe rules (N7) |
| Hardware / speed check | missing | missing | missing | behavior only implied by env vars `web/README.md:60-62` (`VITE_SPEED_TEST_*`, `VITE_REQUIRE_CAMERA`) |

## Verdict
Every feature is **missing** all three Definition-of-Ready artifacts in-repo. The only
product spec is the external wiki (root `README.md:2`) — effectively "missing from repo".
The codebase self-documents intent only through scattered PRD-node references
(`N2`, `N5`, `N7`, `N9`, `N10`, `N13`) and "PRD 01 Section 2" comments, which are
pointers to a spec that is not present, not a substitute for it.

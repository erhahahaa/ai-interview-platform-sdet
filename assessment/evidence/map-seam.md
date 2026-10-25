# Seam Map: web ↔ api mismatches

Findings (each: mismatch — web ref vs api ref — severity):

1. Fit/gap field name drift: API emits `expected_level` (api/app/services/fit_gap/engine.rb:62, api/app/controllers/api/v1/portfolios_controller.rb:205) but web reads `required_level` (web/src/types/index.ts:132, web/src/components/fitgap/ComparisonTable.tsx:50) → "Required" column renders blank — SILENT WRONG-VALUE.

2. `is_override` never sent: web reads `is_override` for the ✏ badge (web/src/types/index.ts:136, web/src/components/fitgap/ComparisonTable.tsx:56) but engine computes `overridden` (engine.rb:83) and never emits it in the comparison hash (engine.rb:58-66) → override indicator is dead — SILENT WRONG-VALUE.

3. `confidence` emitted but ignored: API returns `confidence` per comparison (engine.rb:65) but web `SkillComparison` omits it (types/index.ts:130-137) → field dropped silently — COSMETIC.

4. `ai_level` type: API integer 1..5 (portfolios_controller.rb:181, api/app/models/portfolio_skill.rb:10) vs web `string "L1".."L5"` (types/index.ts:93); `parseLevel` (web/src/utils/constants.ts:4-8) tolerates the number so the badge path works, but raw render `{s.ai_level}` (web/src/pages/fitgap/FitGapReportPage.tsx:196) shows "3" not "L3" — COSMETIC/type drift (no crash).

5. axios unwrap assumes `{ data: ... }` (web/src/services/api.ts:22-27) but no controller emits a top-level `data` key; `paginated_response` (api/app/controllers/concerns/response.rb:17-27) is unused while assessments/vacancies use named keys + meta (api/app/controllers/api/v1/assessments_controller.rb:16-19, vacancies_controller.rb:14-17) → unwrap is dead code built on a false assumption — COSMETIC (latent).

6. `{ status: "generating" }` envelope (portfolios_controller.rb:14, :123) is handled in PortfolioPage (web/src/pages/portfolio/PortfolioPage.tsx:30) but ignored in FitGapReportPage which only checks `data.portfolio` (web/src/pages/fitgap/FitGapReportPage.tsx:51) → empty page with no polling if opened mid-generation — RUNTIME (UX gap).

7. Signup endpoint missing: web POSTs `/signup` (web/src/services/auth.ts:17, web/src/pages/auth/SignupPage.tsx:26) but routes only define `auth/login` (api/config/routes.rb:9), no users/signup resource → RUNTIME 404.

8. Error shape agrees: web reads `errors[0].message` (web/src/pages/assessments/AssessmentNewPage.tsx:103) and API returns `{ errors:[{status,message}] }` (response.rb:12, api/app/controllers/concerns/exception_handler.rb:21) → MATCH (no mismatch).

9. Status codes agree: 404 report-not-found (portfolios_controller.rb:134) drives trigger-on-404 (FitGapReportPage.tsx:35), 401/403 (exception_handler.rb:24-35) drive redirect (api.ts:30-33); only cosmetic quirk: login failure 401 (api/app/controllers/api/v1/authentication_controller.rb:12) re-triggers redirect-to-/login while already there — MATCH/COSMETIC.

10. Enums/units agree: coverage states (api/app/models/coverage_map.rb:4 vs types/index.ts:55 + constants.ts:36-41), generation_status (api/app/models/portfolio.rb:4 vs types/index.ts:81), language en/id (api/app/models/assessment.rb:9-14 vs types/index.ts:5 + AssessmentNewPage.tsx:34), time_limit_min [10,30,45,60,90] (assessment.rb:13 vs constants.ts:1), fit results match/gap/exceed/not_assessed (engine.rb:50,55 vs types/index.ts:128 + constants.ts:58) → ALL AGREE.

Systemic pattern: hand-rolled per-controller `*_json` hashes (no serializers) + web `any`/loose TS types (`res.data as any`) allow field-name drift (`expected_level` vs `required_level`, missing `is_override`) to ship unnoticed; envelopes are inconsistent (named keys vs `data:` vs bare `{status}`) and the axios unwrap contract matches none of them.

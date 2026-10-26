# Design plan — Assessment time-limit boundary

## Approach
A request spec exercising the existing model inclusion validation.

## Data impact
No persistence change; verifies existing validation.

## Risks
None material.

## Test plan
`api/spec/requests/assessment_time_limit_spec.rb` covers the 422 case.

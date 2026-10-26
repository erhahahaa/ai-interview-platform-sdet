# Acceptance criteria — Assessment time-limit boundary

## Scenario: unsupported time limit
- **Given** an authenticated assessor
- **When** they create an assessment with `time_limit_min = 42`
- **Then** the API responds 422 Unprocessable Entity

#!/usr/bin/env bash
# Self-test for tools/dor-check/dor_check.py — "test the tester".
# Six fixtures: three MUST block (exit 1), three MUST pass (exit 0).
set -u

DOR_CHECK="$(cd "$(dirname "$0")" && pwd)/dor_check.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/specs/demo"

cat > "$TMP/specs/demo/prd.md" <<'EOF'
# PRD — demo feature
EOF

cat > "$TMP/specs/demo/acceptance.md" <<'EOF'
# Acceptance
Given a user
When they act
Then it works
EOF

cat > "$TMP/specs/demo/design.md" <<'EOF'
# Design
## Approach
x
## Data impact
y
## Risks
z
## Test plan
w
EOF

# acceptance file WITHOUT Given/When/Then
cat > "$TMP/specs/demo/acceptance_bad.md" <<'EOF'
# Acceptance
Some prose without scenarios.
EOF

BODY_OK="Spec: specs/demo/prd.md
Acceptance: specs/demo/acceptance.md
Design: specs/demo/design.md
Test evidence: ran make net
Data impact: none
Requirement IDs: REQ-1"

BODY_NO_SPEC="Acceptance: specs/demo/acceptance.md
Design: specs/demo/design.md
Test evidence: ran make net
Data impact: none
Requirement IDs: REQ-1"

BODY_BAD_AC="Spec: specs/demo/prd.md
Acceptance: specs/demo/acceptance_bad.md
Design: specs/demo/design.md
Test evidence: ran make net
Data impact: none
Requirement IDs: REQ-1"

cd "$TMP"

fail=0
run() {
  local name="$1" want="$2" body="$3" files="$4"
  PR_BODY="$body" CHANGED_FILES="$files" python3 "$DOR_CHECK" >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$want" ]; then
    echo "PASS  $name"
  else
    echo "FAIL  $name (got=$got want=$want)"
    fail=1
  fi
}

# three MUST block
run "block: no test"           1 "$BODY_OK"     "api/app/models/foo.rb"
run "block: no spec"           1 "$BODY_NO_SPEC" "api/app/models/foo.rb
api/spec/foo_spec.rb"
run "block: no acceptance"     1 "$BODY_BAD_AC" "api/app/models/foo.rb
api/spec/foo_spec.rb"

# three MUST pass
run "pass: docs-only"          0 "" "README.md"
run "pass: assessment-only"    0 "" "assessment/01-audit.md"
run "pass: complete change"    0 "$BODY_OK" "api/app/models/foo.rb
api/spec/foo_spec.rb"

exit "$fail"

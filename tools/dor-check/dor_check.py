#!/usr/bin/env python3
"""Definition-of-Ready gate. Dependency-free (Python 3 stdlib only).

Reads PR metadata from environment variables and a list of changed files, then
fails (exit 1) with a plain list of what is missing if the change is not
"ready". Docs-only and /assessment-only changes are exempt (rule printed).

The PR title and body are treated as untrusted input: they are read from
environment variables and parsed in code, never interpolated into a shell.

Env inputs (all strings):
  PR_TITLE        — PR title (informational)
  PR_BODY         — PR body text (required)
  PR_BASE_SHA     — if set, `git diff --name-only <sha>...HEAD` is used
  CHANGED_FILES   — newline-separated file list (used when PR_BASE_SHA is unset,
                    e.g. in self-tests)
"""

import os
import re
import subprocess
import sys

PLACEHOLDERS = re.compile(r"\b(TBD|TODO|N/A|FIXME|PLACEHOLDER|XXX)\b", re.IGNORECASE)
DESIGN_HEADINGS = ("approach", "data impact", "risks", "test plan")
KEYS = ("Spec", "Acceptance", "Design", "Test evidence", "Data impact", "Requirement IDs")


def parse_body(body):
    entries = {}
    for line in body.splitlines():
        m = re.match(
            r"^\s*[-*]?\s*(Spec|Acceptance|Design|Test evidence|Data impact|Requirement IDs)\s*[:：-]\s*(.+?)\s*$",
            line,
        )
        if m:
            entries[m.group(1)] = m.group(2).strip()
    return entries


def changed_files():
    base = os.environ.get("PR_BASE_SHA", "").strip()
    if base:
        out = subprocess.run(
            ["git", "diff", "--name-only", f"{base}...HEAD"],
            capture_output=True, text=True,
        )
        return [l for l in out.stdout.splitlines() if l.strip()]
    raw = os.environ.get("CHANGED_FILES", "")
    return [l.strip() for l in raw.splitlines() if l.strip()]


def is_docs_only(files):
    return all(
        f.startswith(("docs/", "assessment/")) or f.endswith(".md") for f in files
    )


def is_source(f):
    if not f.startswith(("api/app/", "api/config/", "api/db/", "web/src/")):
        return False
    if f.startswith(("api/spec/", "api/test/", "web/tests/", "web/src/__tests__/")):
        return False
    return True


def is_test(f):
    return (
        f.endswith("_spec.rb")
        or f.startswith(("api/spec/", "api/test/", "web/tests/", "e2e/"))
        or bool(re.search(r"\.(test|spec)\.(ts|tsx|js|jsx)$", f))
    )


def main():
    body = os.environ.get("PR_BODY", "")
    entries = parse_body(body)
    files = changed_files()
    problems = []

    if is_docs_only(files):
        print("DoR gate: PASS — docs-only or /assessment-only change (exempt).")
        return 0

    src = [f for f in files if is_source(f)]
    tests = [f for f in files if is_test(f)]
    if src and not tests:
        problems.append(
            "Source files changed but no test changed. Changed source: "
            + ", ".join(src)
            + ". Add or update a test under api/spec/, web/tests/, or e2e/."
        )

    for key in ("Spec", "Acceptance", "Design"):
        path = entries.get(key, "")
        if not path:
            problems.append(
                f"Missing '{key}' link in PR body. Add a line like "
                f"'{key}: specs/<feature>/<file>.md'."
            )
            continue
        if PLACEHOLDERS.search(path):
            problems.append(f"'{key}' link looks like a placeholder: {path!r}.")
            continue
        if not os.path.exists(path):
            problems.append(f"'{key}' link does not exist: {path}.")
            continue
        if os.path.getsize(path) == 0:
            problems.append(f"'{key}' file is empty: {path}.")
            continue
        text = open(path, encoding="utf-8").read()
        if key == "Acceptance" and not re.search(r"\bGiven\b|\bWhen\b|\bThen\b", text, re.IGNORECASE):
            problems.append(f"Acceptance file {path} has no Given/When/Then scenario.")
        if key == "Design":
            missing = [h for h in DESIGN_HEADINGS if h not in text.lower()]
            if missing:
                problems.append(
                    f"Design file {path} missing required heading(s): {', '.join(missing)}."
                )

    for key, val in entries.items():
        if PLACEHOLDERS.search(val):
            problems.append(f"'{key}' contains placeholder text: {val!r}.")

    if problems:
        print("DoR gate: BLOCKED — the change is not ready.")
        for i, p in enumerate(problems, 1):
            print(f"  {i}. {p}")
        return 1

    print("DoR gate: PASS — inputs present and linked.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

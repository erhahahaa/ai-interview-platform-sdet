# PRD — Assessment time-limit boundary

## Problem
The assessment time limit must be one of the supported values (10, 30, 45, 60, 90). Unsupported values must be rejected.

## Scope
- In scope: validating `time_limit_min` on create.
- Out of scope: changing the allowed set.

## Requirements
- REQ-DEMO-1: reject `time_limit_min` outside [10, 30, 45, 60, 90] with 422.

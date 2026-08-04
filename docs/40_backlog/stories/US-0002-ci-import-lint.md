---
id: US-0002
title: CI — headless import and lint jobs
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-12-BUILD, ADR-0009]
---

# US-0002 — CI: headless import and lint jobs

| | |
|---|---|
| **Milestone** | M0 |
| **Epic** | `EPIC-SCAFFOLD` |
| **Systems** | — |
| **Estimate** | M |
| **Depends on** | US-0001 |

## Description

GitHub Actions workflow with the `import` and `lint` jobs, plus `.gdlintrc` and `.gdformatrc`.

Import runs first because everything else depends on a clean import, and import errors are the
most common cause of works-on-my-machine.

## Acceptance criteria

- [ ] `.github/workflows/ci.yml` defines `import` and `lint`.
- [ ] `import` runs `godot --headless --editor --quit-after 200`, failing on any parse error.
- [ ] `lint` runs `gdlint` and `gdformat --check` over `scripts/ test/ tools/`.
- [ ] `.gdlintrc` sets max-file-lines 400, max-line-length 100, function-arguments-number 6.
- [ ] The `.godot/` cache is keyed on `.godot-version` plus a hash of `project.godot`.
- [ ] Both jobs are required checks on `main`.
- [ ] Cold import completes in ≤ 90 s.

## Test notes

`test_import_time.gd` asserts the 90 s ceiling. Above ~2 min the gate stops being fast enough to
be useful.

## Notes

`gdformat` runs on a pre-commit hook so formatting is never a review topic.

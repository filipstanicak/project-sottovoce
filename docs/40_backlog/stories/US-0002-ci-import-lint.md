---
id: US-0002
title: CI — headless import and lint jobs
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-21
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

- [x] `.github/workflows/ci.yml` defines `import` and `lint`.
- [x] `import` runs `godot --headless --editor --quit-after 200`, failing on any parse error.
- [x] `lint` runs `gdlint` and `gdformat --check` over `scripts/ test/ tools/`.
- [x] `.gdlintrc` sets max-file-lines 400, max-line-length 100, function-arguments-number 6.
- [x] The `.godot/` cache is keyed on `.godot-version` plus a hash of **every input
      Godot imports** — `project.godot`, `**/*.import`, `**/*.gd`, `**/*.tscn`,
      `**/*.tres`. *Criterion corrected 2026-08-04: as originally written it named
      only `project.godot`, and that narrower key was the defect — a commit adding
      only `.gd` files reused a stale cache and CI passed while skipping three test
      scripts. See [`../../20_tdd/12_build_and_ci.md`](../../20_tdd/12_build_and_ci.md) §1.4.*
- [x] Both jobs are required checks on `main`.
      > **True since 2026-08-21**, verified by pushing straight at `main` with `--no-verify` so the client hook could not answer for it: *"Changes must be made through a pull request. 7 of 7 required status checks are expected."* `.github/main-ruleset.json`, TDD-12 §1.3.
- [x] Cold import completes in ≤ 90 s.

## Test notes

`test_import_time.gd` asserts the 90 s ceiling. Above ~2 min the gate stops being fast enough to
be useful.

## Notes

`gdformat` runs on a pre-commit hook so formatting is never a review topic.

> **Outstanding.** The unticked criterion above is blocked by the GitHub
> plan, not by the work: branch protection needs GitHub Pro on a private repo. Server-side branch protection and rulesets
> both return 403 on a free private repository, so `main` has no *required*
> checks — only agreed ones plus a local pre-push hook. Full account and the
> promotion path: [`../../20_tdd/12_build_and_ci.md`](../../20_tdd/12_build_and_ci.md) §1.3.
> Tick it the moment the plan allows.

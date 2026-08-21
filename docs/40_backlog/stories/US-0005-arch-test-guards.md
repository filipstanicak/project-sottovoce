---
id: US-0005
title: Architecture test guards
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-21
depends_on: [TDD-01-ARCHITECTURE, BIBLE-TEST-PLAN]
---

# US-0005 — Architecture test guards

| | |
|---|---|
| **Milestone** | M0 |
| **Epic** | `EPIC-SCAFFOLD` |
| **Systems** | — |
| **Estimate** | M |
| **Depends on** | US-0001, US-0002 |

## Description

The `test/arch/` suite: source scans protecting the architecture rather than behaviour.

These land at M0 because they are cheapest to satisfy when there is no code to violate them.
Retrofitting means fixing existing violations under deadline pressure, which is when they get
weakened instead.

## Acceptance criteria

- [x] `test/arch/README.md` explains why these exist and that they must not be deleted.
- [x] `test_layer_dependencies.gd` — no upward reference from systems/core to presentation.
- [x] `test_core_is_pure.gd` — no Node, get_node, get_tree, Engine or autoload in Core.
- [x] `test_no_utils_files.gd` — no utils/helpers/common/misc/shared.
- [x] `test_file_naming.gd` — file name matches class_name.
- [x] `test_function_lengths.gd` — no function over 40 lines.
- [x] Arch suite completes in under 5 s.
- [x] `test` job required on `main`.
      > **True since 2026-08-21**, verified by pushing straight at `main` with `--no-verify` so the client hook could not answer for it: *"Changes must be made through a pull request. 7 of 7 required status checks are expected."* `.github/main-ruleset.json`, TDD-12 §1.3.

## Test notes

These scan source rather than executing it, which is why they are fast and can assert things a
runtime test cannot.

## Notes

If an arch test fails, the fix is never to weaken the test. It means the change is wrong or an
ADR is needed. This is a stop-and-ask condition.

> **Outstanding.** The unticked criterion above is blocked by the GitHub
> plan, not by the work: branch protection needs GitHub Pro on a private repo. Server-side branch protection and rulesets
> both return 403 on a free private repository, so `main` has no *required*
> checks — only agreed ones plus a local pre-push hook. Full account and the
> promotion path: [`../../20_tdd/12_build_and_ci.md`](../../20_tdd/12_build_and_ci.md) §1.3.
> Tick it the moment the plan allows.

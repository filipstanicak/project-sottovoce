---
id: US-0005
title: Architecture test guards
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
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

- [ ] `test/arch/README.md` explains why these exist and that they must not be deleted.
- [ ] `test_layer_dependencies.gd` — no upward reference from systems/core to presentation.
- [ ] `test_core_is_pure.gd` — no Node, get_node, get_tree, Engine or autoload in Core.
- [ ] `test_no_utils_files.gd` — no utils/helpers/common/misc/shared.
- [ ] `test_file_naming.gd` — file name matches class_name.
- [ ] `test_function_lengths.gd` — no function over 40 lines.
- [ ] Arch suite completes in under 5 s.
- [ ] `test` job required on `main`.

## Test notes

These scan source rather than executing it, which is why they are fast and can assert things a
runtime test cannot.

## Notes

If an arch test fails, the fix is never to weaken the test. It means the change is wrong or an
ADR is needed. This is a stop-and-ask condition.

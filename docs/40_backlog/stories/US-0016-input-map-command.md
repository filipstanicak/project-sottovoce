---
id: US-0016
title: Input map, InputCommand and buffering
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [GDD-02-PLAYER, TDD-03-TICK, TDD-06-PAWN]
---

# US-0016 — Input map, InputCommand and buffering

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-PAWN-STATES` |
| **Systems** | `SYS-INPUT` |
| **Estimate** | M |
| **Depends on** | US-0015 |

## Description

The full input map for keyboard and gamepad, the InputCommand struct, and the action buffer.

The action buffer must live inside PawnContext and inside step(), because it changes the
simulation result. A client-only buffer would mean predicting a vault the server never performed.

## Acceptance criteria

- [ ] Every action from GDD-02 sections 1.2 and 1.3 is bound and rebindable.
- [ ] INPUT-KILL and INPUT-STUN cannot share a binding; the UI refuses it.
- [ ] InputCommand has the fixed layout from TDD-03 section 5.
- [ ] client_tick is present but marked advisory-only in its docstring.
- [ ] Action buffering forgives an input pressed up to 0.20 s early.
- [ ] Hold and toggle modes for every hold input.
- [ ] Sprint requires double-tap or a 0.4 s sustained hold on both KBM and pad.

## Test notes

`test_cli_args.gd` for flags; manual verification for rebinding.

## Notes

Sprint friction is deliberate and is the only intentional friction in the scheme. An input
entered accidentally would spend the suspicion budget without the player deciding to.

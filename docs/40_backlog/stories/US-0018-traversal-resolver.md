---
id: US-0018
title: Traversal resolver and forgiveness
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-06-PAWN, GDD-02-PLAYER]
---

# US-0018 — Traversal resolver and forgiveness

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-TRAVERSAL` |
| **Systems** | `SYS-TRAVERSAL` |
| **Estimate** | M |
| **Depends on** | US-0017 |

## Description

The seven-case first-match-wins resolver plus the magnetism windows.

Combined forgiveness is ~0.45 s — enormous by action-game standards, and correct: a missed ledge
must be a decision error, never a timing error, because the player's attention belongs on the
crowd rather than their own footwork.

## Acceptance criteria

- [ ] Resolution follows TDD-06 section 4.2 order exactly: ledge grab, gap jump, drop, vault, mantle, climb, nothing.
- [ ] Ledge grab is FIRST — forgiveness goes before everything.
- [ ] Vault is checked before mantle, so a low wall you can go over does not become one you climb onto.
- [ ] Climb is LAST — the most expensive option is never selected when a cheaper one applies.
- [ ] Case 7 consumes the input and plays nothing. Silence, not a flail.
- [ ] Magnetism: 0.25 s late window, 0.6 m lateral radius.
- [ ] Gap-jump auto-align within 20 degrees.

## Test notes

`test_traversal_resolution.gd` covers all seven cases in order, including case 7's silence.
`test_traversal_forgiveness.gd` asserts 0.20 s early and 0.25 s late both resolve.

## Notes

A failed traverse must never look like a bug.

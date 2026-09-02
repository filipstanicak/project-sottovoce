---
id: US-0070
title: Ability — Lunge
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-04-ABILITIES, TDD-09-ABILITY, ADR-0017]
---

# US-0070 — Ability: Lunge

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-ABILITIES` |
| **Systems** | `SYS-ABILITY` |
| **Estimate** | M |
| **Depends on** | US-0069 |

## Description

A six-metre committed dash that auto-initiates a kill on arrival.

The "I have been made, commit now" button.

## Acceptance criteria

- [ ] 30 s cooldown, 0.25 s wind-up, 6 m at 9 m/s, +40 suspicion applied at wind-up.
- [ ] Direction LOCKS at wind-up — no steering mid-dash.
- [ ] Auto-initiates the kill only against the caster's own contract.
- [ ] STUNNABLE for the entire wind-up and dash.
- [ ] A whiff costs a 1.2 s stagger in the open. **UNBLOCKED 2026-09-01: `Staggered` exists** (ADR-0017), it is entered by writing `PawnContext.arm_stagger` and transitioning, and it is **interruptible** — which is what makes GDD-04 §3.4's *"stun it"* counterplay pay off, since a prey who dodges the dash converts 1.2 s into a 4 s freeze and a 12 s exile.
- [ ] Startles NPCs within 7 m along the dash path.

## Test notes

`test_lunge_stunnable.gd`, `test_lunge_unsteerable.gd`, `test_lunge_contract_only.gd`.

## What ADR-0017 settled, and what it deliberately did not

**The whiff has a state.** `Staggered` is the fifteenth, added 2026-09-01, and it is the
home for this story's fifth criterion.

**Whether the DASH needs one is still this story's question.** TDD-09 §5.1 used to answer
it — *"only Lunge needs a dash, which already exists"* — and no dash exists; that row is
amended and no longer answers it for you. What has to be decided here: a 6 m committed
displacement at 9 m/s **drives its own position**, which `PawnState.drives_position()`
exists for and which `Vault` and `Drop` already do. Overloading `Drop` was priced and
rejected in the corpus — US-0061's *"a player mid-Lunge is stunnable"* would then make
everybody mid-gap-jump stunnable, which is one state carrying two meanings.

**If it needs one, it is appended to `PawnStateId.ALL` and to GDD-02 §3.1, never
inserted.** That array's order is the wire (`Snapshot.state_index`); `Staggered` consumed
index 14 and `test_pawn_state_count.gd` refuses an insertion before it.

## Notes

A prepared defender ALWAYS beats a Lunge: 0.92 s of telegraphed, unsteerable approach against a
0.7 s stun with a 120 degree cone, and the +40 at wind-up guarantees the lunger is at least
Noticed, which satisfies the stun tier gate.

Sprint is deliberately awkward to enter because it is for PLANNED speed. Lunge is the answer to
UNPLANNED speed — one press, no timing, when your target has turned and you have one second to
decide whether to abandon the hunt or spend everything on it.

Watch TEL-KILLS-BY-METHOD. Above ~15 percent of kills means the approach phase is being
short-circuited.

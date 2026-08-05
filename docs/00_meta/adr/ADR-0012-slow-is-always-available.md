---
id: ADR-0012
title: "Slowing down is always available, from every locomotion state"
version: 1.0.0
status: accepted
owner: Lead Game Designer
last_updated: 2026-08-05
depends_on: [ADR-0008, GDD-02-PLAYER, TDD-06-PAWN]
---

# ADR-0012 — Slowing down is always available, from every locomotion state

## Status

**Accepted**, 2026-08-05. Amends the normative state diagram in
[`../../10_gdd/02_player_controller.md`](../../10_gdd/02_player_controller.md) §3.

## Context

GDD-02 §3 declares its Mermaid diagram normative: *"if the code and this diagram
disagree, the diagram is right until an ADR says otherwise."* This is that ADR.

**The document contradicted itself.** §2.2's transition-rules table declares two
wildcard rows:

| From → To | Condition | Notes |
|---|---|---|
| Any → Blend-walk | `INPUT-SLOW` pressed | **Always available and instant.** Slowing down is never gated, never delayed, never refused. |
| Any → Idle | `INPUT-MOVE` released | Deceleration at `TUN-SPEED-DECEL`, faster than acceleration. |

The §3 diagram draws **neither**. It has `Idle → BlendWalk` and
`Stroll → BlendWalk`, but nothing from `Jog`, `Run` or `Sprint`.

US-0014 asserted `PawnTransitions` against the diagram edge-for-edge and passed,
which means the merged table currently makes `Sprint → BlendWalk` **illegal** —
and `test_slow_always_available.gd`, which US-0015 calls "the critical one",
cannot pass as specified.

### What each source says

| Source | Says |
|---|---|
| GDD-02 §2.2 transition rules | "Always available and instant… never gated, never delayed, never refused" |
| GDD-02 §3.4 information summary | "`Any → BlendWalk` is instant from every locomotion state. No animation, no delay, no refusal." |
| ROADMAP §3.1, the M1 feel gate | "Slowing down is **instant** from every state, at every speed." |
| US-0015 acceptance criteria | "Any state to BlendWalk succeeds within one tick, from every state, at every speed." |
| US-0015 test notes | "`test_slow_always_available.gd` is the critical one… the escape hatch the whole speed economy depends on." |
| GDD-02 §3 diagram | *silent* |

Five say instant-from-anywhere. One omits it.

## Decision

**Add six edges to the normative diagram and to `PawnTransitions`:**

```
Jog → BlendWalk      Jog → Idle
Run → BlendWalk      Run → Idle
Sprint → BlendWalk   Sprint → Idle
```

The diagram was wrong, and it was wrong in a specific and forgivable way: the
two rows it omits are exactly the two **wildcard** rows. Mermaid has no notation
for "from any state in this group", so `Any → X` cannot be drawn without
enumerating it — and enumerating it is what this ADR does.

## Consequences

**The escape hatch is free, which is the point.** Design law 1 says speed is
spent anonymity. That trade only reads as a trade if the player can stop
spending at any instant; a slow key that sometimes takes four ticks to answer
converts a deliberate cost into an unpredictable one, and the player stops
trusting the ladder rather than learning it.

**It does not make speed cheap.** Suspicion already accrued is not refunded —
`Sprint → BlendWalk` stops the +25/s immediately but leaves the meter where the
sprint put it, and decay only resumes below `TUN-SUSPICION-DECAY-SPEED-CEILING`.
The escape hatch buys you *out of the spend*, never *out of the debt*.

**The ladder stays un-skippable upward.** This ADR adds only downward and
lateral edges. `Idle → Sprint` remains illegal: escalation is still one rung at
a time, because that is what makes speed a decision.

**Rejected: follow the diagram literally.** Slowing would walk the ladder one
rung per tick — `Sprint → Run → Jog → Stroll → BlendWalk`, four ticks ≈ 67 ms at
60 Hz. Velocity decays at `TUN-SPEED-DECEL` regardless, so it might well *feel*
identical; but the state machine would lag the input, US-0015's "within one
tick" criterion would fail, and the M1 feel gate would be unmet. Choosing that
would mean deciding the diagram's silence outranked five explicit statements,
one of which is a milestone exit criterion.

**Rejected: add only `Any → BlendWalk`.** §2.2 states both rows with equal
force. Fixing one would leave the other contradiction sitting in the same table
for the next person to rediscover.

## Compliance

- `PawnTransitions.LOCO_INTERNAL` gains the six edges.
- The §3 diagram gains the six edges, so `test_pawn_transitions.gd` continues to
  compare two independent representations rather than being relaxed.
- `test_slow_always_available.gd` asserts the guarantee directly: from every
  locomotion state, at every speed, `INPUT-SLOW` reaches `BlendWalk` in one tick.

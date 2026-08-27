---
id: ADR-0016
title: Split the M4 gate — a technical exit now, the human playtest at M6
version: 1.0.0
status: accepted
owner: Lead Game Designer
last_updated: 2026-08-27
depends_on: [BACKLOG-ROADMAP, BIBLE-TEST-PLAN, US-0063]
---

# ADR-0016 — Split the M4 gate

## Context

**US-0063 was run on 2026-08-27 and one of its ten criteria was met.** Six of the remaining nine
cannot be run at M4 **by construction**, and that is the finding rather than a failure.

The gate scores a *playtest*, and a playtest needs four things M4 does not contain and was never
scheduled to contain:

| Needed by US-0063 | Story | Milestone |
|---|---|---|
| A match — countdown, 8:00 clock, Final Contract, end, winner | `SYS-MATCH`, US-0079 | **M6** |
| A lobby — direct-IP join, ready-up, persona and loadout | US-0078 | **M6** |
| A HUD — Compass, tier, portrait, crosshair | US-0072, US-0073 | M5 |
| A score, so *"did you understand why you died"* has an answer | US-0064, US-0074 | M5 |
| `TEL-MEAN-SPEED`, `TEL-FIRST-CONTACT-OUTCOME` | US-0080 | **M6** |

`ROADMAP.md` §1's M4 row reads *"the game is playable end-to-end"*, and M4's own story list
(US-0049–0063) contains none of them. **The gate did not fail; it was unrunnable when it was
written**, and nobody had checked, because a gate is the one story that is only read at the end.

**Q7 is the sharpest version of the problem.** *"Did you understand why you died"* is TEST_PLAN
§6.2's single most important question, and today the honest expected answer is **no** — a kill is
a state change and a log line, with no animation, no marker, no feed and no score. Running it now
would measure M5's absence and file it as a legibility failure against a design that has not been
given its legibility layer yet.

**And the same shape appears once more, one milestone later.** US-0077 ships a *results screen* at
M5, and `SYS-MATCH` — the thing that ends a match so a result exists — is US-0079 at M6.
Reported here, not fixed: moving a story between milestones is the owner's.

## Decision

**Split US-0063 into a technical exit that can run today and a human playtest that runs when its
dependencies exist.**

- **US-0063 becomes the M4 technical exit.** It asserts that the fifteen M4 systems are built,
  registered in the shipped server, within budget, and that **the loop resolves end to end**.
- **US-0098 becomes the first human playtest** — the twelve questions, THE TURN and the
  feel-regression checklist — filed at **M6**, beside US-0088.

### Why not simply move the whole gate to M6

**The gate's value is finding out early, and M6 already has US-0088.** A second gate at M6 with
the same criteria as the first is not a gate, it is a duplicate. What can be checked at M4 should
be checked at M4; what cannot should be honestly filed where it can.

### Why not force the playtest now with the debug overlay

The gate's own description says the loop must be interesting *"with NO abilities, NO scoring, NO
HUD beyond a debug overlay and NO audio"* — which reads as licence to run it today. **It is not**,
because "no HUD" in that sentence means *the polished HUD is not required*, and what M4 actually
has is **no output at all**: no Compass, no tier indicator, no reticle, no whiff, no marker, no
feed, and no animation clips on either rig. A player cannot see their own suspicion, cannot see
their contract's direction, and is not told they died. That is not a stripped-down build; it is a
build with no player-facing channel, and the twelve questions all assume one.

### What the technical exit is, and what it found

**The loop resolves end to end through the shipped server, and nothing had ever asserted it.**
Every M4 system is unit-tested against its own fixture, and `test_the_loop_closes.gd` is M2's —
it proves the *transport*. `test_the_m4_loop_resolves.gd` is new and drives one contract from a
press to a respawn through `server_root.tscn`'s real `MatchDirector`, with the crowd live: press,
validate, commit, contact frame, death, cycle repair, reassign breath, announcement, respawn
timer, constrained placement, reinsertion. **13.1 s, three tests, twenty assertions.**

It found one thing immediately, and it is the class of finding an integration test exists for:

> **`PawnStateId.DEAD` is never observable from outside a tick.** GDD-02 §3.1 gives `Respawning`
> the entry *"death resolved"* and the exit *"`TUN-RESPAWN-DELAY` 5.0 s"*, and §3's diagram draws
> `Dead --> Respawning: corpse spawned` — the corpse spawns **at** the contact frame, so both
> edges are taken in the same tick. `SYS-KILL` sets `Dead` at the `combat` stage and `SYS-SPAWN`
> moves it on at `contract`, one stage later. **The code is correct and the first version of the
> test was wrong**, which is why the assertion now asks `CombatTargets.is_dead` rather than a
> state id. Anything client-side that keys a death screen on `Dead` will never fire.

The other measurements are in US-0063: server tick **2.16 ms mean against a budget of 8.0** with
all fifteen systems live, and **28 of 29 documented telemetry events with no emitter**.

## Options considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Split: technical exit at M4, playtest at M6** | Everything checkable at M4 is checked at M4. The playtest runs when its questions can be answered. | Two stories where the roadmap expected one; M4's exit no longer includes a human judgement. | **Taken** |
| Move US-0063 wholesale to M6 | One story, no new ID. | Duplicates US-0088, and M4 exits with no gate at all — the milestone whose systems are the least individually verifiable. | Rejected |
| Run it now against the debug overlay | Satisfies the roadmap as written. | Measures M5's absence. Q7 would score near zero and be recorded as a legibility failure of a design that has no legibility layer yet. **Worse than not running it**, because the number would be quoted later. | Rejected |
| Pull the HUD and `SYS-MATCH` forward into M4 | The gate runs as written. | Three milestones of work moved to satisfy a checklist. The fence's own test is whether the loop is fun, not whether a story number sits in a particular milestone. | Rejected |

## Consequences

### Positive

- **M4 exits with something true.** The technical criteria are measured, not asserted.
- **The loop has an integration test at last.** Fifteen systems that had only ever run beside
  their own fixtures now run together, at the real tick, in the real scene.
- **The playtest gets a fair trial.** Run at M6 it is scored against a build with a HUD, a score
  feed and a match end — which is what its questions were written for.

### Negative — stated honestly

- **The single most important measurement in the project moves two milestones later.** THE TURN,
  and with it `RISK-NOT-FUN-SOLO`, is now first measurable at M6. **The risk is unchanged and the
  date we find out is worse**, and that is recorded in `RISK_REGISTER.md` §6 rather than softened.
- **A milestone exit criterion changed after the milestone was built**, which is the shape of
  moving the goalposts. The defence is that the criterion was never satisfiable by M4's own story
  list, and the alternative — a criterion nobody can meet — is what `SCOPE_FENCE` calls a rule
  that stops meaning anything.
- **The integration suite is now at 183.5 s against a documented 180 s.** That budget appears
  in TEST_PLAN §3, TEST_PLAN §10 and TDD-12 §17 and **is enforced nowhere** — a fourth instance of
  trap 14 found by this gate. Either enforce it or raise it; do not leave it as a number three
  documents assert and no job checks.

### Neutral

- `US-0098` is a new story ID and therefore permanent. It is filed at M6 with US-0088 as its
  neighbour, not its parent: the M6 gate judges the MVP, and the first human playtest is evidence
  the M6 gate reads.

## Open question, priced but not decided

**Moving `SYS-MATCH` (US-0079) from M6 to M5 would let the first playtest run a milestone
earlier**, and it is the only single-story lever that does. M5 already ships scoring (US-0064),
the HUD (US-0072–0074) and a **results screen** (US-0077) — and a results screen with no match end
is a screen nothing can open, so the ordering is already questionable on its own terms.

`US-0079`'s stated dependency is `US-0078`, the lobby. **That dependency is worth re-examining
rather than assumed**: a match needs players, a phase clock and an end condition; the *lobby* is
how players arrive, and direct-IP join has existed since M2. If the dependency is presentational
rather than structural, `SYS-MATCH` could land at M5 and US-0098 with it.

**Not decided here.** Moving a story between milestones is the owner's, and this ADR is about the
gate rather than about the roadmap's ordering.

## Revisit trigger

Reopen if `SYS-MATCH` moves to M5 — US-0098 should move with it, since its only hard blocker is a
match. Also reopen if M5 lands and the playtest is still not runnable, which would mean the
dependency table above was incomplete and the split bought less than it claimed.

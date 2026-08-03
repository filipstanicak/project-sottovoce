---
id: DOC-DECISION-LOG
title: Decision Log and ADR Index
version: 0.1.0
status: draft
owner: Documentation Architect
last_updated: 2026-08-03
depends_on: [DOC-GLOSSARY]
---

# Decision Log and ADR Index

Two things live here:

1. **§1 — the append-only log.** One line per decision, in chronological order. Never edit
   or delete a line; supersede it with a new line.
2. **§2 — the ADR index.** Decisions substantial enough to constrain future work get a full
   Architecture Decision Record in [`adr/`](adr/), and are indexed here.

**When does a decision need an ADR rather than a log line?** If any of these are true:

- It constrains how future features must be built.
- It adds something outside the [scope fence](SCOPE_FENCE.md).
- It would be expensive to reverse (more than a day).
- A reasonable engineer would ask "why did they do it that way?" six months later.
- It rejects an obvious alternative for a non-obvious reason.

Otherwise a log line is sufficient.

---

## 1. Append-only decision log

| Date | Ref | Decision |
|---|---|---|
| 2026-08-03 | — | Documentation corpus authored before any gameplay code, per stakeholder brief. |
| 2026-08-03 | — | Glossary and TUNABLES written first; every other document references them rather than restating values. |
| 2026-08-03 | ASM-0001 | Fictional city named **Vessalia**. |
| 2026-08-03 | ASM-0002 | MVP map is **Rione Vetraio**, the Glassmakers' Quarter (`MAP-VETRAIO`). |
| 2026-08-03 | ASM-0003 | Four personas selected for silhouette orthogonality: Vetraio, Cantatrice, Lucerna, Pesatore. |
| 2026-08-03 | ASM-0004 | Five non-playable filler archetypes defined; no player may resemble one. |
| 2026-08-03 | ASM-0005 | The core instrument keeps the plain functional name "the Compass"; no in-fiction alias. |
| 2026-08-03 | ASM-0006 | Balance design centre is 6 players; 4-player config is derived by documented scaling rules. |
| 2026-08-03 | ASM-0007 | Jog and run suspicion rates set at 4/s and 14/s (brief priced only sprint). |
| 2026-08-03 | ASM-0008 | Suspicion decay applies only at stroll speed or slower — the cliff between civilian and non-civilian speeds. |
| 2026-08-03 | ASM-0009 | Tier hysteresis of 5 points added to prevent silhouette-tint flicker corrupting an information channel. |
| 2026-08-03 | ASM-0010 | Kill facing cone set to 60° total; killing a target facing away from you is intended, not incidental. |
| 2026-08-03 | ASM-0011 | Compass pulse curve is a power curve, exponent 2.2, satisfying the "last 15 m feels different" requirement. |
| 2026-08-03 | ASM-0012 | Compass renders a ±12° cone with deterministic wobble — imprecision is a designed property, not an artefact. |
| 2026-08-03 | ASM-0013 | Compass lock fill time 1.6 s, chosen to exceed one NPC stride cycle so incidental gaps cannot complete a lock. |
| 2026-08-03 | ASM-0014 | Respawn constraint ≥ 40 m from killer, with a farthest-available fallback so the spawn system cannot fail. |
| 2026-08-03 | ASM-0015 | Loadouts locked for the whole match including across respawns, so kit knowledge stays durable. |
| 2026-08-03 | ASM-0016 | `SCORE-POISONED` specified and implemented but dormant in MVP; reserved for post-MVP `ABIL-NIGHTSHADE`. |
| 2026-08-03 | ASM-0017 | `SCORE-VARIETY` counts bonus types earned for the first time in the current life; resets on death. |
| 2026-08-03 | ASM-0018 | Suspicion sources are additive with clamp; instant sources are impulses. |
| 2026-08-03 | ADR-0001 | Engine Godot 4.5 stable, Forward+; GDScript for gameplay; C# only on profiled evidence. |
| 2026-08-03 | ADR-0002 | Server-authoritative netcode: 30 Hz tick, client prediction for the local pawn only, snapshot interpolation for remotes. |
| 2026-08-03 | ADR-0003 | Crowd NPCs use hierarchical finite state machines, not behaviour trees. |
| 2026-08-03 | ADR-0004 | Scoring implemented as event sourcing: an immutable `ScoreEvent` log, folded to produce the scoreboard. |
| 2026-08-03 | ADR-0005 | No gameplay constant may be a literal in a script; all live in `TuningProfile` resources. |
| 2026-08-03 | ADR-0006 | Strict one-way UI data flow: systems → event bus → view models → widgets. |
| 2026-08-03 | ADR-0007 | Crowd NPC transforms are server-replicated, not client-simulated from a shared seed. |
| 2026-08-03 | ADR-0008 | Pawn state machine uses state objects, not an enum-and-`match` block. |
| 2026-08-03 | ADR-0009 | Trunk-based development on `main` with short-lived feature branches; no long-running integration branches. |
| 2026-08-03 | ADR-0010 | Lag compensation rewinds the world for kill and stun validation only, clamped to 200 ms. |
| 2026-08-03 | ASM-0020 | The 30 Hz server tick is the authority clock for *all* gameplay, not only movement replication. |
| 2026-08-03 | ASM-0023 | All user-facing strings go through a string table from the first commit, despite localisation being out of scope. |
| 2026-08-03 | ASM-0027 | Documentation commits are per-document; the ~75 story files are committed in per-milestone batches. |
| 2026-08-03 | ASM-0028 | No document is promoted past `draft` until an implementation milestone has exercised it. |
| 2026-08-03 | ASM-0029 | Greybox map authored in-engine as primitives, committed as a `.tscn`. |
| 2026-08-03 | — | IP enforcement automated: a `banned_terms` grep runs in CI as a hard failure, with exactly two exempted files. |
| 2026-08-03 | — | Asset licence register enforced bidirectionally in CI: a missing row and a stale row are both build failures. |
| 2026-08-03 | — | Minimap, kill-cam and cosmetics recorded as permanent design laws rather than schedule cuts. |

---

## 2. ADR index

| ID | Title | Status | Supersedes | Date |
|---|---|---|---|---|
| [ADR-0001](adr/ADR-0001-engine-and-language.md) | Engine and language selection | Accepted | — | 2026-08-03 |
| [ADR-0002](adr/ADR-0002-netcode-model.md) | Server-authoritative netcode model | Accepted | — | 2026-08-03 |
| [ADR-0003](adr/ADR-0003-crowd-ai-architecture.md) | Crowd AI: HFSM over behaviour trees | Accepted | — | 2026-08-03 |
| [ADR-0004](adr/ADR-0004-scoring-event-sourcing.md) | Scoring as event sourcing | Accepted | — | 2026-08-03 |
| [ADR-0005](adr/ADR-0005-resource-driven-tuning.md) | Resource-driven tuning; no hardcoded constants | Accepted | — | 2026-08-03 |
| [ADR-0006](adr/ADR-0006-ui-one-way-data-flow.md) | One-way UI data flow via an event bus | Accepted | — | 2026-08-03 |
| [ADR-0007](adr/ADR-0007-crowd-replication.md) | Crowd replication strategy | Accepted | — | 2026-08-03 |
| [ADR-0008](adr/ADR-0008-state-objects.md) | State objects over enum state machines | Accepted | — | 2026-08-03 |
| [ADR-0009](adr/ADR-0009-branching-strategy.md) | Trunk-based development | Accepted | — | 2026-08-03 |
| [ADR-0010](adr/ADR-0010-lag-compensation.md) | Lag compensation scope and clamping | Accepted | — | 2026-08-03 |

### 2.1 ADR statuses

| Status | Meaning |
|---|---|
| **Proposed** | Written, not yet agreed. Do not build on it. |
| **Accepted** | In force. Code must comply. |
| **Superseded** | Replaced by a named later ADR. Kept forever; never deleted. |
| **Deprecated** | No longer in force, with nothing replacing it. Rare. |

### 2.2 ADR template

New ADRs use this shape exactly. Copy it.

```markdown
---
id: ADR-####
title: <short imperative title>
version: 1.0.0
status: proposed | accepted | superseded | deprecated
owner: <name>
last_updated: YYYY-MM-DD
depends_on: [<ids>]
supersedes: <ADR-#### or none>
---

# ADR-#### — <title>

## Context
What forces are at play? What is true about the project that makes this a decision
rather than an obvious choice? Include the constraint that makes the easy answer wrong.

## Options considered
| Option | Pros | Cons | Verdict |

## Decision
One paragraph, imperative. What we are doing.

## Consequences
### Positive
### Negative — stated honestly; an ADR with no downsides is an ADR that has not been thought about
### Neutral / follow-on work required

## Compliance
How a reviewer can tell, mechanically, whether code complies with this ADR.

## Revisit trigger
The specific, observable condition under which this decision should be reopened.
```

---

## 3. How to append to this file

- Add your line at the **bottom** of the §1 table. Do not reorder.
- Reference the `ASM-` or `ADR-` ID if one exists; use `—` if the decision is small enough
  to live only as a log line.
- If your decision reverses an earlier one, write a new line saying so and naming the ID it
  reverses. Do not edit the old line.
- Appending to this file is part of the
  [Definition of Done](../30_bible/DEFINITION_OF_DONE.md) for any story that made a decision.

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
| 2026-08-03 | ADR-0001 | Engine Godot 4.7.1 stable, Forward+; GDScript for gameplay; C# only on profiled evidence. |
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
| 2026-08-04 | ADR-0011 | Engine version pinned to **Godot 4.7.1 stable** (was 4.5). Recorded as a superseding ADR rather than an edit, because ADR-0001's own rule forbids absorbing a version change silently. |
| 2026-08-03 | ASM-0030 | Contract portrait starts unknown and is filled permanently by completing a Compass lock — reconciles the brief's HUD element with the rule that a hunter is never told their contract's persona, and gives the lock a payoff worth its cost. |
| 2026-08-05 | — | CI guards enumerate files through `.ci/repo_files.sh`, which falls back to `find` outside a git work tree and **fails on an empty or anchorless list**. `ip-guard` and `asset-inventory` had reported "clean" over zero of 739 files in a `git archive HEAD` extraction — the environment the checkpoint procedure uses. Rejected: making the guards merely skip outside git, which preserves the vacuous green and hides it better. TDD-12 §1.5. |
| 2026-08-26 | ADR-0013 | **Mechanical fidelity to the reference title is the design direction.** Where a rule here diverges from the reference, the reference wins unless the owner rules otherwise. |
| 2026-08-26 | ADR-0013 | Never-do #12 narrowed: the hit-direction ban is lifted and the prey warning is directional. "Nameplate" now means a **name** — a relationship marker on your own contract or your own revealed pursuer is permitted. |
| 2026-08-26 | ADR-0013 | Never-do #13 excepted once: **a committed kill is not interruptible.** Stun keeps its range advantage, tier gate, freeze and lockout; it no longer rescues a victim at the moment of commitment. Reverses GDD-02 §3.2 rule 1. |
| 2026-08-26 | ADR-0013 | `TUN-COMPASS-WARN-GIVES-DIRECTION` false → **true**. Reverses the rejection recorded under GDD-01 Law 5, which is preserved rather than deleted. |
| 2026-08-26 | — | The scoring table is **owed a re-pricing** and is not in ADR-0013. Moving thesis enforcement out of mechanics without moving it into scoring leaves speed neither punished nor discouraged. |
| 2026-08-26 | — | The re-pricing is **done**: `SCORE-SILENT` 100 → 200, `SCORE-PATIENT` 150 → 100, `SCORE-FOCUS` 100 → 150, `SCORE-RECKLESS` −50 → **0**. Invariant 18 rewritten from an ordering to a floor. **It narrowed the Patient : Aggressor ratio rather than widening it** — 2.68 : 1 → 2.55 : 1 — because removing the penalty is worth more to the Aggressor than the stealth uplift is to the Patient. |
| 2026-08-26 | ADR-0014 | **The escape verb is added to the MVP.** A hunter who alerts their prey enters a chase; sight refreshes a timer, absence drains it, and an empty timer costs the hunter the contract. Structurally a respawn without a death. |
| 2026-08-26 | ADR-0014 | `SCOPE_FENCE.md` IN #5 amended to name escape; the document is at 0.2.0. **The cut that pays for it is NOT decided** — recommended: defer `ABIL-WHISPERBOLT` to post-MVP. Recorded as an outstanding payment in §1.1 of that file. |
| 2026-08-26 | — | The reference's **multi-escape bonuses are refused, permanently.** They need two and three simultaneous pursuers; a Hamiltonian cycle gives every player exactly one incoming edge. The single-pursuer guarantee underwrites GDD-03 §7.4's validity proof and is not for trading. |
| 2026-08-27 | — | **The fidelity audit is redone: 21 faithful, 7 diverging, 4 missing, 4 blocked by our own rules**, against 17/12/7/4 on 2026-08-26. The row decomposition differs (36 against 40), so the totals are not comparable; the seven verdict changes are. Full table outside the repo per ADR-0013. |
| 2026-08-28 | — | **Scoring is a log and a pure fold, and TDD-10 §1.3's own signature was the thing that had to go.** US-0064. `fold(events, tuning)` contradicts §1.2 and the struct, which both freeze the points on the event — a fold that re-read the tuning could produce a different total from the one the score feed already showed, which is exactly the two-sources-of-truth defect §1.1 argues against. Amended to `fold(events)`. **`ScoreAward` is new**, because `gdlint` refused an eight-argument constructor and `.gdlintrc` says that limit is a design signal rather than a style preference; an award is a claim a system makes and an event is what the log made of it. **`server_root.gd` split at 400 lines** into `MatchAnnouncer`, the one place a peer id becomes a wire slot. |
| 2026-08-27 | — | **The Compass cone's motion is chased over `TUN-NET-INTERP-BUFFER`.** Reported from the controls as *"not as smooth as I would like... I wouldn't say it stutters"* — which is a **quantisation staircase**, not a dropped frame: the wire sends the bearing as a byte, 1.41° a step, at 30 Hz, drawn at 144, and the wobble moves it slower than one step per tick. The drawn bearing and the drawn arc width now chase the authoritative values over the same buffer every other remote thing is drawn behind. **Not prediction**: the chase is strictly *older* than the simulation, never ahead. The camera's own yaw is deliberately not smoothed. **`test_compass_invents_nothing.gd`'s ban on the string `lerp_angle` was replaced by an assertion that the drawn bearing never crosses the value it was given** — a name-ban cannot tell smoothing from extrapolation. |
| 2026-08-27 | — | **The Compass ring closes where the lock starts working: `TUN-COMPASS-CONE-FULL-RADIUS` = `TUN-COMPASS-LOCK-RANGE` 20 m.** Third value in one day — 4.0 m, 6.0, then 20 — and every one of them was moved by somebody playing it rather than by an argument. **The second miss is the instructive one: 6.0 m was derived from `TUN-SUSPICION-OPEN-RADIUS` and was still wrong**, because that is the radius at which the *crowd* stops hiding you, not the radius at which *you* can pick a face out of it. A derivation is not a justification. Invariant 33's equality re-pinned; `net_readout.gd` now prints the contract's bucket and the arc it produces, because pricing the second miss meant estimating a distance from apparent capsule height off a screenshot. |
| 2026-08-27 | — | **The Compass ring closes at the space you are standing in.** The widening arc shipped that morning derived its full-ring radius from the half-width alone and closed it at **4.0 m**; the owner judged it too tight at the controls — *"currently i have to stand right next to the pray"*. The law has **two anchors** now, the far half-width and `TUN-COMPASS-CONE-FULL-RADIUS`, with the exponent between them computed to pass through both, so no third number can contradict the first two — and the near anchor is **derived rather than chosen**: it equals `TUN-SUSPICION-OPEN-RADIUS` 6.0 m, already this game's answer to how big the space you occupy is. **Invariant 33 amended** to that equality plus its original kill clause. **No source gives the reference's radius in metres**; what the sources give is that a complete circle means the target is *within range* — close enough to engage, not touching — which is what rules 4.0 m out. **290 tunables, 33 invariants.** |
| 2026-08-27 | — | **The Compass cone pointed the wrong way, and the fixed-angle arc was a design defect.** Two missing conversions — `HudRoot` read the camera node's Godot heading (yaw 0 faces −Z) and the widget mapped a world angle onto a screen angle whose sign runs the other way — composed into a front-to-back flip that drew **correctly at both shoulders**. Found by the owner playing it; the half-turn was **measured** off a rig built the way `CameraRig` builds one, and the mirror was found by the test written from that measurement. Separately the arc now covers a constant **length of ground** rather than a constant angle, becoming a whole ring at 4.0 m — the reference's behaviour, and the fix for a 12° arc that spanned 1.06 m at kill reach and would have named the body the lock exists to charge for. **289 tunables, 33 invariants.** |
| 2026-08-27 | — | **The stealth ladder was a cliff and is now a staircase.** `SCORE-SILENT` paid 200 at Anonymous and `SCORE-RECKLESS` 0 at Exposed, and **a kill at Noticed paid neither** — being glimpsed and being caught in the open scored the same. `SCORE-HALFSEEN` +50 is the missing rung and **invariant 32** keeps the ladder strictly descending and strictly positive. **289 tunables, 32 invariants.** |
| 2026-08-27 | — | **The re-audit's second finding is RETRACTED.** It reported a name collision on `SCORE-SILENT` — ours priced 200 like the reference's Silent but supposedly a different rung. **It is the same rung**: ours fires at Anonymous-at-initiation, theirs on a briefly-conspicuous approach that is clean at the kill, and both pay 200. GDD-07 §5.1 already said so and `IP_GUARDRAILS` §2.4 prescribes the name. **No rename.** |
| 2026-08-27 | — | **Streak bonuses are storied as post-MVP (`US-0099`), not proposed.** The reference has eight across two slots and this project has none — the only wholly absent system the re-audit found. It is **new scope with nothing left to pay for it**, and the losing streak must grant *utility* rather than points or it becomes a reward for dying. |
| 2026-08-27 | ADR-0016 | **The M4 gate is split: a technical exit at M4, the human playtest at M6.** US-0063 was run and one of ten criteria was met; **six could not be run at M4 by construction** — a playtest needs a match (US-0079, M6), a lobby (US-0078, M6), a HUD (US-0072/0073, M5) and a score (US-0064/0074, M5), and M4's story list contains none of them. ROADMAP's M4 row said *"playable end-to-end"* and was never true of that list. The playtest is `US-0098`. |
| 2026-08-27 | ADR-0016 | **Running it now was rejected as worse than not running it.** Q7 — *"did you understand why you died"* — would score near zero against a build that does not tell a player they died, and a number that low gets quoted later. It would measure M5's absence, not the design. |
| 2026-08-27 | — | **`RISK-NOT-FUN-SOLO`'s first-measurable moves M4 → M6.** Probability and impact unchanged — no new evidence about fun — and **a risk found two milestones later than planned is worse at the same score.** Recorded rather than softened. |
| 2026-08-27 | — | **The M4 loop had never been run end to end.** `test_the_m4_loop_resolves.gd` is the first test to drive press → death → repair → respawn through the shipped `MatchDirector`. It found that **`PawnStateId.DEAD` is never observable from outside a tick** — correct per GDD-02 §3's `Dead --> Respawning: corpse spawned`, and a trap for any client keying a death screen on `Dead`. |
| 2026-08-27 | — | **Open, priced, not decided: moving `SYS-MATCH` (US-0079) from M6 to M5** would let the first playtest run a milestone earlier, and is the only single-story lever that does. M5 already ships a **results screen** (US-0077), which nothing can open without a match end. US-0079's stated dependency on the lobby is worth re-examining rather than assumed. |
| 2026-08-27 | ADR-0015 | **A kill needs a clear line to its contract.** TDD-10 §3's flowchart had no line-of-sight node and US-0060 reported the gap rather than inventing a rule. Settled by a measurement US-0054 created: a market stall is 2.0 m deep and its two derived lean spots sit `NAV_AGENT_RADIUS` clear of each face, so **the twelve blend spots form six pairs at 2.80 m against a 2.85 m reach** — mutually killable through the stall they hide behind. Sight is a **target-selection filter**, so a stranger in the open still absorbs the press. |
| 2026-08-27 | ADR-0015 | **`SYS-STUN` gains no sight gate, deliberately.** That would be a weakening and never-do #13 forbids it; the asymmetry is the range advantage's (3.35 m against 2.85). Asserted by a test so reversing it is a deliberate act. **The part of the decision most likely to want reversing.** |
| 2026-08-27 | — | **The contradiction ADR-0015 settles was mis-cited for two milestones.** TDD-10 §3.2 and US-0056 both attributed it to *"TDD-04 §10's test table"*; §10 is an interfaces section with no test table. The phrase is an **unticked** criterion in ADR-0010 describing an **NPC-occluded** line — which TDD-07 forbids by masking `has_los` to `WORLD`. It was never evidence either way. |
| 2026-08-27 | — | **The concealment rule was written twice** — `KillSystem._is_concealed` and an inline copy in `StunSystem`, both encoding GDD-03 §4.1.4. Now `CombatTargets`. Two copies of a targeting rule that disagreed would read as a hiding spot that works against one verb and not the other. |
| 2026-08-27 | ADR-0014 | **The cut that pays for the escape verb is chosen: `ABIL-WHISPERBOLT` is deferred to post-MVP.** Chosen on engineering cost — it is the only MVP ability needing a replicated moving entity, hit validation at an impact 0.55 s after the press (which `RewindClamp` has no rule for), and downstream bandwidth already at 105 %. **And it is the cheapest cut to reverse.** `SCOPE_FENCE.md` IN #4 reads three abilities, OUT #18 carries the reasons, and the document is at 0.3.0. |
| 2026-08-27 | ADR-0014 | **Costs recorded rather than hidden:** loadout variety halves (18 builds → 9), and **nothing in the MVP can reach a player on a roof** — the roof stratum is priced by `TUN-SUSPICION-GAIN-ROOF` and by scoring zero, which is an economic answer where Whisperbolt was the mechanical one. Revisit if `TEL-TIME-BY-STRATUM` shows roof time rising. |
| 2026-08-27 | — | **The published two-camper anti-camp finding is retracted.** *"Two campers on spawn points reduce it to one"* was measured against a rule this game does not have — the 40 m killer rule asked of both campers, where only one player is ever the killer. Corrected: a killer and an accomplice leave **two**, one body denies at most one spawn, and with a body on every spawn point the rule 7 fallback still places the victim **61.5 m** from their killer. **No rule for coordinating campers is needed.** |

---

## 2. ADR index

| ID | Title | Status | Supersedes | Date |
|---|---|---|---|---|
| [ADR-0001](adr/ADR-0001-engine-and-language.md) | Engine and language selection | **Superseded** by ADR-0011 | — | 2026-08-03 |
| [ADR-0002](adr/ADR-0002-netcode-model.md) | Server-authoritative netcode model | Accepted | — | 2026-08-03 |
| [ADR-0003](adr/ADR-0003-crowd-ai-architecture.md) | Crowd AI: HFSM over behaviour trees | Accepted | — | 2026-08-03 |
| [ADR-0004](adr/ADR-0004-scoring-event-sourcing.md) | Scoring as event sourcing | Accepted | — | 2026-08-03 |
| [ADR-0005](adr/ADR-0005-resource-driven-tuning.md) | Resource-driven tuning; no hardcoded constants | Accepted | — | 2026-08-03 |
| [ADR-0006](adr/ADR-0006-ui-one-way-data-flow.md) | One-way UI data flow via an event bus | Accepted | — | 2026-08-03 |
| [ADR-0007](adr/ADR-0007-crowd-replication.md) | Crowd replication strategy | Accepted | — | 2026-08-03 |
| [ADR-0008](adr/ADR-0008-state-objects.md) | State objects over enum state machines | Accepted | — | 2026-08-03 |
| [ADR-0009](adr/ADR-0009-branching-strategy.md) | Trunk-based development | Accepted | — | 2026-08-03 |
| [ADR-0010](adr/ADR-0010-lag-compensation.md) | Lag compensation scope and clamping | Accepted | — | 2026-08-03 |
| [ADR-0011](adr/ADR-0011-engine-version-pin-4-7-1.md) | Engine version pin — Godot 4.7.1 stable | Accepted | ADR-0001 | 2026-08-04 |
| [ADR-0012](adr/ADR-0012-slow-is-always-available.md) | Slowing down is always available, from every locomotion state | Accepted | — | 2026-08-05 |
| [ADR-0013](adr/ADR-0013-mechanical-fidelity.md) | Mechanical fidelity to the reference title | Accepted | — | 2026-08-26 |
| [ADR-0014](adr/ADR-0014-the-escape-verb.md) | The escape verb — a hunt that can be survived | Accepted | — | 2026-08-26 |
| [ADR-0015](adr/ADR-0015-a-kill-needs-a-clear-line.md) | A kill needs a clear line to its contract | Accepted | — | 2026-08-27 |
| [ADR-0016](adr/ADR-0016-split-the-m4-gate.md) | Split the M4 gate — technical exit now, human playtest at M6 | Accepted | — | 2026-08-27 |

**Three rows were missing from this table until 2026-08-26** — ADR-0012, ADR-0013 and ADR-0014
existed as files and as §1 log lines while this index stopped at ADR-0011. Nothing was wrong
with the decisions; what was wrong is that the index a reader consults to find them did not
list them, which is [trap 14](../../CLAUDE.md)'s shape in a table rather than in a claim.
**Adding an ADR means adding a row here**, and the file list under `adr/` is the check.

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

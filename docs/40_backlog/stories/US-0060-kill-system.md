---
id: US-0060
title: KillSystem with contest and lag compensation
version: 0.2.0
status: done
owner: Technical Director
last_updated: 2026-08-26
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-10-SCORING, ADR-0010]
---

# US-0060 — KillSystem with contest and lag compensation

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-COMBAT` |
| **Systems** | `SYS-KILL` |
| **Estimate** | **L** |
| **Depends on** | US-0059 — **sequencing only.** The prey warning shares no code, no tunable and no system with the kill; nothing here waited on it |

## Description

Kill validation against the lag-compensated world, the contest window, and the committed
animation.

## Acceptance criteria

- [x] Valid only against the killer's own contract; any other target is rejected.
      It reads the **announced** contract, never the graph's. During
      `TUN-CONTRACT-REASSIGN-DELAY` a killer has been told nobody, and reading the graph
      there would pay pressing the button at random during the breath.
- [x] A rejected kill applies +30 suspicion and plays a WHIFF — never silence.
      The penalty and the answer are both real: the rejection rides
      `NET-S2C-KILL-RESULT` with a **victim slot of zero**, which US-0029 reserves to mean
      nobody. **The animation does not exist** — there are no clips in this project on
      either rig — so what arrives is the event rather than the gesture.
- [x] Range 2.5 m plus 0.35 m grace, evaluated after rewind.
      Measured in three dimensions, unlike the Compass beside it: a horizontal reach would
      put the whole roof stratum, 3.5 m up, inside kill range of the street.
- [x] Facing cone 60 degrees for the killer; the VICTIM's facing is irrelevant.
      Enforced by an **absence**. `KillRules` reads a yaw exactly once, for the killer, and
      `test_kill_facing_cone.gd` scans the file to keep it that way.
- [ ] Rewind clamped to 100 to 200 ms; NPCs and Cinderfall volumes rewound too.
      **The clamp and the Cinderfall half are built; NPCs are not, and the reason is that
      nothing would read them.** ADR-0010 rewinds NPCs "because NPCs occlude line of sight
      and determine blend membership", and **both premises are false in the built game**:
      `has_los` masks `WORLD` only (GDD-03 §9.2, US-0056), and a blended player is killable
      normally (GDD-02 §3.2 rule 3). Kill validation performs no line-of-sight query at all
      — TDD-10 §3's flowchart has no such node. Recording 78 NPC transforms a tick would
      take the ring from 28.1 KB to about 130 KB for no consumer. Reported in ADR-0010 and
      TDD-04 §8.2 rather than built; the owner's call.
- [x] Tier, contract and cooldowns are NOT rewound — always current.
      Structural: `RewoundWorld` carries ids, positions, yaws and a tick, and
      `test_lagcomp_rewind.gd` asserts that field list exactly, so there is nowhere to put
      them.
- [x] Contests inside 0.4 s resolve by SERVER RECEIVE TICK, never client time.
      A same-tick tie breaks on an **arrival ordinal** stamped in
      `MatchDirector.enqueue_input` — see the notes.
- [ ] The loser staggers 1.5 s with no points and no lockout.
      **No points and no lockout are true; the stagger is an initiation lockout rather than
      a movement one.** GDD-02 §3's normative diagram declares fifteen states and none of
      them is a stagger, so there is nothing to transition into — and three separate rules
      need one (`TUN-KILL-CONTEST-STAGGER`, `TUN-STUN-INVALID-STAGGER`,
      `TUN-LUNGE-WHIFF-STAGGER`). Adding a sixteenth state amends a normative diagram and
      is the owner's.
- [x] 1.4 s animation; victim dies at the 0.9 s contact frame.
      Counted in **net** ticks by the system and in **step** ticks by `KillAnimState`, and
      the two are asserted to agree in wall time — trap 9, in the one place it would decide
      a death.
- [x] Kill initiation is blocked inside any Cinderfall volume, including the caster's own.
      `TUN-CINDERFALL-BLOCKS-KILL` is read rather than assumed. **Nothing places a cloud
      until `SYS-ABILITY`**, so the gate has no live trigger; it is driven directly in
      `test_kill_system.gd`.

## Test notes

| File | State |
|---|---|
| `test/unit/core/combat/test_kill_contract_only.gd` | **Built** |
| `test/unit/core/combat/test_kill_facing_cone.gd` | **Built** |
| `test/unit/core/combat/test_kill_contest.gd` | **Built** |
| `test/unit/core/combat/test_lagcomp_rewind.gd` | **Built** — absorbs `test_lagcomp_no_exploit.gd`, whose property (the ceiling refuses a reach past 200 ms) is asserted here as a kill rather than as arithmetic |
| `test/unit/systems/combat/test_kill_system.gd` | **Built** |
| `test/arch/test_no_client_time_in_kill.gd` | **Built**, falsified against three planted defects |
| `test/unit/net/client/test_reconciler_sees_a_forced_state.gd` | **Built** — see the finding below |
| `test/unit/core/tuning/test_tunables_match_the_document.gd` | **Built** — see the finding below |

## Notes

Killing a target facing away from you is the intended patient play, not an exploit.

Server receive order for contests advantages low ping. Accepted: client timestamps are trivially
forgeable, and server receive order is the only ordering the server can trust. TEL-CONTEST-RESOLVED
logs both RTTs so the skew is measurable rather than assumed.

---

## What was found building it

**THE CLIENT COULD NOT HAVE BEEN TOLD IT WAS KILLING ANYBODY.** `Reconciler` compared the
server's answer against its own prediction with `PredictedState.error_against`, which is
**position only** — correctly, because `TUN-NET-RECONCILE-THRESHOLD` is expressed in metres.
That is true of velocity and false of state: every state the server can force —
`KillAnim`, `Dead`, `Stunned`, `Respawning` — arrives at a pawn that may be standing
perfectly still, so the positional error is **0.000 m**, the reconciler returned early, and
`own_state` rode the snapshot and was never applied.

Nothing failed, nothing errored, and the symptom would have been a player pressing kill and
watching their character keep walking. **US-0060 is the first story that forces a state,
which is why it is the first that could tell.** A state disagreement is now a divergence at
any distance, counted separately as `Reconciler.forced` — a replay inside the threshold is
the server having decided something, where one outside it is latency, and a single counter
would report a healthy connection as a sick one every time somebody was killed. The
integration suite still measures **zero replays** at all four latency profiles.

**A SAME-TICK CONTEST TIE HAD NO HONEST TIE-BREAK, AND BOTH OBVIOUS ONES WERE WRONG.**
Iterating `ctx.pawns` is *join* order, which would hand the earliest-joined player every tie
for the whole match; a seeded coin would make the most decisive moment in the game random.
Server receive order exists in exactly one place in the process — `MatchDirector.enqueue_input`,
which sees packets in the order the socket delivered them — so it stamps a monotonic
`received_ordinal` on each command. It is **never serialised**, so a client cannot choose its
own place in a race.

**`TUN-CINDERFALL-DURATION` HAS BEEN 0.0 SINCE M0, AGAINST A PUBLISHED 4.0.** The `duration`
row is simply absent from `cinderfall.tres`, so `AbilityData`'s own default shipped — a
cinder cloud that lasts one tick. Godot writes only the properties that differ from a
script's defaults, so **a missing row is indistinguishable from a deliberate zero**, and
`SYS-KILL` is the first code that ever asked how long a cloud lives.

**AND NOTHING COMPARED `TUNABLES.md` TO THE SHIPPED DATA.** 288 tunables, the document
CLAUDE.md calls "THE gameplay values", and the only checks were `@export_range` bounds and
§17's cross-field invariants — neither of which can see a value that is simply the wrong
one. `test_tunables_match_the_document.gd` now compares **283 of them** and finds exactly one
disagreement, which is this one. The `@export_range` sweep beside it cannot cover abilities
at all: `AbilityData` is one class holding four abilities' fields, so `duration` means 4 s of
smoke for Cinderfall and 15 s of a false face for Second Face, and no single band is right
for both.

**`expire()` HAS TO LAG THE REWIND CEILING RATHER THAN THE EXPIRY.** ADR-0010 says *"one
that has expired must still have blocked"* a kill validated up to 200 ms in the past.
Dropping a cloud on the tick it burned out makes that half unimplementable — there is nothing
left to ask. Clouds are kept for `RewindClamp.max_ticks()` past expiry, and every liveness
query takes the tick it is asked about.

**AND THE TWO CINDERFALL SWITCHES WERE ONE.** `_radius()` returned zero when
`TUN-CINDERFALL-BLOCKS-LOS` was false, folding "how big is a cloud" into "does a cloud stop
sight". Harmless while sight was the only reader; wrong the moment the kill gate asked the
second question. `TUN-CINDERFALL-BLOCKS-KILL` is honoured by the kill query and
`-BLOCKS-LOS` by the sight query.

**`RewoundWorld` MOVED INTO CORE.** It was always pure — "no Node, no autoload, no lookups",
by its own docstring — and was filed under `scripts/net/server/` beside the ring that
produces it. `KillRules` is a pure rule, Core may not reference Net, and a value type living
one layer up made the rule that consumes it illegal.

**A DEAD PLAYER KEEPS THE CAMERA, AND AN EXISTING SWEEP DECIDED THAT.** The first `DeadState`
took it, on the reasoning that a dead player has nothing to aim.
`test_camera_control.gd::test_it_is_the_only_state_that_does` refused it: `Stunned` is the
only state allowed to take the camera, and taking it on death is where a kill-cam starts —
which never-do #12 forbids outright.

**AND `Dead` HAS NO EXIT.** The graph's only edge out of it is `Dead -> Respawning`, and
`Respawning` is US-0062's. **A player killed today stays dead for the rest of the match.**
That is stated in `DeadState` rather than papered over with a timer, because a timer there
would be a second authority over how long death lasts, in code that is replayed during
prediction reconciliation.

**TWO STATES CANNOT DIE AT ALL, AND THAT IS THE DIAGRAM.** GDD-02 §3's normative diagram has
no `Drop -> Dead` and no `StunAnim -> Dead`, so a player killed while falling or mid-stun-swing
cannot enter `Dead`. `KillSystem._enter` reports the missing edge rather than asserting past
it: the death still resolves and the pawn keeps walking. Amending the diagram is design prose
and is the owner's.

**AND KILL VALIDATION PERFORMED NO LINE-OF-SIGHT QUERY. SETTLED 2026-08-27 BY
[ADR-0015](../../00_meta/adr/ADR-0015-a-kill-needs-a-clear-line.md): IT DOES NOW.**
TDD-10 §3's flowchart had no such node — Cinderfall, contract, range, cone, contest — and this
story reported it rather than inventing a gameplay rule no criterion asked for. That was the
right call at the time and the measurement that settled it did not exist yet.

**THE CITATION IN THIS PARAGRAPH WAS ALSO WRONG.** It attributed the opposing claim to
*"TDD-04 §10's test table"*; §10 is an interfaces section with no test table. The phrase is an
**unticked** acceptance criterion in `ADR-0010`, and it describes an **NPC-occluded** line —
something TDD-07 forbids by masking `has_los` to `WORLD` alone. It was never evidence.

**WHAT SETTLED IT WAS US-0054.** A market stall is 2.0 m deep and its two derived lean spots sit
`NAV_AGENT_RADIUS` clear of each long face, so the twelve blend spots built on 2026-08-26 form
**six pairs at 2.80 m against a 2.85 m reach** — mutually killable through the stall they hide
behind. The stalls are the only geometry on the map thin enough; the nearest miss is the
2.6 m Mercato west wall at 3.40 m.

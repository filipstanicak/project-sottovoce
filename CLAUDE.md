# Project Sottovoce

<!-- This file is generated from docs/30_bible/CLAUDE.md_SEED.md. -->
<!-- Edit the seed, then copy here in the same commit. The reverse too — this is the file that drifts. -->
<!-- test_claude_md_synced.gd asserts every seed line appears here, in order. This file is a superset: -->
<!-- "Where the work is right now" is authored here and must NOT be copied back into the seed. -->

An online multiplayer **social-stealth** game for 4–6 players in a Renaissance-Italian city
district. Every player holds a **contract** on one other player and is the contract of an unknown
third. The district holds 60–90 AI civilians, including 8–12 **identical clones** of each playable
persona. You must move slowly and civilianly to stay invisible, while hunting demands you close
distance and commit. Matches are 8 minutes, free-for-all, decided by **score**, not kills.

**The thesis, which every decision is measured against:** this is not a shooter with hiding. It
is a game about restraint, observation, and the terror of being watched. **Speed is a resource
that costs anonymity.**

---

## The six design laws

Violating one of these is a blocker, not a discussion.

1. **Speed is spent anonymity.** Any increase in velocity costs something the player values,
   immediately and legibly.
2. **The crowd is a mechanic, not a backdrop.** Every NPC behaviour produces information a player
   can act on.
3. **Every ability has a tell.** No ability resolves without the victim having had a perceivable
   chance to read it. No invisible instant-wins.
4. **Patience must be the strongest strategy, not merely the safest.** Hiding must *win matches*,
   not just keep you alive.
5. **The prey must have teeth.** Stun hard-counters a reckless hunter and is worth as much as a
   kill. Never weaken it.
6. **Uncertainty is authored, not accidental.** Where the game is imprecise, the imprecision is
   designed, bounded, deterministic and learnable.

---

## Tech constraints

| | |
|---|---|
| Engine | **Godot 4.7.1 stable**, Forward+ renderer. Version pinned in `.godot-version` |
| Language | **GDScript**. C# only for a *profiled* hotspot, with an ADR |
| Networking | Godot high-level multiplayer, `ENetMultiplayerPeer`, dedicated headless server, **server-authoritative** |
| Netcode | Server tick **30 Hz**; client input **60 Hz**; prediction for the **local pawn only**; snapshot interpolation **100 ms** for remotes; lag compensation **100–200 ms** for kill/stun only |
| Persistence | **None.** `IProfileStore` is stubbed |
| Matchmaking | **None.** Direct IP + `--server` |
| Platforms | Windows + Linux desktop, 1080p/60 |
| VCS | Git, LFS for binaries, **trunk-based** with short branches |

---

## Folder map

```
scripts/core/          PURE. No Node, no get_node, no autoloads. Unit-testable with no engine.
scripts/systems/       SERVER ONLY. Every rule that decides an outcome.
scripts/net/           Replication, RPC, prediction, interpolation, lag compensation.
scripts/pawn/          Shared server/client state machine. MUST be deterministic.
scripts/mirrors/       CLIENT. Read-only copies of replicated state.
scripts/presentation/  CLIENT ONLY. Camera, HUD, view models, audio. Excluded from server export.
scripts/server/        MatchDirector, headless entry.
scripts/debug/         Stripped from release.
data/tuning/default/   THE gameplay values. Every number lives here.
data/strings/en.csv    THE string table. No user-facing literal anywhere else.
test/arch/             Architecture guards. Do not delete these.
docs/                  The corpus. Start at docs/README.md.
```

**Dependencies point downward only:** Presentation → Net → Systems → Core. A system must never
reference anything in `scripts/presentation/`.

---

## Naming rules

| Thing | Rule | Example |
|---|---|---|
| Script | `snake_case.gd` matching its `class_name` | `SuspicionSystem` → `suspicion_system.gd` |
| Signal | **past-tense fact** | `contract_assigned`, never `on_contract` |
| Private | `_` prefix | `_rebuild_cycle()` |
| Tunable | `TUN-<DOMAIN>-<NAME>` → `<Domain>Tuning.<name>` | `TUN-SUSPICION-DECAY-BASE` → `SuspicionTuning.decay_base` |
| Test | subject's path with `test_` prefixed | `test/unit/core/math/test_suspicion_math.gd` |

**All IDs are immutable once merged.** Full grammar: `docs/30_bible/NAMING_AND_IDS.md`.

**Original names only.** Never use franchise terminology — see the never-do list below and
`docs/00_meta/IP_GUARDRAILS.md`. CI fails hard on any banned term anywhere in the repo.

---

## Read these before touching that

| Touching… | Read first | Then |
|---|---|---|
| Suspicion, blending, tiers | `docs/10_gdd/03_social_stealth.md` §3–4 | `docs/20_tdd/07_suspicion_and_detection.md` |
| The Compass | `docs/10_gdd/03_social_stealth.md` §8 | `docs/30_bible/UI_UX_SPEC.md` §5 |
| Contracts / the cycle | `docs/10_gdd/03_social_stealth.md` §7 | `docs/20_tdd/10_scoring_and_match_state.md` |
| Kill, stun, contests | `docs/10_gdd/03_social_stealth.md` §10 | `docs/20_tdd/04_networking.md` §8 |
| Movement, states, traversal | `docs/10_gdd/02_player_controller.md` | `docs/20_tdd/06_player_pawn.md` |
| Any ability | `docs/10_gdd/04_abilities.md` | `docs/20_tdd/09_ability_system.md` |
| NPCs, crowd density | `docs/10_gdd/03_social_stealth.md` §6 | `docs/20_tdd/08_crowd_system.md` |
| The map | `docs/10_gdd/05_level_design.md` | `docs/30_bible/ART_BIBLE.md` |
| HUD, score feed, menus | `docs/10_gdd/06_ui_audio.md` | `docs/30_bible/UI_UX_SPEC.md` |
| Any sound | `docs/10_gdd/06_ui_audio.md` §5–6 | `docs/30_bible/AUDIO_BIBLE.md` |
| Scoring, balance | `docs/10_gdd/07_balance.md` | `docs/50_tuning/BALANCE_MODEL.md` |
| Any RPC or replicated state | `docs/30_bible/NETWORK_PROTOCOL.md` | `docs/20_tdd/04_networking.md` |
| Any `.tres` shape | `docs/30_bible/DATA_SCHEMA.md` | `docs/20_tdd/05_data_architecture.md` |
| Any animation | `docs/30_bible/ANIMATION_SPEC.md` | `docs/10_gdd/02_player_controller.md` §8 |
| A new global event | `docs/30_bible/SIGNAL_AND_EVENT_BUS.md` | — |
| CI, exports, the server | `docs/20_tdd/12_build_and_ci.md` | — |
| **Anything, before committing** | `docs/30_bible/DEFINITION_OF_DONE.md` | `docs/30_bible/CODING_STANDARDS.md` |

---

## Commands

```bash
# Tests
# Prefer these — they refuse to pass over a suite that ran too few scripts.
.ci/run_gut.sh test/unit unit
.ci/run_gut.sh test/arch arch
.ci/run_gut.sh test/integration integration

# By hand. -ginclude_subdirs IS NOT OPTIONAL — see trap 10.
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit

# Lint and format
gdlint scripts/ test/ tools/
gdformat --check scripts/ test/ tools/

# Import (what CI does first)
godot --headless --editor --quit-after 200

# Run a dedicated server
godot --headless -- --server --port 27015 --max-players 6

# Run a client that joins immediately
godot -- --connect 127.0.0.1:27015

# What the input layer reports with nobody touching the controls.
# NEVER --headless: there is no windowing layer there to see a device. Trap 13.
godot --path . -s res://tools/input_probe.gd
```

---

## Commit convention

```
<type>(<scope>): <summary>

Why the change was needed. What was rejected and why, if anything was.
```

Types: `feat` `fix` `docs` `refactor` `test` `chore` `perf`.
Scope: a system slug (`compass`, `crowd`, `net`) or a doc section (`gdd`, `tdd`, `bible`).

Branches: `us/US-0042-compass-lock-arc`, `fix/<slug>`, `docs/<slug>`, `chore/<slug>`.
Target branch lifetime ≤ 2 days, hard ceiling 5. Squash merge. **Never push directly to `main`.**

---

## Never do this

1. **Never hardcode a gameplay constant.** Every number lives in `data/tuning/default/*.tres`
   with a `TUN-` ID in `docs/50_tuning/TUNABLES.md`. If changing it would change how the game
   plays or feels, it is a tunable.
2. **Never let the client be authoritative over an outcome.** No message may express "I killed
   X". Kill and stun are *buttons*, validated server-side against the lag-compensated world.
3. **Never predict gameplay state.** Only the local pawn's movement is predicted. Suspicion,
   tier, detection, contracts, cooldowns and score come from the server. A client-side suspicion
   estimate "just for the HUD" will drift, and a HUD that disagrees with the server is worse
   than no HUD.
4. **Never add an ability without a tell.** Two tell channels minimum, at least one environmental
   or audio, so it survives the victim not looking at the caster.
5. **Never use franchise terminology from the banned list** in `docs/00_meta/IP_GUARDRAILS.md`
   §2. Not in code, comments, commits, branch
   names, filenames or docs. CI fails hard.
6. **Never write a file over 400 lines or a function over 40.**
7. **Never call `get_node` from a widget** outside its own subtree. Widgets read view models;
   view models read the event bus.
8. **Never use `randf`/`randi` outside `scripts/presentation/`.** Gameplay randomness comes from
   the seeded `MatchContext.rng`, server-side only.
9. **Never call `Time.*`, `get_node`, `get_tree` or any autoload except `Tuning` inside
   `scripts/pawn/`.** That code is replayed during prediction reconciliation and must be
   deterministic.
10. **Never put a user-facing string in a script or scene.** It goes in `data/strings/en.csv`.
11. **Never add an asset without a licence row** in `docs/00_meta/ASSET_LICENSES.md`, in the same
    commit.
12. **Never add a minimap, a kill-cam, a global kill feed, player nameplates, or a hit-direction
    indicator.** These are permanent design laws, not backlog items. Each would convert an
    earned inference into a given fact.
13. **Never weaken stun** to make hunting feel better. If hunters are frustrated, make the
    *Anonymous approach* more reliable instead.
14. **Never reduce crowd density to fix performance** before exhausting the LOD ladder in
    `docs/20_tdd/08_crowd_system.md` §11.3. Density is the game's substrate.
15. **Never add an autoload.** There are eight. Adding a ninth requires an ADR.

---

## When to stop and ask

Halt and ask rather than guessing if:

- The work would require adding something outside `docs/00_meta/SCOPE_FENCE.md`'s IN list.
- Two documents contradict each other.
- A change would alter a `TUN-` value, a `SYS-` ID, or any merged ID.
- A test in `test/arch/` fails and the "fix" would be to weaken the test.
- The design intent is genuinely ambiguous and the readings imply materially different work.
- You are about to violate any item in the never-do list "just this once".

Full protocol: `docs/30_bible/AGENT_PLAYBOOK.md`.

---

## Where the work is right now

*Updated 2026-08-20 (checkpoint after #123). Keep this section current — it is the first thing a fresh
session reads, and a stale one is worse than none.*

**AND THE CROWD PERF "DRIFT" IS RETRACTED — THERE ISN'T ONE.** The previous
checkpoint recorded p95 0.59-0.64 as stale and published 0.89-0.95 with an
unexplained regression. **Measured properly the next day, that was wrong.** From a
`git archive` extraction on a quiet machine, the commit that first published those
figures reads **mean 0.521, p95 0.575**, and `HEAD` twenty-three PRs later reads
**mean 0.536-0.559, p95 0.590-0.807**. The 0.89-0.95 readings were transient
machine state, taken in a session that was repeatedly starting and killing headless
servers, and they are withdrawn from every document that carried them.

**THE ONLY REAL MOVEMENT IS +7 TO +10 %, AND IT IS ACCOUNTED FOR.** Bisected across
seven commits with no step anywhere: ordinary ticks 0.497 to 0.530, the 2 s pass
1.215 to 1.340. `MAP-VETRAIO` gained anchors over the same span — **62 to 67, +8 %**
— when the Fondaco's missing row was fixed, and both figures track it.

**WHAT IS REAL IS THAT THE GATE'S STATISTIC WAS BADLY CHOSEN.** The distribution is
**bimodal by construction**: 2 of 90 ticks carry the 2 s pass at ~1.34 ms and 88
cost ~0.53, so a p95 over 90 samples is the **~4.5th highest** and lands exactly on
the boundary. Three identical local runs moved the **mean 3 %** and the **p95 38 %**
(0.586, 0.598, 0.723). On CI, ~2.4x slower, the same estimator read 1.067, 1.249
and then **1.815 — failing a build with nothing behind it.** The gate asserts the
**ordinary-tick** p95 now and prints the whole-population figure beside it; the pass
is still guarded by `test_the_two_second_pass_is_what_the_max_is`. TDD-08 §11.2.2.

**CI IS ABOUT 2.4x THIS MACHINE** — mean 1.08-1.29 against 0.53 — which is the one
part of the earlier finding that stands: a wall-clock budget asserted on a shared
runner has far less headroom than a local number implies.

**AND EVERY PROCESSION WALKS THROUGH SOLID GEOMETRY — 15 TO 28 % OF EACH ROUTE.**
The island is not the whole of it. Sampled every half metre along the interpolated
route rather than at the waypoints: **CIRC-A 15.8 %, CIRC-B 15.4 %, CIRC-C 28.0 %,
CIRC-D 19.8 %** unwalkable, either inside a building mass or over no floor at all.
Five waypoints are literally inside blocks — two of CIRC-D's in `FornaceRow`, three
across `MercatoNorthWall`.

**THAT IS THE TREMBLING, AND IT IS A COMPLETE EXPLANATION RATHER THAN A
CORRELATION.** `CrowdFormations` drives members with `Steering.drive_to` —
**straight at the slot, with no path query at all**, deliberately, because a slot
moves every tick and pathing to one would starve `RepathQueue` (US-0043). That is
safe only while the route is walkable. A member whose slot is inside masonry
presses into the wall and stays. The trembling bodies were measured at
**x 30.4-31.0, z 11.4-12.7** — `FornaceRow`'s east wall, at exactly the z of
CIRC-D's `(28, 12)` waypoint.

**THE WAYPOINTS ARE NOT THE ROUTE**, which is why a waypoint check alone understates
it: `CrowdCircuit` interpolates, so a segment that clips a corner puts a slot inside
masonry with both endpoints clear. CIRC-A has **no** bad waypoint and 15.8 % of a bad
route. `test_circuit_separation.gd` carries it, `pending`, and
`tools/stuck_census.tscn` grades a candidate route in one run.

**THE "FLOATING NPCs" AND THE "NPCs INSIDE A WALL" ARE ONE DEFECT, AND IT IS
GUARDED NOW.** `CrowdRescue` puts anything below `NAV_BAKE_FLOOR` back on a map
anchor and **counts it**; `server_root` logs the count each time it rises, naming
`test_circuit_separation.gd` as the cause. Measured on a live server: **5 over no
floor and 4 inside `MercatoNorthWall` before, 0 and 0 after.**

**IT IS NOT A FIX FOR THE CAUSE AND MUST NOT BE READ AS ONE.** The cause is that
14-28 % of every procession route runs over ground that does not exist. What the
guard buys is that the crowd stops draining, the client stops being told a lie, and
**the count is a number somebody can read**. It must be **zero** on a district whose
routes are walkable, so a log line there is a level-data defect reporting itself.

**AND THE "FLOATING NPCs" ARE FALLING OUT OF THE WORLD — THE WIRE JUST CANNOT SAY
SO.** Reported from the controls as NPCs hovering over the hole instead of
dropping. Measured on the server: **four of 78 are at y −135 to −200 m, still
accelerating at −51 to −62 m/s**, and all four are members of **procession group 1,
`CIRC-B`**, whose route crosses x ≈ 101, z 54–66 where there is no floor at all.
`CrowdFormations` drives members straight at the slot with no path query, so they
walk off the edge and never come back.

**THE CLIENT DRAWS THEM ON THE STREET BECAUSE `height_to_u8` CLAMPS TO 0..255.**
The NPC height byte spans 0 to 12.75 m at 5 cm, so y = −200 encodes as **0**. The
clamp is right — its own comment says pinning is debuggable where wrapping would
put a market NPC on a rooftop — but it makes a **server** defect look like a
rendering one. A crowd that loses members to a hole all match is a slow drain
nothing reports.

**THE FIX IS THE ROUTES, NOT THE CLAMP**, and it is the outstanding level-design
work: 14–28 % of every procession route is unwalkable.

**AND THERE IS A DEBUG DISTRICT MAP NOW, WHICH IS NOT A MINIMAP.** Never-do #12
forbids one as a permanent design law. `scripts/debug/district_map.gd` tints each
street-level floor by hue and draws the same colours as a map in the top-left, with
the crowd as dots and anything below the street in red. It **cannot ship**: all
three release presets exclude `scripts/debug/`, `LocalPawnDriver` loads it behind
`OS.has_feature("debug")`, and `test_no_scene_references_debug.gd` refuses any
scene naming it. The two text readouts moved clear of it —
`DistrictMap.RESERVED_WIDTH` — because text with no background under an opaque
panel made both unreadable.

**AND ONE FINDING IS OPEN AND IS THE OWNER'S: A TRAVERSAL IS PLANNED TO A LANDING
THAT DOES NOT EXIST.** Reported from the controls — *"when i am at a edge into the
abyss and move towards it and jump, my jump stops mid air so that my speed goes
down to 0 m/s"*. **It is not US-0093's defect returning**; that was a held key
arming a traverse every frame, and this happens on a single press.

The chain: the probes find no floor within `TUN-TRAVERSE-GAP-PROBE-DEPTH`, so
`drop_height` is `INF`; `_over_the_edge` classifies `DROP`, which is **§7.2 case 3
as written**; `_plan_drop` calls `_finite()`, which **substitutes the probe depth
for the missing number and invents a landing ten metres down**; and `DropState`
zeroes velocity, interpolates to it, and sets `grounded = true` **in mid-air**.

**THE RESOLVER ALREADY ARGUES WITH ITSELF ABOUT THIS.** `_over_the_edge`'s docstring
says a fall the probes cannot measure "is not planned at all" and that substituting
the depth "set the pawn down in mid-air at exactly that depth". `_finite` thirty
lines below still does it, under a comment defending it. **Two comments in one file,
disagreeing since US-0019.**

**I CHANGED THE CLASSIFICATION AND WAS WRONG TO.** Returning `NONE` fixed the
symptom and broke `test_a_long_fall_with_nothing_found_is_still_a_drop`, whose own
comment says: *"§7.2 case 3 as written: no landing within range resolves to Drop. An
unmeasured drop is a poor thing to plan — see the note on `_finite` — but the case
is not in doubt."* The test's author had already thought about it. Reverted; the
finding is carried by `test_traverse_into_the_void.gd`, `pending`.

**BOTH FIXES ARE DESIGN DECISIONS.** Either §7.2 case 3 is amended so an unmeasured
fall is not a manoeuvre, or the pawn gains a state that **falls under gravity**
rather than interpolating to a plan — which it does not have, because every
traversal in this architecture is a planned arc that discards momentum.

**AND THE DISTRICT HAS WALLS NOW, WHICH IT NEVER HAD.** GDD-05 §2.1 draws them;
`VetraioLayout` had **none at all**, so nothing anywhere stopped a body walking into
a void — nineteen NPCs a minute went over, and a player could walk off the piazza's
south edge. **Zero falls in fifty seconds after**, against 19 in 45 before.

**DERIVED FROM THE FLOOR TABLE, NEVER LISTED.** `VetraioGround.parapets()` walks
every street-level floor edge in one-metre steps, probes half a metre outside, and
emits a run of parapet wherever there is neither floor nor block. **Hand-listing
void edges is the transcription that produced four unwalkable routes**; a floor
added later is fenced without anybody remembering to. They sit **outside** the
floor, so the walkable width of a 2.6 m alley mouth is unchanged, and they are
`H_VAULT` — a civilian never goes over one and a player who means to still can,
which is the difference between falling and jumping. Navmesh 219 → 211 polygons.

**`VetraioGround` IS IN CORE BECAUSE THE GENERATOR CANNOT SEE `tools/`.** Three
readers now need "is this point walkable" — the census, the circuit test and the
generator — and the two that had written their own **both** filtered street floors
with `row[6]`, the *material string*, which `float()` parses to `0.0` and equals
`STREET_Y`. Neither ever skipped anything. One class, one rule.

**THE FOUR PROCESSION ROUTES ARE RE-AUTHORED, AND US-0043 IS DONE.** They had been
transcribed from GDD-05 §2.5's prose and never measured against the floor table:
14-28 % of each ran through masonry or over no floor, `CIRC-A` and `CIRC-B` passed
within **0.51 m** against a rule of 8, and the declared periods implied **2.6-3.2
m/s** — twice stroll and faster than `TUN-SPEED-RUN`.

| | Length | Period | Walked at stroll | Implied |
|---|---|---|---|---|
| `CIRC-A` | 84.0 m | 60 s | 60 s | 1.40 m/s |
| `CIRC-B` | 84.0 m | 60 s | 60 s | 1.40 m/s |
| `CIRC-C` | 81.0 m | 58 s | 58 s | 1.40 m/s |
| `CIRC-D` | 100.0 m | 71 s | 71 s | 1.41 m/s |

**SEPARATION IS HELD BY DISTANCE, NOT BY TIMING**, and that is the decision worth
carrying: phasing four periods so nobody ever coincides breaks the moment any period
is retuned, where spatial disjointness holds forever. The four sit in separate zones
at `x 45-69`, `78-115`, `94-114` and `18-28`. Furthest spawn from any circuit:
**21.47 m of 25**. No circuit enters Piazza Secca. **Zero procession members
trembling**, against four before.

**ONE OF §2.5's ROUTES CANNOT EXIST, AND THAT IS LEVEL GEOMETRY RATHER THAN AN
OVERSIGHT.** `CIRC-B` is documented "Loggia → Mercato Piccolo → Loggia", and
**Mercato is reachable from the Loggia only through Piazza Secca**, which the same
section forbids a circuit from entering. It is the Loggia's east half now; §2.5
records the amendment.

**AND THE TEST THAT ASSERTED THE DEFECT IS WHAT CLOSED IT.** It demanded every
circuit's implied speed **exceed** stroll, failing with "circuit 0 now fits its
declared period — retick US-0043's first criterion". Re-authoring made it fail
exactly that way. It asserts the property now: **the speed is the invariant and the
period is the read-out**, because `Steering` honours the speed — so a route too long
for its period silently overruns it, which is how this survived two milestones.

**BUT NPCs STILL FALL OUT OF THE WORLD, AND THAT WAS NEVER THE ROUTES.** With every
route measuring fully walkable a live server still lost **19 bodies in 45 seconds**.
Recording *where* named it at once:

```
(43.3, 35.7)  0.3 m outside Loggia        (45.7, 94.8)  0.3 m outside PonteCorto
(43.0, 35.0)  0.7 m outside MouthWest     (22.5, 95.5)  0.5 m outside FondacoStreet
(42.9, 31.1)  0.8 m outside MouthWest     (30.3, 65.7)  0.3 m outside ViaDelleLampe
```

**Every fall is 0.2-1.1 m outside a floor edge** — the alley mouth, the bridge, the
warehouse street, a seam between two floors. RVO jostles bodies sideways off a
navmesh already eroded by the agent radius and **there is no wall anywhere to stop
them**. That is the missing walls, and it is the same gap that lets a player walk off
the piazza's south edge. **A count could not have found this**: it said the district
leaks, and only the positions said where.

**PIAZZA DEL VETRO IS CONNECTED: THE TWO ALLEY MOUTHS GDD-05 §2.1 DRAWS ARE
BUILT.** Its schematic has always marked the piazza's south edge at z = 30 as a
wall pierced by two openings — the `╥` marks — with matching arcade openings into
the Loggia. **Neither was ever built**, so nothing bridged z 30-36 for x 30-90 and
the district's largest and densest space was a disconnected navmesh island.

**THE EAST MOUTH'S POSITION IS DERIVED, NOT CHOSEN.** `CIRC-A`'s existing route
crosses z = 30 at **x = 69.1** on its way from `(74, 22)` to `(60, 45)` — the
procession was authored walking through an opening nobody had cut, so the route
says where it belongs. The west mouth is the piazza's western quarter point,
x = 45, which is also where §2.1 draws it. Both are `MIN_ALLEY_WIDTH` 2.6 m wide,
the constant the layout already carried for exactly this and had never used.

| | Before | After |
|---|---|---|
| Streets `PiazzaDelVetro` can walk to | **0 of 8** | **all of them** |
| Idle anchors unreachable on foot | **24 of 67** | **8** |
| Navmesh polygons | 195 | **219** |
| Floors | 10 | **12** |
| Idle anchors | 67 | **67 — unchanged** |

**THE EIGHT THAT REMAIN ARE A DIFFERENT DEFECT AND ALL EIGHT ARE INSIDE MARKET
STALLS.** `_place_anchors` grids each zone with no obstacle filter, so two anchors
land inside each of StallA-D. US-0041 recorded that and did not fix it, because
filtering them changes the per-zone density a unit test asserts.

**AND THE ANCHOR COUNT DID NOT MOVE**, which is what makes this a cheap change: the
mouths are floors, not zones, so no density figure and no seating test is disturbed.
`test_the_district_is_one_connected_island` **turned green by itself**, which is what
a `pending` that names its own blocker is for.

**THE ROUTES ARE STILL NOT WALKABLE AND THAT IS THE NEXT JOB.** The mouths took
CIRC-A from 15.8 % to 14.1 % unwalkable and left the other three where they were:
what remains is **masonry, not the missing floor** — 33, 25, 25 and 71 sampled
points inside building masses. Re-authoring four routes against the period band, the
8 m separation and walkable ground is the outstanding level-design work.

**`test_navmesh_coverage.gd` PASSED OVER IT FOR FOUR MILESTONES, AND THE REASON IS
TRAP 3.** It samples 2011 street points and asks whether each is **on** the mesh.
**Every point on an isolated island passes that.** Coverage is not connectivity,
and only one of them had ever been checked. `test_the_district_is_one_connected_island`
is the other, `pending` with the finding.

**AND ONE CODE DEFECT MADE IT VISIBLE.** `Steering.arrived()` asked only
`is_navigation_finished()`, which measures against the **raw** target — so an NPC
sent to an unreachable anchor never arrives, never times out, and never picks
another goal. Its own docstring has always said *"or once it has decided it cannot
get there, which is the same thing to the caller"*; **the second half was never
implemented.** And `drive()` lacked the no-overshoot guard `drive_to` has carried
since US-0043, whose comment names this exact symptom: *"oscillates across it
every frame, which reads as a civilian fidgeting and is visible from across a
plaza"*.

**THE LIVE CENSUS COULD NOT DECIDE EITHER FIX, AND SAYING SO IS THE POINT.**
`tools/stuck_census.tscn` measures trembling in one-second windows — the
whole-watch version reported **zero** while the owner was looking at one — and it
puts the crowd at **7 to 10 trembling body-seconds of 4680**. But the navigation
layer is **not reproducible run to run**: the same seed and the same code gave 10,
then 7. So the A/B is noise at that scale, and the `arrived()` fix is asserted by a
**deterministic** test instead — aim an agent into the void, and it must report
arrival. **An earlier version of this finding claimed four NPCs walked 59-75 m to
achieve exactly 0.000 m. That was my own instrument**, comparing a 60 s path
length against a 15 s displacement; corrected, it is zero. Retracted.

**THE JITTER CAME BACK, AND THE REPEAT RULE WAS STILL TOO EAGER.** US-0028 fixed
the repeat from "fewer than a full tick" to "nothing at all", which was stricter
and still wrong: **the client sends 60 commands a second and the server consumes
exactly 60 a second**, so there is *no margin*, and a burst empties the queue for
one tick with nothing lost. Repeating there injects two steps the client never
predicted. `GRACE` forgives the first empty tick; a real loss still gets its repeat
one tick later, inside `TUN-NET-INTERP-BUFFER`.

**THE OWNER'S SCREENSHOT WAS THE EVIDENCE AND IT WAS QUANTISED IN COMMANDS.**
`STILL for the last 120 commands`, and yet mean 0.066, p95 0.075, six replays,
every one of them `BACK 0.150`. **0.075 m is exactly one command at
`TUN-SPEED-RUN` and 0.150 is two** — the baseline for a stationary pawn is 0.000
over 300 comparisons.

**`tools/drive_probe.tscn` IS WHAT MADE IT REPRODUCIBLE.** It boots the real client,
joins a real server and holds `input_move_forward` + `input_run` through
`Input.action_press` — the same path a finger takes, not a written `InputCommand`.
Of four ten-second runs, **the one that logged `input starvation: 2 repeats` is the
one whose error was not 0.000 m**; the other three logged none and read zero. The
correlation is exact and it is what named the mechanism.

**AND THE FIRST A/B OF IT NEARLY ACCUSED THE WRONG COMMIT.** One run of the current
build read 0.042 and one run of `5070ea4` read 0.000, which looks like a clean
regression — only three files had changed and all three were crowd-only. Repeated,
**both builds read 0.000 twice more**. The event is rare, so a single sample cannot
tell the builds apart, and the honest statement is that this defect predates those
three commits. The deterministic unit tests are what assert the fix: planted back,
they show the old rule producing **46 substeps for 24 commands** on an alternating
but complete feed, with 11 ticks counted starved and nothing lost.

**THE FAR-BAND STUTTER IS FIXED, AND THE CAUSE WAS NOT THE ONE THIS CORPUS
PUBLISHED.** The owner reported it twice — *"NPCs which are far away don't walk
smoothly but stutter a bit"* — and that second report is what unblocked it, because
the fix TDD-04 §7.2.1 named had been **built and reverted for want of evidence**.

**THE MARGIN WAS REAL AND IT WAS NOT THE CAUSE.** `CrowdWire.crowd_extra_delay()`
draws the crowd one far-band send interval deeper, which took a synthetic stream
from **5.01 % to 0.00 %** and moved the live figure by **0.01 of a point**. A fix
that measures perfectly and changes nothing live is aimed at the wrong mechanism.

**IT WAS `SnapshotAssembler` AGAIN, AND FOR THE SAME REASON AS THE FAREWELL.** That
class carries the crowd forward — right on the wire, where absence means "no
update" — and `NpcView` pushed **all of it** into the interpolator, re-stamping a
three-tick-old position with this tick's time. The interpolator cannot tell that
from an observation and honours it exactly: **two ticks drawn motionless, then
three ticks of ground covered in one.** A staircase, not an underrun, and worse the
further away because rate LOD is what opens the gap. Matched A/B, same seed and
spawn point: **2.17 % → 0.03 %.**

**AND THE INSTRUMENT COULD NOT SEE THE BODIES IT WAS ABOUT.** `FramePacing` judged
"is this NPC walking" by its **median** frame step, and a staircase's median is
**zero** — so the worst-affected NPCs failed that test and were dropped as
standing. It counted 2 walking far NPCs where the corrected instrument counts 7,
and the 1.68 % this corpus published was measured over the ones that were fine. The
reference is the **mean** now. **The guard added to stop counting idle NPCs is what
hid the defect**, which is trap 3's shape inside an instrument rather than a test.

**BOTH FIXES ARE REQUIRED AND ONLY ONE IS VISIBLE.** Dropping the duplicates leaves
an honest 10 Hz track, and a 10 Hz track under a 100 ms buffer is the underrun the
document described from the start. TDD-04 §7.2.1.

**AND CI CAN RUN AGAIN: THE REPOSITORY IS PUBLIC AS OF 2026-08-20.** Actions is free
for public repositories on standard runners, and all seven jobs are `ubuntu-22.04`.
Before that, the free allowance was exhausted and jobs were refused — see trap 6,
where the cause is now confirmed rather than suspected. **Branch protection is also
free on a public repository**, so US-0002/0003/0004/0005's four "required check on
`main`" criteria are unblocked for the first time; the ruleset JSON has been ready
since M0 and is **not applied yet**.

**THE JITTER IS FIXED AND THE OWNER HAS JUDGED IT: "IT WORKS PERFECTLY."** It
took four reports from the controls and **three wrong diagnoses from prose**, and
the thing that finally settled it was building an instrument the person who could
feel it could read. `scripts/debug/net_readout.gd` is that instrument — a live
overlay in debug builds only, attached by `LocalPawnDriver` the way
`feel_readout.gd` is.

**IT WAS TWO DEFECTS IN THE INPUT QUEUE, NOT RENDERING.**

1. **A LATE COMMAND WAS PAID FOR TWICE.** `MatchDirector._drain` applied the whole
   queue and `_repeat_last` then padded any tick that received fewer than
   `_frames_per_tick` with a **stale repeat**. The client sends two commands per
   tick and they do not *arrive* two per tick — arrival is bursty on localhost as
   much as on a wire — so a tick that got one applied `[new, stale-repeat]` and the
   next applied all three of its arrivals on top. **Five steps for four commands**,
   measured as the applied sequence `[1, 1, 2, 3, 4]`. The extra step integrates a
   direction the client never predicted, so the correction tugs toward the
   *previous* input. Reported as **"I press D to go right and it feels as if S is
   tapped in between."** The repeat is right for a **lost** command and wrong for a
   merely **late** one, and late is the common case.
2. **AND THE FIRST FIX FOR IT CAUSED A SECOND DEFECT.** Capping the drain at one
   tick's worth stopped the duplicates — and made a deficit **unrepayable**, since
   the client produces exactly `_frames_per_tick` per tick. Every starved tick added
   *permanent* lag. Measured from the controls: **a mean reconciliation error of
   0.068 m while walking, biased BACK**, under `TUN-NET-RECONCILE-THRESHOLD` so it
   never snapped and never corrected. **One command is 7.5 cm at `TUN-SPEED-RUN`**,
   which is that number. `CATCH_UP` is 1: a deficit of N clears in N ticks.

**`CATCH_UP` IS THE ONE PLACE A CLIENT'S SEND RATE COULD BUY DISTANCE**, since every
applied command is a step of movement. Bounded twice — the queue is capped by
`TUN-NET-INPUT-BUFFER-SIZE` and `SequenceGate` refuses replays — but **nothing
checks a client's send rate**, and that belongs with US-0026's authority work. The
pre-US-0028 code drained the whole queue and was strictly more exposed.

**THE OVERLAY EXISTS BECAUSE PROSE COULD NOT LOCATE THIS, AND IT MISLED ME THREE
TIMES BEFORE IT HELPED.** Each failure is designed out now:

- **It showed only the instantaneous `move`**, so a screenshot of `(0.00, 0.00)`
  beside twelve corrections read as a pawn shoved with nobody driving. It says
  `driving: N of the last 120 commands moved` now.
- **It decomposed with the CURRENT yaw**, so one stored correction printed
  `BACK/LEFT` and `FWD/RIGHT` from two headings — an oscillation that was not there.
  Each correction carries the yaw it happened at.
- **It dropped the vertical component entirely.** A 0.163 m correction displayed as
  `BACK 0.053 LEFT 0.053`, components accounting for 0.075 of it; the other
  **0.145 was Y** and invisible. It prints `UP`/`DOWN`, and a `ground` line
  comparing server and client grounded, so a floor disagreement cannot hide inside
  a magnitude.
- **`replays` counts only corrections over the snap threshold**, so a client sitting
  persistently at 0.068 m looked healthy at "3 replays". The `error` line reports
  mean, p95 and max over every comparison — and that is the line that found defect 2.

**THE BASELINE IS EXACT: standing still, 300 comparisons, error 0.000 m, 0 replays.**
So any disagreement is caused by input, which is what made the queue the suspect.

**AND ONE OPEN FINDING WAS RETRACTED**: the "pawn drives itself with nobody at the
controls" sightings were most likely the owner moving in the window. Not carried as
a defect any more.

**THE JITTER THE OWNER REPORTED IS FIXED, AND IT WAS NEVER PERFORMANCE.**
`CameraRig._process` runs on the **render** frame while `LocalPawnDriver` writes
`ctx.position` at **60 Hz**, and nothing interpolated between ticks. Measured
live: **37.7 % of rendered frames showed a new position — each one was drawn 2.7
times** — while frame pacing was perfectly clean (0 of 1241 frames over 20 ms at
~157 fps). The crowd never caused it; the crowd made it **legible**, which is
exactly why an empty district looked fine.

`physics/common/physics_interpolation` is **on** now, and **37.7 % → 99.9 %**:
every rendered frame draws a new position. Frame pacing tightened as well, p95
12.06 → 7.05 ms.

**TWO NODES HAD TO BE HANDLED BY HAND AND BOTH WOULD HAVE INVERTED THE DEFECT.**
`CameraRig` **opts out** — it writes `global_position` on every rendered frame, so
interpolating it would blend toward where it was at the last physics tick. And it
now aims at `get_global_transform_interpolated()` of the pawn body rather than at
`ctx.position`: with interpolation on, the engine draws the pawn between ticks
while the simulation value still steps, so following the simulation would leave
the camera stepping against a smoothly drawn pawn — the same defect with the sign
reversed.

**AND THE INSTRUMENT READ THE WRONG QUANTITY FIRST, WHICH LOOKED EXACTLY LIKE A
FIX THAT DID NOTHING.** `global_position` still reports the last physics tick's
value when interpolation is on; the transform the renderer uses is a different
one. The probe measured 36.9 % after the fix and 37.7 % before it. It reads
`get_global_transform_interpolated()` now, and prints whether interpolation is on
at all.

**AND NPCs SIT ON THE `PAWN` COLLISION LAYER.** `npc_server.tscn` declares
`collision_layer = 2`, and `project.godot` names layer 2 **PAWN** and layer 3
**NPC**. Nothing depends on it today — pawn and NPC both mask only `WORLD`, so
they pass through each other and there is no contact of any kind — but
`TUN-SUSPICION-GAIN-NPC-BUMP` exists for the day something does, and a mask
written against `NPC` would then match nothing.

**PICK UP HERE. THE DISTRICT IS NO LONGER EMPTY: A CLIENT DRAWS THE CROWD.**
`NpcView` is the thing four unticked criteria across US-0044, US-0045 and US-0047
have been waiting for. Verified by **looking at it** — a windowed client against a
headless server draws **66 NPCs spread across 108.7 m**, and
`tools/crowd_probe.tscn` produces that picture and prints those two numbers,
because a screenshot alone cannot tell a crowd from one NPC near the camera nor a
placed crowd from seventy-eight bodies stacked on the origin.

**AND WATCHING IT FOR EIGHT SECONDS FOUND THREE MORE DEFECTS, ALL SERVER-SIDE.**
`tools/crowd_probe.tscn` samples every **drawn** NPC and reports what a still
frame cannot carry. **The one number this system is built around is now checked on
the wire: 1.400 m/s drawn against a documented stroll of 1.400** — invariant 1
holds through interpolation, which nothing had ever verified.

**THE NPC DELTA NEVER CONVERGED AND WAS INERT IN EVERY REAL GAME.** An ack lags by
at least a tick, so a record is re-sent while its first copy is in flight — and
refreshing the in-flight stamp on each re-send means the entry **always leads the
ack, is never promoted, and the NPC is sent every tick for the rest of the
match**. Measured live: a motionless NPC at a constant **7.6122 m, sent on twelve
consecutive ticks**. **Every unit test acknowledged synchronously**, one tick after
the send, which is the single timing that hides it. The entry keeps the *earliest*
tick carrying the current value now.

**A DEPARTING NPC BECAME A STATUE.** Absence cannot say "gone", and the last
position a client is told is inside the radius by definition, so its own distance
check can never fire however far the NPC walks. Eight seconds with a stationary
player produced **zero drops** — which reads like good news. The server sends
**one final out-of-range record**; the client reads that as a goodbye because the
server would never otherwise send one. Eight bytes, no protocol change.

**AND THE CULL BOUNDARY CHATTERED**, because a single threshold is not stable
against a crowd: RVO shoves a standing body at up to 0.1 m/s so a walking group
does not walk through an idle cluster. Leaving is at
`TUN-NET-NPC-CULL-RADIUS`; re-admission one margin inside it.

**AND THE RESIDUAL CHURN IS EXPLAINED AND FIXED: THE CLIENT REPLAYED EVERY
GOODBYE FOREVER.** Four to six NPCs per spawn point were created and freed about
once per snapshot at **70.01–70.05 m** against a 70.00 m radius, and it survived
one round of investigation as an open finding because **both deterministic cases
are server-side and both were quiet.** It was not the server.
`SnapshotAssembler` carries the crowd forward — correct, since absence means "no
update" — and the **farewell is the one record for which that is false**: the
server discards a culled NPC's baseline as it sends it and never mentions it
again, so the assembler cached the goodbye and re-presented it in every later
snapshot. `NpcView` read each replay as a fresh departure, spawned a body for an
index it no longer held, and freed it. **485 drops for 5 real departures across
six spawn points; 7 for 7 after.**

**NEITHER CLASS WAS WRONG ABOUT ITS OWN JOB, WHICH IS WHY EVERY TEST OF EITHER
PASSED.** The rule "a received record beyond the cull radius is the server saying
goodbye" was known only to `NpcView`, and the assembler sits **between** the wire
and the view. `CrowdWire.is_farewell()` is that rule now, one class both call.
**And the constant distance was the tell, misread as a tight band** — 70.01–70.05
is not a population near the line, it is a few records each frozen at the one
value the server sent once. Measured: **70.0231 m on 199 consecutive ticks.**

**`tools/cull_trace.tscn` FOUND IT, AND ITS FIRST VERSION REPORTED A CLEAN
BOUNDARY OVER IT.** It boots the real `server_root.tscn` and prints the
**server's** own decision about every NPC around each drop — the half
`crowd_probe.tscn` cannot see. It fed the views **raw wire snapshots**, a path no
client uses, since `Net` assembles before it emits `snapshot_received`. Two
drops, both correct, over the live defect. It also printed a perfect boundary
over **36 788 records built and 0 delivered**, because `Snapshot.deserialise` is
static and calling it on an instance throws the result away — which its
vacuous-success guard caught on the first run. TDD-04 §7.1.3.

**AND IT WAS WATCHED WITH THE FIX IN.** Four live runs, observer standing still:
the centre of the district draws **73 NPCs, 0 dropped**; `S3` draws **34, 0
dropped**; `S4` draws **18, with one departure and exactly one drop** — a clean
farewell at 70.027 m. Drawn speed 1.400–1.514 m/s against a stroll of 1.400.
**The level-data blocker is visible on screen for the first time**: a player at
`S4` can see 18 NPCs in the whole district against 73 at the centre.

**TWO OF THOSE RUNS SHOWED THE PAWN MOVING WITH NOBODY AT THE CONTROLS, AND IT IS
NOT EXPLAINED.** The observer finished 23 m and then 41 m from its spawn point,
HUD reading `Run` at 4.50 m/s; two later runs were perfectly still. `PadSelection`
logged the identical line in all four — pedals ignored — and
**`tools/input_live.tscn` measured 0 of 240 sampled commands carrying movement and
0.00 m of travel** on the real client scene joined to a real server. So it is not
US-0090's pedals defect and not the input layer as far as anything here can see.
**Observed twice, absent twice, open.**

**`tools/input_probe.gd` NEARLY GAVE THE WRONG ANSWER, AND THE REASON IS TRAP 13
AGAIN.** It is a `-s` script, so it stands up no client scene and `PadSelection`
never runs — it reported all three pedal actions held at 1.00 while the game was
correctly ignoring them. Both true; only one about the game. **`input_live.tscn`
is the missing half**, and `crowd_probe` now prints whether the observer moved,
because every other number in its report means something different if the player
was walking.

**ABSENCE MEANS "NO UPDATE", NOT "GONE" — THE OPPOSITE OF `RemotePawns`.** That
class frees a slot the snapshot stops mentioning and is right to, because every
pawn is offered every tick. An NPC is culled, rate-LOD'd and delta-omitted, so
the same rule would **delete most of the crowd on most ticks** — and a timeout,
the tempting fix, deletes exactly the NPCs standing at an anchor, which is the
crowd's commonest state. It culls **by distance instead, one margin wider than the
server**, derived as `TUN-NET-INTERP-BUFFER` × `TUN-SPEED-SPRINT`.

**AND BUILDING THE CLIENT FOUND A DEFECT IN THE SERVER THAT NOTHING ELSE COULD
HAVE.** Culling and the NPC delta together **lost an NPC permanently**: a
standing NPC that a player walks away from and back to left the snapshot because
it was culled, its baseline survived the cull, and on return its record was
byte-identical to the one the server believed the client held. Measured at **0 of
12 returning**. The cull now invalidates the baseline it made unreachable. Neither
mechanism was wrong alone, and no test of either could see it — it took something
that consumes the crowd.

**NO NPC WEARS A PERSONA, AND THAT IS ASSERTED RATHER THAN LEFT TO DRIFT.**
`CrowdRoster` derives identity from `match_seed` and **no client is ever told the
seed** — `NET-S2C-MATCH-START` carries it and `SYS-MATCH` is M4's. Guessing would
put the wrong clone on screen, which is an anonymity leak that looks exactly like
correct behaviour. The test goes red the day a client learns the seed.

**AND THE SIZE AN NPC IS DRAWN AT WAS AGREED BY COINCIDENCE.** `GreyboxBody`
reads its capsule from a parent collider, and `NpcView` is not a pawn, so every
NPC uses the **fallback** the class itself flags as "if these are ever the values
in play, something upstream is already wrong". It happens to equal
`pawn_local.tscn`'s and `npc_server.tscn`'s colliders — three declarations, nothing
tying them together. Resize the pawn and the crowd keeps the old silhouette,
silently. That is `RISK-ANONYMITY-LEAK` in one sentence and it is asserted now.

**THE M3 GATE IS RUN, AND IT FOUND A BUDGET MISS NOBODY WAS LOOKING
FOR.** Three of US-0048's ten lines are met, **one is a measured miss**, and six are
blocked on clone meshes on the wire, animation clips and an owner at a windowed
client. **The tag is not pushed — that is the owner's call and the outstanding
items are listed in the story.**

**DOWNSTREAM BANDWIDTH IS 112 % OF BUDGET, NOT THE 97 % THIS CORPUS HAS PUBLISHED
SINCE US-0029.** `test_crowd_bandwidth.gd` did not exist — exactly as
`test_upstream_bandwidth.gd` did not exist at the M2 gate — and writing it measured
**108.0 kbit/s against 96**. §7.1's head-counts were very nearly right (41.0 near
against ~45, 29.2 far against ~30). **Its two change fractions were not: 0.776 and
0.761 measured, against 0.55 and 0.70 assumed**, and those two decide the total.

**THE RECORD WAS NEVER THE PROBLEM AND THE MULTIPLIER ALWAYS WAS.** US-0029 shrank
the NPC record 10 B → 8 B on the strength of that table and `0.55` sat unquestioned
inside it both times it was re-derived, because it looks like an assumption about
the *network* and is not one. **It is the crowd's idle duty cycle.** A strolling NPC
covers 4.7 cm per tick against a **1 cm position quantum**, so every NPC that walks
at all changes its record every tick; the fraction is simply how much of the crowd
is walking, which follows from `TUN-CROWD-IDLE-DURATION-MIN..MAX` and could not have
been known before US-0040. **And 112 % is a lower bound** — modelled navigation is
shorter than a navmesh path, so it understates how often an NPC is walking.
TDD-04 §7.1.1.

**THE FIRST CONSUMER OF `NpcPool.position_of()` FOUND IT HAD BEEN STALE ALL
ALONG.** It returned a cached array that only `set_position` wrote, and
`set_position` is called at **placement and never again** — `Steering` moves the
bodies directly from the avoidance callback. Nothing had ever read it, so nothing
was wrong; the moment `SnapshotBuilder._fill_crowd` did, a live server would have
replicated all seventy-eight NPCs **at their spawn anchors, forever**. No error,
no failing test, and the only symptom a playtester saying the crowd looked like
statues. It reads the body now.

**IT WAS FOUND BY A NUMBER BEING TOO GOOD.** The NPC delta measured **25 % of
budget** where the change fraction says 78 % of records move every tick. A delta
can only drop what does not move, so a saving that large is arithmetically
impossible — **a result better than the mechanism can explain is a broken
measurement**, and this time the program under it was broken too. Corrected, the
same test reads 112 %.

**THE CROWD IS ON THE WIRE, CULLED, RATE-LOD'D AND DELTA-ENCODED. 155 % → 112 %.** US-0030's
three culling criteria and US-0031's rate-LOD line had been unticked since M2 with
the note "there is no crowd until M3". There is one now. Priced by
`test_crowd_wire_cost.gd` on the **real builder's serialised bytes**, at the worst
of six spawn points:

| | Culled | + rate LOD | **+ delta** |
|---|---|---|---|
| Mean snapshot | 591 B | 447 B | **420 B** |
| Of a 96 kbit/s budget | 148.6, **155 %** | 114.0, **119 %** | **107.6, 112 %** |

**THE LAST COLUMN WAS 111 % AND IS NOW 112 %, BECAUSE IT IS CHARGED AGAINST A
LAGGING ACK.** The delta's baseline advances on acknowledgement, so acking the
tick you just built measures a connection nobody has — and the delta being
measured that way **never converged in a real game at all**. At a three-tick ack
(100 ms) it is 112 %, and the sensitivity is guarded now: 415 B instant, 414 B at
three ticks, 426 B at ten. Restoring the defect takes the three-tick figure to
**460 B** and both guards fire.

**AND 112 % MEASURED AGREES WITH §7.1.1's 112 % PROJECTED, BY TWO INDEPENDENT
ROUTES** — one walks a modelled crowd and counts which records change, the other
serialises the real builder's output and weighs it. They were built for different
questions and agree to one point.

**CULLING WAS NOT THE LEVER AND RATE LOD WAS.** The cull removes **11 of 78** —
the radius is 70 m and `MAP-VETRAIO` is 120 × 120 m, so most of the district is
within reach of most of it. It is still correct and still required; the money was
not there. Rate LOD took 36 points.

**THE STAGGER IS THE HALF THAT WOULD HAVE SILENTLY NOT HAPPENED.** Sending the
whole slowed band on one tick divides the **mean** by the stride and leaves the
**peak** exactly where it was — one snapshot in three carrying the entire crowd,
which is the size that has to meet an MTU. **The kbit/s figure is identical either
way**, so nothing about the budget would have revealed it. Staggered by
`(tick + index) % stride`, the shape `CrowdBands` already uses.

**§7.2's TWO NUMBERS FINALLY HAVE IDS.** "NPCs beyond 45 m at 10 Hz" has been
specified since M0 as bare prose, because there was no crowd for the rule to apply
to — the same omission `TUN-CROWD-IDLE-DURATION-MIN/-MAX` and
`TUN-CROWD-CLONE-LOCAL-RADIUS` had. **288 tunables, 31 invariants**; 30 pins the
rate-LOD radius inside the cull radius and 31 refuses a "reduced" rate above the
snapshot rate. `TuningInvariants` was split at 400 lines; `TuningInvariantsTech`
holds the wire and budget rules and `check()` is still one entry point.

**THE DELTA WAS WORTH EIGHT POINTS AND NEEDED NO PROTOCOL CHANGE.** It is small
because **0.776 of visible NPC records change every tick anyway**. And the wire
change it was thought to need was **already paid for**: remote pawns needed
`present_slots` because *absent* used to mean "gone", where for the crowd absent
already meant "no update this tick" — culling and rate LOD both omit NPCs a client
must keep drawing. **What the protocol still cannot say is that an NPC has LEFT**,
which was equally true before, and which nothing observes because there is no
`NpcView`.

**`NpcDelta` COULD NOT REUSE `SnapshotDelta`, AND THE REASON IS RATE LOD.** That
one keys a baseline per **tick**, which is right for pawns since every pawn is
offered every tick. An NPC past the rate-LOD radius is offered on one tick in
three and is therefore missing from almost every tick's baseline through no fault
of the client — a tick-keyed comparison calls it "new" every time and sends it,
which is a delta that saves nothing while reporting that it works. `NpcDelta` keys
**per NPC** and advances on the **ack**, never on transmission.

**WHAT IS LEFT IS 12 %, AND IT IS PRICED NOW: NEITHER CANDIDATE CAN DELIVER IT.**
`test_cull_radius_price.gd` sweeps `TUN-NET-NPC-CULL-RADIUS` through the real
builder, adopting each value. **The curve is FLAT** — 70 m 113 %, 67.5 m 104 %,
65 m 112 %, 62.5 m 113 %, 60 m (invariant 17's floor) 110 %. **The knob turns and
the bytes do not move**: culling from 70 m to the floor removes **22 % of the
reachable crowd (284 → 221) and about 3 % of the bytes**, because everything it
removes is beyond `TUN-NET-NPC-RATE-LOD-RADIUS` and already sent at a third, while
the worst snapshot is dominated by the **near** crowd.

**AN EARLIER VERSION OF THAT SWEEP SAID 65 m CLOSED THE BUDGET AND IT WAS WRONG
TWICE OVER** — it scaled the rate-LOD radius to the cull radius's *shipped
fraction*, making every row a function of the profile, and it carried the crowd
forward 180 ticks between rows, so the radius fell while the crowd walked. **That
was the entire gradient.** The corpus's original "culling was not the lever" was
right. What is left needs a smaller record, a lower crowd update rate, fewer NPCs
(never-do #14 forbids that first), or a bigger budget.

**AND THE OTHER CANDIDATE IS NOT ONE.** The corpus has named ADR-0007's
seed-derived far crowd as the alternative since US-0031. **ADR-0007 sets that
boundary at "≥ 70 m so it stays outside every gameplay radius" — which is exactly
where the cull already sits**, so every NPC it would stop replicating is one the
builder already refuses to send. Measured: **zero records past 70 m over all six
spawn points.** The two candidates were always one lever, a boundary; they differ
only in what the client draws beyond it. The fallback is still worth building, for
the opposite reason to the one written down — a client currently draws **empty
street** past 70 m, and a district that visibly ends at a radius tells a player
how far they can be seen from. **The 65 m change is a `TUN-` change with a
gameplay consequence and is the owner's**: it cuts invariant 17's margin over
`TUN-COMPASS-RANGE-MAX` from 10 m to 5. TDD-04 §7.1.2, ADR-0007.

**THE SERVER TICK IS MEASURED FOR THE FIRST TIME: 2.15 ms p99, 2.27 ms MAX,
AGAINST A BUDGET OF 8.0.** The gate named an instrument that did not exist —
`test_crowd_perf.gd` times `CrowdDirector.tick()`, one row of PERFORMANCE_BUDGET
§2's eight — so `test_server_tick_budget.gd` was written. Mean 1.58, p50 1.55,
p95 1.81, over 180 samples, **reproducible to three decimal places across runs**.
**27 % of budget against a table that projected 61 %.**

**IT BOOTS THE REAL `server_root.tscn`, WHICH NO TEST HAD EVER DONE** — trap 4
names the server scene specifically — and measures between `net_ticked` and
`tick_completed`, which bracket exactly the thing under budget. Six players join
through `Net.peer_joined`, the shipped path, so the pawn and snapshot stages are
real rather than idle.

**THE MAXIMUM IS ASSERTED, NOT THE p99**, because it is strictly stronger: if no
tick is over budget then no percentile can be, and a p99 over 180 samples is one
of the worst two readings whatever estimator you pick.

**FOUR OF §2's EIGHT ROWS HAVE NO CODE YET** — suspicion and detection, kill/stun,
abilities, most of scoring, together 1.08 ms of the projection. So this is not
"the budget is met"; it is **"the half that exists costs a third of what the whole
was budgeted at"**. **And it excludes snapshot serialisation**, because
`Net.send_snapshot` early-returns without an ENet peer: measured separately at
**1.26 ms for six clients** and deliberately not added, since summing a measured
number to a separately-measured one is the projection this gate has already caught
twice.

**THREE OF THE FOUR RISKS RE-SCORED WENT UP.** `RISK-ANONYMITY-LEAK` Low → Medium
(a live instance in the level data, not a hypothesis about an animator);
`RISK-ANIM-SCOPE` Medium → High (**the clip count in this project is zero**, on
either rig, with three stories blocked behind it); `RISK-BANDWIDTH` impact Low →
Medium (downstream's fix is culling or ADR-0007, neither free, where upstream's was
cheap). **`RISK-CROWD-PERF` did not move, and that is the finding**: the server half
is measured and comfortable, and the 0.10 ms margin is on the **client**, which has
no mesh and no `AnimationTree` to measure — `NpcView` exists as of US-0045, and
§11.1's client budget is animation-dominated, so the expensive part is still
absent.

**READ THIS BEFORE TRUSTING ANY NUMBER BELOW.** Six PRs landed on 2026-08-18 and
**three of them existed to correct figures this same corpus had published**: US-0045's
"6 of 78 brains stepped" (measured on a district with no players in it), US-0047's
"12 958 of 12 960" floor (a property of one anchor arrangement), and TDD-04 §7.3's
115 % upstream projection. Every one was found by measuring the thing the sentence
actually named. The numbers here are the corrected ones and were verified from a
`git archive HEAD` extraction at this checkpoint — arch 41/154/239, unit
83/748/6205 with three `pending` by design, integration 31/231/631 at 159.2 s, and
both generated artefacts reproduced byte-identical (67 anchors, 195 navmesh polygons).

**THE OPEN LEVEL-DATA BLOCKER, AND IT IS NOT THE ANCHORS.** Three of `MAP-VETRAIO`'s
six spawn points cannot hold `TUN-CROWD-CLONE-LOCAL-MIN` — **S3 has 4 seats of 8, S4
has 1, S5 has 6**. The corpus called that an idle-anchor problem. It is not one:
**S3 and S4 are in the Fondaco, and the Fondaco is empty on purpose.** GDD-05 names
it three times as "low density, few NPCs — where chases go to be resolved", gives it
3–5 NPCs in its own density table, and §2.7 puts both spawns in it by name. Raising
its anchor density to satisfy the clone minimum **deletes the one place on the map
designed to have no crowd to hide in.**

**SO THREE DOCUMENTS EACH SAY SOMETHING TRUE AND THE THREE CANNOT ALL HOLD** —
GDD-05 §2.7, GDD-05 §3/§4.4, and GDD-03 §6.3 rule 3, which is a release blocker.
Choosing between them is a design decision with an owner, and the options are
priced: move S3/S4 out of the Fondaco (the nearest legal 8-seat site for S4 is
**55 m away at (72, 52)**, which drags it to the centre and is what the anti-camp
spread exists to prevent); raise the Fondaco's density; or scope rule 3 so it does
not bind at the spawn instant. **S5 is the cheap one** — 10.8 m to a legal site,
still "Mercato Piccolo, north".

**AND MEASURING GDD-05 §2.7's OWN RULES FOUND ONE OF THEM FALSE.** §2.7 carries a
note saying rules 4 and 6 were never re-derived after the 2026-08-13 spawn move, and
both have carried a ✅ since. **Rule 4 holds** — every spawn within 25 m of a circuit
*segment*, worst 22.50 m at S3. **Rule 6 does not**: every pair is already more than
25 m apart, so the rule can only mean every pair is occluded, and **nine of fifteen
are in clear sight** — worst `S4 → S5` at **30.86 m**, the closest pair on the map.
**The cause is that `VetraioLayout.BLOCKS` holds seven masses**, four of them corner
blocks, with **no building mass in the middle of the district at all**; no spawn
position can occlude a 120 m open span. The anti-spawn-camp analysis is asserted
against geometry the greybox does not have. `test_spawn_points.gd` measures all of
it every run and `tools/anchor_census.gd` grades a change in one.

---

US-0047 built clone-parity **layer 4** — the one TDD-08 §5.1 calls the one that actually
matters. `CloneBalance` runs on the same 2 s director pass as the formations, counts
clones of each in-use persona within `TUN-CROWD-CLONE-LOCAL-RADIUS` of every player,
and re-routes existing ones to close a hole. Nothing respawns and nothing is
re-personaed.

**THE SKETCH IN TDD-08 §5.1 CONTAINED ONLY THE HALF THAT CANNOT WORK ALONE.** A clone
crosses 25 m in about **eighteen seconds** and a hole opens the instant somebody walks
out of one, so a rule that can only *fetch* is eighteen seconds behind every churn —
measured, it left a clustered player at **zero**. Each pass now **holds** first: a clone
of a thin persona already inside the region gets an anchor on this side of it, which
costs no travel time at all. Two more things were needed and neither was guessable:

- **IDLE CLONES ARE RESERVED WITHOUT BEING WOKEN.** Holding only walkers leaves a
  two-second window every pass — an idle clone near the edge ends its pause, picks a far
  anchor and is gone before anybody looks again. **91 readings of 12 960** under the
  floor. A reservation it simply finds waiting costs it nothing; cutting the pause short
  would be motion the region did not need, and motion is what reads.
- **THE DESTINATION IS KEPT A PASS'S WALK INSIDE THE BOUNDARY.** An anchor at 24.8 m is
  inside one player's radius and outside their neighbour's. The margin is
  `TUN-CROWD-NPC-SPEED-STROLL` × `TUN-CROWD-DIRECTOR-INTERVAL` — 2.8 m, **derived from
  two existing tunables rather than chosen**. It took the breaches from 75 to **2**.

**AND THE STREAM IS PREVENTED BY ACCOUNTING, NOT BY A THROTTLE.** Eighteen seconds is
nine passes, so counting only *arrived* clones sends nine to fix a hole one deep — nine
Lucerna converging on a market, which is exactly the leak the story warns about. A clone
walking into the region counts toward the minimum while it is on its way: **8 fetched on
the first pass of a starved district, 0 over the next five.** A cap would have hidden
the fact that the arithmetic was wrong.

**TWO OF ITS FIVE CRITERIA STAY UNTICKED, AND THE FIRST ONE'S NUMBER WAS MARGINAL.**
The floor was published at **12 958 of 12 960** readings; that held for one anchor
arrangement and nothing else. Fixing an unrelated level bug (US-0096: `Fondaco` got
**zero** anchors) moved the crowd from 62 anchors to 67 and took the *same code* to **248**
breaches. **The guarantee was marginal and the corpus did not say so.** The cause is the
**journey**, not supply — the clustered region holds 23.9 NPCs and **4.27 clones of each
persona** against a floor of 2. Deciding the floor on *arrived* clones and fetching to
floor+1 halved it to **100 of 12 960**, and what the rule can actually guarantee is
**"a breach is never ignored"**: of 21 short pairs the pass saw, 18 already had a clone
walking and 6 were dispatched. That is what the test asserts now. TDD-08 §5.1.4. The
second, "re-routing does not read as clones following players", has its mechanical half
asserted — the destination is a map anchor, never a player, and it does not re-aim when
the player moves — and its readable half cannot be judged, because **no client has ever
rendered a clone.** NPCs reach the wire as of US-0030; **what does not exist is an
`NpcView`**, so nothing draws one.

**`TUN-CROWD-CLONE-LOCAL-RADIUS` WAS MISSING AND NOW EXISTS.** GDD-03 §6.3 rule 3 and
TDD-08 §5.1 both say "within 25 m" and no tunable carried it — the same omission
`TUN-CROWD-IDLE-DURATION-MIN/-MAX` had, and the value is the documents' own. **286
tunables, 29 invariants**: invariant 29 pins the radius at or below
`TUN-NET-NPC-CULL-RADIUS`, because a clone held near a player must be one that player
can see. Three stale counts in the corpus said 20, 22 and 23 invariants and are corrected.

**THE THREE-MINUTE MATCH IS A UNIT TEST, DELIBERATELY.** The integration suite is at
152 s of the 180 s it is allowed and 5 400 ticks of *physics* would not fit. The crowd in
`test_clone_local_min.gd` is real — real brains, real pool bodies, the real hash — and
only navigation is modelled, as a straight line at stroll speed, which is optimistic
about travel time and cannot flatter the rule.
**`test_director_runs_layer_four.gd` is the other half**: every assertion about
`CloneBalance` would stay green with the director never calling it, which is precisely
what happened to US-0039's pool.

**US-0041 IS NOW COMPLETE: THE FAR-BAND LINE IS BUILT.**
`Steering.tolerate_drift()` scales `NavigationAgent3D.path_max_distance` by the band's
own **stride** — Near 5.0 m, Mid 15.0, Far 75.0. `path_max_distance` is the one path
query `RepathQueue` does *not* stagger, which is the spike TDD-08 §12 Q2 asks about.
**The stride is the multiplier rather than a new number**: how often an agent is thought
about and how far it may wander are the same question twice. Near keeps the engine's own
default, **captured rather than declared**, so the agents a player can watch are unchanged.
It nearly shipped inert twice — a band seed that agreed with the answer meant genuinely
Far agents were skipped and **the Far band was the only one that never got its
tolerance** (Near 5.0, Mid 15.0, Far 5.0, measured), and seeding before `Steering` had
captured the base would have multiplied **zero**. `CrowdBands` was split out of
`CrowdDirector` for it, which was at 400 lines again.

**AND THE CROWD PERF TEST WAS MEASURING A DISTRICT WITH NOBODY IN IT.** Found while
checking whether US-0047's 2 s pass costs anything. `MatchContext.pawns` was empty, so
`CrowdLod.band_of` answered Far for everything, `CloneBalance` did nothing, and the
sprinter sweep did nothing. **Six pawns now stand at the map's own spawn points**, and
every number the corpus published from that test has moved:

| | Empty district | **Six players** |
|---|---|---|
| `CrowdDirector.tick()` mean | 0.439 ms | **0.52 ms** |
| p95 (the asserted line, budget 1.75) | 0.521 ms | **0.59–0.64 ms** |
| max over 90 ticks | 0.686 ms | **1.26–1.29 ms** — was 2.16–2.43 before the spike was found |
| Brains stepping | 6 of 78 | **46 of 78** |
| Bands | 0 / 0 / 78 | **30 Near, 48 Mid, 0 Far** |

**THERE IS NO FAR BAND AT MATCH START**, so §4.1's fifteen-tick stride and US-0041's
longer path validity only apply once players cluster. The reduction is **1.7×, not
§4.1's 2.6× and not the 13× the empty run implied**. US-0048 carries that.

**AND THE SPIKE WAS ISOLATED: IT WAS THE 2 S PASS, AND IT WAS THIS SESSION'S OWN CODE.**
A max over budget with p95 under it is one expensive tick, and exactly one thing happens
on some ticks and not others. Partitioning the samples *while they are taken* — so the
two subsets sum to the whole — put pass ticks at **1.925 ms against ordinary ticks'
0.500**. `CloneBalance` was asking the same question twenty-four times for six answers:
which anchors are in a region, who is standing in it and how many of each identity are
all properties of the **region**, not of the persona being served. Hoisting the anchor
list and the grid query to one per player took the pass to **0.71 ms** and the whole-tick
max to **1.26–1.29 ms — inside budget, max included**. An A/B against `personas_in_use`
puts layer 4 at about 0.46 ms of that 0.71.

**A THIRD CHANGE BOUGHT NOTHING AND IS RECORDED ANYWAY.** Squared distances throughout,
matching `SpatialHash`: 0.710 → 0.712 ms, inside run-to-run noise. Kept because it is
correct and cheaper in principle; written down because a change that was expected to help
and did not is worth as much as one that did. **§11.2's 0.05 ms row for the pass is still
missed by 14× and is amended rather than chased** — it was written before formations,
corpses or clone balancing existed, and the number that matters is the total.

**US-0096 SEATS THE CROWD, AND FOUND THE MAP CANNOT SATISFY RULE 3.** `CrowdPlacement`
deals round-robin over idle anchors with no persona awareness; `CrowdRoster` derives
identities with no idea where anybody stands. Both are seeded, both correct, and
**nothing joined them** — so a match could open with every Lucerna in the north and a
Lucerna player spawning in the south. `CrowdSeating` is that join, as a **permutation**:
the multiset of positions is unchanged, so the navmesh snapping, the anchor round-robin
and the scatter bound cannot regress. 18 short (spawn × persona) pairs become 9.

**THE NINE THAT REMAIN ARE PHYSICALLY IMPOSSIBLE, AND THAT IS THE REAL FINDING.** Four
personas at the minimum need **eight clone seats** within 25 m. `MAP-VETRAIO` offers
12, 15 and 10 at three spawn points — and **3, 6 and ZERO** at the other three.
**(114, 97.5) can see no NPC at all**, so a player spawning there starts with zero clones
*and* on open ground for `TUN-SUSPICION-GAIN-OPEN`: alone, uniquely identifiable, before
they can move. GDD-03 §6.3 rule 3 is a **release blocker** and it is the **idle anchors**
that fail it. Reported rather than failed, like US-0043's 0.51 m circuits — re-authoring
anchors is the owner's. `test_crowd_seating.gd` asserts **zero shortfalls where there is
room** (7 → 0) and prints the seat census every run.

**AND THE TAKE SIDE NEEDED THE SAME GUARD AS THE GIVE SIDE.** The first working version
left 2 of 7, both at the last spawn points processed: the give side refused to hand over
a clone somebody else depended on, the take side happily conscripted one. Same asymmetry
`CloneBalance._nearest_spare` was designed against, written the wrong way anyway.

**M3'S REMAINING WORK IS US-0048, THE GATE**, and eight of its ten lines are still
blocked on things that do not exist — clone meshes on the wire, animation clips, and an
owner at a windowed client. The two that pass are `test_crowd_perf.gd` and
`test_clone_local_min.gd`.

---

**EARLIER, AND STILL TRUE: THE SERVER CROWD IS FEATURE-COMPLETE.**
US-0039 built the pool and roster, US-0040 the brain, US-0041 the navmesh and the
steering under it, US-0042 the shared spatial hash, US-0043 the four walking
groups, US-0044 the startle wave, the gawk cluster and the corpse, US-0045 the
LOD bands. **US-0048's `test_crowd_perf.gd` was written before US-0045**, so LOD
had a number to move rather than a hope. A server logs `NpcPool: 90 bodies allocated` and
`crowd placed: 78 NPCs across 62 anchors`, and the seventy-eight now stroll
between idle anchors, stand at them for 8–25 s, and walk round each other.

**US-0041 IS DONE BAR ONE LINE, AND THAT LINE IS NOW UNBLOCKED.** Far-band path
validity needed the Near/Mid/Far bands; US-0045 built them, and
`CrowdDirector.band_of(index)` answers. **It is unstarted rather than blocked**,
and it is the cheapest open crowd item left — a Far agent wants a larger
`NavigationAgent3D.path_max_distance` so it recomputes less often. Nobody has
written that line.

**PICK UP AT US-0047** (clone local minimum) — `SpatialHash.count_persona()` has
been waiting for it since US-0042, it needs no art, and TDD-08 §5.1 calls it
"the one that actually matters": global sufficiency with a local hole is the
failure a player cannot see. It is also **layer 4 of the four US-0046 half-built**.

**US-0046 IS THREE OF SEVEN, AND IT CONTAINED SOMETHING IT NEVER MENTIONED.**
Four documents point at US-0046 for "the meshes" — US-0039's omission table,
US-0044, US-0045 and TDD-08 §11.1 — while ART_BIBLE §6.1 says the four greybox
personas belong to **US-0039**, which shipped without them. `SCOPE_FENCE` IN #3
makes them an **M3 deliverable**. So they were owned by no story's acceptance
criteria, which is how a scope item goes missing without anything failing. They
are built now, as `PersonaBody`: procedural from primitives, one per §6.1 row.

**NOTHING WEARS ONE YET, AND THAT IS THE HONEST HEADLINE.** The pawn still wears
`GreyboxBody`, because nothing chooses a persona for a player — there is no lobby
and `NET-C2S-LOADOUT` is M4's. NPC records reach the wire as of US-0030, but
`NpcView` draws the crowd as of US-0045 — but **in grey capsules**, because
`CrowdRoster` derives identity from `match_seed` and **no client is ever told the
seed**. Guessing would put the wrong clone on screen, which is an anonymity leak
that looks exactly like correct behaviour, so it is asserted rather than risked.
The four exist and render in `tools/persona_lineup.gd`; the district is still
empty on every client.

**THE FIRST RENDER OF THEM FOUND A DEFECT NO ASSERTION WOULD HAVE.** Lucerna's
pole floated detached beside the figure: §6.1 says "cylinder pole 0.9 m above
head", which is where its *top* goes, and a 0.9 m cylinder put the whole thing in
the air. It runs from hand height now. `tools/persona_lineup.gd` produces that
picture and **refuses to run headless**, because a blank PNG reads exactly like a
bad model — trap 13. Run it after any change to a persona:

```bash
godot --path . -s res://tools/persona_lineup.gd
```

**AND §6.1 MAKES TWO DIFFERENT WIDTH CLAIMS THAT MUST NOT BE CONFLATED.** Vetraio
is `LOW_BROAD` — ×1.4 at the **shoulders**, 0.98 m against Cantatrice's 0.43.
Cantatrice is `FLOOR_TRIANGLE` — widest at the **ground**, 1.05 m against
Vetraio's 0.70. The first silhouette test asked which figure was widest *overall*,
got Cantatrice, and read like a modelling error; the assertion was too crude.

**Still blocked on art that no story authors:** US-0045's three client-LOD lines,
US-0044's "reads directionally *to a human observer*", US-0046's own layer 3 (no
`AnimationTree` to hook), the idle cycler, and footstep parity (`Audio.play()` is
a stub until US-0075). **There are no animation clips in this project on either
rig**, and ANIMATION_SPEC §8 costs the parity set alone at 14 × 4 × 2.

**WHAT THE MEASUREMENTS SAY, AFTER TWO STORIES OF MEASURING:**

| | §11.2 budget | **Measured**, 78 NPCs |
|---|---|---|
| Spatial hash rebuild | ≤ 0.15 ms | **0.054 ms** |
| `NpcBrain.step()` × all 78 | ≤ 0.50 ms for ~34 | **0.046 ms** |
| Everything inside `CrowdDirector.tick()` | — | **0.54–0.57 ms** with six players; 0.44 with none |
| Effective brain steps | ~34 of 90 | **46 of 78** — 30 Near, 48 Mid, **no Far at all** |
| Crowd movement, per physics frame | ≤ 0.60 ms | **not measurable — see below** |
| Physics frame, **wall clock** | — | **16.73 ms** full, 16.56 with no crowd, deadline 16.67 |

**THE DECISIONS ARE ALMOST FREE.** The whole crowd stage — hash, brains, goals,
repath queue, formations — is under half a millisecond, well inside §11.2's
1.75 ms, and reproducible to two decimal places across runs.

**CROWD MOVEMENT COULD NOT BE MEASURED, AND A FIGURE FOR IT WAS PUBLISHED WRONG.**
`Performance.TIME_PHYSICS_PROCESS` gave **31 ms**, then **5.69**, then **24–28**
for arrangements whose wall clock never moved off 16.73 ms. A cost larger than
the frame containing it is a **broken instrument**, not a slow frame. PR #95 and
TDD-08 §11.2.1 briefly carried the 5.69 ms figure; **it should not be quoted**,
and §11.2.1 now says so. Getting a trustworthy per-item movement cost needs a
profiler this project does not have — owed, not estimated. What is coherent: the
server keeps up, with the full crowd, against a 16.67 ms deadline.

**§4.1's LOD SAVES A FIFTH OF A MILLISECOND, AND IS STILL WORTH BUILDING.** The
reduction was published as "6 of 78 effective brain steps, not ~34 of 90" and
**that number was measured on an empty district** — US-0047 found that
`test_crowd_perf.gd` stood up no pawns at all, so every NPC banded Far and 6 is
just 78 divided by the Far stride of 15. With six players at the spawn points it
is **46 of 78: 30 Near, 48 Mid and no Far whatsoever**, because six spawn points
on a 120 × 120 m map leave nothing beyond 45 m of somebody. So the reduction is
**1.7×, not §4.1's 2.6× and not the 13× the empty run implied**, and the Far
band exists only when players cluster. It is still worth *less* than §4.1 hoped,
because the brains were 0.046 ms to begin with. It is built for ADR-0003, and because it **unblocks US-0041's
far-band path validity**. US-0045 says that rather than claiming a win it does not
deliver.

**AND LOD NEARLY CHANGED BEHAVIOUR TWICE, INVISIBLY:**

- **A banded brain's timers.** Stepped every fifteenth tick and decremented by
  one, an 8–25 s idle pause becomes 120–375 s. `NpcBrain.step()` takes a
  **`stride`** for exactly this. The only symptom would have been a distant crowd
  standing unusually still, which reads as atmosphere.
- **Events raised on a tick the brain did not think.** Clearing `CrowdContext`
  every tick regardless — the first version — wipes a `startle_flag` before
  anybody reads it, so **LOD would have silently dropped startles and gawk tokens
  for two thirds of the crowd**, worse the further away you are. Startle is the
  one interrupt the design requires to be *reliable*.

Both are behaviour changes wearing a rate change's name, which is what ADR-0003
forbids. Neither would have produced an error, a log line or a failing test.

**AND LOD WAS THE FIRST THING TO READ `ctx.tick`, WHICH FOUND TWO MORE HARNESSES
THAT NEVER ADVANCED IT.** `test_crowd_moves.gd` and `test_walking_groups.gd` both
ticked the director without incrementing `ctx.tick`, so the band stagger —
`(tick + index) % stride` — made only every fifteenth NPC ever eligible to think.
The symptom was twelve NPCs holding formation slots with one of them in the
state. `IntegrationHarness` had exactly this defect from US-0036 to US-0031:
**zero is a plausible tick**, and it stays invisible until something reads it.

**WHAT THE CROWD CANNOT DO YET.** All five states are reachable, LOD bands them
(US-0045) and their records now go **on the wire**, culled, rate-LOD'd and
delta-encoded (US-0030, US-0031), **and a client draws them** (US-0045). What it
draws is **grey capsules**: there is no mesh, no `AnimationTree` and no persona,
because the roster needs a `match_seed` no client is told. And there is **no
violence**, since kill and stun are M4 — a sprinting player is the only thing in a
live match that startles anybody. The crowd is real, replicated, drawn, and
anonymous in the wrong way: every NPC looks like every other.

**US-0044 IS SIX OF SEVEN, AND THE SEVENTH NEEDS A HUMAN.** "Startle waves read
directionally **to a human observer**" cannot be judged without rendered clones,
and NPC meshes are US-0046. The mechanical half is measured — 13 of 13 startled
NPCs sent away from the violence — and the criterion is left unticked, the same
treatment M1's feel gate got. Four things in it are worth carrying:

- **THE DIRECTION LIVES IN THE FLEE VECTORS, NOT IN THE SHAPE OF THE SET.** The
  startled set is a disc with a soft edge; what a distant player reads is people
  *running*, each away from whatever scared them, so the vectors diverge from a
  point and the point is recoverable. A **propagated** NPC flees the neighbour who
  scared it rather than the violence, which is why some cross the original point
  — that is the decay, and it is why the front thins unevenly instead of
  expanding as a ring. An assertion that every startled NPC moves away from the
  *violence* is therefore false, and measured one fleeing "toward" it before the
  test was corrected.
- **TWO EXPLICIT ROUNDS, BECAUSE GDD-03 §6.4's RECURSION CAPS THE AGENT AND NOT
  THE WAVE.** Every startled NPC propagating once bounds nobody: on a dense crowd
  the wave walks to the canal. TDD-08 §3.2 already claimed "two hops", so that is
  what is built, and the reach is asserted.
- **`has_propagated` CLEARS ON LEAVING `STARTLE`, NOT ON ENTERING IT.** Set once
  per wave, kept while still fleeing so a re-startle buys no second round, cleared
  on the way out. Uncleared — which is what it was, since `reset()` was the only
  thing that touched it — an NPC would propagate exactly **once per match**, and
  the crowd would grow quieter as the match went on with nothing reporting it.
- **A GAWKER WALKS TO THE BODY, AND THAT IS WHAT MAKES THE CAP MEAN ANYTHING.**
  `TUN-CROWD-GAWK-MAX` exists so a corpse cannot depopulate a blend pocket — and
  an NPC that never left the pocket could not depopulate it however many tokens
  went out. Without the walk, the pocket-preservation criterion is **vacuously
  true**. Its test asserts the counterfactual first: twelve NPCs eligible against
  a cap of six.

**AND THE SHARED HASH IS EMPTY UNTIL THE FIRST TICK.** `startle_at` and
`register_corpse` query the grid `_reindex` rebuilds at the top of the `crowd`
stage; called before any tick they find nothing and startle nobody, **silently**.
Safe in production for a reason worth stating rather than relying on: `SYS-KILL`
resolves at the `combat` stage, four positions *after* `crowd`.

**US-0043 IS FOUR OF SIX, AND BOTH OPEN CRITERIA ARE THE LEVEL'S, NOT THE
CODE'S.** A real server logs `processions formed: 16 NPCs across 4 of 4
circuits` — 16 of 78, exactly as GDD-05 §5.2 intends. Two findings came out of
the map data before a line of the story was written:

- **THE CIRCUITS ARE 150–237 M LONG AND THEIR PERIODS SAY 55–75 S**, which is
  **2.6–3.2 m/s** — roughly twice `TUN-CROWD-NPC-SPEED-STROLL` and faster than
  `TUN-SPEED-RUN`. Three documents cannot all be true. The **speed** is what the
  implementation honours, because the walking group is the only blend that lets a
  player *travel* while gaining anonymity and at twice blend-walk it is a speed
  cheat wearing a crowd. `CrowdCircuit` is parametrised by **distance** and
  `period_at()` is a read-out; a lap comes out at 107–169 s. **The fix is to
  shorten the routes**, which is level design with an owner.
- **CIRC-A AND CIRC-B PASS WITHIN 0.51 M**, against GDD-05 §5.2's 8 m. **Geometry,
  not timing**: both run along z = 45 through the Loggia spine, so re-timing them
  moves the closest approach by 15 cm. `test_circuit_separation.gd` reports it
  rather than failing, and goes green by itself once the routes are re-authored.

**AND AN AGENT THAT HAS ARRIVED STOPS AVOIDING.** The afternoon US-0043 lost, and
the most portable thing in it. A `NavigationAgent3D` whose `target_position` it
has reached — **or never had** — answers `velocity_computed` with **exactly
zero**, whatever `set_velocity()` was handed. Formation members were driven at
1.4 m/s straight at their slots and stood perfectly still while the slots walked
away; the desired velocity was right, the bodies were on the floor and in the
right state, and nothing errored. Group members now aim at a point **one rebalance
interval ahead on their circuit**, refreshed through the repath queue when they
get there: never finished, so avoidance keeps running, at about a third of a
query per tick instead of sixteen.

Two more decisions worth carrying:

- **A procession waits for its stragglers.** Slot and member both move at exactly
  stroll, so any lag is never closed and the group sheds people it can never take
  back. `CrowdFormations._pace` throttles the formation by the worst lag, because
  the alternative is a clone breaking into a jog — which is a clone a player
  cannot imitate.
- **The district starts with its processions already walking.** Recruitment picks
  up about four people per *lap*, so the groups would be missing for the first
  minute or two of an eight-minute match. `form()` seats them at match start and
  refuses to form a group the crowd cannot spare.

**US-0042 IS DONE: ONE GRID, FOUR CONSUMERS, 0.0561 MS.** A counting sort over
buffers sized once, so a rebuild allocates nothing — measured at **37 % of
§11.2's 0.15 ms budget**, which is what closes TDD-08 §12's third open question
in favour of correctness over double-buffering. Three things in it are worth
carrying:

- **The cell size is READ from `TUN-SUSPICION-OPEN-RADIUS`, not declared as
  6.0.** The criterion is that the two are the *same number* — a literal stops
  satisfying it the first time the radius is retuned, and nothing would say so.
- **Two empty answers agree.** Every brute-force comparison also counts how often
  it found *anybody* and fails if that number is low, because a hash returning
  nothing at all matches brute force whenever brute force found nothing — which
  on random points is most of the time. Trap 3's family, designed out.
- **A hash built once at setup passes every unit test in its own file.** The
  count is right forever; only the *positions* go stale. The one assertion that
  separates the two lives in `test_crowd_moves.gd`: after thirty ticks of
  walking, every NPC must be findable **at its own feet**.

`nearest_distance()` takes a **bound** and returns `INF` outside it, deviating
from TDD-08 §6's signature: unbounded, it must widen until it finds somebody,
which is a full crowd scan per pawn per tick arriving exactly when the district
is emptiest. TDD-08 §6.1 records that and two other amendments.

**THE NUMBER THAT MATTERS IS 1.400 M/S AGAINST A DOCUMENTED STROLL OF 1.400.**
"The NPCs moved" is satisfied by NPCs moving at any speed at all, and the crowd's
speed is its one load-bearing number: invariant 1 forces
`TUN-CROWD-NPC-SPEED-STROLL` to equal `TUN-SPEED-BLENDWALK` so that a
blend-walking player is indistinguishable from the crowd **by motion**. A crowd
at any other speed passes every other assertion and is a silent
`RISK-ANONYMITY-LEAK` — discovered by a playtester saying the clones look slow.
It nearly happened twice:

- **`NavigationAgent3D` emits `velocity_computed` EVERY PHYSICS FRAME** once
  avoidance is on. Measured, not assumed: nine callbacks over ten frames after a
  *single* `set_velocity()`. So the body is moved there, at 60 Hz, and only the
  *desired* velocity is chosen at the 30 Hz net tick. Moving it from the tick
  instead halves every NPC's speed in silence, because `move_and_slide()` always
  integrates by the **physics** delta whatever rate you call it at. Trap 9's
  family, in a new domain.
- **RVO MAY PICK ANY VELOCITY UP TO `max_speed`, NOT UP TO THE ONE IT WAS ASKED
  FOR.** Left at the flee speed, a *strolling* NPC dodging a neighbour sidestepped
  at **2.24 m/s**. `Steering.drive()` now sets `max_speed` from the state's own
  speed every tick, with a 0.1 m/s floor so a standing NPC is still shovable —
  at exactly zero a walking group would walk *through* an idle cluster.

**AND ONE NPC SPENT EVERY RUN STANDING ON A MARKET STALL.** `Npc003` at
(38.3, **0.90**, 18.6): inside StallA's footprint, on top of the counter, on the
navmesh, on the floor, and unable to leave — the exact failure
`CrowdPlacement`'s own docstring exists to prevent, wearing a disguise. It was
not *off* the mesh; it was on a piece of mesh nothing can reach.
**`map_get_closest_point` is a 3D nearest-polygon query and knows nothing about
connectivity.** `agent_max_climb` decides whether a stall top is *linked* to the
street and does nothing at all to stop a nearest-point query landing on it. The
fix is to ask for the snap from `H_VAULT` **below** the point, which biases the
answer to the street; a height gate and an explicit `NAV_MAX_CLIMB` 0.4 sit
behind it. **The idle anchors are still generated on a grid with no obstacle
filter**, so some sit inside stalls — recorded in US-0041, not fixed there,
because filtering them changes the per-zone density a unit test asserts.

Nothing animates or replicates the crowd, so US-0030's four culling criteria and
US-0031's two still wait for NPCs *on the wire*.

**TDD-08's OWN FILE TABLE AND TEST TABLE WERE AUDITED AT THIS CHECKPOINT, AND
BOTH WERE PARTLY FICTION.** §10 named nineteen tests of which **fourteen did not
exist as files** — some covered under another name, some genuinely future work,
and the table said nothing about which. §9 listed
`scripts/systems/crowd/npc_states/*.gd`, "5 state handlers", for a machine
ADR-0003 deliberately built as a flat table; the directory existed empty since M0
and was never tracked by git, so it was not even in a clean checkout. Both tables
now carry a state column naming the file that actually asserts each row, or the
story that will write it. **Trap 14's fourth instance, and the first one found by
looking for it rather than by tripping over it.**

**US-0095 CLOSED HALF THE GATE'S UPSTREAM FINDING.** `NET-C2S-INPUT` was going
out as six loose RPC arguments — Godot variant-encodes those at **56 bytes**
against a budgeted 9 — and is hand-packed into 12 now. **253 % → 145 %.**

**What is left is packet overhead, and it is 84 % of the budget on its own.**
28 B × 60 Hz is 13.4 kbit/s before a single byte of payload, so coalescing two
commands per packet is now the right next step and lands at **91 %, under
budget** — which it would not have done before, when it left the miss at 211 %
for 16 ms of input latency. Not built: that is a feel decision, not a bandwidth
one.

**The gate's own projection was too optimistic and is corrected.** US-0038 said
hand-packing would reach 115 %; it reached 145 %, because a `PackedByteArray` RPC
argument costs **8 bytes of Variant wrapper plus the payload rounded up to
four**. A projection is not a measurement — and that one was a projection made a
layer *above* the thing it described, which is the same mistake §7.3 made a layer
below.

The rest of this section is why each of those sentences is true, and what has
already cost somebody an hour.

**M0 IS COMPLETE. M1'S EXIT CRITERION IS MET AND ITS FEEL GATE IS PASSED**, judged
at the controls on 2026-08-13: slowing instant from every state, the FOV ladder
perceptible without discomfort, and **ten of ten sloppy vaults resolved**. One
player walks, blends, runs, sprints, climbs and vaults locally. **M2 may begin.**

**US-0024 REMAINS `in-progress` ON TWO CRITERIA THAT CANNOT BE MADE TRUE HERE** —
input→animation needs an animation, and "with prediction active" needs US-0032 in
M2. They stay unticked rather than rounded up.

**M1 IS 11 DONE + 1 OPEN.** US-0013 to US-0023 are
`status: done`; **US-0024 is `in-progress` and everything buildable in it is
built.** One of its four criteria is met (the commitment ceiling). The other
three are blocked, each by something real:

- **Input→animation cannot be measured.** `test_feel_latency.gd` exists and
  reads 16.7 ms slowing down, 33.3 ms accelerating from rest — three of the five
  stages `FeelChain` declares. `ANIMATE` has no clip to change pose and `PRESENT`
  has no display in headless CI. **The number is a lower bound and says so.**
  `test_feel_chain.gd` holds a tripwire that goes red the day a clip lands.
- **"With prediction active" needs prediction**, which is US-0032, in M2.
- **The feel-gate checklist is the owner's, and ALL THREE LINES ARE NOW JUDGED AND
  PASSED (2026-08-13).** On 2026-08-13 the owner logged *slowing is instant* and *the FOV
  ladder is perceptible without discomfort*, and settled
  `TUN-SPEED-RUN-RESOLVE` at 0.15 s — the one number in US-0090 chosen rather
  than derived. **The vault count came in at ten of ten**, without any change to
  the forgiveness windows — which is the strongest thing the gate says about
  them. The centred framing from US-0092 was judged with the lens and accepted.

**M1's gate is passed. The remaining M1 work is nothing** — US-0024's two open
criteria wait on an animation that does not exist and on prediction, which is
US-0032 in M2.

**M2 HAS STARTED. US-0025 IS BUILT AND THE TRANSPORT IS UP.** A dedicated server
listens on three ENet channels, a client dials in with `--connect`, and the
`NET-C2S-HELLO` / `NET-S2C-WELCOME` handshake completes — verified by hand across
two real processes on 2026-08-14, because **no automated test in this repo can
reach it**: `Net` is an autoload, one process holds one of it, and an RPC
resolves by node path, so a second `Net` could not answer the first. That round
trip is US-0036's harness. The story leaves its last criterion unticked and says
so.

**The decisions are pure and the wiring is not.** `Handshake` and `Messages`
hold every branch that decides something — the channel a message rides, whether
a peer is admitted, whether the server must correct its tuning — with no socket,
no node and no autoload, so five of seven criteria are proven by tests that
stand nothing up. Three things worth knowing:

- **A socket is not a player.** `Net.player_count()` counts peers that finished
  the handshake, never peers that merely connected.
- **`Handshake.check()` cannot see the tuning hash.** Not a rule written in a
  comment — there is no argument through which tuning could ever refuse a peer.
  A mismatch is answered with `NET-S2C-TUNING-SYNC`, and `Tuning.adopt()`
  validates every invariant before installing it.
- **RTT has two sources on purpose.** The server reads ENet's own statistic; the
  client smooths its own pongs. `client_time` is forgeable, and lag compensation
  rewinds by an amount derived from RTT — an RTT a client could inflate is an
  RTT a client could use to reach further into the past.

**THE HAND RUN FOUND SOMETHING THE SNAPSHOT WILL HAVE TO ANSWER.** Godot's peer
ids are 32-bit random numbers — the test client was welcomed as peer
**1526710570** — and both protocol tables declare `peer_id:u8`. Nothing is
broken yet because nothing is hand-serialised, but US-0029 cannot pack that into
a byte. Either the server maps peers onto small slot numbers for the wire, or
the schema is wrong. Recorded in US-0025, not decided.

**US-0026 IS BUILT: THE AUTHORITY CHOKEPOINT EXISTS.** Every inbound client
message arrives at `RpcRouter`, is authorised there, and reaches a system only
as a signal — so the router does not know `SYS-COMBAT` exists and does not
change when one is added. The decisions are pure again: `Authority` holds §6.1's
authority column as a table, `SequenceGate` holds one `u16` per peer.

- **Warmup is not playing.** Input is legal in ACTIVE and FINAL only. A pawn
  exists in warmup, so only the phase stands between an input and the
  simulation — which is why phase is checked rather than inferred from the pawn.
- **The `u16` sequence wraps every ~18 minutes, inside a match.** A gate written
  as `seq > last` passes every test anyone would think to write and then rejects
  *every input for eighteen minutes*, on a server logging nothing. `is_newer()`
  compares the signed distance in modular arithmetic, and both edges of the
  window are asserted.
- **The router keeps its own roster.** Asking `Net.has_player()` made three
  tests true for the wrong reason — every assertion collapsed to "not a player",
  which stays true with pawn tracking deleted. State the router owns is state a
  test can set.

**TWO GUARDS TDD-04 PROMISED IN M0 WERE FINALLY WRITTEN**, and the first one
found zero handlers and passed. `SourceScanner.code_lines()` strips string
literals so a guard is never tripped by its own documentation — and the thing
being matched *is* a literal, the `"any_peer"` inside the annotation. **A guard
that scans the wrong way is vacuously green forever**; trap 3's family, third
instance. Both are falsified against planted violations now:
`test_no_client_authority.gd` (a handler with no `_authorise`, and a handler
that acts before authorising) and `test_client_cannot_assert_outcome.gd`
(`damage:u8` added to a C2S row in the catalogue).

**AND `.ci/run_gut.sh` CAUGHT ITS FOURTH SILENT SKIP** — 48 scripts ran, 51 exist
on disk, because three new test files had never been imported. Run
`godot --headless --editor --quit-after 150` after adding a test file.

**US-0027 IS BUILT: THE SERVER HAS A CLOCK AND AN ORDER.** `MatchDirector`
fires one net tick every second physics frame — **derived, never timed**. An
accumulator that fired when `delta` passed 33.3 ms drifts, fires twice after a
hitch, and gives two machines different tick counts for the same match; a count
of frames divided by two is exact. 10 000 frames are 5 000 ticks, asserted.
`ctx.elapsed()` is derived from the tick for the same reason — a clock read from
`Time` would give "how long is left" two answers, one the players see and one
the scoring uses.

- **The pawn substep is the one thing that is not 30 Hz, and it is not an
  optimisation.** The client predicts twice at 1/60 with a decision between the
  two steps; a server integrating once at 1/30 diverges on every acceleration
  curve, immediately and permanently at `TUN-SPEED-ACCEL` 18 m/s². The server
  steps once per received `InputCommand`.
- **The order is parsed from TDD-01 §4's diagram**, so the document is the
  authority. Systems registered backwards still tick crowd → suspicion →
  detection.
- **`ingest`, `pawn` and `snapshot` are positions, not systems.** Registering a
  `GameSystem` under one is refused: it would run in the right place by accident
  and hide that nothing owns it.
- **`GameSystem` and `MatchContext` are NOT in Core**, though TDD-01 §6's file
  table puts them there. `GameSystem extends Node` and Core is pure by law.

**THE NEW GUARD CAUGHT `Net._process` ON ITS FIRST RUN** — the ping heartbeat
written four hours earlier in US-0025. A heartbeat on rendered frames samples RTT
144 times a second on one machine and 12 during a hitch, feeding a smoothing
filter whose window is then different on every machine. Moved to
`_physics_process`. **Nothing server-side may declare `_process` at all**, and no
`GameSystem` may tick itself.

**US-0028 IS BUILT: THE SERVER SIMULATES PAWNS, AND LANDS WHERE THE CLIENT
DOES.** A peer joins, `PawnHost` spawns `pawn_server.tscn` at a declared spawn
point, and every command that peer sends is applied through the same state
machine the client predicts with. Verified across two processes — a client
dialling in now produces `pawn spawned for peer 48400797 at (12, 0, 36)` on the
server.

**THE STORY'S REAL CONTENT IS `PawnMotion`.** ADR-0008 required the two peers to
run the same `PawnStateMachine`, and they always did — **that is only half a
tick.** The other half is the fifteen lines deciding who owns position during a
traversal, when gravity applies, and what is written back from the body, and
they lived in `LocalPawnDriver` alone. A second copy for the server would have
been a divergence in prediction with a green suite either side of it: **every
unit test calls `step()` directly and never reaches that code**, which is trap
7's family and exactly how US-0019's vault computed a perfect arc and moved
nothing. Both drivers now call `PawnMotion.advance()`, and
`test_substep_matches_server.gd` asserts the two land in the **same place** —
not merely within `TUN-NET-RECONCILE-THRESHOLD`.

**A missing command repeats the last one rather than stalling.** A stalled pawn
produces a position the client cannot have predicted — it kept walking — so
every dropped packet would guarantee a reconciliation, and a lossy connection
would stutter continuously against a server that was merely being careful. A
peer that has *never* sent a command is not stepped: `InputCommand.empty()` is
not "standing still", it is "we have never heard from them".

**TRAP 4 AGAIN, IN THE SAME SHAPE AS US-0019.** `test_pawn_host.gd` failed on
its own probe assertion the first time it ran, and the failure was worth more
than the test: `PawnHost` in isolation has no world geometry, so every pawn in
that file was **falling** — and "the pawn moved more than half a metre" was
passing on it. The file loads the map's collision now, asserts the travel
horizontally, and asserts the pawn is still grounded at the end.

**US-0029 IS BUILT AND ITS THIRD CRITERION IS DELIBERATELY UNTICKED.** The
wire format serialises, deserialises and round-trips; the information rules live
in the format rather than in a widget, so a hunter's snapshot has **no field** for
their contract's persona, position, elevation or tier — asserted structurally,
because a rule that lives in a widget can be broken by a different widget.

**PEER IDS NEVER REACH THE WIRE.** Godot hands out random 32-bit ids and the
catalogue declares `peer_id:u8` in seven places. The catalogue is right: six
players fit in three bits, and the byte is what the bandwidth budget was written
against. `SlotTable` maps one to the other and **slot 0 is reserved to mean
nobody**, so a record never filled in decodes as absent rather than as player
one.

**THE BANDWIDTH BUDGET DID NOT CLOSE, AND THE FORMAT WAS NOT THE PART THAT WAS
WRONG.** TDD-04 §7.1 budgeted 7 bytes per NPC and 14 per remote pawn. **An NPC's
index and position alone are seven**, before its yaw and animation. Measured
from `Snapshot.serialise()`: NPC 10 B, remote pawn 10 B, fixed part 53 B against
a budgeted 25. §7.1's own worst case on the measured sizes came to **108.3
kbit/s against a 96 budget — 113 %**, where the document concluded 87 %.

**THE CROWD RECORD WAS SHRUNK RATHER THAN THE BUDGET MOVED** (#71). The crowd is
90 of the ~96 replicated entities, so it is the only place the money is: an NPC's
`y` is a **byte at 5 cm** rather than an `i16` at 1 cm, and its animation is
`u3 + u5` in one byte rather than `u4 + u6` in two. Ten bytes to **eight**, and
the projection closes at **93.0 kbit/s — 97 % of budget**. Nothing a player can
perceive changed: nothing reads a crowd member's height, and 32 animation phase
steps are finer than a walk cycle can be read at 45–70 m. Player records keep
their centimetre in all three axes, because a player's elevation is gameplay.

**The lesson is the arithmetic, not the bytes.** A budget table whose per-record
sizes were never measured against the format they describe reports whatever its
author expected. `test_snapshot_size.gd` measures every record and recomputes
§7.1's total on every run.

**THE LOOP IS CLOSED.** Two clients connect, each gets a server pawn, input
goes up and a snapshot comes back, and **each player sees the other appear**.
Verified across three processes on 2026-08-14; `test_the_loop_closes.gd` drives
both halves against real objects in one.

**THE CLIENT COULD NOT SEND ANYTHING AT ALL, AND US-0026 NEVER NOTICED.** Godot
addresses an RPC by **node path** and the receiving peer looks up the same path —
`/root/ServerRoot/NetServer/RpcRouter` does not exist on a client, so there was
no node to call it from and `NET-C2S-INPUT` was unsendable. The whole authority
chokepoint was built and nothing had ever reached it. The handshake worked only
because `Net` is an autoload at `/root/Net` on **both** peers.

**The doorway moved to `Net`; the decision stayed with the router.** Every
handler calls `RpcRouter.authorise()` first — public now, because a
private-by-convention method called from another object is worse than an honest
public one — and `test_no_client_authority.gd` still refuses one that does not.
**The general answer, worth knowing before the next surface needs one: anything
the `Net` autoload creates in `_ready()` is at the same path on every peer too.**
`PingClock` is the first to use it.

**AND THE FIRST TWO-PROCESS RUN FOUND ANOTHER.** `NET-S2C-WELCOME` was sending
`GameState.phase` — the **client's** read-only mirror — from the server, so every
joiner was told LOBBY while the match ran. One line of the log said `phase 0`,
and no test reads a welcome. Same family as every other defect here: found by
looking.

**US-0034 IS BUILT: REMOTE PAWNS MOVE INSTEAD OF TELEPORTING.** Every remote
entity is drawn `TUN-NET-INTERP-BUFFER` 100 ms in the past, between the two
stamped samples that bracket that moment. Two pure objects, and the split is the
design: `SnapshotInterpolator` answers *where was this at time T*, `RenderClock`
answers *what is T*.

- **Stamped, never spaced.** Assuming a fixed 33 ms interval is simpler and
  breaks the moment the crowd LOD arrives — far NPCs come at 10 Hz and near ones
  at 30, and a fixed interval makes the two rates fight.
- **The clock only moves forward and never smooths.** A late snapshot does not
  wind it back, because remote pawns jumping backwards is indistinguishable from
  a real rubber-band. And a clock that eased toward the server would make the
  delay drift — **a drifting delay is an adaptive buffer by accident**, which
  ASM-0021 refuses.
- **No extrapolation, ever.** Past the newest sample the last transform is held.
  An extrapolated player who was about to stop is a player who appears to walk
  through a wall.

**A GUARD CRIED WOLF AND WAS TIGHTENED, NOT RELAXED.**
`test_input_sampled_by_one_caller.gd` matched `.sample(` anywhere, so
`SnapshotInterpolator.sample()` tripped a guard about input sampling. It now
requires the file to name `InputSampler` too. A guard that fails on unrelated
files gets loosened, and the loosening is what actually costs you.

**`TUN-NET-TIMEOUT` WAS NEVER APPLIED ON THE CLIENT, AND IS NOW** (#74).
`_apply_timeout()` looked the connection up with `get_peer(id)`, which works on a
**server** — where `peers` is keyed by unique id — and never worked on a client
at all: that map is empty, the call fails its own `ERR_FAIL_COND`, and every
client logged `Condition "!peers.has(p_id)" is true` on connect. The early return
meant nothing broke, so the only real symptom was **the client silently falling
back to ENet's default timeout instead of the tunable**. It applies to every
connection the host holds now, which removes the id lookup that was the wrong
idea. Client logs are clean.

**AND THE FIRST PROBE WRITTEN TO DIAGNOSE IT LIED.** It called
`ENetMultiplayerPeer.get_peers()` behind a `has_method` guard — the method does
not exist — so it printed an empty list that read exactly like evidence.
`host.get_peers()` is the real route and holds one peer in state `CONNECTED`.
**A probe that cannot see reports the same thing as a quiet machine**, which is
trap 13 in a new costume.

**US-0032 AND US-0033 ARE BUILT: THE CLIENT PREDICTS AND THE SERVER CORRECTS
IT.** **The simulation snaps; the visual blends** — TDD-04 calls that its most
important sentence and it is now code. On a divergence the context takes the
server's answer *exactly*, every unacked command replays through the same
`PawnMotion` the server used, and the difference between where the pawn was
**drawn** and where it now **is** goes to `PersonaVisuals` as an offset decaying
over `TUN-NET-RECONCILE-SMOOTH-TIME`. If the simulation blended, later
predictions would run from a position the server never had and the error would
**compound instead of converging**.

- **`PredictedState` has nowhere to put gameplay state.** Position, velocity,
  state, timer, grounded — that is the whole object, and the omissions are the
  design: nothing gameplay-relevant is predicted, and the way to keep that true
  is to have nowhere to put it.
- **It reconciles on a physics frame, not on arrival.** A replay calls
  `move_and_slide()` and re-casts the probes, and Godot delivers RPCs on the idle
  frame. The snapshot is held and answered from `pawn_stepped`, which also puts
  the replay *after* this frame's prediction rather than racing it.
- **The common case is free.** Ninety frames of ordinary walking produce **zero**
  replays: both peers run the same code from the same commands.
- **`InputHistory.ack()` compared with `<=` and broke at the `u16` wrap.** Every
  ~18 minutes the buffer would stop draining and the replay would re-run
  eighteen minutes of input per snapshot. It uses `SequenceGate.is_newer()` now —
  the same arithmetic the server's gate uses, because both ends must agree on
  what "already answered" means.

**TWO OF THE RECONCILIATION TESTS WERE WRONG BEFORE THE CODE WAS.** One looped
four latency profiles calling `before_each()` by hand — standing up a second
client and a second server without freeing the first, three pawns sharing one
input — and reported a divergence that grew neatly with latency and looked
exactly like a real finding. The other read the visual offset "three frames
after" a shove, which is a guess: the snapshot carrying it is built on the *next*
sampled command and then held for its latency. **Both are trap 4's family, and
both were caught only because the numbers were implausible rather than merely
red.**

**US-0036 IS BUILT: THE LOOP IS UNDER CI.** `IntegrationHarness` stands up a
real server and **three real clients in one process** — the real client scene
with its real driver and reconciler, a real `PawnHost`, real `Snapshot` bytes —
and walks them at four latency profiles. **Only the wire is synthetic**, because
`Net` is an autoload and an RPC resolves by node path, so one process cannot hold
both ends of a real one.

**This is what retires "verified by hand"** from US-0025, US-0028 and US-0030.
Those log excerpts were real evidence and they stay in the stories; what a log
cannot do is fail a pull request. The integration suite runs in **87.7 s**
against the 180 s the story allows.

- **A comment in the harness was wrong before the code was.** It said a poor
  profile ought to produce more replays. Measured: **zero replays at every
  profile**, which is the right answer — the two peers run identical code from
  identical commands, so *being late is not the same as being wrong*. What
  latency costs is how stale a correction is when one is genuinely needed.
- **The first version added every node twice**, because the harness parented them
  and the test adopted them again. It owns what it makes now — which matters
  beyond tidiness, since GUT frees a test instance between *scripts* and three
  clients would have become six.
- **One criterion stays unticked and one test is not written.** "Every netcode
  test runs at all four" is true only of the harness's own agreement test — the
  rest are pure and have no wire to give a latency to. Separately,
  `test_frame_rate_independence.gd` **cannot exist headless**: there is no
  display rate to vary. That one is a missing test, not an unticked criterion.
  The property it was to prove is guarded structurally by
  `test_no_gameplay_in_process.gd` instead, which is stronger in one direction
  and weaker in another, and the story says which.

**US-0037 IS BUILT: CHURN LEAVES NOTHING BEHIND.** 40 cycles of three peers —
**120 joins and 120 departures** — with five counters back at baseline
afterwards: server pawns, `MatchContext.pawns`, wire slots, clients, and
**packets still on the wire**.

**Cleanup is the code most likely to look correct and never have executed.** It
is written once, beside the thing it cleans up, and the happy path never reaches
it. The failure it looks for is **inheritance, not leakage**: ENet reuses peer
ids, so anything left behind is handed to the next joiner, who is then named as
somebody else in every message that names anybody.

- **A departed client sent one more command.** `queue_free()` frees at the end of
  the frame, so a removed client's driver sampled once more and enqueued a packet
  nobody could deliver — and the snapshot answering it arrived for a client that
  no longer existed. Found by the in-flight count failing to return to zero,
  which is why the baseline counts the wire and not only the entities.
- **A test of this file was true of the wrong thing.** It let a pawn stand still
  for 30 frames and then asserted a rejoining one had not resumed from where it
  stopped — which it trivially had not, because it had never gone anywhere. Trap
  4, inside a test about cleanup.
- **Two criteria stay unticked**: a timeout behaving identically to a clean
  disconnect needs a real connection to time out (two processes), and "the match
  ends gracefully below minimum players" is `SYS-MATCH`'s, in M4.
- **Five minutes is repetition, and repetition is what is counted.** 18 000
  physics frames would outlast the 180 s the integration suite is allowed;
  nothing here accumulates with time rather than with cycles.

**US-0035 IS BUILT, AND IT FOUND THE SNAPSHOT ON THE WRONG SIGNAL.** A 500 ms
ring records every pawn transform each tick; **nothing reads it until M4**, which
is ADR-0010's point — the buffer is proven before anything depends on it.

**THE STORY'S ONE REAL CORRECTNESS PROPERTY IS WHICH TICK A FRAME BELONGS TO.** A
rewind resolves against a tick a client saw *in a snapshot*, so the history and
the snapshot must share a timeline. Checking that found they did not:
`MatchDirector` emitted one `net_ticked` at the **top** of `_net_tick()`, before
the stage loop, and the snapshot builder was connected to it — so a snapshot
stamped tick N carried the world from the end of N−1, while `server_root.gd` and
`snapshot_builder.gd` **both** carried a comment saying "last in the tick".

- **Nothing was broken, which is why it lasted.** Measured over 120 samples at
  run speed, the client's reconciliation error was **0.00000 m** — the snapshot
  was internally *consistent*, its position and its `last_acked_seq` describing
  the same moment. The only symptom was the **label**: `RemotePawns` derives
  `server_time` from `server_tick`, so every remote drew one tick staler than
  `TUN-NET-INTERP-BUFFER` declares — **133 ms against a documented 100**.
- **There are two signals now.** `net_ticked` before the stages,
  `tick_completed` after them; the builder and the recorder both use the second,
  and `test_tick_completed_is_last.gd` asserts the emission order. It was
  reasoned about twice and written into two comments, and was wrong in both.
- **The ring is pure and the recorder is not.** `LagCompHistory` takes plain
  arrays; `LagCompRecorder` walks the world. Same lesson as US-0026: a buffer
  whose contents arrive through a global cannot be *asked a question* in a test.
- **It keys by peer, never by wire slot.** Slots are reused the moment somebody
  leaves, so a rewind resolving a kill against slot 3 could name the player who
  inherited it. US-0037's lesson, applied before it could bite.
- **Two criteria stay unticked.** NPC transforms need a crowd (M3), and the
  memory came in at **28.1 KB against §8.3's 23** — 20 B per record, not 16,
  because the entity id is stored rather than implied. §8.3 is amended with the
  measured figure rather than the criterion reworded.

**`IntegrationHarness.disagreement()` MEASURED THE PREDICTION LEAD AND CALLED IT
AN ERROR**, and three tests compared it against `TUN-NET-RECONCILE-THRESHOLD`. In
a predicting architecture the client is *always* ahead of the server — that is
what prediction is — so the number is never zero and grows with speed: **0.0733 m
at stroll, 0.1500 m at run, exactly 2.00 commands at both**, against a 0.10 m
threshold. The assertions passed only because the harness never drove faster than
a walk. It is `prediction_lead()` now, with `reconciliation_error()` beside it
reading `Reconciler.last_error`. **Trap 4, in the harness written to catch trap 4.**

**US-0031 IS BUILT: ONLY WHAT CHANGED GOES ON THE WIRE.** A settled snapshot for
two motionless players is **55 bytes — the fixed block, with not one remote
record.** The protocol had no way for a client to acknowledge a snapshot, and
that was the story's first half.

**`client_tick` PAID FOR THE ACK AND COST NOTHING.** It was specified
advisory-only, TDD-03 §4 asked whether it should be sent at all, and in practice
`InputSampler` set it to `_seq` — with an integration test asserting the two were
**identical**. Two bytes of a number already in the packet, at 60 Hz, on an
upstream budget already at **112 %**. It is `acked_tick` now, upstream is
unchanged, and TDD-03 §4's open question is closed. **The forgeability rule is
untouched**: it orders nothing, and a lying client earns itself a delta it cannot
assemble and therefore cannot acknowledge — it can waste its own bandwidth and
nobody else's.

- **The baseline is what the client ACKNOWLEDGED, never what was last sent.**
  Snapshots are unreliable, so *sent* says nothing about *arrived*. Delta-ing
  against the last sent snapshot works perfectly until one packet drops and then
  corrupts every frame after it — on a connection that looks healthy, and never
  on a LAN.
- **`present_slots` is the one field delta encoding made necessary.** Absent used
  to mean *gone*; it now means *unchanged*. Without it, a player who disconnects
  **while standing still** is omitted for being unchanged and is never freed.
- **Delta encoding is a wire concern and stops at `Net`.** The assembler runs
  before `snapshot_received` is emitted, so every consumer is handed the same
  complete object as before and none of them knows deltas exist.
- **Two criteria stay unticked.** Rate LOD is **NPC-only by design** — §7.2
  justifies 10 Hz by "those NPCs are outside all gameplay radii anyway", which is
  not true of a player at 46 m — and the 90-NPC measurement needs a crowd. The
  projection is now **93.5 kbit/s, 97 %**, up from 93.0: the two new header bytes.

**AND IT FOUND THE HARNESS'S SERVER CLOCK HAD NEVER TICKED.**
`IntegrationHarness` never advanced `ctx.tick`, so every snapshot it built from
US-0036 onward carried `server_tick = 0`. Nothing depended on it — the reconciler
orders by `last_acked_seq` — so nothing failed. Delta encoding was the first
thing to read it, found a client whose newest assembled tick was permanently
zero, and **sent full snapshots forever while five of the six new tests passed**.
The sixth was written first and specifically to catch that. **Trap 3's family,
fifth instance.**

**US-0038 IS RUN: M2 IS COMPLETE.** Six of nine gate criteria are met, and the
three that are not are each blocked by something real and named. The gate's value
was not running the suite — it was **checking that the things it names exist and
measure what they claim to**, and two did not.

**THE UPSTREAM BUDGET IS AT 253 %, NOT 112 %, AND THE PLANNED FIX DOES NOT WORK.**
`test_upstream_bandwidth.gd` **did not exist**; §4.1 called it "expected to FAIL",
which reads like a test that runs and goes red, and nothing ran. Written, it
measured the payload at **56 bytes against the 9 §7.3 budgets**, because
**`NET-C2S-INPUT` is not hand-serialised** — it goes out as RPC arguments and
Godot encodes those as Variants. §7.3's arithmetic was right for a format nothing
ever used.

| | Payload | Total | Of budget |
|---|---|---|---|
| §7.3's old assumption | 9 B | 18.0 kbit/s | 112 % |
| **Measured** | **56 B** | **40.5 kbit/s** | **253 %** |
| Coalescing only | 56 B | 33.8 kbit/s | 211 % |
| Hand-packed only | 10 B | 18.4 kbit/s | 115 % |
| Hand-packed **and** coalesced | 10 B | 11.7 kbit/s | **73 %** |

**Coalescing must not be built first.** It halves the packet rate, so it halves
only the 28-byte overhead, and spends up to 16 ms of input latency against an
80 ms feel budget to do it. **Hand-serialise `InputCommand` the way `Snapshot`
already is** — that alone reaches 115 %, and costs nothing a player can feel.

- **The hand run was real and retired US-0037's last open criterion.** Four
  processes: a headless server and three clients, each welcomed into a distinct
  wire slot, **each seeing the other two appear**. First multi-process run with
  delta encoding live. A hard-killed client — no disconnect packet, which is the
  **timeout** path — produced `peer left` then `pawn freed` about ten seconds
  later, the same sequence a clean disconnect takes.
- **The headless clients cannot move** (trap 13), so that run proves the
  *transport*, not replicated movement. The harness proves the movement. Saying
  otherwise would be the rounding-up a gate exists to refuse.
- **The frame-rate line stays unticked and its substitute is accepted
  explicitly.** `test_no_gameplay_in_process.gd` is stronger in one direction —
  gameplay cannot ride the render clock *by accident* — and weaker in another: a
  client-side visual reading gameplay state per frame still slips past. Good
  enough for M2's transport criterion, not good enough to tick.
- **The churn line IS ticked at 120 cycles rather than five minutes**, because
  that substitution loses nothing: what five minutes buys is repetition, and
  nothing in the lifecycle path accumulates with time rather than cycles. The
  difference between this line and the frame-rate one is exactly that.
- **`run_gut.sh` CAUGHT ITS FIFTH SILENT SKIP**, during US-0095. A parameter
  named `bytes` collided with an existing local in `IntegrationHarness`, the file
  failed to parse, and four integration scripts were skipped — the suite reported
  **153 passing tests and no failures**. Without the script-count check that is
  indistinguishable from a healthy run.
- **RISK-NETCODE moved DOWN, RISK-BANDWIDTH moved UP.** Prediction converges at
  four profiles with a measured reconciliation error of 0.00000 m — but its
  *impact* is unchanged, because kill, stun and contests are all M4 and nothing
  has yet depended on it being right.

**M2 IS COMPLETE.** US-0025 to US-0038 are all built. US-0030's culling criteria
and US-0031's two stay unticked — there is no crowd on the wire until US-0040.

**M3 HAS STARTED. US-0039 IS BUILT — AND ITS POOL IS NOT PLUGGED IN YET.** Real
`CharacterBody3D` nodes from `npc_server.tscn`, not array slots — **the cost this
story moves off the hot path is the body**, and a pool that sized an array would
satisfy the criterion's words while missing its point entirely. Instantiating one
mid-match is a frame spike, and a frame spike in a game decided at 2.5 m is a
lost kill.

**THE ROSTER IS DERIVED, NEVER REPLICATED, AND ITS FAILURE MODE IS SILENT.** A
roster that differed between peers would not error, crash or desync anything —
NPC identity is *visual* and derived, so two clients would simply be looking at
different cities. The symptom is a player saying **"I saw a Lucerna by the
furnace" and being wrong**, which reads as a lying teammate rather than a bug.
`CrowdRoster` is pure and in Core so parity is asked directly.

- **The clone quota derives from existing tunables rather than a new ratio.**
  TUNABLES calls 10/11/12 per persona "chosen"; BALANCE_MODEL calls them
  "derived"; neither gives a rule. The rule used is TUNABLES' own prose — each
  seat below a full lobby costs one clone — and it **reproduces all three
  documented numbers exactly** from tunables that already exist. **No new
  gameplay constant was invented**, which never-do #1 would have forbidden.
- **The shuffle is not cosmetic.** The pool hands index 0 the first spawn point,
  so an unshuffled roster would put every clone in one quarter of the district.
  `Array.shuffle()` is banned here — it draws from the global RNG, which is both
  rule 8 and non-deterministic. Fisher–Yates against the seeded generator.
- **The seed is mixed, not used raw.** Adjacent seeds share **5 of 78 slots**;
  used raw they would differ in one draw and every match in a session would look
  like the last.
- **The NPC capsule matches the pawn's on purpose.** A clone findable by walking
  into it is exactly the silent discriminator `RISK-ANONYMITY-LEAK` names.
- **The pool was in no scene until US-0040 wired it.** `server_root.tscn` held no
  `NpcPool` and nothing called `preallocate()`, so ninety bodies were allocated in
  tests and nowhere else — while the criterion saying so was ticked. **A criterion
  can be true of a class and false of the game.**

**US-0041 IS HALF BUILT, AND THE NAVMESH FINALLY EXISTS.** US-0012 ticked
"navmesh baked" while its own note said the bake was **"recorded as owed rather
than claimed"** — a ticked criterion and a note denying it, in one story. TDD-08
§7's "rebake: never at runtime" is what resolves it: the bake is a **build-time**
operation, so `tools/generate_map_vetraio.gd` bakes it and the mesh is committed.
219 polygons; 2017 street points sampled on a 2 m grid, **17 uncovered**.

- **THE AGENT DIMENSIONS WERE BEING SILENTLY CHANGED.** Recast quantises
  `agent_radius` and `agent_height` to whole voxels and **ceils** them, so at
  Godot's default 0.25 cell the 0.4 m radius bakes as **0.5** and the 1.8 m
  height as **2.0** — only a warning says so, and ticking the criterion on the
  property values would have been false. The cell is 0.2, which divides both
  exactly, and the test asserts the quotients are whole.
- **AN UNSYNCED NAVIGATION MAP ANSWERS EVERY QUERY WITH THE ORIGIN.** Not an
  error — the origin. The coverage test first reported **2011 of 2011 street
  points unreachable**, which is a timing defect wearing a level defect's
  clothes. `map_force_update()` alone does nothing; the map needs **two**
  iterations (the first registers the region, the second rasterises it); querying
  before the first is an *error*, so polling with `map_get_closest_point` fills
  the log on the way to succeeding; and **`before_all()` cannot hold the wait** —
  its coroutine returns at the first `await` and the tests run anyway, which is
  why the *last* test in a file passes while the first does not.
- **The same wait is in `server_root._place_the_crowd`**, or every NPC snaps to
  (0, 0, 0) and the crowd stacks in one corner.
- **Placement had nowhere else to live.** There is no spawn-distribution story in
  M3; a position off the navmesh is a position an agent can never leave, so
  `CrowdPlacement` spreads the crowd round-robin over the map's idle anchors with
  a seeded scatter. Its first version **threw the scatter away** when there was no
  map, stacking 78 NPCs on 20 points — caught by the one assertion that could see
  it.

**US-0040 IS BUILT: FIVE STATES, ONE GLOBAL INTERRUPT.** A flat HFSM, not a
behaviour tree — per-tick tree traversal across ninety agents in GDScript is
thousands of virtual calls for five behaviours, and **the crowd is not required
to be intelligent, only legible.**

- **All 35 state-event pairs are present**, and the deliberate no-ops say
  `IGNORED` rather than being absent. **The silent no-op is the classic FSM
  bug**: a missing pair looks exactly like a handled one, and the symptom is an
  NPC that never leaves Idle while nothing anywhere errors.
- **`step()` is three operations** — one compare, one decrement, one small call —
  and allocates nothing. The guard **scans rather than measures**: a runtime
  memory probe would be flaky, and a flaky test gets a wider threshold until it
  means nothing. Falsified against a planted `var scratch := []`.
- **Two tunables were missing.** GDD-03 §6.1 specifies an idle pause of "8–25 s"
  and nothing carried it, so the machine could not leave Idle.
  `TUN-CROWD-IDLE-DURATION-MIN/-MAX` now exist **with the GDD's own numbers**,
  plus invariant 27. 282 tunables, 27 invariants.
- **Timers are net ticks — trap 9.** A brain is ticked by a system at 30 Hz, so
  `step_ticks()` would halve every duration silently. The test asserts the right
  converter *and* that the two differ, so it cannot pass by them agreeing.
- **The seed is real now.** `--seed` had been parsed since M0 and only **logged**;
  it reaches `MatchContext.match_seed` and the RNG. Without the flag the server
  picks one and logs it, so a surprising match is reproducible. `SYS-MATCH` takes
  this over at M4 and sends it in `NET-S2C-MATCH-START`, whose field already
  exists.
- **Nothing ticks a brain.** `NpcBrain` is a machine with no driver until
  something can steer, which is US-0041's.

**WHAT IS RUNNABLE AND WHAT IS NOT.** Three clients and a headless server hold a
match: peers join, the server simulates their pawns, snapshots come back, each
player sees the others move, and the local pawn predicts and reconciles. **There
is no game in it yet.** No suspicion, no contracts, no crowd, no abilities, no
kill, no stun, no score, no HUD, no match end — every one of those is M3 or
later. What M2 proves is that the *transport* under them is honest.

**TWO M2 GATE LINES CANNOT PASS AS WRITTEN**, and it is better to know now than
at the gate. ROADMAP §4.1 asks for `test_frame_rate_independence.gd` at 30/60/144
fps — impossible headless — and for a five-minute churn run, which US-0037
delivered as 120 join/leave cycles because 18 000 physics frames would outlast
the whole integration suite's 180 s budget. Both are flagged in §4.1 itself.
US-0038 will have to judge them or amend them; it may not quietly tick them.

**US-0024's "≤ 80 ms with prediction active" IS MEASURED — AND STAYS UNTICKED.**
With a real server, a real snapshot stream and reconciliation live, the response
is **two ticks, 33.3 ms, at LAN, GOOD, TYPICAL and POOR alike** — identical to
the local-only reading. That is the whole point of prediction: the client
simulates its own input immediately, and the network decides when it is
*corrected*, never when it *responds*. A number that grew with latency would have
meant the local pawn was waiting on the wire.

It stays unticked because the number is still a **lower bound on a five-stage
chain measured across three** — `ANIMATE` has no clip, `PRESENT` has no display.
One of its two blockers is gone; the other is US-0039's.

**TWO STORIES WERE WRITTEN AND HELD BEHIND THE GATE**, both for the same reason:
they change what `INPUT-TRAVERSE` does, and the gate's second line *counts
traverse presses*. Once Space always produces something, "nothing happened" stops
being observable and the vault tally stops meaning what the checklist says. **The
gate passed on 2026-08-13, so the hold expired.**

- **US-0093 IS BUILT AND MERGED** (#62, 2026-08-14) — a speed-scaled hop on
  §7.2's no-match case. An impulse rather than a fifteenth state, so the resolver
  stays the only owner of Space. **Open question: does a hop cost anonymity?**
  Raised, never ruled on, recorded rather than invented — there is no crowd to
  observe until M3, so it waits for something to observe. Its first day in the
  owner's hands found the held-traverse repeat above (#63); nothing was wrong
  with the hop itself.
- **US-0094 IS STILL A DRAFT AND STILL NEEDS A DECISION BEFORE ANY CODE** — the
  steered wall cling. **It reverses GDD-02 §7's "assisted, not
  simulated" and §1.1's "the player never chooses which manoeuvre"**, so its
  first acceptance criterion is the owner's sign-off in the GDD before any code.
  It also costs things nobody would look for: the level-design contract sized
  MAP-VETRAIO around five verbs, and a cling you can hang on for free is a
  hiding place on a façade.

**THREE MORE M1 STORIES WERE ADDED AND FINISHED ON 2026-08-12, ALL FROM THE OWNER
AT THE CONTROLS.** They are not part of the original US-0013–0024 span and they do
not change what blocks the gate:

- **US-0090** — the ladder lost its Jog rung and `INPUT-RUN` resolves into Run or
  Sprint after `TUN-SPEED-RUN-RESOLVE`. **The owner has judged this one: "top
  notch, exactly how I wanted it."** Sprint is the double-tap only now;
  `TUN-SPEED-SPRINT-HOLD` is deprecated because a held key means Run.
- **US-0091** — a greybox body and the light to see it by. `PersonaVisuals` had
  been empty since the scene was written, and nothing in the project had ever
  created a light or an environment.
- **US-0092** — the pawn is centred; the shoulder offset, its swap and
  `INPUT-SHOULDER` are retired.

**PLAYING THE GAME HAS FOUND NINE DEFECTS, ALL FIXED, NONE REACHABLE BY ANY TEST.**
The suites have no window, no display and no input devices, so every one of them
lived in exactly the gap a subjective gate exists to cover. Four came from
attempting the gate:

- **The vertical was inverted from US-0021** (#48) — positive pitch raised the
  arm, and a raised arm looking *at* the pivot looks down.
- **Nothing set `Input.mouse_mode`** (#48), so the cursor stayed free, the camera
  stopped turning at the window edge, and a visible arrow slid over the game.
- **A set of sim pedals was playing the game.** Windows presents any HID device
  with axes as a joypad; `project.godot` binds the sticks with `device: -1`,
  meaning *every* device; and the pedals rest their axes at −1.0. So
  `input_move_left`, `input_move_forward` and `input_look_left` all read 1.00
  forever — the pawn walked forward-left at stroll (2.20 m/s) and the camera
  turned without stopping. `PadSelection` now restricts every joypad binding to
  the lowest-numbered device the engine has a **gamepad mapping** for, and to no
  device at all when there is none. `TUN-SPEED-STICK-DEADZONE` could never have
  helped: a deadzone rejects drift, and this was full scale from a device working
  perfectly. Measured before and after with the pedals attached — 11 m of drift
  in six seconds, then zero.
- **A AND D WERE SWAPPED, AND MOVEMENT NEVER FOLLOWED THE CAMERA AT ALL.**
  `LocomotionState` built its world direction as `Vector3(move.x, 0, move.y)`,
  spending the stick on fixed world axes: W walked north whatever the camera was
  doing, and A walked west — which at yaw 0, the heading everything spawns at, is
  the pawn's RIGHT. `move` is an intention in the CAMERA's frame and is now
  rotated onto `look_yaw`. It survived nine stories because the code agreed with
  itself — `ProbeLayout.forward` cited `InputCommand.move` as the reason yaw 0
  faces +Z — and because every test asked whether the pawn moved, never whether
  it moved where the camera pointed. **An assertion written as a world axis is
  true of both frames**, which is trap 4 in its purest form.

Two more came from the owner asking to *see* the character, which is the same
lesson from a different direction:

- **THE PAWN DID NOT RENDER, AND NOTHING WAS LIT** (US-0091). `PersonaVisuals` was
  an empty `Node3D` in both pawn scenes, and no light or environment existed
  anywhere, so the district drew near-black. **US-0021, 0022 and 0023 built a
  spring arm, an FOV ladder and crowd-scan around a pawn that did not render, and
  every suite passed** — they assert positions, distances and lens values, all of
  which a camera behind an invisible capsule satisfies.
- **`TUN-CAM-SHOULDER-OFFSET` NEVER CHANGED THE FRAMING** (US-0092). The rig slid
  the camera 0.45 m sideways and then aimed at the pivot — the pawn's own axis —
  so the pawn re-centred in view regardless. A tunable that changed only the
  viewing angle. Found in one glance at the first screenshot of a rendered body,
  and unobservable before it. The owner chose centred framing; the offset, its
  swap and `INPUT-SHOULDER` are retired.

**Both were found by taking a screenshot of the running game**, which no suite
here can do and which took one throwaway script. Do that after any visual change.

**AND TWO MORE ON 2026-08-13, FROM THE OWNER TRYING TO VAULT A MARKET STALL.**

- **THE WHOLE DISTRICT'S FLOOR WAS 0.1 M HIGH.** `FLOORS` declares the height of
  the walkable *surface*, and the generator built each slab **straddling** that
  height rather than hanging below it — so the street's top sat at 0.100 while
  everything measured from the layout stayed put. A 0.9 m stall counter was
  therefore only **0.80 m above a pawn standing at 0.10**, the 0.85 m waist probe
  passed over it, and pressing Space at a market stall did nothing at all. Every
  existing test missed it because `test_traversal_probes_geometry.gd` builds its
  own exact boxes and `test_client_boot_walks.gd` vaults a 1.8 m block — the
  *mantle* band, where 10 cm cannot move anything out of a 1.2 m window. **The
  vault band is 0.9–1.1 and the only geometry in it is the stalls, which nothing
  had ever tried to vault.** The same fix put three spawn points back on the
  ground: S3, S4 and S6 were outside every floor rectangle.
- **SHIFT + SPACE SPRINTED.** GDD-02 §1.3 gives the pad a second sprint route,
  "L2 full + A", and nothing restricted it to a pad — `INPUT-TRAVERSE` is `Space`
  on a keyboard. It predates US-0090 and got much easier to hit once Shift meant
  Run. The combo now requires a mapped pad to be holding the bindings, which
  `PadSelection` already knows.

**AND ONE MORE ON 2026-08-14, FROM HOLDING SPACE INSTEAD OF TAPPING IT.**

- **A HELD KEY BOUGHT A FRESH TRAVERSE SIXTY TIMES A SECOND.**
  `PawnInputBuffer.tick()` armed from `InputCommand.buttons`, which is *held*
  state, so it re-armed the counter on every frame the key was down — and
  `TraversalResolver.resolve()` spends whatever is armed. It shipped that way
  from US-0016 and showed nothing for nine stories, because the extra resolves
  had nothing to do. **US-0093 gave them something.** Hop off a 0.9 m stall with
  Space held and the pawn rises ~0.22 m, which is enough for the lip it just left
  to measure deeper than `TUN-TRAVERSE-DROP-MIN-HEIGHT` — so the second resolve
  classifies the same edge as a **gap jump**, plans an interpolation, and zeroes
  the velocity. It reads exactly as the owner reported it: *"if i jump of a edge
  from a vautlable height, it slows me down mid air"*. The buffer now arms on the
  edge, via `InputBits.newly_pressed` — which existed, was written for this, and
  nothing had ever called. Reasoning about it was wrong twice; a per-frame log of
  `classify()`, `state_id` and `velocity` found it in one run.

**The gate is genuinely runnable now.** One command, no server — `boot.gd` loads
`client_root.tscn` with or without `--connect`, so the "client, menu" log line
names a menu that does not exist:

```bash
godot --path . 
```

**THE DOUBLE-SAMPLE FOUND ON 2026-08-08 IS FIXED**, as of 2026-08-11.
`InputSampler.sample()` ran twice per physics frame and `TUN-SPEED-SPRINT-HOLD`
opened sprint in 0.21 s instead of 0.4 — half the friction GDD-02 §1.5 defends.
The sampler no longer drives itself; `LocalPawnDriver` is the only caller and
owns `command_sampled`. **Trap 12**, and two guards. Any feel judgement recorded
before this date was made against the fast sprint gate and should be re-run.

**THE PAWN WALKS AND TRAVERSES.** A key press reaches the speed ladder through
the real input map, the probes see the district, and every manoeuvre performs —
vault, mantle, climb, drop and gap jump. `test/integration/` asserts the walk,
the vault and the climb end to end. Launch a client and drive it:

```bash
godot --headless -- --server --port 27015 --max-players 6
godot -- --connect 127.0.0.1:27015
```

WASD, Left Ctrl to blend-walk, **Left Shift held past `TUN-SPEED-RUN-RESOLVE`
(0.15 s) to run**, double-tap Shift to sprint — a sustained hold no longer
sprints, US-0090 —
Space to traverse — the game picks the manoeuvre from what is in front of you.
The camera is the real `SYS-CAMERA` rig as of US-0021, and since US-0022 the
lens widens with the speed **state** — 55° blend-walk to 72° sprint at 90°/s.
Middle mouse holds crowd-scan: 48°, look at 0.45×, pace capped at blend-walk,
and **nothing else at all** (US-0023).

M1's gate is *subjective* (ROADMAP §3.1). **If the pawn does not feel good at
M1, it will not feel good at M6.** Three of its four lines are judgeable now;
**the fourth cannot exist yet** — input→animation needs an animation, and
US-0024 measures it against clips that do not exist.

| | |
|---|---|
| CI | 7 jobs. **Running again as of 2026-08-07 after a two-day outage** — run `31200490320`, all seven green. The seven commits merged during the outage were never through it, see trap 6. `.ci/run_gut.sh` fails if a suite runs fewer scripts than exist on disk |
| Tests | **41 arch + 95 unit + 32 integration scripts**, holding 154 + 817 + 237 tests and 239 + 6415 + 645 assertions. **Nine are `pending` by design** — two of them in the integration suite, reporting that Piazza del Vetro is a disconnected island and that an NPC aimed into the void never gives up. The three numbers this row used to call assertions were **test** counts — corrected at US-0041 by reading both off the runner. The integration suite is at **170.9 s** of the 180 s it is allowed, up from 87.7 s at M2 — **9 s of headroom left, and the next integration test has to justify itself hard against that**. `test_server_tick_budget.gd` cost 9.8 s of it and is a gate line; the one before it, the 2 s pass A/B, samples ninety ticks **twice** — US-0044's three suites are deliberately *unit* tests for that reason: `test_crowd_moves.gd` walks a crowd for sixty net ticks eight times over, and physics frames run in real time even headless. **Eight of those are in the unit suite** — `test_cull_radius_price.gd` among them, reporting that the cull-radius curve is FLAT and the budget is missed at every legal radius. — `test_upstream_bandwidth.gd` reports the 145 % upstream miss, **`test_crowd_bandwidth.gd` the 112 % downstream projection and `test_crowd_wire_cost.gd` the 155 % it actually costs today**, `test_circuit_separation.gd` US-0043's 0.51 m circuits, **`test_spawn_points.gd` two of GDD-05 §2.7's own rules** — rule 6's nine unoccluded spawn pairs and the clone minimum S3/S4 cannot hold — and `test_clone_animation_parity.gd` the missing clip library. Each reports a finding the code cannot fix rather than going red, the same choice `test_snapshot_size.gd` made. A `pending` that turns green by itself the day its blocker is authored is the point. The *script* counts are guarded by `test_claude_md_counts_are_current.gd`; the assertion counts are a snapshot and are not. This line read `119 + 515 + 132` for **twelve PRs** — every update to it was an unasserted `str.replace` that silently matched nothing. See trap 15 |
| Tuning | 288 tunables across 14 resource classes; all 31 cross-field invariants assert — split across `TuningInvariants` and `TuningInvariantsTech` since the first file hit 400 lines, with one entry point still. **Eight IDs are deprecated** and recorded in TUNABLES §19 — never reused |
| Autoloads | All eight. `Tuning` precomputes 89 durations into **two** tick tables — see trap 7 |
| Strings | `data/strings/en.csv`, 56 keys, no user-facing literal anywhere else |
| Boot | Branches on `--server`; 7 CLI flags parsed in pure Core; 5 export presets |
| Map | `MAP-VETRAIO` greybox, 120 × 120 m. Client loads 28 meshes, server loads none. **The street surface is exactly `STREET_Y`** — floors used to straddle their declared height, putting every walkable top 0.1 m high, which made the 0.9 m stalls unvaultable and three spawn points float over nothing. **Lit as of US-0091** — one key light and a sky, because nothing in the project had ever created either and the district rendered near-black. **The navmesh is baked at build time and committed** (US-0041): **211 polygons across 12 floors**, with a derived `H_VAULT` parapet on every floor edge that borders a drop, and it sits **0.400 m above the street**, which is why steering applies gravity rather than trusting the snap |
| Pawn | 14 states declared — **the Jog rung was removed in US-0090** and `Jog` is a retired ID absent from `ALL`. Transition edges asserted against the normative diagram. **Eleven implemented**: five locomotion + `Vault`, `Climb`, `Drop`, `KillAnim`, `Stunned`, `Blended`. `Respawning`, `StunAnim` and `Dead` are M4 |
| Traversal | **Complete.** Probes cast, all seven §7.2 cases resolve from real geometry, both forgiveness windows open, and vault, mantle, climb, drop and gap jump all perform. **Case 7 hops as of US-0093** — an impulse, not a state, scaled by the speed rung and adding nothing horizontal. **The action buffer arms on the PRESS, not the hold** — arming from the held bit spent a traverse every frame a finger stayed down |
| Crowd | 90 bodies pre-allocated, 78 active, each with a brain and a `CrowdContext` allocated beside it. One `SpatialHash` on `MatchContext`, rebuilt at the **top** of the crowd stage so the brains and every downstream system read the same grid — 0.0561 ms, allocating nothing. `CrowdDirector` ticks them at the `crowd` stage and translates the five flags `NpcBrain.step()` deliberately does not read into `handle()` calls; `Steering` moves the bodies from the **avoidance callback**, on the physics frame, and knows nothing about states — it takes a point and a speed. Repath is FIFO and capped at three a tick. **Four processions of four walk the map's circuits** (US-0043), each with a fifth slot no NPC may take, at a pace throttled by its worst straggler. **Banded by distance** as of US-0045 — 20/45/70 m, strides 1/3/15, staggered by index — and `CrowdBands` also scales each agent's `path_max_distance` by its band's stride (US-0041's last line), which is the one path query `RepathQueue` does not stagger. **All five states are reachable** as of US-0044: a sprinting player startles the crowd once a second, a wave propagates one hop at 0.4, and a corpse gathers six onlookers who walk to it and disperse before it fades. Violence has an entry point and no caller until M4. **On the wire as of US-0030/US-0031**: `SnapshotBuilder._fill_crowd` sends each observer the NPCs within `TUN-NET-NPC-CULL-RADIUS`, positionally and never visually, at `TUN-NET-NPC-RATE-LOD-HZ` beyond `TUN-NET-NPC-RATE-LOD-RADIUS` and staggered by `(tick + index) % stride`, delta-encoded per NPC against the client's **ack**. **Drawn on a client** as of US-0045 by `NpcView`, which culls at the same radius one margin wider, treats absence as "no update" rather than "gone", and dresses nobody. **Departure is a value, not silence** — one out-of-range record — and `CrowdWire.is_farewell()` holds that rule for both `NpcView` and `SnapshotAssembler`, which must agree on it: when only the view knew it, the assembler carried one goodbye forward into every later snapshot and the view created and freed a body from it once per tick. **Clone-parity layer 4 hangs off the same 2 s pass as the formations** (US-0047): `CloneBalance` holds the clones already near a player and fetches one when a persona is short, always to a map anchor and never at the player. **The floor is decided on clones that have ARRIVED**: crediting one still walking satisfied the minimum in expectation while the player was short in fact for the eighteen seconds of the journey |
| Pawn body | `GreyboxBody`, procedural — capsule, head and a chest marker on `+Z`, measured from the collider so the two cannot drift. **`PersonaVisuals` was empty through US-0021, 0022 and 0023**: three stories of camera work built around a pawn that did not render, every suite green. Not a persona — ART_BIBLE §6.1's four constructions are US-0039's |
| Camera | Real spring arm: 2.6 m, **pawn centred** (US-0092 — the 0.45 m offset never changed the composition, because the rig aims at the pawn's own axis; `INPUT-SHOULDER` retired with it), occlusion that pulls **in** and never sideways, `WORLD`-masked so a crowd cannot push it. The FOV ladder is bound to the **state**, never to `ctx.velocity`: the rung is a consequence of the decision, not of the physics that follows it. Crowd-scan narrows to 48° and grants nothing. **Positive pitch LOWERS the arm** — the rig looks *at* the pivot, so a raised arm looks down; it shipped inverted from US-0021 until somebody played it |
| Input | 20 `InputMap` actions from 14 live `INPUT-` IDs — `INPUT-SHOULDER` is retired via `InputActions.DEPRECATED`, still in the corpus and bound to nothing, KBM + pad. Chain GDD-02 → `Ids` → `InputActions` → `project.godot`, guarded on every hop, both directions. **Sampled once per physics frame by `LocalPawnDriver`, the only caller** — see trap 12. The mouse is **captured** on boot; `INPUT-MENU` releases, a click takes it back. **Only a mapped gamepad holds the joypad bindings** — `PadSelection`, applied through the one `InputMap` writer, because a set of sim pedals was steering |

**Forty criteria are deliberately unticked**, each blocked by something real — counted
from the `done` and `in-progress` stories on 2026-08-16. **Nine of them arrived at once**:
US-0048 moved from `draft` to `in-progress` when its first instrument was built, so the M3
gate's own checklist now counts. That is the honest direction — a story with work in it is
not a draft — but the nine are gate lines waiting on US-0045, 0046 and 0047, not stalled work. A prose count of these has now drifted four times, so they are a table — and the
story files are the source of truth, not this. Regenerate the count rather than
editing it:

```bash
grep -c '^- \[ \]' docs/40_backlog/stories/*.md
```

| Story | Unticked | Blocked by |
|---|---|---|
| US-0002/3/4/5 | four "required check on `main`" lines | branch protection needs GitHub Pro on a private repo. TDD-12 §1.3 |
| US-0019 | root motion for hand and foot placement | there are no animation clips |
| US-0022 | motion-reduction's compensating indicator | the FOV **lock** is done and tested; the persistent speed indicator belongs to the HUD, US-0084 |
| US-0023 | ambience ducked, footsteps sharpened | `Audio.play()` is an empty stub until US-0075 |
| US-0024 | input→animation measured; ≤ 80 ms with prediction | no clips. **The prediction half is now measured** — 33.3 ms at every latency profile — but the chain is still three stages of five, so the number is a lower bound. The feel-gate checklist is DONE (2026-08-13) |
| US-0025 | ping/pong RTT proven over a real wire | the client half needs two processes. `RttTable` is unit-tested and the server half reads ENet directly |
| US-0029 | "remote pawn is 14 B, NPC is 7 B" | **false as written.** Measured at 10 and 8; TDD-04 §4 and §7.1 were amended instead of rewording the criterion |
| US-0030 | `render_state` per observer | **the three culling criteria are DONE** — US-0030's cull landed once M3 gave it a crowd. `render_state` needs `SYS-DETECTION`, which is M4's |
| US-0036 | "every netcode test runs at all four profiles" | true only of the harness's own agreement test; the rest are pure and have no wire to give a latency to |
| US-0037 | match end below minimum players | `SYS-MATCH`'s, in M4. **The timeout criterion was ticked at the M2 gate** — a hard-killed client took the same `peer left` → `pawn freed` path across four real processes |
| US-0047 | "always had 2 within 25 m"; "does not read as following" | **"Always" is not achievable and the reason is a walk**: a fetched clone crosses 25 m in ~18 s, so a player who loses one is short for that walk. Supply is not the constraint — 4.27 clones of each persona on average against a floor of 2. 100 of 12 960 readings under the floor, never below 1, and **of 21 short pairs the pass saw, 18 already had a clone coming and 6 were dispatched**: the rule never ignores a breach, and that is what is asserted. The second criterion's readable half needs a client that has ever rendered a clone |
| US-0046 | layers 2 and 3, footstep parity, the idle cycler | **there are no animation clips in this project, on either rig.** Layer 2's declaration half asserts and its library half reports; layer 3's check exists with no call site because a call site needs an `AnimationTree`; footsteps need `Audio.play()`, a stub until US-0075. ANIMATION_SPEC §8 costs the parity set at 14 × 4 personas × 2 rigs |
| US-0045 | the three client-LOD lines | **US-0046.** `NpcView` exists now and draws the crowd; what is missing is the **mesh and the `AnimationTree`**, so animation LOD, the silhouette-fairness check and mesh LOD still have nothing to band. There are no animation clips on either rig |
| US-0048 | six of the ten M3 gate lines | **the gate is RUN.** Four are met — `test_crowd_perf.gd`, `test_clone_local_min.gd`, the risk re-score, and **server tick p99 at 2.15 ms of 8.0**, measured here by booting the real `server_root.tscn`. Of the six left, `test_crowd_bandwidth.gd` is a **measured miss** at 112 % and not a blocked line; the rest wait on clone meshes on the wire, animation clips, and an owner at a windowed client. **The tag is the owner's call** |
| US-0044 | startle waves read directionally **to a human observer** | needs rendered clones and an owner at a windowed client. **NPC meshes are US-0046.** The mechanical half is measured — 13 of 13 startled NPCs sent away from the violence — and the criterion is not rounded up on it |
| US-0043 | the circuits' declared periods; the 8 m circuit separation | **both are the level's, not the code's.** The routes are 150–237 m, so 55–75 s implies 2.6–3.2 m/s; and CIRC-A and CIRC-B share the z=45 spine, passing within **0.51 m** against a rule of 8 m — geometry, so no re-timing fixes it. Re-authoring four routes against six competing rules is the owner's |
| US-0038 | frame-rate independence; downstream "measured"; the 180 ms feel check | impossible headless (the structural substitute is accepted, not ticked); the entity counts in the projection need M3's crowd; the feel check is the owner's and needs a windowed client |
| US-0031 | downstream measured within 96 kbit/s | **rate LOD is DONE** and NPC-only by design, since a *player* at 46 m at 10 Hz would be visibly coarse. The measurement is now real and it **misses**: 112 % with culling, rate LOD and the NPC delta all built, charged against a lagging ack. The remaining 12 % is ADR-0007's or a tuning change, neither priced |
| US-0035 | NPC transforms recorded; memory "around 23 KB" | there is no crowd until M3. Memory measured at **28.1 KB** — 20 B per record, not §8.3's 16, because the entity id is stored rather than implied by slot. TDD-04 §8.3 amended |

Two more things are owed and are **not** acceptance criteria, so they are not in
the count: the navmesh **bake** (recorded in US-0012) and
**`test_frame_rate_independence.gd`** (US-0036's test notes) — the latter cannot
exist headless, because there is no display rate to vary. Do not go looking for
it as an unticked line; it is a missing *test*, not a missing tick.

**Nothing here is forgotten and nothing is half-ticked** — a story marked done
over a criterion that is not true makes the whole backlog unreadable as a status
view.

### Sixteen things that will cost you an hour if you do not know them

1. **Two things are GENERATED.** `scripts/core/ids.gd`, `scripts/core/tuning/*.gd`
   and `tuning_index.gd` come from `tools/tuning_codegen/run_all.py`; the map
   scenes and `MapData` come from `tools/generate_map_vetraio.gd`, whose single
   source is `scripts/core/vetraio_layout.gd`. Hand-edits to any of them are
   silently reverted on the next run. **Change the layout table, not the scene.**
   **`Ids` IS HARVESTED FROM `docs/`**, which has a consequence worth knowing
   before you need it: an ID cannot be removed by deleting its table row. The
   harvest finds it again, `Ids` declares it, and the guard that every documented
   action has a row fails. A retired ID is *declared dead* instead —
   `InputActions.DEPRECATED` is the pattern, US-0092.
2. **`duplicate(true)` does not deep-copy a `TuningProfile`.** The sections are
   *external* resources, and Godot's deep duplicate only copies embedded ones.
   Use `TuningProfile.clone()`. Getting this wrong writes to the live profile.
3. **Verify against `git archive HEAD`, not the working tree.** Git does not
   track empty directories, and a local pass proved nothing once already.
   **The extraction has no `.git`**, so anything reaching for git there gets
   nothing: `ip-guard` and `asset-inventory` both enumerated with `git ls-files`
   and printed "clean" over **zero of 739 files** for two milestones — vacuously
   green exactly where the checkpoint most trusted them. Both now enumerate
   through `.ci/repo_files.sh`, which falls back to `find` and refuses an empty
   list. TDD-12 §1.5. If you write a third guard, source that helper.
4. **BOTH ROOT SCENES ARE BOOTED BY A TEST NOW.**
   `test/integration/test_client_boot_walks.gd` drives the real client through
   the real bindings, and `test_server_tick_budget.gd` boots the real
   `server_root.tscn` with a full lobby and the full crowd (US-0048). **The
   server half was owed from M0 and this trap named it for four milestones.**
   Everything else is still unbooted, and it has bitten twice:
   `change_scene_to_file` from `_ready()` failed with 92 tests green, and
   spawning through `transition()` into an unimplemented state failed with 222.
   **Run the game after touching anything scene-related.**
   **A TEST THAT BOOTS A ROOT SCENE MUST PUT THE AUTOLOADS BACK.**
   `server_root._ready()` calls `Net.bind_router`, and `Net` outlives the test —
   a dangling router handed to whatever runs next is US-0037's defect in a new
   place. `after_each` clears it.
   **AND ASSERT THE SHAPE OF A RESULT, NOT ITS MAGNITUDE.** "The pawn moved more
   than half a metre" was true of a pawn falling through the world. Its most
   expensive instance so far: `test_looking_up_raises_the_camera` asserted that
   pitching up lifts the arm — true, and not the question. The rig looks *at* the
   pivot, so a lifted arm looks DOWN, and the vertical shipped inverted through
   three stories behind that green test. Nobody found it until the owner played
   the game.
5. **OPENING THE GODOT EDITOR REWRITES `project.godot`** and deletes every key
   whose value matches an engine default, plus every comment. It did this once
   already, removing `rendering_method` and `physics_ticks_per_second`.
   `test_project_settings_pinned.gd` now catches it; the fix is
   `git checkout project.godot`. `--headless --editor` is safe; the GUI is not.
6. **`main` has no server-side protection** — see §1.3 of
   `docs/20_tdd/12_build_and_ci.md`. Run `git config core.hooksPath .githooks` in
   every fresh clone, and wait for a run to report `completed success` before
   merging. `gh run watch` can return while a run is still queued.
   **ACTIONS WENT SILENT FOR TWO DAYS AND CAME BACK.** No runs at all between
   `31039868975` (2026-08-05T19:32Z) and `31200490320` (2026-08-07T17:03Z), on any
   trigger, with Actions reporting `enabled` throughout — most likely exhausted
   free-plan minutes, never confirmed, because the billing endpoint needs a `user`
   OAuth scope this token does not carry. **Four stories and two checkpoints
   merged on local evidence in the gap** (#33, #35, #36, #37, #38), each PR body
   saying so. The pipeline is green again; if it goes quiet a second time, check
   that a run actually *appears* before waiting on one — a stale `gh run list`
   looks exactly like a healthy pipeline that has not fired yet — and verify from
   a `git archive HEAD` extraction meanwhile. TDD-12 §1.3.1.
   **AND ON 2026-08-20 IT WAS CONFIRMED, WEARING A CODE FAILURE'S CLOTHES.** Run
   `32389932998` reported five jobs green and **`test` and `export` failed** — each
   started and completed **in the same second, with zero steps and no log to
   fetch**, which reads exactly like a suite that crashed before printing. The
   cause is in the check-run *annotation*, never in the log: `The job was not
   started because recent account payments have failed or your spending limit
   needs to be increased`. **All seven jobs are `ubuntu-22.04`, and the two refused
   are the only two that `needs: [version, import]`** — so they start last and are
   the ones the allowance runs out under, which is why a partial green is the
   symptom rather than a silent pipeline. A rerun reproduced it exactly. **Read the
   annotation before believing a failed job with no log:**

   ```bash
   gh api repos/<owner>/<repo>/check-runs/<job-id>/annotations --jq '.[].message'
   ```

   **Both refused jobs reproduce locally.** `test` is the three suites against a
   `git archive HEAD` extraction; `export` does not build anything at all — it is
   two greps over `export_presets.cfg` — so it is one line.
7. **A STATE THAT WRITES `ctx.position` MUST SAY SO**, by returning true from
   `PawnState.drives_position()`. Otherwise `LocalPawnDriver` runs
   `move_and_slide()` and overwrites it from the physics body — which, with the
   velocity frozen as a traversal requires, has not moved. US-0019's vault
   computed a perfect arc and left the pawn exactly where it stood. Every unit
   test passed, because they call `step()` directly and the driver does not.
8. **A STATE'S OWN EXIT IS NOT AN INTERRUPTION.** `transition()` takes an
   `interrupting` flag and `step()` passes false. Gating a state's completion on
   `is_interruptible()` makes every uninterruptible state permanent: `Vault` and
   `KillAnim` both declined their own exit, the latter since US-0013, unnoticed
   because nothing had ever run it. The symptom is a frozen player, not an error.
9. **THERE ARE TWO TICK DOMAINS.** `Tuning.ticks()` converts at the 30 Hz net
   tick; `Tuning.step_ticks()` converts at the 60 Hz input rate. Anything
   incremented inside `PawnState.step()` — `ctx.state_timer_ticks`, the action
   buffers — advances at 60 and must use `step_ticks`. Getting it wrong halves
   the duration *silently*, because both are plausible integers. Four merged
   call sites had it wrong until US-0016, including the stun freeze, which
   design law 5 forbids weakening. `test_step_counters_use_step_ticks.gd` now
   refuses `Tuning.ticks(` anywhere under `scripts/pawn/`.
10. **GUT REPORTS "NOTHING WAS RUN" AS A SUCCESS SHAPE, NOT AS A FAILURE.**
    Without `-ginclude_subdirs` it scans only the top level of `-gdir`, finds no
    `test_*.gd` — every suite here is nested — and prints *"On the one hand
    nothing failed, on the other hand nothing did anything"*. It is the same
    silent-skip family as trap 3 and as the cache bug in `.ci/run_gut.sh`'s
    header. **Use `.ci/run_gut.sh`**, which counts the scripts on disk and
    refuses to pass over a short run. **It has now caught three silent skips**,
    the last on 2026-08-12: deleting `CameraArm.Shoulder` broke three test
    scripts, which failed to parse and were skipped, and both suites reported
    green while running three fewer scripts than exist on disk.
11. **THE FUNCTION-LENGTH GUARD MEASURES `func` TO `func`**, so a function is
    charged for the docstring of the one AFTER it. Adding a seven-line docstring
    to a new function pushed its *neighbour* over 40 lines in US-0022. The
    message names the wrong function, and the tempting fix — deleting a
    docstring — is the wrong one. Shorten the comment you just added, or split
    the function the guard actually named.
12. **`InputSampler.sample()` IS NOT A GETTER, AND HAS EXACTLY ONE CALLER.** It
    advances `_seq`, resolves every hold/toggle latch and ticks `SprintGate`.
    From US-0016 to US-0025 it ran **twice a frame** — the sampler emitted from
    its own `_physics_process` and `LocalPawnDriver` took a second sample in
    its. Input ran at 120 Hz, and `TUN-SPEED-SPRINT-HOLD` opened in 0.21 s
    instead of 0.4, halving the friction GDD-02 §1.5 spends a page defending.
    Nothing looked wrong: `_command` is one reused object holding **absolute**
    look values, so the two invocations agreed on everything visible and
    differed only in what was counted. Same family as trap 9. `command_sampled`
    is now declared on the **driver**, beside the only call that produces it —
    if you need a command, listen to that. `test_input_sampled_by_one_caller.gd`
    names the cause; `test_input_sampled_once.gd` measures the consequence.
13. **`--headless` CANNOT SEE AN INPUT DEVICE, SO A HEADLESS DIAGNOSTIC PROVES
    NOTHING ABOUT ONE.** There is no windowing layer to poll a pad or deliver
    mouse motion, so every reading is a zero — and a zero from a probe that
    cannot see is indistinguishable from a zero from a quiet machine. A tool
    written to find the spinning camera reported "connected joypads: 0 — a
    spinning camera is NOT coming from a stick" under `--headless`, on a machine
    where a pair of sim pedals was holding three actions at full deflection. It
    was believed for a day. `tools/input_probe.gd` refuses to run headless, and
    polls for twelve seconds because a pad's **resting axis values arrive about a
    second after it enumerates** — a single glance at frame zero reads 0.00 even
    with a window. Trap 3's family: a check that reports clean over nothing.
14. **A DOCUMENT SAYING "X ASSERTS Y" IS NOT EVIDENCE THAT X EXISTS.** Check that
    it is a file, and that something runs it. This has now been wrong three
    times: the seed claimed `test_claude_md_synced.gd` from US-0001 and it did
    not exist until US-0023; TDD-12 §11 lists thirteen test hooks of which
    **twelve do not exist**; and `NETWORK_PROTOCOL.md`'s header claimed
    `test_protocol_docs_sync.gd` from M0 — **two deliberately duplicated
    documents, drifting unguarded for two milestones, under a note telling every
    reader they were checked.** Written 2026-08-15; no drift had accumulated,
    which was luck rather than process. `test/metrics/` is likewise declared,
    empty, and **not run by CI**, so a suite placed there would never execute.
    **The claim is worse than the absence**, because the claim is what stops
    anybody checking by hand.
15. **AN UNASSERTED `str.replace` REPORTS SUCCESS BY DOING NOTHING.** Most edits
    to this corpus are scripted, and Python's `replace` against a string that has
    already changed matches zero characters and returns happily. CLAUDE.md's
    Tests row read `119 arch + 515 unit + 132 integration` for **twelve pull
    requests** while the real counts climbed past it — three separate checkpoints
    each "updated" it and each silently did nothing. **Assert every `old in s`
    before replacing**, which is what the surviving edits in those same scripts
    did and why only this one rotted. Trap 3's family in a text editor: an
    operation whose failure mode is indistinguishable from its success.
    `test_claude_md_counts_are_current.gd` now guards the script counts, which
    are readable from disk; the assertion counts are a snapshot and say so.

16. **KILLING GODOT MID-RUN CORRUPTS `.godot/`, AND THE SYMPTOM IS A SUITE THAT
    HANGS FOREVER WITH NO OUTPUT AND NO ERROR.** `taskkill //F` is the only way to
    stop a headless server on Windows, and doing it while an import or a suite is
    in flight leaves the import cache inconsistent. The integration suite then
    starts, prints its header, and never finishes — no failure, no message, no
    progress. **Every one of the 32 scripts still passes when run alone**, which is
    what makes it so misleading: bisecting finds nothing, and a `git stash` control
    on clean `HEAD` hangs identically, so it reads as "the machine is broken"
    rather than "the cache is". The fix is `rm -rf .godot` followed by
    `godot --headless --path . --editor --quit-after 600`, after which the suite
    ran 32 scripts and 234 tests in 168.9 s. Cost most of an afternoon on
    2026-08-20. **Godot's stdout is buffered when redirected, so a single header
    line and nothing else is normal for a healthy run too** — do not read silence
    as a hang until the process has had its full expected runtime.

### Local environment

**THE REPOSITORY MOVED OWNER ON 2026-08-19**, from `Slimexsan` to `filipstanicak`
— the GitHub account was renamed. `filipstanicak/project-sottovoce` is canonical.
GitHub redirects the old path, so nothing is broken, but **every PR link merged
before that date carries the old owner** in commit messages and PR bodies, which
git history cannot rewrite and should not. One corpus link was updated in place;
`git remote` and the `lfs` section of `.git/config` were repointed by hand,
because `git remote set-url` does not touch the LFS key. **A fresh clone needs
neither fix.**

Godot and gdtoolkit are not on `PATH` on this machine:

- `C:\Users\Slimex\Desktop\Godot_v4.7.1-stable_win64.exe`
- `C:\Users\Slimex\AppData\Roaming\Python\Python314\Scripts\gdlint.exe`

`.ci/run_gut.sh` invokes a bare `godot`, so shim it before running a suite:

```bash
mkdir -p /tmp/shim
printf '#!/usr/bin/env bash\nexec "/c/Users/Slimex/Desktop/Godot_v4.7.1-stable_win64.exe" "$@"\n' > /tmp/shim/godot
chmod +x /tmp/shim/godot
export PATH="/tmp/shim:/c/Users/Slimex/AppData/Roaming/Python/Python314/Scripts:$PATH"
```

`/tmp/shim` does not survive between sessions, so the `mkdir` is not optional —
without it the redirect fails and the PATH export points at nothing, which then
reads exactly like Godot not being installed.

Python is on `PATH` as `python` (3.14.6), which is what the tuning codegen needs.

---

## Fresh session? Read these four first

1. This file.
2. `docs/00_meta/GLOSSARY.md` — every term has exactly one meaning.
3. `docs/50_tuning/TUNABLES.md` — every number.
4. Your story file in `docs/40_backlog/stories/`.

Then the routing table above for the one or two documents governing your system. **Do not read
the whole corpus** — read the `depends_on` chain of what you need.

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
5. **The prey must have teeth, and more than one.** Being hunted is the more frightening role
   and must not be the weaker one. A stun outscores a base kill and loses to a well-made one;
   the prey reaches that outcome by more than one route — a read stun, an escape, a Lunge into
   a pursuer — and none of them may be traded away to make hunting feel better.
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

# ALL THREE AT ONCE, FROM cmd: a server, N walking bots, and you.
# Close the game window and it shuts the server and the bots down.
play.bat            REM 3 bots
play.bat 5 27016 42 REM 5 bots, another port, a fixed match seed

# One bot on its own, against a server that is already up.
# A scene, not a `-s` script: it needs the autoloads (trap: a `-s` script gets none).
godot --headless --path . res://tools/bot_client.tscn -- --connect 127.0.0.1:27015 --bot 1

# What the input layer reports with nobody touching the controls.
# NEVER --headless: there is no windowing layer there to see a device. Trap 13.
godot --path . res://tools/input_probe.tscn

# THE BENCH. A 40 m courtyard for reproducing something in ten seconds rather
# than ten minutes. DEBUG ONLY - excluded from every export preset.
# docs/30_bible/MAP_SANDBOX.md, and read its section 4 before quoting any number.
sandbox.bat            REM a server, 1 hunter, 12 civilians, and you
sandbox.bat 1 0        REM one hunter and an EMPTY district
sandbox.bat 1 12 3     REM ...plus 3 QUARRY bots: somebody to stalk
sandbox.bat 0 12 3     REM nobody hunting you at all. Seed is now arg 4

# --map MUST be given to every process, INCLUDING each bot: a bot instantiates
# the client root itself and never sees boot.gd, so without it the bot loads the
# district while the server runs the courtyard.
godot --headless --path . -- --server --port 27015 --map sandbox --crowd 12

# Look at a map from above, with its spawn points marked. Windowed only.
godot --path . res://tools/map_probe.tscn -- --map sandbox
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
12. **Never add a minimap, a kill-cam, a global kill feed, or player nameplates.** Each would
    convert an earned inference into a given fact. **Narrowed 2026-08-26 (ADR-0013):** the
    hit-direction ban is lifted — the prey warning carries a bearing, as the reference's does —
    and "nameplate" means a **name**. A *relationship* marker on your own contract or your own
    revealed pursuer is permitted; a marker that names anybody, or that marks a player you have
    no relationship with, is not.
13. **Never weaken stun** to make hunting feel better. If hunters are frustrated, make the
    *Anonymous approach* more reliable instead. **One exception, decided 2026-08-26 for
    reference fidelity (ADR-0013): a committed kill is not interruptible.** Range advantage,
    tier gate, freeze and lockout are all untouched, and none of them may be traded away.
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
### 2026-09-08 — shared pawn navigation constants, PR #211

`PawnNavigation` now owns all eight `NAV_*` constants formerly in `VetraioLayout`.
Values and bake assignment order are unchanged. Map layout clearance, crowd steering,
rescue and `MapBuild` share that autoload-free definition; both generators still use
`-s`. Both maps reproduced byte-identically: all four scenes and all four map/navmesh
resources match their pre-refactor SHA-256 hashes (255 and 53 navmesh polygons).

Local unit verification: 194 scripts, 1,665 tests, 1,657 passing and the existing eight
pending, 29,718 assertions. Architecture: 56 scripts, 220 passing tests, 1,254 assertions.
The final clean-archive suites and exact checked commit are recorded in PR #211's handoff.
This extraction changes no milestone or gameplay rule. Existing generator cleanup/RID
messages remain; they are not a claim that the generated files failed to reproduce.

Codex works in the separate `sv-codex` worktree on `refactor/pawn-nav-constants`.
The owner's `project-sottovoce` checkout is not an agent working directory.

*Updated 2026-08-27 (ADR-0016, the M4 gate). Keep this section current — it is the first thing a
fresh session reads, and a stale one is worse than none.*

## THIS FILE WAS 6 594 LINES AND THE TRAPS WERE AT THE BOTTOM OF IT

**RAISED BY THE SECOND AGENT, AND HALF RIGHT IN A MORE USEFUL WAY THAN IT LOOKED.**
The complaint was volume: thousands of lines make it hard to find which rules
actually bind. **The measurement found an ordering defect underneath it.** One
section — *"THE FIFTEEN STORIES"* — held **3 301 lines** of M0-M4 history, and
filed beneath it were the state tables, the eighteen traps and the local
environment. The three things a cold session needs first sat at the bottom of a
section about M4's story list.

**6 594 -> 3 334 LINES, AND NOTHING LIVE WAS DELETED.** The history is
`docs/00_meta/history/M0-M4_the_build.md`; the tables, the unticked list, the traps
and the environment are now top-level sections in the order a session meets them.
Every live fact those pages carried was already in the tables or the unticked
table — what moved is *how each was found*.

**AND THE ARCHIVE IS INDEXED, BECAUSE THE LENGTH WAS NEVER THE REAL PROBLEM.** The
`-s` autoload fix **was already in this file**, three sections above the error it
explained, and went unconnected for four milestones. A shorter file does not fix
that; a route into the reasoning does.
`test_claude_md_stays_findable.gd` caps the file at 4 000 lines, asserts the
reference sections are present **and in order**, and refuses any archived document
the manual does not link — an archive nothing routes into is one nobody reads.

**THE SPLIT THIS DID NOT MAKE.** Thirty narrative sections stay at the root and
some are certainly dead. Deciding which is thirty judgement calls, and making them
unilaterally is how a finding gets quietly dropped. The budget makes the next
checkpoint archive a few; the guard makes it impossible to forget.

**AND THIS PR IS THE FIRST TIME TWO AGENTS' WORK COLLIDED, WHICH IS WORTH THE
RECORD.** It landed beside #211 (Codex's `NAV_*` extraction), both branches cut
from the same `main`. The rebase `strict: true` now forces produced **exactly one
conflict** — the Tests row — because each PR had counted its own new script and
neither had counted the other's: mine said `57 arch + 193 unit`, theirs
`56 arch + 194 unit`, and **the truth after both is 57 and 194, which neither
carried**. `test_claude_md_counts_are_current.gd` went red on it rather than
anybody remembering. That is the whole design working: git found the textual
overlap, the guard found the arithmetic one, and the row is set from a measured
run rather than from arithmetic over two stale numbers.

## TWO AGENTS WORK THIS REPOSITORY NOW, AND THE SECOND MANUAL HAD ALREADY DRIFTED

**A SECOND AGENT (GPT Codex) SHARES THIS REPO AS OF 2026-09-06, AND IT ARRIVED
WITH ITS OWN COPY OF EVERYTHING.** `AGENTS.md` — the file Codex reads first by
convention — was a **6 529-line verbatim copy of this file**. Two days later it
was already wrong.

**THE COPY DRIFTED IN THE ONE ROW THAT IS HARDEST TO NOTICE.** Its Tests row
carried the 05-09 figures (192 unit scripts, 1 659 tests, 29 686 assertions)
against this file's 06-09 ones (193, 1 663, 29 712). And its header made two
claims that were **both false**: that it was generated from
`docs/30_bible/Codex.md_SEED.md`, **a file that has never existed**, and that
`test_claude_md_synced.gd` asserted its contents — that guard reads `CLAUDE.md`
and its seed and had never opened it. Nothing under `test/`, `tools/`, `.ci/` or
`.github/` mentioned `AGENTS.md` at all.

**AND THE CHECKPOINT PROCEDURE EXISTED TWICE AND HAD DIVERGED IN SUBSTANCE, WHICH
IS THE WORSE HALF.** `.claude/commands/save.md` and
`.agents/skills/source-command-save/SKILL.md` both held the full `/save` steps —
and one instructed its agent to write the live project state into **`CLAUDE.md`**
while the other named **`AGENTS.md`**, with memory paths of `.claude/` against
`.Codex/`. So two agents were told, in writing, to checkpoint one project into two
documents. **The drift was not an accident; it was instructed**, and neither
instruction was wrong on its own terms — which is exactly why reading either one
would never have found it.

**ONE HOME, TWO POINTERS, AND THE GUARD RESOLVES THE TARGET.**
`docs/30_bible/CHECKPOINT.md` is the procedure; `AGENTS.md`, the slash command and
the skill file are all pointers under 30 lines.
`test_agent_entry_points_are_pointers.gd` refuses a copy growing back **and refuses
a pointer naming a file that is not there** — the half a line count cannot do, and
the half `Codex.md_SEED.md` would have walked straight through. Sixth instance of
this corpus's most-repeated shape: **a document asserting a check that does not
exist is worse than one asserting nothing.**

**`main` NOW REQUIRES A BRANCH TO BE UP TO DATE BEFORE IT MERGES.**
`strict_required_status_checks_policy` was `false` from the day the ruleset was
applied, and with one agent that cost nothing. With two it is the quiet failure:
two branches from the same `main`, no textual overlap, both green, both merge —
and **the second was never tested against the first**. Git reports nothing,
because there is nothing to resolve. TDD-12 §1.3.3, and the committed
`.github/main-ruleset.json` was updated in the same change, because a settings
file that disagrees with the applied settings is the drift this whole section is
about.

**EACH AGENT GETS ITS OWN WORKTREE, AND TRAP 16 IS WHY.** `D:/Claude Code/sv-claude`
and `sv-codex` beside the main checkout, which stays on `main` so there is always a
merged tree to play. One HEAD, one index and **one `.godot/`** shared between two
agents is trap 16 as a standing condition rather than an accident: killing Godot
mid-run corrupts the import cache, and the symptom is a suite that prints its
header and never finishes — no failure, no message. That cost most of an afternoon
on 2026-08-20 **with one agent**. The `pre-push` hook is repo config, so it holds in
every worktree; the price is one full Godot import per worktree.

**AND THE `NAV_*` FIGURE THIS FILE HAS PUBLISHED FOR THREE CHECKPOINTS IS WRONG IN
BOTH DIRECTIONS.** Codex asked for it to be re-measured before anybody acted on it,
and was right to: this file says *"`NAV_AGENT_RADIUS` and its four siblings, 22
references across 8 files"*. Measured 2026-09-08: **21 references across 9 files**,
and there are **seven** siblings rather than four — `NAV_AGENT_HEIGHT`,
`NAV_MAX_SLOPE`, `NAV_MAX_CLIMB`, `NAV_BAKE_FLOOR`, `NAV_BAKE_CEILING`,
`NAV_CELL_SIZE`, `NAV_CELL_HEIGHT` — formerly at `scripts/core/vetraio_layout.gd:58-95`.
**Closed by PR #211:** all eight unchanged declarations now live in the autoload-free
Core class `PawnNavigation`. The clearest former dependency was `sandbox_layout.gd`:
the 40 m bench asked the 120 m district how wide a body was. It now reads the shared
pawn definition directly. Both maps reproduce byte-identically, including their
collision scenes, MapData and navmesh resources; no bake value or assignment order changed.

## THE TICK GATE FAILED A BUILD WITH NOTHING BEHIND IT AGAIN, ONE ESTIMATOR ALONG

**AND THE CORRECTION IS MINE FROM YESTERDAY.** `test_server_tick_budget.gd` was
changed on 2026-09-03 from asserting the **max** to asserting the **p99**, on the
strength of three local runs, and this file published *"the p99 spans 9 % across
the three and the max spans 99 %"*. On 2026-09-04 the p99 read **8.493 ms** on CI
against a budget of 8.0, on a map change that does not touch the tick path.

**THE SAME COMMIT, RE-RUN, NO EDIT OF ANY KIND:**

| CI, one commit | mean | p95 | p99 | max |
|---|---|---|---|---|
| first run | 4.238 | 5.116 | **8.493 — FAILED** | 8.887 |
| re-run | 3.937 | 4.328 | **4.893 — passed** | 5.977 |

**74 % apart on the p99 with the code byte-identical**, which is the whole finding.

**THREE QUIET RUNS ARE NOT A SPREAD.** Fourteen local runs on 2026-09-04 — seven on
`main`, seven on the branch:

| over 7 runs of `main` | low | high | spread |
|---|---|---|---|
| mean | 2.629 | 2.847 | **8 %** |
| p95 | 3.059 | 3.788 | **24 %** |
| p99 | 3.296 | 6.702 | **103 %** |

**THE CAUSE IS ARITHMETIC, NOT LUCK.** `sorted[int(180 × 0.99)]` is index **178** —
the **second-worst reading**. It forgives exactly one interrupted tick, and two
interrupted ticks in 180 is an ordinary event on a shared runner. **A "p99" over
180 samples is not a percentile; it is `second-worst` wearing a percentile's name.**
The p95 is index 171, the tenth-worst, which is why it moves by a quarter where the
p99 moves by double.

**THE TARGET IS NOT LOWERED, BECAUSE THIS TEST WAS NEVER MEASURING IT.**
PERFORMANCE_BUDGET §5.3 still wants p99 ≤ 8.0 ms and is right to — *"a game decided
in 0.4 s contest windows is ruined by the 1 % of frames that hitch"*. Estimating a
99th percentile needs far more than six seconds of ticks, and the suite is already
over its 180 s limit. **The p99 belongs to a long server log; what six seconds of CI
can honestly assert is the p95.** Both are printed every run with the tail ratios.

**IT STILL CATCHES A REGRESSION AND THAT IS FALSIFIED RATHER THAN CLAIMED.**
Dropped to a 2.0 ms budget it fails at a p95 of 2.757 and names the criterion. CI's
worst observed p95 is 5.116 against 8.0 — **36 % of headroom, where the p99 had
none.**

**AND THIS IS THE THIRD TIME THE SAME LESSON HAS BEEN PAID FOR.**
`test_crowd_perf.gd` learned it in August and moved to a p95. Yesterday this file
wrote *"a lesson applied to one instance is a lesson half learned"* — and then
applied it half way, moving one estimator instead of asking what 180 samples can
support.

**THE MAP CHANGE WAS EXONERATED BY MEASUREMENT, NOT BY THE RE-RUN.** Seven local
runs per branch: mean 2.772 against 2.868 (+3.5 %, inside `main`'s own 8 % spread),
p95 3.29 against 3.37, and the branch's p99 was **more** stable than `main`'s
(3.61-4.51 against 3.30-6.70).

## THERE IS A BENCH NOW: `MAP-SANDBOX`, 40 m, AND `sandbox.bat`

**ASKED FOR FROM THE CONTROLS: *"for testing and debugging wouldn't it be better
to have a way smaller map, with just one or two bots?"*** Yes, and the week before
it was the argument: every defect reported cost minutes of walking to reach the
arrangement that showed it, and one of them — a hunting bot wedged in a corner —
needed a corner of a known shape to be reproduced at all.

```bash
sandbox.bat            REM a server, 1 hunter, 12 civilians, and you
sandbox.bat 1 0        REM one hunter and an EMPTY district
sandbox.bat 1 12 3     REM ...plus 3 QUARRY bots: somebody to stalk
sandbox.bat 0 12 3     REM nobody hunting you at all. Seed is now arg 4
```

**EVERY SOLID IN IT IS THERE FOR A NAMED REASON**, which is the difference between
a bench and a doodle. Two spawns **15.3 m apart** so an encounter happens rather
than being travelled to; a **centre block** so the Compass has something to point
around and a chase can be broken at all; a **nook with one 2 m mouth**, which is
the corner the bot walked into; two **stalls at `H_VAULT`**, the band whose only
geometry in the district is a market stall and which hid the floor-height defect
for three milestones.

**AND `MAP_SANDBOX.md` §4 IS THE HALF THAT MATTERS: WHAT MUST NOT BE MEASURED ON
IT.** `SpawnRules` wants 40 m between a victim and their killer, which a 40 m
courtyard cannot give — so **every respawn here takes rule 7's fallback**. There
are no zones, so no density; no circuits, so no processions. A number taken on the
bench and quoted about the game is the shape of every retracted figure in this
corpus, and this map makes that easy to do by accident.

**THE MAP IS NO LONGER AN `ext_resource` IN THE ROOT SCENES.** It was one in both,
plus a `const` in `server_root.gd` and a `load()` inside `LocalPawnDriver` — four
places, and remembering three of them is a client that draws one place and stands
in another. `MapCatalogue` is the one table, and `client_root.tscn` gained a script
for it: it was the only root scene with none.

**AND THE BOT NEEDED ITS OWN COMMAND LINE.** `bot_client.gd` instantiates the
client root itself and never goes through `boot.gd`, so nothing had published its
flags — the bot would have loaded the district while the server ran the courtyard,
which reads as a broken navmesh rather than a wrong map. `LaunchConfig.active` is
the seam, a **static rather than a ninth autoload** (never-do #15), and every
reader falls back to the default because **null is the normal case in a test**:
every test that boots a root scene does so directly.

**THE PLUMBING IS SHARED AND THE BAKE SETTINGS ARE WHY.** `MapBuild` holds the box
builder, the navmesh settings, the bake and the byte-stable scene write. A bench
baked with a different agent radius, cell size or climb height is a bench the pawn
traverses **differently**, so a defect reproduced on it would not be the defect.
`generate_map_vetraio.gd` went 319 → 176 lines and **the district reproduces
byte-identical**, which is the only reason that refactor was safe to make.

**THE EIGHT `NAV_*` CONSTANTS NOW LIVE IN `PawnNavigation` (PR #211).** They describe
the shared pawn and static bake contract, not the district. The earlier claim of
four siblings and 22 references across 8 files was wrong: the pre-extraction census
found seven siblings and 21 radius references across 9 files. The definitions and
all executable readers have moved without changing any value; both maps reproduce
byte-identically. No tunables or autoload dependencies were introduced.

**THE DEBUG DISTRICT MAP WAS DRAWING THE WRONG DISTRICT.** `district_map.gd` read
`VetraioLayout` unconditionally and scaled every position by the district's 120 m,
so on a 40 m bench it drew the district and put the player's dot in the wrong
corner of it. **An instrument wrong in a plausible direction is worse than no
instrument** — recorded three times in this file and not yet applied to itself. It
asks which map is open now, and a bench gets a ground rectangle, the blocks, the
crowd and the player rather than a hue legend that means nothing.

**AND MY OWN GUARD PASSED OVER THE ONE FILE THAT NAMED IT.**
`test_sandbox_is_debug_only.gd` scanned for `"sandbox"` through
`SourceScanner.code_contains`, which matches **case-sensitively** — so it walked
straight past `SandboxLayout`, the identifier every real offender would use. It
matches case-insensitively now, and `scripts/debug/` is exempt by construction
rather than by listing: it is already excluded from all three release presets.
Falsified against `SandboxLayout.MAP_SIZE` planted in `ContractSystem`.

**AND LOOKING AT IT IS A TOOL NOW.** `tools/map_probe.tscn` boots the real client
root, disables the camera rig, drops an orthographic eye over the map and marks
every spawn point in red — a wall built from its centre rather than its corner, a
floor that straddles its height, a nook whose mouth is on the wrong side are all
instant in a picture and invisible in a coordinate list. All three have happened
here.

```bash
godot --path . res://tools/map_probe.tscn -- --map sandbox
```

**ITS FIRST VERSION FREED THE PAWN TO GET IT OUT OF SHOT**, which took
`LocalPawnDriver` down with it — *"the Object-derived class of argument 2
(previously freed)"* on the next physics frame. The rig is **disabled** rather than
freed now, and the pawn is left standing, which is worth seeing anyway.

## A `-s` SCRIPT CANNOT COMPILE A CORE CLASS, AND THAT COST ONE INVARIANT SINCE M0

**THE ERROR WAS ON THE SCREEN EVERY RUN FOR FOUR MILESTONES AND WAS READ AS
NOISE**, including by me yesterday: *"Nonexistent function 'full_ring_distance' in
base 'GDScript'"*, twice per run of `generate_default_tuning`. I recorded it as *"a
static call on a `class_name` made from `_init()`, while the global class registry
is still being built"*. **That was wrong, and isolating it took one throwaway
probe.**

```
SCRIPT ERROR: Compile Error: Identifier not found: Tuning
   at: GDScript::reload (res://scripts/core/compass/compass_math.gd:130)
```

**A `-s` SCRIPT IS COMPILED BEFORE THE AUTOLOADS ARE REGISTERED.** So `Tuning` is
an unresolvable identifier — and ADR-0005 makes `Tuning` **the one permitted
autoload in Core**, deliberately, because threading a `TuningProfile` through every
constructor would be worse. **Sixteen Core classes read it.** Every one fails to
compile, along with everything depending on them, and **GDScript caches the
failure**: they stay broken for the rest of the process *even once the autoloads
exist*, which is why the `Tuning` autoload's own `_ready` reported it too.

**THE FAILURE SURFACES FOUR FILES FROM ITS CAUSE, WHICH IS THE WHOLE REASON IT
SURVIVED.** The message names `CompassMath.full_ring_distance` — a function that
plainly exists, on a class that is plainly correct. The cause is the launch mode,
and **nothing in between mentions either**. `Tuning.ticks()`'s parse error did this
same thing at US-0059 and the note then was *"the failure surfaces four files
away"*; this is that lesson in a second place, and it went unlearnt for a day.

**WHAT IT ACTUALLY COST: `validate()` CHECKED 36 OF 37 INVARIANTS IN THE ONE TOOL
THAT WRITES THE DATA.** Invariant 33 pins `TUN-COMPASS-CONE-FULL-RADIUS` equal to
`TUN-COMPASS-LOCK-RANGE` — the rule that makes the Compass arc stop pointing at
exactly the range the lock starts working, so a player learns one boundary rather
than two. **The generator could not check it and said so, every run, in a message
about something else.**

**THE FIX IS THE ONE THIS PROJECT ALREADY MADE ONCE: A SCENE, NOT A `-s` SCRIPT.**
`tools/generate_default_tuning.tscn`. `tools/anchor_census.gd` was converted for
exactly this reason and its note says so — *"a `-s` script gets no autoloads, so
`Tuning` does not exist and every Core class that reads it fails to compile"* —
which was **already in this file** and was not connected to the error being read
three sections above it.

```bash
godot --headless --path . res://tools/generate_default_tuning.tscn
```

**FALSIFIED RATHER THAN ASSUMED SILENT.** Planting `cone_full_radius` 20.0 → 30.0
against a lock range of 20.0 now reports *"33. compass.cone_full_radius (30.00)
must EQUAL compass.lock_range (20.00)"* by name and by number. **Silencing an error
and delivering the check it was hiding are different outcomes**, and only the plant
tells them apart.

**AND I NEARLY REPORTED AN ARCHITECTURE VIOLATION THAT IS NOT ONE.** `CompassMath`
lives in `scripts/core/` and reads an autoload, which the folder map calls
forbidden — *"PURE. No Node, no get_node, no autoloads."* **`test_core_is_pure.gd`
permits exactly one**, `Tuning`, and says why in its own docstring. Reading the
guard before filing the finding is what stopped it, and that is the third audit
claim withdrawn here after `LaunchConfig.unknown` and
`TUN-SUSPICION-GAIN-WHISPERBOLT-WINDUP`.

**THE OTHER FOUR `-s` TOOLS WERE CHECKED RATHER THAN ASSUMED, AND ONE OF THEM WAS
WORSE OFF.** Both map generators run clean and **reproduce byte-identically**,
because `VetraioLayout`, `SandboxLayout` and `MapBuild` read no autoload at all,
and `persona_lineup.gd` touches no Core class.

**BUT `tools/input_probe.gd` COULD NOT LOAD AT ALL, AND HAD NOT SINCE
2026-08-27.** It names `TuningProfile` to read `TUN-SPEED-STICK-DEADZONE` from the
shipped resource, and the engine prints the whole cascade:

```
compass_math.gd:130   Identifier not found: Tuning
tuning_invariants.gd  Failed to compile depended scripts
tuning_profile.gd     Failed to compile depended scripts
input_probe.gd        Failed to compile depended scripts
ERROR: Failed to load script "res://tools/input_probe.gd"
```

**It broke the day invariant 33 was added**, because that is what put `CompassMath`
into the profile's dependency chain — nine days, in the tool this file documents
for diagnosing phantom input, and **the tool that found the sim-pedals defect**.
Nothing said so: a script that fails to load prints an engine error and **none of
its own output**, which reads exactly like a probe that found nothing to report.
Trap 14's shape — a documented command that does not run.

**AND ITS OWN DOCSTRING ARGUED FOR THE THING THAT BROKE IT.** *"Straight from the
resource rather than through `Tuning`. The autoloads are added after
`_initialize()` returns"* — a correct observation about autoload **timing** that
missed the autoload **dependency**: naming `TuningProfile` at all is what pulled
the chain in, whichever way the value was read. It is a scene now, and it reaches
its own headless refusal, which it could not do before.

**SO THE DEFECT WAS IN TWO OF THE FIVE `-s` TOOLS AND I FOUND THE SECOND ONLY BY
WRITING THE GUARD.** Reasoning found one; the sweep found the other.

**`test_a_script_tool_gets_no_autoloads.gd` IS THE GUARD, AND IT IS TRANSITIVE
BECAUSE ONE HOP WOULD HAVE MISSED BOTH CASES.** Neither tool names `CompassMath`;
both reach it at depth three through `TuningProfile`. It builds `class_name -> file`
for all 211 classes, marks the 92 that call the autoload, and walks the closure
breadth-first so the message is the **shortest** chain:
`generate_default_tuning.gd -> TuningProfile -> TuningInvariants -> CompassMath`.
Falsified by planting `extends SceneTree` back, which reddens it with exactly that
line.

**AND THE GUARD WAS WRONG TWICE BEFORE IT WAS RIGHT, BOTH TIMES IN MY FAVOUR.**
Its first needle was the substring `Tuning.`, which also matches
`MovementTuning.new()` — and its premise assertion demanded that **fewer than a
third** of classes call the autoload, on my assumption that a large set meant a bad
needle. Both were guesses about the codebase wearing a guard's clothes. Measured:
**94 of 225 files under `scripts/` call it**, because ADR-0005 makes it the way
every gameplay constant is read, so the large set is the design working. **I
changed the needle believing it explained the `input_probe` hit. It did not — that
hit was true, and I nearly explained away the second defect while fixing the
first.**

## THE BENCH TAKES A QUARRY COUNT, AND THE CYCLE LIMITS WHAT THAT CAN MEAN

**ASKED FOR FROM THE CONTROLS: *"X gives me the number of hunters that hunt me
and Y the amount of civilians, but can i also get a Z for the amount of NPCs i
can hunt?"*** Built — and **half the premise is not how the contract graph
works**, which is worth more than the flag.

```bash
sandbox.bat 1 12 3       REM one hunter, 12 civilians and 3 QUARRY bots
sandbox.bat 0 12 3       REM nobody hunting you - three to stalk
sandbox.bat 1 12 3 42    REM the seed is the FOURTH argument now
```

**A QUARRY BOT IS A HUNTER'S COMMAND LINE WITH `--hunt --reckless` REMOVED.** It
joins the same lobby as a real player, strolls in random legs and pursues nobody
— somebody to stalk, approach and kill without being chased while you do it.
Nothing in `bot_client.gd` changed: `play.bat` has launched exactly this bot
since US-0066 and the sandbox simply never offered one.

**BUT X WAS NEVER "HUNTERS THAT HUNT ME", AND Z CANNOT BE "HOW MANY I CAN
HUNT".** `ContractCycle` is a single Hamiltonian cycle over the living players
(GDD-03 §7), so **every player has exactly one outgoing edge and exactly one
incoming edge** — for a reason that has nothing to do with launchers: *deleting a
node from a cycle leaves a cycle*, which is what makes a repair free and why a
cycle beat a random matching. So:

- **at most one bot holds a contract on you, however many hunt**;
- **exactly one player is yours to kill at any instant**;
- which one is **the cycle's to decide, not the command line's**.

**WHAT THE THIRD NUMBER ACTUALLY BUYS IS THE ODDS AND THE TEMPO.** With one
hunter and three quarry your contract is a passive bot **three times in four**,
so a stalk can be practised without a chase running through it; `0 12 3` removes
the chase entirely. And in a `3 0` run the two hunters not assigned to you are
**hunting each other** — worth knowing before reading anything into what they do.

**A QUARRY BOT IS NOT STUNNABLE, AND THAT IS THE TIER GATE RATHER THAN AN
OVERSIGHT.** `TUN-STUN-MIN-TIER` makes an Anonymous player unstunnable and a
strolling bot never leaves Anonymous — which is the rule that makes *"an
Anonymous hunter cannot be stunned, patience is genuinely safe"* true. Quarry is
there to be **killed**; stunning is practised against `--reckless` hunters. Same
reason `--reckless` had to exist at all.

**THE CAP IS ON THE TOTAL AND IT WAS ON NEITHER NUMBER BEFORE.** Six is the lobby
and you are one of it, so `set /a` trims the **quarry** and keeps the hunters: a
session that asked for hunters is a session about being hunted. A seventh peer is
refused by the handshake — it starts, fails to join and vanishes, which reads as
a bot that crashed rather than as a lobby that is full.

**AND THE QUARRY CONTINUES THE `--bot` NUMBERING RATHER THAN RESTARTING AT 1.**
That number is the bot's own RNG seed and nothing else, so two bots given the
same one walk the same legs at the same moments — they would stroll as a pair and
read as one body with a shadow.

**VERIFIED BY RUNNING IT, BECAUSE A BATCH FILE FAILS SILENTLY.** A neutered copy
with every `start` replaced by an `echo` was run over six argument shapes —
default, `1 12 3`, `0 12 3`, `1 12 3 42`, `3 12 4` and `6 12 2` — and each was
read for the right process count, the right flags and distinct `--bot` seeds. A
mis-parsed count starts the wrong number of processes, and what you see is bots
that crashed.

**MY OWN PATCH SCRIPT FAILED ITS FIRST ASSERTION, WHICH IS TRAP 15 PAYING OUT.**
`sandbox.bat` is **CRLF** and the needles were written `\n`, so every replace
would have matched nothing and reported success. The assert caught it before a
single byte moved.

## ADR-0018'S PROSE DEBT IS SWEPT, AND THERE WERE SEVEN PLACES RATHER THAN FOUR

**REPORTED AT THREE CONSECUTIVE CHECKPOINTS AND NOT ACTED ON.** `TUN-STUN-SCORE`
went 100 → 200 on 2026-09-03 and the prose did not hear. All of it is corrected.

**THE FOUR THAT WERE NAMED**: `01_vision.md:233` (the Mei archetype — the file
**contradicted itself two pages apart**, since `:132` already carried 200),
`07_balance.md:417` (the aggressor/defender model), `08_liveops_and_future.md:135`
(the new-player on-ramp, *"= 100, equal to a kill"*), and `07_balance.md:706`'s
release checklist still asserting `TUN-SCORE-STUN == TUN-SCORE-CONTRACT` against
an invariant that became `>`.

**AND THREE MORE THAT THE REPORT MISSED, BECAUSE IT WAS A GREP FOR ONE ID.**

- **`07_balance.md:554`'s skill-floor table** — *"scores 100 per success, equal to
  a kill"*, which names the **value without naming the tunable** and so was
  invisible to every search that found the other four. It is the row about the
  floor strategy, which is the exact strategy ADR-0018 paid.
- **`TUNABLES.md:516` — THE PRIMARY DOCUMENT CONTRADICTED ITSELF ONE ROW APART.**
  `TUN-SCORE-ESCAPE`'s rationale said it lands *"equal to a base kill **and to
  `TUN-SCORE-STUN`**"*, and the row **directly above it** had already moved to
  200. The value is untouched and was never in doubt — ADR-0014 sourced it and got
  it exactly. What is wrong is the comparison, and the corrected sentence is worth
  more than the fix: **the prey's three teeth are deliberately not priced alike, and
  a read stun is the expensive one.** `US-0097:150` carries the same claim and is
  corrected the same way.
- **`US-0065`'s ticked criterion was a false sentence**: *"Stun scores exactly one
  base kill… `TUN-SCORE-STUN == TUN-SCORE-CONTRACT`"*. **It stays ticked**, and
  that distinction is the point: what it asserts about the **code** is still exactly
  true — the rule reads the pin rather than a literal, which is *precisely why the
  value could move without `server_root` changing*. Only its arithmetic went stale.
  Unticking it would claim an implementation regressed when a number was re-priced.

**THE TOTALS IN §4.5 ARE DELIBERATELY NOT RE-DERIVED, AND §4.9's ANSWER GETS
STRONGER ANYWAY.** *Can a defensive player podium?* — yes, and the change pays the
defensive column. But §4.3 already holds every kills-and-stuns figure in §4.4 and
§4.5 stale on a **45 % stun rate measured before ADR-0013** removed the
last-instant save. **Re-pricing one input of a model whose other inputs are known
stale produces a number that looks fresher than it is.** `TEL-STUN-RATE` settles
both at once, and §4.9 now says so rather than quietly carrying a new total.

**AND THE EDIT WENT THROUGH THE CODEGEN, WHICH IS THE PIPELINE FIXED AN HOUR
EARLIER.** `TUNABLES.md`'s rationale column is the source of the generated
docstrings, so `scoring_tuning.gd` regenerated with the corrected sentence and no
`.tres` moved — the value did not change. **First real exercise of the repaired
workflow**, end to end, and it behaved.

**WHAT NO TEST CAN SEE, RESTATED BECAUSE IT IS NOW THE ONLY DEFENCE.**
`test_tunables_match_the_document.gd` compares the **table** against the shipped
profile, and all seven of these were **prose**. Nothing in this project reads a
sentence. The sweep was found by grepping for a value that a document had spelled
out in words, and the one that took longest to find never named the tunable at all.

## THE TUNING CODEGEN DESTROYED SHIPPED GAMEPLAY WHEN RUN AS DOCUMENTED

**IT REPRODUCES NOW, END TO END, INCLUDING THE `.tres` NOBODY WAS CHECKING.** The
finding below was reported on 2026-09-04 during `MAP-SANDBOX` and deliberately left
alone; taken on its own it turned out to be **two independent defects, and the
second is the worse one**.

```bash
python tools/tuning_codegen/run_all.py && gdformat scripts/ && git diff --stat scripts/
godot --headless --path . res://tools/generate_default_tuning.tscn && git diff --stat data/tuning/
```

Both are empty on a clean checkout now. **The second line did not exist**, which is
the whole story: the verification stopped at `scripts/`, so the data the game
actually loads was outside it for four milestones.

**DEFECT 1: TWO ASTERISKS DELETED A TUNABLE, AND TOOK THE GUARD WITH THEM.**
ADR-0018 wrote `TUN-STUN-SCORE`'s new value as `**200**` to mark that it had
changed. `parse_tunables.py` matches a value cell with a leading-digit pattern,
which fails on an asterisk — so the row was **dropped**, `combat_tuning.gd` kept
the pre-ADR **100**, and regenerating deleted `combat.score` and `scoring.stun`
outright. `tuning_invariants_score.gd` reads `p.scoring.stun` for **invariant 19**,
so the documented command broke the build.

**AND `test_tunables_match_the_document.gd` — WRITTEN FOR EXACTLY THIS DRIFT —
COULD NOT SEE IT, FOR THE SAME REASON.** Its `_first_number` walked past `**200**`
with `is_valid_float()`, found no number in any later cell, and **dropped the row
too**. Two independent readers of one column, defeated identically by the same two
characters. Falsified: with emphasis stripped it reports
`TUN-STUN-SCORE: document says 200.0, data ships 100.0` on unmodified `main`, and
coverage goes **290 -> 292**.

**AND `gen_tuning.py` REFUSES TO WRITE ANYTHING NOW IF A DOCUMENTED VALUE CANNOT BE
READ.** That refusal is the half that generalises: a code generator which silently
emits less than it was given is worse than one that stops, because the diff then
looks like a deliberate deletion. It names every unreadable row and exits non-zero
**before** touching the output directory.

**DEFECT 2: THE `.tres` WRITER CARRIED A FOURTH COPY OF 45 NUMBERS, AND IT HAD
DRIFTED.** `tools/generate_default_tuning.gd` writes every section's resource from
that section's own class defaults — except the abilities, because **`AbilityData`
is one class holding four abilities' fields** and a class default can only be one
of them: `duration` is 6 s of smoke for Cinderfall and 15 s of a false face for
Second Face. So that file held a hand-written `ABILITIES` table, and the codegen
README told you to run it after every regeneration.

**MEASURED, ON A CLEAN CHECKOUT, FROM A RUN THAT PRINTED SUCCESS:**

| What the documented command did | Cost |
|---|---|
| `TUN-CINDERFALL-THROW-RANGE` **0.0 -> 8.0** | undoes ADR-0013 — the cloud is thrown again |
| `TUN-CINDERFALL-DURATION` **6.0 -> dropped** | the value the owner set at the controls the day before |
| `effect_script` **dropped from both live abilities** | **Cinderfall and Lunge stop doing anything at all** |

**THE THIRD ROW IS THE ONE THAT MATTERS, AND IT WAS NEVER IN THAT TABLE.** US-0067
hand-patched `effect_script` into `cinderfall.tres` — against trap 1 — so the
generator had never heard of it. A regeneration would have left `CinderfallEffect`
and `LungeEffect` unreachable, which is the shape of every defect this week:
**something that looks correct and is never reached.**

**AND THE `duration` HOLE IS TRAP 17'S OWN ORIGINAL INSTANCE, FOUND FROM THE OTHER
END.** That table never had a `duration` key for Cinderfall at all — which is why
the cloud shipped at **0.0 from M0 against a published 4.0**, and why nothing asked
how long a cloud lives until `SYS-KILL` did. The defect and its cause sat in this
file for three milestones and nobody had joined them.

**`AbilityDefaults` IS THE FIX, AND IT IS GENERATED BESIDE `ability_data.gd`.**
`gen_abilities.py` emits `scripts/core/tuning/ability_defaults.gd` — 4 abilities,
40 values — from the same parse that writes the class. What stays hand-written in
the writer is `ABILITY_WIRING`: an id, a display key, a tell sound and the
server-only effect script. **Content and code, never a number.**

**AND THE GUARD ASSERTS THE PROPERTY RATHER THAN THE TABLE.**
`test_the_ability_writer_holds_no_tunables.gd` reads `ABILITY_WIRING` out of the
script's own **constant map** rather than parsing the source, so a reformat cannot
defeat it, and refuses any field `TuningIndex` has a `TUN-` id for. Falsified
against `"cooldown": 45.0` planted back into Cinderfall's entry.

**MY OWN GUARD NAMED THE WRONG TUNABLE ON ITS FIRST FALSIFICATION RUN.** It mapped
field -> id, and **all four abilities have a `cooldown`**, so the map held whichever
the index listed last: a planted Cinderfall value was reported as shadowing
`TUN-WHISPERBOLT-COOLDOWN`. The guard fired correctly and lied about why — the
*instrument wrong in a plausible direction* this file has now recorded five times.
Keyed on `(ability, field)`.

**THE `.tres` ARE BYTE-REPRODUCIBLE, AND A HAND-EDIT IS VISIBLE IN THEM.** Unlike a
`.tscn`, Godot derives a `.tres` `ext_resource` id from content rather than
randomly, so no id stripping is needed and two consecutive runs are identical.
**Which makes a hand-typed id a signature**: `cinderfall.tres` carried
`id="2_cndrf"` and `lunge.tres` carried `id="2_lunge"`, mnemonics no generator
produces. That is how US-0067's hand patch was identified rather than guessed at.

**ONE ROW LEGITIMATELY DISAPPEARS AND IT IS NOT TRAP 17 RETURNING.**
`throw_range = 0.0` is no longer written to `cinderfall.tres`, because
`ability_data.gd`'s class default is **also** 0.0 and Godot omits a property equal
to its default. Both are emitted by the same generator from the same parse in the
same run, so a missing row can now only mean *equal to the documented value* — and
`test_tunables_match_the_document.gd` compares the **loaded profile**, which
resolves through the default either way. Trap 17's rule stands for a hand-written
`.tres`; this is the case where the hazard is closed by construction.

**AND A PRE-EXISTING ERROR PRINTED ON EVERY RUN OF THIS TOOL — FIXED 2026-09-05,
AND THE CAUSE I NAMED HERE WAS WRONG.** See the section directly above.

**WHAT IS STILL STALE IS STILL REPORTED RATHER THAN SWEPT.** ADR-0018 moved
`TUN-STUN-SCORE` to 200 and four prose places did not hear: `01_vision.md:233`,
`07_balance.md:417` and `08_liveops_and_future.md:135` all read **100**, and
`07_balance.md:706`'s release checklist still asserts
`TUN-SCORE-STUN == TUN-SCORE-CONTRACT`, which invariant 19 stopped being on
2026-09-03. **`test_tunables_match_the_document.gd` still cannot see any of them**
— it compares the table against the shipped profile, and every one of these is
prose. Untouched by this work, and named here so it is not lost.

## ADR-0019: A STUN COSTS THE PURSUER THE CONTRACT, AND HALF THE RULE WAS ALREADY THERE

**REPORTED FROM THE CONTROLS AS THE REFERENCE'S RULE RATHER THAN AS A DEFECT:**
*"if a pursuer gets stunned or the prey escapes, his contract is failed and he
gets a new prey."* Checked against the code before acting, and **exactly half of
it was already true**: an escape has removed the hunter from the cycle and
reinserted them since US-0097, which is the whole of ADR-0014.

**A STUN DID NOTHING TO THE CONTRACT AT ALL.** `StunSystem._land` froze the
pursuer for `TUN-STUN-FREEZE` 4 s, held them at `TUN-SUSPICION-MAX`, and exiled
them from that one target for `TUN-STUN-LOCKOUT` 12 s — **and then they walked
back to the same person.** GDD-03 §10.2 argued the exile was *"what makes it
counterplay rather than a delay"*, which was the strongest thing true of the built
game and is now superseded by a stronger version of its own argument.

**IT IS `report_escape`'s OWN BODY WITH A DIFFERENT REASON ON IT**, deliberately
rather than a second route. The clear, the anti-repeat memory, the breath and the
reinsertion are one rule `test_contract_cycle_fuzz.gd` drives over 10 000 events —
and **the line a copy would omit is `cycle.remember` before the removal**, which is
the only thing stopping the pursuer being handed straight back the person who just
stunned them. It is one line, it is not obvious, and it has no local reason to
exist.

**THE EXILE STAYS AND IS NOT NOW REDUNDANT.** It is a per-`(hunter, target)` rule
that still binds if the cycle later deals those two together again, and **removing
it because the contract loss subsumes it would be the weakening never-do #13
forbids outright.** The prey is paid once as well: `TUN-SCORE-STUN` 200, never also
`SCORE-ESCAPE`, or one read is priced twice under two names.

**`Reason.STUNNED` IS APPENDED, NEVER INSERTED.** `NET-S2C-CONTRACT-ASSIGNED`
carries `reason:u8` as an index into `ContractSystem.Reason`, so a name inserted in
the middle silently retells every client a different story about why its contract
moved — `PawnStateId.ALL`'s hazard in a second enum. Both indices are asserted, and
the protocol row now lists the values.

**THE ASSERTION THAT MATTERS IS THE ARGUMENT ORDER, NOT THE RULE.**
`stunned(stunner, target, lockout)` carries two peer ids of the same type in
adjacent positions and one of them now loses a contract. Transposed, **the player
who read an approach and defended themselves is punished for it** — and every
assertion about the rule still passes, because those call `report_stun` directly.
`test_match_consequences.gd` is that hop, and the planted transposition reddens two
of its assertions by name.

**AND THE WIRING IS PROVEN ON THE REAL SCENE FOR 0.4 s OF BUDGET.**
Neither unit file boots `server_root.tscn`, so a deleted `connect` line would leave
both green and the mechanic gone — which is exactly what left
`NET-C2S-ABILITY-REQUEST` with no caller under three completed stories. The
integration assertion **raises the signal rather than earning a stun**: what
`SYS-STUN` decides is `test_stun_system.gd`'s and is not re-proven at 30 Hz. It
stops at the one hop, and says in the file why it does not settle through the
breath: **the first version did settle, and cost 3.8 s** of a suite already over
its 180 s limit, to re-prove in a hundred physics ticks what the unit file proves
in milliseconds. 183.8 s → 184.2 s.

**MY OWN TEST ASSERTED THE SEED RATHER THAN THE RULE, AND THE RUN FOUND IT.**
`test_the_stunner_keeps_their_own_hunt` pinned the stunner's contract *after* the
breath and read 21 against an expected 23 — **correctly**, because the reinsertion
may legitimately land the stunned pursuer directly in front of the stunner. It
asserts before the breath now, and only that the stunner still holds somebody
after. **`test_contract_escape.gd`'s equivalent assertion has the same shape and
passes on its own seed** — reported rather than changed, because it is not wrong
today and re-seeding it is a separate judgement.

**`MatchConsequences` IS THE SPLIT THIS FORCED**, at 417 lines against 400, and it
is the seam `MatchAnnouncer` left behind: that split took *who is told what*, this
one takes *what else changes*. Every method in it is a signal handler and none of
them decides anything. **Fifth file the length guard has usefully split.** Its
collaborators are named fields rather than a seven-argument constructor —
`.gdlintrc`'s six-argument cap read as the design signal it says it is, since seven
positional systems is a call site where a transposition is invisible.

**AND THE DECISION LOG HAD NEVER HEARD OF ADR-0018.** Neither §1's log nor §2's
index carried a row for it, a day after it was accepted. **Third time this index
has run short of the ADRs that exist**, and the first two were found the same way —
by going to add the next one. Both are logged now.

**WHAT IS STILL STALE AND IS REPORTED RATHER THAN SWEPT — ADR-0018 MOVED A NUMBER
AND FOUR PROSE PLACES DID NOT HEAR.** `TUN-STUN-SCORE` reads **100** at
`01_vision.md:233` (the Mei archetype), `07_balance.md:417` (the aggressor model)
and `08_liveops_and_future.md:135`, against the **200** TUNABLES and
`01_vision.md:132` both carry — so **one document contradicts itself two pages
apart**. And `07_balance.md:706`'s release checklist still asserts
`TUN-SCORE-STUN == TUN-SCORE-CONTRACT`, which invariant 19 stopped being on
2026-09-03 when it became `>`. GLOSSARY names the ID without a value and is fine.
GDD-03 §10.1's row is fixed here only because this change rewrites the table it
sits in; the other four are one clean sweep and folding them into this diff would
make it unreadable. **`test_tunables_match_the_document.gd` cannot see any of
them** — it compares TUNABLES' table against the shipped profile, and every one of
these is prose.

## THE HUNTING BOT WALKED INTO A CORNER AND STAYED THERE

**REPORTED FROM THE CONTROLS: *"the bot hunting me was stuck in a corner and
spammed q. I had to move away from the corner so that he could come closer."***
Both halves are one defect. `--hunt` steers on the Compass bearing and **nothing
else** — no path query, no probe — so a bot whose contract stands beyond a corner
presses `input_move_forward` into masonry for the rest of the match. The Q is
`--reckless` casting on `TUN-CINDERFALL-COOLDOWN` **45 s**, which is not a spam
rate; it reads as one because it was the only thing the bot was doing.

**THE FIX MEASURES DISPLACEMENT RATHER THAN PROBING AHEAD**, and the distinction is
the whole of why it works: **a bot wedged in a corner has clear ground in front of
it** and still cannot travel, so a forward probe would report everything fine. What
is unarguable is its own position over time. Fifteen beats under 5 cm and it turns
for twenty-five while still walking, ignoring the bearing for the duration —
because the bearing is what walked it into the wall.

**AND THE TURN DIRECTION IS HELD FOR THE WHOLE SHOVE.** Re-deciding it every beat
is how a bot rocks in place against the corner it is already in, which is the same
family as the `_held_key` thrash that made the first hunting bot walk 0.0 m in
forty seconds.

**`tools/bot_hunt.gd` IS THE SPLIT**, because the fix took `bot_client.gd` to 402
lines. The seam is honest: everything in it decides *where to walk* from the one
fact a client is told about its contract, and nothing in it knows how a key is
pressed or that a wire exists. `decide()` returns the keys and how long to hold
them; the client presses them. 308 + 111 lines.

## SOMETHING HUNTS YOU NOW, AND A HELD `input_run` MOVES A PAWN 0.0 m

**ADR-0018 SHIPPED A VERB NOBODY COULD PLAYTEST, AND I OFFERED THE PLAYTEST
ANYWAY.** A Lunge into your pursuer stuns them — and `tools/bot_client.gd` walked
in **random legs**, so no bot had ever pursued anybody, and a strolling bot sits at
Anonymous all match, which `TUN-STUN-MIN-TIER` makes **unstunnable by design**. The
feature was untestable against the only opponents this project has.

**`--hunt` STEERS ON THE COMPASS AND NOTHING ELSE**, which is the only thing a
client is told about where its contract is (GDD-03 §8.5). It cannot cheat because
there is nothing to cheat with: the bearing carries `TUN-COMPASS-CONE-WOBBLE`'s lie
exactly as a human's does. Measured with two bots on a real server: they converge —
one walked 24.9 → 43.8 on x while the other walked 114.0 → 102.3.

**AND `--reckless` EXISTS BECAUSE A CAREFUL HUNTER IS UNSTUNNABLE ON PURPOSE.** A
hunting bot that strolls can never be practised against, which is correct game
behaviour rather than a gap. Casting an ability costs +40 against
`TUN-SUSPICION-TIER-NOTICED` 30, so a bot that re-casts on cooldown is a hunter who
has chosen to be seen.

**A HELD `input_run` MOVES THE PAWN 0.0 m, AND THAT IS THE FINDING TO CARRY.**
Measured, repeatedly, against the same bot walking **15 m** with `input_slow`: a
synthetic `Input.action_press("input_run")` held continuously produces **no travel
at all**, with or without a clean press edge, while forward alone works. Something
in the run path will not accept a held synthetic press. **Reported rather than
worked around**, because trap 13 was narrowed on the evidence that
`Input.action_press` *is* the same path a finger takes — and if that is true here, a
player holding Shift across a match start meets whatever this is.

**IT WAS FOUND ONLY BY READING THE WHOLE RUN.** Grepping for `bot N:` showed four
identical position lines and nothing else; the isolation that named it was swapping
one action and re-running. **Capture the run, read the top** — the corpus's own
note, paid for again.

## ADR-0018: THE PREY HAS MORE THAN ONE TOOTH, AND LAW 5 WAS WRONG IN EVERY CLAUSE

**REPORTED AS A DECISION, NOT A DEFECT: *"the Lunge should stun the pursuer, also
revamp design law 5 so that it is fitting to the original."*** Owner decision 9,
taken. Both halves are done and the second found more than the first.

**`ABIL-LUNGE` DID NOTHING AT ALL IF YOU ARRIVED AT THE PERSON HUNTING YOU.** The
reference's equivalent resolves against **whoever it connects with** — a kill on
the target it reaches, a stun on a pursuer it reaches, with one of its unlock
challenges being to stun your pursuer with it. Half the ability was absent, and it
was the defensive half.

**THE KILL IS ASKED FIRST, WHICH IS THE REFERENCE'S OWN ORDERING** — *a kill is
always prioritised over a stun*. And **a connection is not a miss**: a dash that
stuns pays no `TUN-LUNGE-WHIFF-STAGGER`, because GDD-04 §3.4 prices that stagger
for arriving at **nothing**.

**EVERY OTHER GATE STAYS, AND THE TIER FLOOR IS THE ONE THAT MATTERS.**
`TUN-STUN-MIN-TIER` is what makes *"an Anonymous hunter cannot be stunned —
patience is genuinely safe"* true; a route that stunned through it would delete
that sentence rather than add a tooth. It calls `StunSystem._land`, so the exile,
the freeze, the score and the wire message are a pressed stun's — **one stun,
reached three ways**, rather than a second set of numbers to drift.

**AND THE LAW WAS WRONG IN EVERY CLAUSE, MEASURED.** It read *"stun hard-counters
a reckless hunter and is worth as much as a kill; never weaken it."*

| The law said | The reference does |
|---|---|
| a stun is *worth as much as a kill* | **200** for a stun against a base kill's **100** |
| — and implicitly no more | a well-made kill is 100 + up to **400**, so it still beats a stun |
| the prey's teeth are **the stun** | a read stun, a smoke flush, a charge into a pursuer — and escape |
| *never weaken it* | already excepted once, by ADR-0013 |

**THE PRICING ERROR IS THE ONE THAT MATTERED.** `TUN-SCORE-STUN` shipped at **100**
with invariant 19 pinning it *equal* to `TUN-SCORE-CONTRACT` — so the rule that
existed to **be** design law 5 was under-paying the prey by half while looking like
fidelity. It is **200** now, and invariant 19 is `>` rather than `==`: **a floor,
not a ratio**, because a stun must still lose to a well-made kill and `== 2 x`
would pin a number no source gives.

**`TUN-SCORE-ESCAPE` WAS ALREADY RIGHT AT 100**, which is worth saying: ADR-0014
sourced it and got it exactly. Only the stun was wrong.

**THE NEW LAW NAMES A PRINCIPLE AND THREE INSTRUMENTS RATHER THAN ONE MECHANIC:**
*the prey must have teeth, and more than one … and none of them may be traded away
to make hunting feel better.* That last clause is **never-do #13 generalised from
the stun to the set** — a law protecting one mechanic can be satisfied while the
prey is disarmed of the other two, which is exactly what had happened: escape
shipped at ADR-0014 and the law never mentioned it.

**THE BALANCE MODEL MOVES AND IS DELIBERATELY NOT RE-DERIVED.** §4's
kills-per-match figures already modelled a 45 % stun rate measured before ADR-0013
removed the last-instant save; doubling the payout moves the ratio again.
`TEL-STUN-RATE` settles both, and guessing a rate then three numbers that depend on
it is what §4 already warns against.

**`LungeArrival` IS THE SPLIT THIS FORCED**, at 412 lines, and it mirrors
`KillGates`: everything about the **arrival** — where the dash began, what it
connected with, what a miss costs, how often each happens — and nothing that judges
a press. **Fourth file this week the length guard has usefully split.**

**AND MOVING `_whiff` INTO IT DROPPED THE LOCKOUT LINE**, which
`test_the_whiff_is_a_state_and_a_lockout_together` caught on the same run. ADR-0017
put those two on adjacent lines deliberately — the lockout is the rule, the state is
the tell — and that test exists because the pair is exactly what a refactor
separates. It worked.

**AND MY OWN PRIORITY TEST STAGED NO RACE.**
`test_a_dash_that_reaches_both_kills_rather_than_stuns` omitted
`announced_contracts[A] = B`, so there was no kill to prioritise, the arrival fell
through to the stun and the failure read exactly like the ordering being wrong. The
name promised a race the fixture never set up — **trap 3 inside a test name, again.**

## A GATE FAILED A BUILD WITH NOTHING BEHIND IT, AND THE STATISTIC WAS WHY

**`test_server_tick_budget.gd` FAILED CI AT 10.84 ms AGAINST A BUDGET OF 8.0, ON A
TUNING CHANGE THAT CANNOT REACH IT.** The commit raised
`TUN-CINDERFALL-DURATION`; that test **never casts an ability**, so
`CinderfallVolumes` is empty for every tick of it. Exoneration by construction
rather than by re-running until green — though the re-run was green, untouched.

**IT ASSERTED THE MAXIMUM, AND THE MAXIMUM IS NOT A MEASUREMENT OF THIS CODE.**
The old docstring argued a max is *strictly stronger* than a p99, which is true of
the arithmetic and false of a shared runner: the largest of 180 samples is decided
by whichever tick the scheduler interrupted.

**THE EVIDENCE IS TWO LOCAL RUNS RATHER THAN THE ARGUMENT.** Same machine, same
commit, nothing else changed:

| | p99 | max | max / p99 |
|---|---|---|---|
| run 1 | 3.042 | 3.179 | 1.05x |
| run 2 | 2.909 | **5.554** | **1.91x** |
| run 3 | 2.783 | 2.794 | 1.00x |

**AND THE CONCLUSION DRAWN FROM THAT TABLE WAS WRONG — CORRECTED 2026-09-04, SEE
THE SECTION AT THE TOP OF THIS FILE.** It read *"the p99 spans 9 % across the three
and the max spans 99 %"*, which is true of these three runs and false of the
estimator: **three quiet runs are not a spread.** Fourteen runs the next day put
the p99's spread at **103 %**, and the p99 then failed a build with nothing behind
it exactly as the max had. What survives from this section is that the **max** is
unusable; what replaced it was not robust either.

**AND THE NEW ASSERTION IS FALSIFIED RATHER THAN ASSUMED**: dropped to a 2.0 ms
budget it fails at a p99 of 2.783 and names the criterion in the message.

**AND p99 IS WHAT THE GATE ACTUALLY ASKS FOR**, so this is a correction rather than
a weakening: ROADMAP's M3 line is *"server tick p99 at or under 8.0 ms"* and
asserting the max was an over-reach past the documented criterion. **It is precise
about what it forgives**: `sorted[int(180 × 0.99)]` is index 178, the
**second-highest** reading, so it tolerates exactly one spike and not two — one
outlier says something about the runner, two say something about the code. The max
is printed on every run with its ratio to the p99, so a real regression that shows
only as spikes stays visible to a reader.

**THIS PROJECT HAD ALREADY LEARNED IT ONCE AND ONLY FIXED ONE GATE.**
`test_crowd_perf.gd` read 1.067, 1.249 and then **1.815 — failing a build with
nothing behind it** — and was changed to assert an ordinary-tick p95 and print the
population. The server-tick gate never got the same treatment, and this file even
recorded *"one run reported a 6.000 ms max… recorded as an outlier rather than
explained"*. **A lesson applied to one instance is a lesson half learned.**

## THE DENSITY IS RIGHT AND THE DURATION IS 6.0 s, JUDGED AT THE CONTROLS

**BOTH CINDERFALL QUESTIONS ARE ANSWERED, AND ONE OF THEM IS A RULED DIVERGENCE.**
The owner played it: *"the density is good"*, and the duration goes **4.0 → 6.0 s**
— which is what the instruments below were built for, and the whole of their
return.

**THE REFERENCE'S NUMBERS, SOURCED BEFORE CHANGING OURS.** Its smoke comes in three
variants and all three cool down in **60 s**: base 3.2 m / **3 s**, Strong 4 m /
3 s, Long Lasting 3.2 m / **4 s**. **So ours already sat at the reference's
upgraded value**, the owner's condition was met, and 6.0 is 1.5× its best.

**IT IS THE TOP OF THE BAND**, which is worth knowing before somebody reaches for
7: `AbilityData.duration`'s `@export_range` and TUNABLES both say **3–6**, so the
next increase is an ADR rather than a value.

**AND THE COST IS TWICE THE REFERENCE'S UPTIME, WHICH IS SAID RATHER THAN LEFT TO
BE FOUND.** 6 s per 45 s is **13.3 %** against the reference's 4 s per 60 s at
**6.7 %** — and GDD-04 §3.1's *Failure mode* row names duration growth as exactly
the corner-camping risk, with the symptom *"players deploying it pre-emptively
rather than reactively"*. **The counterweight if that shows up is
`TUN-CINDERFALL-COOLDOWN` 45 → 60**, which is *also* the reference's own value and
lands at 10 %. Recommended rather than done: the owner asked for one change.

**AND INVARIANT 12 ALREADY FORBADE THE OTHER HALF OF THE FIDELITY QUESTION.**
`TUN-CINDERFALL-RADIUS >= 2 × TUN-KILL-RANGE` — *"the cloud must actually deny a
kill attempt, not merely obscure one"* — holds at **exactly** its floor, 5.0 = 2 ×
2.5. So shrinking the radius toward the reference's 3.2 m was never a value change
available to anybody; the arithmetic I derived independently yesterday was already
in the corpus as a cross-field rule. **Read §17 before deriving a constraint —
sixth time this file has recorded that lesson.**

## MAKING THE ONE NUMBER I CANNOT DERIVE CHEAP TO JUDGE

**`TUN-CINDERFALL-DURATION` 4.0 s IS THE LAST UNSETTLED VALUE IN THIS ABILITY, AND
IT HAS TO BE FELT FROM INSIDE THE CLOUD.** The cloud is centred on the caster since
2026-09-03, so a cast now costs four seconds of not being able to read the street —
a price that was set when it could be thrown eight metres away. Nothing about that
is derivable; it is a judgement, and the owner has taken it.

**SO TWO INSTRUMENTS, BECAUSE THE JUDGEMENT WAS EXPENSIVE TO MAKE.**

- **The debug overlay counts the cloud down**: `cinder up, 3.9 s of 4.0 left`. It
  **asks `CinderfallView`** rather than running a timer of its own — a second clock
  beside the first is `TUN-CINDERFALL-DURATION` implemented twice, which is exactly
  the gap US-0067's effect and volume kept and where that defect lived.
- **`tools/cinderfall_probe.tscn -- --live` leaves the client running with no
  cooldown**, so the ability can be cast as often as it takes:

```bash
godot --path . res://tools/cinderfall_probe.tscn -- --live
```

  `TUN-CINDERFALL-COOLDOWN` is **45 s**, so a real match offers about ten casts in
  eight minutes with three quarters of a minute between each — not a rate anybody
  forms a judgement at. **What it therefore does not prove is the pipeline**: no
  server, no wind-up, no suspicion cost, no startle wave and no kill block. Those
  are `tools/ability_probe.tscn`'s, and the sandbox says so rather than implying
  otherwise.

**AND THE READOUT SPLIT, BECAUSE ITS NAME STOPPED BEING TRUE.** `net_readout.gd`
was printing the Compass range, both cooldowns, the last refusal, the last kill and
the cloud — **none of which is the wire** — and it passed 400 lines saying so.
`GameplayReadout` is the seam and the name is the argument: everything in it is a
fact about the match, and nothing in it knows what an ack or a reconciliation is.
277 + 195 lines.

**WHAT THE ANSWER TO THE STUN QUESTION WAS, AND THE ARITHMETIC THAT DECIDED IT.**
Asked whether Cinderfall should become the reference's version — thin, small, and
it **stuns** everyone inside rather than blocking sight. Recommended **no**, and
the reason that settled it was not taste: our rule blocks kill *initiation* tested
against the **killer's** position, so a hunter outside the cloud can still reach
`KillRules.reach` 2.85 m into it. The genuinely protected core is
`radius - reach` = **5.0 - 2.85 = 2.15 m**. At the reference's ~1.6 m radius that
core is **negative** — anyone could reach straight in and the kill-block would mean
nothing. **Their cloud can be that small precisely because it stuns instead of
blocking kills; the two are a package and half of it is incoherent.** That reversed
my own instinct, which was to shrink the radius toward the reference.

**THE OTHER TWO REASONS ARE ON THE RECORD RATHER THAN IN A CHAT LOG.** A
see-through cloud would let a hunter watch their prey clearly and be refused a kill
they can plainly see, which is the illegibility this whole session has been
removing. And an area stun with no cone, no range, no tier gate and no
pursuer-only rule makes the **deliberate** stun redundant — the one that costs a
correct read of an approach — which is never-do #13's spirit even though it is an
addition rather than a weakening. The sources call the reference's smoke its best
and most ubiquitous ability, used *"for assassinations as well"*; GDD-04 §3.1's own
failure-mode row names that outcome. **ADR-0013 says the reference wins unless the
owner rules for the divergence, and this is a case to rule for it.**

## TWO DEGREES. THE LUNGE'S CONE WAS DEGENERATE AND THE OWNER FOUND IT THREE TIMES

**REPORTED FROM THE CONTROLS, WITH NUMBERS THIS TIME: *"compass was 6, F went to
cooldown, combat did not resolve a kill"*.** That is a press the server accepted
and an arrival it refused, at exactly the distance my own probe said lands — and
it is the third report of this ability failing.

**MY PROBE PLACED THE PREY EXACTLY ON THE DASH LINE, WHICH IS THE ONE THING A
PLAYER CANNOT DO.** Sweeping the *angle* instead of the distance found it at once,
at a 6 m approach:

| Aim error | Gap at arrival | Before | After |
|---|---|---|---|
| 0° | 0.15 m | kill | kill |
| **2°** | **0.26 m** | **whiff `OUT_OF_CONE`** | kill |
| 10° | 1.04 m | whiff | kill |
| 25° | 2.6 m | whiff | kill |
| 45° | 4.54 m | whiff | whiff `OUT_OF_RANGE` |

**TWO DEGREES OF TOLERANCE, AND THE CAUSE IS INVERTED FROM EVERY INTUITION: A CONE
IS AN ANGLE, SO THE GROUND IT COVERS SHRINKS TO NOTHING AS YOU CLOSE.** At the
2.85 m reach a 60° cone spans 2.85 m; at the 0.26 m a dash actually ends at it
spans 26 cm, because a 0.26 m lateral offset at 0.26 m range is an **86° bearing**.
**Arriving accurately made the test harder rather than easier.**

**THIS PROJECT HAS ALREADY FIXED THIS EXACT FLAW ONCE.** The Compass shipped with a
fixed 12° arc that spanned 1.06 m at kill range — *"narrower than two people
standing side by side, so it picks one, for free"* — and
`CompassMath.cone_halfwidth_for` fixed it by covering **ground rather than an
angle**. Nobody connected the two, because a *press* is made while approaching,
where a cone is fine.

**`within_cone` IS DELIBERATELY UNTOUCHED, AND ITS OWN DOCSTRING IS WHY.** It says
a target *beside* the killer being refused is the **intent** — so widening the
shared rule would change every kill in the game to fix one ability, and a press is
made at a moment the player chose. `KillRules.resolve_swept` is the arrival's own
rule: **did the dash pass within reach of the contract at any point along its
path.**

**WHICH SETTLES OWNER DECISION 8, AND NOT THE WAY EITHER CANDIDATE PROPOSED.**
Neither the lateral steering nor the closest-approach judgement was needed: a
contract the dash went **through** is on the corridor, so the close-range overshoot
closes as a side effect. The reference agrees — its version *"resolves against
whoever it connects with"*.

**THE ARRIVAL CARRIES ITS OWN ORIGIN RATHER THAN DERIVING ONE.**
`ctx.auto_kill_arrivals` holds `[peer, dash origin]` now, recorded by `LungeEffect`
at the burst. Deriving the corridor from the final yaw would draw it along a
heading the player was not travelling, because `LungingState` keeps the camera.

**AND IT JUDGES THE CONTRACT ALONE, WHERE A PRESS JUDGES THE NEAREST BODY.** An
arrival's refusal costs the same whatever the reason — `_whiff` charges nothing —
so there is nothing a nearer stranger could change, and GDD-03 §9.2 already says
the crowd hides by being confusing rather than solid.

**`KillGates` IS THE SPLIT THIS FORCED, AND THE SEAM IS HONEST.** `kill_system.gd`
went to 410 lines and `_verdict_for` past six returns. Everything in the new class
is a fact about the **situation** — a cloud, an exile, an invulnerability, a hiding
place — and nothing in it knows where anybody stands relative to anybody else.
Third file this session the length guard has usefully split.

**TWO OF MY OWN TESTS WERE WRONG AND ONE OF THEM WAS WRONG ON PURPOSE.**
`test_a_dash_that_ended_past_its_target_records_the_cone_rather_than_the_range` —
written yesterday — asserted that a contract 1.85 m behind you whiffs. It now
kills, which is the change; it is rewritten as
`test_a_contract_the_dash_passed_through_is_killed` with a counterfactual beside
it. And a fixture asserted the corridor was 5.85 m long in a **unit** test, where
`drives_position()` is false and no physics runs, so the pawn never travels — the
length is the probe's to measure and the test says so.

**AND THREE SWEEP ROWS WERE MY INSTRUMENT AGAIN.** Rows reporting an 11 m gap and
`NO_TARGET` were the probe writing a body's position **inside a building**, which
physics then ejects. It says so now rather than looking like a rule that cannot see
its target. Fourth instrument error this session, and the fourth caught before it
was reported as a defect.

## THE CLOUD BURSTS ON YOU NOW, AND THE ABILITIES HAVE A READOUT

**REPORTED FROM THE CONTROLS: *"the smoke from q should detonate around me… in the
original the smoke only surrounds the player"*.** Sourced rather than taken on
trust, and it is right: the reference deploys its smoke **at the player's own
feet**, and the *sequel* is what added throwing it. Under ADR-0013 the reference
wins, so `TUN-CINDERFALL-THROW-RANGE` is **8.0 → 0.0** and the cast is clamped to
the caster's own position.

**IT NEEDED NO CODE.** `AbilityRules.aim` already clamps the requested distance to
the ability's reach, and `reach_of` returns `throw_range` — so zero makes every
cast land underfoot however far a client aims, which `InputSender` deliberately
does. The `@export_range` band had to open from `5–12` to `0–12` to admit the
value, and **the ID stays live rather than deprecated**: it is still read, and
restoring the sequel's throw is this one number.

**THE CASTER IS NOW ALWAYS INSIDE THEIR OWN CLOUD, AND THAT IS A FEEL CHANGE
RATHER THAN A DETAIL.** `TUN-CINDERFALL-RADIUS` is 5.0 m and the camera arm is
2.6 m, so a caster spends the full `TUN-CINDERFALL-DURATION` 4 s unable to read
the street. That is exactly what the ability now *is* — GDD-04 §3.1's *Why it
exists* row already calls it the escape — but it was priced when the cloud could
be thrown eight metres away.

**AND THE REFERENCE'S CLOUD IS FAR SMALLER: ABOUT 3.2 m ACROSS AGAINST OUR 10.**
Sourced in the same pass. A self-centred cloud at three times the radius blinds
its caster for four seconds where the reference's is a puff you step out of.
**Reported rather than acted on** — `TUN-CINDERFALL-RADIUS` is a merged value that
GDD-04 §3.1's failure-mode row is written against, and it is the owner's.

**THE ABILITIES HAVE A DEBUG READOUT, WHICH IS THE OTHER HALF OF THE REPORT.**
`net_readout.gd` gains two lines answering the three questions somebody pressing a
key that seems to do nothing actually has:

```
ability Q ready   F 12.4s   denied ON_COOLDOWN 1.2s ago
combat  slot 3 killed slot 5   0.8s ago
```

**The key names are read from `InputMap`, never written as "Q"** — both
`INPUT-ABILITY-*` are rebindable and a label that goes stale is a label that lies.
Debug only: `scripts/debug/` is out of all three release presets, so a player is
never told a cooldown they should be counting themselves.

**AND THE FIELD IS A COUNTDOWN DESPITE BEING CALLED `cooldown_a_tick`.**
`AbilitySystem.cooldown_ticks` returns `ready_at - now` clamped at zero. Checked
rather than inferred from the name — dividing a *deadline* by the tick rate would
have printed a plausible and completely wrong number, which is this session's
recurring failure in a new place.

**TWO GUARDS CAUGHT ME, BOTH CORRECTLY.** `test_ids_match_glossary.gd` refused
**`ANIM-CINDERFALL-CAST`** — an ID I minted by writing prose in the GDD, when
`ANIM-CINDERFALL-THROW` already exists and is merged. And
`test_the_reach_comes_from_whichever_field_this_ability_populates` asserted
Cinderfall's reach was above zero, which was correct until this change and is now
the assertion that pins it at zero.

## THE CINDER CLOUD IS DRAWN, AND LOOKING AT IT FOUND TWO THINGS NO TEST COULD

**`ABIL-CINDERFALL` HAS CHANGED THE WORLD SINCE US-0067 AND NOTHING HAS EVER
DRAWN IT.** A cloud blocks every line of sight through it and forbids kill
initiation inside it — including the caster's own — and on a client it was an
*absence* of information: the Compass stops pointing, the reticle stops offering,
and nothing on screen says why. `CinderfallView` is the first thing in
`scripts/presentation/vfx/`.

**THE DRAWN CLOUD IS THE GAMEPLAY VOLUME, EXACTLY.** Same centre, same
`TUN-CINDERFALL-RADIUS`, same `TUN-CINDERFALL-DURATION`, no fade and no generous
edge. GDD-04 §3.1 names the counter to this ability as **patience** — *wait at the
cloud's edge* — and **a player cannot wait at an edge the game draws somewhere
other than where it tests**, so every softening would take away the counterplay it
looks like it is decorating.

**AND IT IS NOT DRAWN FOR THE LAG-COMPENSATION GRACE.**
`CinderfallVolumes.expire` deliberately keeps a burnt-out cloud for
`RewindClamp.max_ticks()` longer so a kill validated in the past still meets one
that was up when the attacker pressed. That window is **validation, not cover**:
drawing it would promise up to 200 ms of concealment no live query grants.

**NOTHING ON THE WIRE HAD TO CHANGE, AND ONE ASSERTION DID.** `HudBridge` dropped
the aim outright at US-0090, on the reasoning that *a tell says something happened
there*. **That rule was written when nothing drew anything and it made this
ability undrawable**: a cloud lands up to `TUN-CINDERFALL-THROW-RANGE` 8 m away, so
a consumer given only the thrower's feet puts cover where there is none. The
narrowed rule is **stronger** than the one it replaces — *the bus says where an
ability landed and never who* — and it is asserted structurally, on the signal's
own argument list, so a target cannot be added to it quietly.

**THE WIRE'S `dir` WAS A UNIT VECTOR AND IS NOW THE GRANTED DISTANCE.**
`AbilityRules.aim` already reads the *client's* direction length as the requested
distance; answering in a different convention left every other client unable to
say where a throw landed without re-deriving the server's clamp — **which works
only while a client cannot aim short**, and would have broken in silence the day
that was fixed. Three floats either way, so `NET-S2C-ABILITY-STARTED`'s width is
untouched.

**AND THE TEST THAT PINNED THAT NORMALISATION PROVED THE OPPOSITE OF WHAT IT
SAID.** `test_the_tell_carries_the_clamped_aim_rather_than_the_request` asserted a
length of **1.0** — and a normalised vector is the same vector whatever was
requested, so the test named the clamp and measured the one quantity a clamp
cannot affect. It asserts the granted 8 m now, and that the requested 40 never
reached the wire.

**THEN SOMEBODY LOOKED AT IT, AND THAT IS WHERE THE REAL DEFECTS WERE.**
`tools/cinderfall_probe.tscn` boots the real client and emits the tell on the bus
— no server, no wire, so what it proves is the drawing:

```bash
godot --path . res://tools/cinderfall_probe.tscn
```

- **THE DISTRICT WAS PERFECTLY READABLE THROUGH A CLOUD WHOSE WHOLE RULE IS THAT
  NOTHING CAN BE SEEN THROUGH IT.** At alpha 0.72 the buildings, the ground and
  the horizon all came through. A drawing that **promises less concealment than
  the rule grants** teaches a player not to trust their own cover, which costs the
  ability its purpose. Same family as the vignette's alpha, found the same way.
- **AND ONE SHELL IS NOT A VOLUME, WHICH IS THE HALF THAT RAISING THE ALPHA WOULD
  HAVE HIDDEN.** A translucent sphere tints only what is **beyond** it, so from
  *inside* one the ground at your feet came through untouched and the cloud read
  as absent — exactly where it matters most, since somebody standing in a cloud
  cannot initiate a kill and cannot be seen. It is **`SHELLS` nested spheres**
  now, so opacity follows how much ash stands between you and what you are looking
  at: solid from outside, dense from the middle, **and thin at the edge, which is
  right** — an edge you cannot see past is not a place to wait.

**MY OWN INSTRUMENT WAS WRONG FIRST, FOR THE THIRD TIME THIS SESSION.** The probe
counted **frames** and waited 46 of them for a 0.45 s wind-up on the assumption of
60 fps; this machine renders far faster, so it sampled before the pot landed and
reported **0 clouds at the burst and 1 after the duration** — which reads exactly
like a view that draws everything one beat late. It waits in seconds now.

**THE PALETTE OUTGREW THE HUD, AND THAT IS A DECISION RATHER THAN A DRIFT.**
`Palette`'s docstring said *every colour the HUD draws*; the cloud's edge is a
**gameplay boundary** and §7.1's colourblind variants have to be able to move it,
so it lives there rather than beside itself — a second home for colour is the
duplicated-rule shape this project keeps finding. `test_no_colour_literals.gd`
scans `scripts/presentation/vfx/` as well, added **with** the directory rather
than after it.

**WHAT IS STILL NOT DRAWN.** A **Lunge** has no wind-up pose, no shout and no
dust — but its effect is a body moving at 9 m/s, which the client already draws,
and GDD-04 §3.4 names exactly that as its visual tell. `ANIM-LUNGE-WINDUP`,
`ANIM-LUNGE-DASH` and `ANIM-LUNGE-WHIFF` remain specified and absent, along with
every other clip in this project.

## THE LUNGE AUTO-KILL WAS JUDGED IN THE PAST, AND ITS BAND WAS A METRE SHORT

**REPORTED FROM THE CONTROLS: *"the autokill on lunge does not work"*.** It does
work — measured landing on a real server — and **two separate things made it fail
far more often than the design says it should**, one a defect and one this game's
own documented rule. Neither was visible to the player or to any test.

**THE DEFECT: AN ARRIVAL WAS LAG-COMPENSATED LIKE A PRESS.** `_verdict_for`
rewound the world by `RewindClamp` for every judgement, and **an arrival is not a
press**. Lag compensation exists to honour *what the attacker saw when they
decided*; the auto-kill is decided by the **server**, at the end of a dash the
client is only predicting, so there is no observation to align with. Worse,
`RewindClamp`'s floor is `TUN-NET-LAGCOMP-MIN` **100 ms at any ping at all** —
correct for a press, because every client draws remotes that far behind — and at
`TUN-LUNGE-SPEED` 9 m/s that is **0.9 m of the hunter's own travel subtracted from
a 2.85 m reach.**

**MEASURED, AND THE BOUNDARY MOVED EXACTLY WHERE THE ARITHMETIC SAYS.**
`tools/lunge_arrival_probe.tscn` stands the caster's own contract a chosen
distance down the dash line on the real `server_root.tscn` and presses:

| Approach | Before | After |
|---|---|---|
| 7.5 m | landed | landed |
| 8.0 m | **whiffed** (rewound gap 2.90 against a 2.85 reach) | landed |
| 8.7 m | whiffed | **landed** — 5.85 m of dash + 2.85 m of reach, exactly |

**So the band ended at 7.5 m against the 8.7 m the tuning gives it, and it
narrowed further the worse your connection was.** A rule whose range depends on
ping is not the rule `TUN-KILL-RANGE` documents. `KillRewind.present_world` is the
fix; it does not touch the ring, so ADR-0010's two rewind call sites are still
two.

**THE OTHER HALF IS THE DESIGN, AND SAYING SO IS THE POINT.** The dash is a fixed
5.85 m and unsteerable, and GDD-04 §3.4 and `TUN-LUNGE-AUTO-KILL` **both** say the
kill fires if the dash *ends* within range and cone. So a lunge from closer than
about 5.5 m goes straight **through** the contract and leaves them **behind** the
hunter. Measured at a 4.0 m approach: the contract is **1.85 m away — inside the
2.85 m reach — and refused `OUT_OF_CONE`.** The usable band is roughly
**5.5 m to 8.7 m**, a ring in the middle of a 6 m dash, and it is at close range
that a panicking hunter presses the panic button. **Owner decision 8**, because
changing it changes what two documented rows promise.

**AND A WHIFF REACHES NOBODY, WHICH IS WHY THIS TOOK AN AFTERNOON.** `_reject`
emits `kill_rejected`; `_whiff` deliberately emits nothing, because GDD-04 §3.4
prices a miss at `TUN-LUNGE-WHIFF-STAGGER` *and nothing else* — right for the
player, and it left *overshot*, *behind you* and *wrong target* indistinguishable
to everybody including a developer. `KillSystem.last_whiff` records the verdict
now, for the reason the three `arrivals_*` counters beside it exist.

**MY OWN INSTRUMENT WAS WRONG FIRST AGAIN, AND IN THE SAME DIRECTION.** The probe
drove both pawns with `InputCommand.empty()` — **yaw 0, facing +Z** — while
dashing toward −X, and reported a whiff at a live gap of **0.15 m**, which reads
exactly like an auto-kill that never fires. **The cone is read from the pawn's
yaw, not from the dash direction**, and the two are only the same because a real
player aims with the camera they then keep still. One line of instrument, and it
would have been reported as a defect in the arrival path.

**THE SEAM WAS PROVEN BY NOBODY, WHICH IS THE THIRD TIME THIS WEEK.**
`test_lunge_effect.gd` proves the effect queues an arrival;
`test_lunge_arrival.gd` **appends to that queue by hand** and proves `SYS-KILL`
judges it. Neither runs the two together, so the hop from the `abilities` stage to
the `combat` stage was covered by no test — and every fixture in the arrival file
fills the lag-comp ring with the pawn's *current* position, which is precisely
what hides a rewind defect. It fills it with the pawn a dash *behind* now.

**AND THE STAGGER WAS WRITTEN A THIRD TIME.** `arm_stagger` plus
`CombatEntry.into(STAGGERED)` were two adjacent lines in `KillSystem._whiff`,
`KillSystem._stagger` and `StunSystem`'s invalid swing. `CombatEntry.stagger` is
the one home — found because this change pushed `kill_system.gd` to 408 lines and
**the length guard is what asks the question**, for the second time in three
stories.

## PRESSING F DID NOTHING, AND IT HAD NEVER DONE ANYTHING

**REPORTED FROM THE CONTROLS: *"absolutely nothing happens when i press f"*.**
It was right, and the cause is one missing line of client code under three
completed stories.

**`NET-C2S-ABILITY-REQUEST` HAD EVERYTHING EXCEPT A CALLER.** The RPC on `Net`,
its row in `Authority`, its channel in `Messages`, its hop in `RpcRouter`, its
`server_root` wiring into `SYS-ABILITY` — and behind that five validations, an
integer-tick cooldown, the suspicion cost, the reliable tell broadcast,
`CinderfallEffect`, `LungeEffect` and the `Lunging` state. **Nothing on the client
ever sent the message.** Q and F did literally nothing through US-0066, US-0067
and US-0070.

**AND NO TEST COULD HAVE SEEN IT, WHICH IS THE PART WORTH KEEPING.** The unit
suites drive `AbilitySystem` directly — correctly, because that is how you test a
system without a wire — and `tools/ability_probe.tscn` boots the real server and
calls `report_request` **in-process**, deliberately, for the same reason. **The
missing hop is exactly between the two.** It is the gap US-0074 lost a whole
integration run to, in its purest form: every piece proven, the seam between them
proven by nobody.

**A STORY CAN BE HONESTLY COMPLETE AND ITS FEATURE STILL UNREACHABLE.** US-0066's
eight criteria are each true of the system and each tested against it. None of
them names the client hop, so none of them was wrong — and the ability was
unusable. The criteria are **not** being unticked; the story carries the note
instead.

**THE SEND LIVES IN `InputSender`, NOT `Net`.** An RPC resolves by **node path**,
so `c2s_ability_request` has to stay on the autoload that exists at the same path
on every peer — US-0030's lesson, when the whole authority chokepoint was
unreachable because the router was not at a shared path. What does not have to
live there is the four lines that call it, and `net.gd` is at **398 of its 400**:
its own comment has said since M4 that *"the C2S doorway below could move the same
way if this file grows again"*.

**ON THE PRESS EDGE, NOT THE HOLD.** `InputCommand.buttons` is held state at
60 Hz; a held F would be sixty casts a second, each refused by the cooldown and
each a reliable packet. `InputBits.newly_pressed` already existed for this.

**AND THE AIM IS SENT LONG SO THE SERVER'S OWN CLAMP DECIDES.**
`AbilityRules.aim` treats the direction's **length** as the requested distance and
clamps it to the ability's reach — and a client cannot know which ability is in
which slot, because the loadout is the server's. The cost is that **a player
cannot aim a throw short**, which matters only for Cinderfall and is owed when a
HUD indicator exists. `CameraArm.forward` is the conversion, because a second
yaw-to-vector convention is the defect the Compass shipped with.

**VERIFIED OVER A REAL WIRE, BECAUSE NOTHING ELSE COULD.**
`tools/bot_client.gd` takes `--ability <slot>` now: it presses the real action on
a real client joined to a real server and reports what came back.

```bash
godot --headless -- --server --port 27077 --max-players 6
godot --headless --path . res://tools/bot_client.tscn -- --connect 127.0.0.1:27077 --bot 1 --ability 1
```

Measured: **`ability requests sent 0 -> 1`**, then **`states seen after the press:
Lunging, Idle   suspicion 53.0 -> 65.0`**. The dash happened and the server
charged for it.

**MY OWN INSTRUMENT WAS WRONG FIRST, IN THE USUAL DIRECTION.** It read
`PawnContext.suspicion` and reported `0.0 -> 0.0`, which reads exactly like a cost
that never applied — **a client never writes that field at all**; suspicion is
server state and `HudBridge` takes it straight off the snapshot. It reads
`EVT-SUSPICION-VALUE-CHANGED` now. Trap 4's family, caught before it was reported.

**AND `gdlint` AND `gdformat` BOTH PASSED OVER A SCRIPT WITH NO `extends`.** An
edit dropped `class_name InputSender` and `extends Node`; both tools reported
clean and only loading the script in Godot said *"Function get_node_or_null() not
found in base self"*. **The lint pass is not a parse check** — run the suite, not
just the linter.

**THE OTHER C2S MESSAGE WITH NO SENDER IS NOT A BREAK.**
`NET-C2S-BLEND-REQUEST` is a **second** doorway for a verb that already works: a
blend press rides `InputBits.BLEND` into `PawnContext.blend_requested`, which
`SuspicionSystem` reads at the `suspicion` stage. The RPC and
`RpcRouter.blend_requested` are wired to nothing in `server_root`. **Reported, not
deleted** — a `NET-` id is merged and removing a protocol message is the owner's
call — and named in the guard's exemption list so it stays visible.

## TEN DOCUMENTED WAYS OF RUNNING THE SUITES RAN ZERO TESTS

**`DEFINITION_OF_DONE.md`'s PRE-COMMIT LINE SAID A COMMAND *"PASSES"*, AND IT DID —
OVER NOTHING.** Ten `gut_cmdln` invocations across five documents lacked
`-ginclude_subdirs`, so GUT scanned only the top level of `-gdir`, found no
`test_*.gd` — every suite here is nested — and printed *"On the one hand nothing
failed, on the other hand nothing did anything"*, which is a **success shape**.
Trap 10, sitting in the documents that teach the process: `TEST_PLAN` §9 (four,
including the *before every PR* list), `TDD-12` (three), `AGENT_PLAYBOOK` (two),
`DEFINITION_OF_DONE` (one). Only CLAUDE.md and the seed had it.

**AND ONE OF THOSE COMMANDS POINTED AT AN EMPTY DIRECTORY.** `test/metrics/` was
declared in TDD-02's file table from M0 as *"map geometry assertions — boundary
bands, dead ends, widths, density, circuit separation"*, held a `.gdkeep`, and was
named in `TEST_PLAN` §9. **Those assertions were written into
`test/unit/core/map/` instead and have run in CI all along** — the coverage was
real and the directory was theatre. TDD-02 §3 even *answered* a question about it
with *"it runs in CI as a test and fails the build"*, which was true of the files
and false of the folder. Gone, and the table names the real home.

**THE FIX IS `.ci/run_gut.sh` EVERYWHERE**, which counts the scripts on disk and
refuses to pass over a short run — and
`test_documented_commands_run_something.gd` is the guard that stops it coming
back. It is deliberately narrow: it forbids the **silent** failure, not the raw
invocation, because CLAUDE.md documents the by-hand form on purpose and says the
flag is not optional. It also refuses a documented suite directory that holds no
tests.

**`--record` IS PARSED, VALIDATED, STORED AND READ BY NOTHING**, while
`docs/40_backlog/playtests/README.md` told a facilitator to *"attach the telemetry
export"*. A silent flag costs a session its evidence and nobody finds out until it
is over. `LaunchConfig.warnings()` says so at boot — **a warning, not a problem**,
because the two mean opposite things: a problem says *the launch is not what you
asked for* and refuses to start, where this says *the launch is exactly right and
one artefact will be missing*, and refusing would stop a playtest that is fine.

**THE BLOCKER IS UPSTREAM OF THE FILE WRITER.** `TelemetrySink.append` and
`flush` are stubs and **28 of GDD-07 §8's 29 events have no emitter**, so an
implemented `--record` would export one event kind and read as a working export of
an empty match. That is the harder half and it is nobody's story yet.

**AND TWO OF THE THINGS I REPORTED AS DEFECTS WERE NOT ONES.**
`TUN-SUSPICION-GAIN-WHISPERBOLT-WINDUP` is excluded from the tuning index **by
name** in `gen_index.py`'s `NOT_A_VALUE`, because that row documents an ID
carrying no number. And `LaunchConfig.unknown` **is** honoured — `problems()`
appends every unrecognised flag and `boot.gd` refuses to start — my grep for
`.unknown` missed it because the member is accessed bare inside its own class.
**Both were withdrawn after reading the code rather than the count.** An audit
that produces findings faster than it verifies them is an audit that costs more
than it saves.

## THE WHOLE EVENT CHANNEL REACHED THE CLIENT AND STOPPED AT THE BRIDGE

**`MatchAnnouncer` SENDS SEVEN EVENT MESSAGES, `EventWire` RE-EMITS ALL SEVEN,
AND `HudBridge` FORWARDED ONE.** Contract, kill, stun, prey warning, ability
tell, ability denial — every one arrived at the client and was dropped on the
floor. Only `score_reported` was wired, at US-0074.

**AND ONE WIDGET HAD ALREADY SUBSCRIBED, WHICH IS WHAT MADE IT A DEFECT RATHER
THAN A GAP.** `PortraitWidget._on_assigned` clears the reveal on a new contract,
and its own docstring says why: *"a portrait that persisted across a repair would
be **free identification of somebody you have never looked at**."* Nothing emitted
`contract_assigned`, so it never fired — **once revealed, the portrait stayed
revealed for the rest of the match, across every reassignment.** ASM-0030 and the
1.6 s lock exist to charge for exactly that identification, and an unwired signal
was handing it out.

**THERE WAS NO SECOND PATH EITHER.** `_publish_compass` emits
`contract_portrait_revealed` on the **rising** edge only, so the server clearing
`portrait_revealed` on reassignment updated the bridge's own field and told nobody.

**THIS IS THE COST THE GUARD'S OWN DOCSTRING NAMES.**
`test_eventbus_signals_documented.gd`: *"a widget author cannot tell what the
payload means or when it fires, so they subscribe and guess, and the guess is
wrong in the one case that matters."* It was right, and the case that mattered was
the one widget that had guessed correctly and got nothing.

**THREE PAYLOADS NAMED A PEER ID A CLIENT CANNOT HAVE.**
`ability_started(peer)`, `kill_resolved(killer, victim)` and
`stun_resolved(stunner, target)` — a client has **no peer ids at all**, because
`SlotTable` exists precisely so the engine's random 32-bit ids never reach the
wire. Renamed to `..._slot`, in the signals and in the catalogue.

**WHAT THE BRIDGE DELIBERATELY DROPS IS AS IMPORTANT AS WHAT IT FORWARDS.** The
**contract slot** (GDD-03 §8.5 — the reason alone reaches the bus, or every widget
gets a free identification), the ability's **aim direction** (a tell says *something
happened there*; forwarding where it was pointed would let a VFX author draw an
arrow at the target), and the stun's **lockout** (until a widget draws one). All
three are asserted, not merely commented.

**AND THE RELAYS ARE A TABLE RATHER THAN SEVEN `connect` LINES**, because a table
is countable: eight messages arrive and one was forwarded, which nothing could see
at a glance.

**TWO SIGNALS STAY UNWIRED AND BOTH BLOCKERS ARE REAL.** `EVT-CAPTION` needs the
audio dispatcher (US-0075), which has **no sound file in the repository** to
dispatch. `EVT-CONNECTION-CHANGED`'s only documented consumer is a menu system that
does not exist (US-0078, M6), and `Net` already carries `handshake_completed`,
`handshake_rejected` and `peer_left` — wiring it now would be a third copy of
connection state with no reader. Both say so in the catalogue now.

**`EVT-ABILITY-COOLDOWN-CHANGED` IS THE ONE DERIVED RATHER THAN RELAYED.** Both
cooldowns are in the own-gameplay block the bridge already reads; nobody had
joined the two. **Per slot, not per pair**, so a widget is never told about the
ability that did not change.

**FOUR PLANTED DEFECTS, ALL RED**: the contract relay removed, the contract slot
leaked to the bus, cooldowns emitted on arrival, and the tell forwarding its aim
as its origin.

## THE TWO MISSING `Dead` EDGES ARE CLOSED, AND THEY WERE NOT COSMETIC

**A VICTIM KILLED WHILE FALLING WAS TOLD THEY DIED AND KEPT PLAYING.** GDD-02 §3
declared no `Drop -> Dead` and no `StunAnim -> Dead`, and `KillSystem._land`
emitted `killed` and counted the kill **whether or not the transition was
legal** — so the contract cycle was repaired around the victim, a corpse was
spawned, the crowd was startled and `NET-S2C-KILL-RESULT` went out, while
`CombatTargets.is_dead` still answered **false**, because it reads `state_id`.

**AN UNDEAD VICTIM IS A LIVE TARGET THEIR KILLER'S SUCCESSOR IS STILL HUNTING**,
in a cycle that has already been repaired as though they were gone. US-0060
reported this as *"the death still resolves and the pawn keeps walking"*, ADR-0017
priced it as *"a separate design question with no rule behind it either way"*, and
**both readings were too kind**. The corpus carried it as cosmetic for three
milestones.

**AND IT CASCADED.** `SpawnSystem._enter_respawning` requires `state_id == DEAD`,
so the victim never reached `Respawning` either — losing their five seconds of
`TUN-RESPAWN-INVULN` on top of not dying. That second-order consequence was
written down in `spawn_system.gd` and never asserted.

**THE FIX IS TWO EDGES AND ONE FAIL-SAFE.** `_land` refuses to announce a kill it
could not apply, so the next state added without an edge is a **loud refusal**
rather than a silent undead. The machine gained two states in two days, which is
exactly why.

**THE PROPERTY IS ASSERTED, NOT THE TWO NAMES.**
`test_every_living_state_can_reach_dead` walks `PawnStateId.ALL` and requires an
edge to `Dead` from everything that is not already dead.

**AND MY OWN FAIL-SAFE TEST PROVED NOTHING, WHICH THE FALSIFICATION RUN FOUND.**
It poked a victim into `Respawning` and checked no kill was announced — and
`_land` returns early on `CombatTargets.is_dead`, which counts `Respawning`, so it
never reached the guard it was testing. **Deleting the guard left it green.** A
counterfactual that changes nothing is telling you the primary test is measuring
something else — second instance, after US-0051's saturated tap-sprint
measurement.

## US-0070 IS DONE, SIX OF SIX: THE PANIC BUTTON WORKS, AND ITS TELL HAD NO READER

**Press F and 0.25 s later you dash 6 m at 9 m/s in the direction you were
aiming, steering none of it.** Arrive within reach of your contract and the kill
**auto-initiates**; arrive short and you stand in the open for 1.2 s, Noticed,
unable to act. `ABIL-LUNGE` is the second ability in this game that changes the
world, and the first that moves the player.

**`TUN-LUNGE-WINDUP` 0.25 s WAS IN `lunge.tres` AND NOTHING READ IT.**
`AbilitySystem._cast_ticks` read `AbilityData.cast_time` alone, and its own
docstring said *"Lunge has no `cast_time` at all"* — **true of the field and
false of the ability**. The wind-up lives in `AbilityData.windup`, which had no
reader anywhere in the project.

**SO A LUNGE WOULD HAVE BURST ON THE PRESS TICK WITH NO TELEGRAPH**, which
deletes design law 3's *perceivable chance to read it* and with it this ability's
whole counterplay: GDD-04 §3.4 prices it as *"0.92 s of telegraphed, unsteerable
approach against a 0.7 s stun"*, and without the wind-up it is 0.67 s and
undodgeable. `ANIM-LUNGE-WINDUP` was authored against the same 0.25 s and would
have had nothing to play over. **Trap 14, and the comment is what stopped anybody
checking.** `AbilityRules.windup_of` takes whichever of the two fields an ability
populates — `reach_of`'s own rule in a second place — and Whisperbolt's 1.00 s
would have had the identical problem.

**AND THE DASH'S DURATION IS DERIVED RATHER THAN STORED.** 6.0 m over 9.0 m/s is
0.67 s, which is what ANIMATION_SPEC §3.3 already calls `ANIM-LUNGE-DASH`'s
*derived* length. A `duration` row in the `.tres` would be a third number that
can contradict the first two.

**`Lunging` IS THE SIXTEENTH PAWN STATE, AND THE REASON IS PREDICTION RATHER THAN
TIDINESS.** ADR-0017 left this question to this story and set the rule it had to
follow. `AbilityEffect` lives in `scripts/systems/`, stripped from every client
export — so a dash driven from there is **6 m the client never predicted**,
corrected on all twenty of its ticks at 0.3 m each, on the most decisive action in
the game.

**THE LOCKED DIRECTION IS `ctx.velocity`, SO THERE IS NO NEW FIELD AND NO NEW WIRE
ROW.** `own_velocity` is already full floats in the own-pawn block precisely
because it is what prediction reconciles against, and `own_state` and
`own_state_timer` carry the rest. **That matters more than it looks:
`PredictedState.apply_to` assigns `state_id` directly and never runs `enter()`**,
so anything captured on entry would be captured on the server alone and a client
forced into the state would dash in a direction it invented. Asserted by entering
the state the way a reconciliation does — fields set, no transition.

**IT DOES NOT DRIVE ITS OWN POSITION, WHICH IS THE OPPOSITE CALL FROM `Vault`,
`Climb` AND `Drop`.** Those own theirs because the probes **measured** what they
traverse, and `PawnMotion` skips `move_and_slide()` for them entirely. A dash is
aimed at open ground nobody measured, so owning its position would send a player
**through a wall** at 9 m/s. A grazed wall deflects it instead, which is what
every movement state does and is not steering — no input is read at all.

**AN ARRIVAL IS A PRESS THE PLAYER DID NOT HAVE TO MAKE.** The first version gave
the auto-kill its own `_resolve_arrivals` and `_judge_arrival`, duplicating the
verdict, the contest claim and the ordering — the *rule implemented twice* this
project keeps finding, and **the file-length guard is how it was noticed** at 448
lines. It joins `_requests` with `ARRIVAL_ORDINAL` -1, which sorts ahead of every
press in the tick: `KillContest` resolves by who committed first, and a Lunge
committed 0.92 s ago.

**THE ONE DIFFERENCE AN ARRIVAL MAKES IS WHAT A REFUSAL COSTS.** `_reject` charges
`TUN-SUSPICION-GAIN-FAILED-KILL` +30, right for somebody who pressed at nothing
and wrong for somebody who spent a 30 s cooldown, +40 suspicion and a 6 m
telegraph to arrive a metre short. A miss is `TUN-LUNGE-WHIFF-STAGGER` and nothing
else — asserted, including that the impulse queue stays empty.

**AND STUNNING A LUNGER DOES NOT ALSO WHIFF THEM.** `LungeEffect.end` queues an
arrival only when the pawn came back to locomotion, which is the one exit
`LungingState` takes on its own. A stagger on top would price the prey's read
twice.

**TWO RULES WERE WRITTEN TWICE AND THE LENGTH GUARD FOUND BOTH.** `_enter` was
fourteen identical lines in `KillSystem` and `StunSystem`, including the same
warning text — `CombatEntry.into` is the one home. The rewind moved to
`KillRewind`, and **the arch guard naming ADR-0010's two rewind call sites fired
on it, correctly.** Widening a filename allowlist is how a guard gets hollowed
out, so the rule is restated as **ownership**: exactly one class may hold a
`KillRewind`, asserted, which is strictly stronger than the list it replaced.

**US-0061's NINTH CRITERION IS CLOSED AFTER FOUR MILESTONES.** *"A player
mid-Lunge is stunnable for the entire wind-up and dash"* could not be run because
there was no state to be mid-. The wind-up is spent in a locomotion state;
`LungingState` is interruptible and absent from `_is_stunnable`'s three
exclusions. **Both halves are absences, and an absence is what a later reader
deletes by accident**, so both are asserted.

**AND A TEST FIXTURE WAS WRONG IN A WAY WORTH KEEPING.** `test_lunge_effect.gd`
first ticked only the ability system, so the dash never ended and no arrival was
queued — **the fixture was wrong and the guard was right**: `LungingState` is
driven at the `pawn` stage. That is US-0067's *one clock, not two* lesson, and it
is asserted deliberately now rather than left as a fixture detail.

**EIGHT PLANTED DEFECTS, ALL RED**: the wind-up losing its reader again, the
duration stored rather than derived, the player steering the dash, the dash owning
its position, a stun unable to reach it, a miss charged as a rejected press, a
press outranking a committed dash, and a stunned lunger whiffed as well.

**AND A LIVE SERVER FOUND TWO THINGS EVERY TEST MISSED.**
`tools/ability_probe.tscn` presses slot 1 on the real `server_root.tscn` now:

```bash
godot --headless --path . res://tools/ability_probe.tscn
```

- **A PEER THAT NEVER SENDS INPUT IS NEVER STEPPED.** The first probe joined a
  peer, pressed, and watched the pawn enter `Lunging`, travel **0.00 m** and stay
  there — which reads exactly like a dash that does not work. US-0028's own rule:
  *"Nothing is repeated for a peer that has never sent one — a pawn that has not
  yet moved must not start."* **A probe that does not send input measures a pawn
  nobody is simulating**, trap 13's family. It drives like a client now.
- **THE DASH OVERSHOT ITS OWN TUNABLE BY 21 %: 7.27 m AGAINST 6.0.** The state
  held its forty ticks exactly and the pawn then left at 9 m/s and **coasted**
  while `IdleState` decelerated it. `TUN-LUNGE-DISTANCE` says *"closes the gap and
  nothing more"*, and the extra metre is spent **after** the auto-kill is judged.
  `LungingState.exit` zeroes the horizontal velocity now. **No unit test could see
  it** — they assert the state and its velocity, and the overshoot is in the
  pawn's total displacement after the state has ended.

**AND THE FIX FOR THE REMAINING 2.5 % WAS TRIED AND REVERTED, WHICH IS THE MORE
USEFUL HALF.** The timer is incremented before `step()` runs and the ending call
sets no velocity, so the pawn moves on `dash_ticks() - 1` steps: **5.85 m**,
exactly 39 × 0.15. Ending one step later delivers the full 6.0 **and makes the
state outlive `AbilityEffect`'s window by one net tick** — `LungeEffect.end` fires
while the pawn is still `Lunging`, refuses to queue an arrival, and **the whole
resolution is silently dropped**: no kill, no whiff, no stagger. The probe
measured that too, ending `Idle` where it should end `Staggered`. **One clock and
2.5 % short beats two clocks and exact**, and
`test_the_dash_ends_inside_its_own_effect_window` is what stops the next person
trying it.

**MEASURED, REPRODUCIBLE ACROSS RUNS: 40 step ticks of 40, 5.85 m of a tuned 6.0,
ending `Staggered` with no contract to kill.**

**WHAT NOBODY CAN SEE IS THE DASH ITSELF.** There are no animation clips on either
rig, so a Lunge is a pawn that moves very fast with no wind-up pose, no shout and
no dust — the same absence Cinderfall's cloud has. `ANIM-LUNGE-WINDUP`,
`ANIM-LUNGE-DASH` and `ANIM-LUNGE-WHIFF` are all specified and none exists.

## ADR-0017: A FAILED ACTION LEAVES YOU `Staggered`. FIFTEEN STATES AGAIN.

**Owner decision 3 is settled and it was the highest-value one left.** Lose a kill
contest, swing a stun at somebody who is not hunting you, or (when US-0070 lands)
whiff a Lunge, and you now enter a **state** rather than merely losing the use of
two buttons. `Staggered` is the fifteenth, appended at wire index 14.

**THREE TUNABLES HAVE DESCRIBED IT SINCE M0 WITH NOWHERE TO LIVE** —
`TUN-KILL-CONTEST-STAGGER` 1.5 s, `TUN-STUN-INVALID-STAGGER` 2.0 s and
`TUN-LUNGE-WHIFF-STAGGER` 1.2 s. What was built instead is `CombatLockouts.stagger`,
chosen deliberately at US-0060, and it expresses *"losing a race should cost tempo,
not the match"* and **not** the other two: a player serving a lockout can still walk,
run, sprint, vault, climb and blend. So *"unable to act"* was false, and *"flailing is
strictly worse than doing nothing"* was false — **two seconds of buttons is not two
seconds of exposure.**

**THE ARGUMENT THAT DECIDED IT IS NOT ANY OF THE THREE TUNABLES: A LOCKOUT HAS NO
TELL.** `state_id` is on the wire in every remote pawn record and `CombatLockouts` is
on nobody's — so a prey who read a Lunge, sidestepped it and watched the hunter whiff
saw them **stand up and walk away normally**. The read was correct, the punishment
landed, and the player who earned it could not perceive that it had. Design law 3 is
written about abilities and the same principle runs the other way; GDD-02 §9's failure
mode 7 is *"kill feels unresponsive"* and **this is its mirror** — a player earning an
advantage the world refuses to show them.

**IT IS INTERRUPTIBLE, AND THAT IS NEVER-DO #13 RATHER THAN A PREFERENCE.** A whiffed
lunger would otherwise be in a locomotion state, which is stunnable, so a stagger stun
could not follow would be **a weakening dressed as an addition**. It is also GDD-04
§3.4's named counterplay to Lunge paid off: a prey who dodges the dash converts a 1.2 s
stagger into a 4 s freeze and a 12 s exile.

**THE ASYMMETRY WITH `StunAnim` IS A RULE RATHER THAN AN ACCIDENT: you are protected
while DOING something, not while PAYING for having done it.** `KillAnim` and `StunAnim`
decline COMBAT because commitment is the mechanic; `Stunned` declines it because a
re-stunnable player could be chain-locked out of the match by two opponents. None of
that is true of a 1.2-2.0 s recovery you caused yourself.

**AND IT KEEPS THE CAMERA, BECAUSE `Stunned` MUST REMAIN THE ONLY STATE THAT DOES
NOT.** That is the stun's signature — four seconds of not even choosing where to look —
and nothing else may borrow it. Planting `camera_controlled → false` reddens this
story's own test **and** `test_camera_control.gd`'s existing sweep.

**THE DURATION IS ON `PawnContext` AND THE CLIENT'S COPY IS A CEILING, NOT A
PREDICTION.** Three causes, three durations, one state. All three entries are **server
knowledge** — whether a stun was valid, who won a contest, whether a dash landed — so a
client is forced into the state by a snapshot and is told only the *elapsed*. The
default is `max` of the three, **derived rather than a fourth tunable**, so a client's
stagger can only ever end **late**, never early, and the server's next snapshot ends
it. UI_UX_SPEC §3.3's own rule — information newer than the simulation is forbidden,
older is fine — applied to a state instead of a HUD element.

**THE LOCKOUT STAYS, AND THE TWO ARE NOT ONE RULE WRITTEN TWICE.** The lockout answers
*may this player initiate*, which both combat systems must answer **with no state
machine in reach** — that is every unit fixture. The state is the tell and the tempo.
They are armed on adjacent lines at each of the two call sites, and a test at each
asserts they agree **and are on the right clock**: net ticks for the lockout, step ticks
for the state, which is trap 9 at the one seam where the two domains meet.

**`PawnStateId.ALL`'s ORDER IS THE WIRE AND IT IS APPEND-ONLY.**
`Snapshot.state_index` encodes `state_id` as an index into it, so inserting a name in
the middle silently remaps every remote pawn's animation to a different state — a defect
that would read as a rendering fault and is plausible at every position. That docstring
used to say the order was GDD-02 §3.1's *document* order, which was **true by
coincidence** and is the weaker statement. `test_pawn_state_count.gd` now refuses an
insertion before index 14.

**AND A TEST NAME PROMISED WHAT THE CODE COULD NOT DO, FOR THE THIRD TIME.**
`test_the_first_arrival_kills_and_the_second_is_staggered` asserted **`IDLE`** — there
was no stagger state to be in. Trap 3's reading hazard inside a test name, after
`..._is_measured_and_currently_missed` and `test_there_are_fifteen_states` asserting
fourteen. **The name is the part nobody re-reads.**

**REFERENCE FIDELITY, SOURCED RATHER THAN RECALLED — AND ONE HALF IS A FINDING.** The
reference family has a short recovery distinct from the stun: in the *sequel* to the
reference title, a simultaneous kill-and-stun leaves the prey dead and the other party
*"dazed for a short while"*, with its own scoring bonus. So a brief, self-inflicted,
non-stun recovery is faithful. **But `TUN-KILL-CONTEST-STAGGER` models a mechanic the
reference title itself does not have** — the contested kill and its bonus are the
sequel's. That is a divergence ADR-0013's audit did not flag, it is a merged `TUN-` ID
and a merged rule, and it is **reported rather than acted on. Seventh thing waiting on
the owner.** Nothing in ADR-0017 depends on it.

**THE STATE'S NAME LOST AN ARGUMENT TO THREE MERGED IDS.** `Staggered` sits one
letter's distance from `Stunned`, which is the transposition hazard this corpus keeps
finding, and the reference's own word — *dazed* — is more distinct. It was rejected
anyway, because three `TUN-*-STAGGER` ids name the thing and a state whose name
disagrees with the tunables that cause it is the drift GLOSSARY's one-term-one-meaning
rule exists to prevent. **The distinction a reader needs is one line and it is in the
state's docstring and in §3.1: `Stunned` is done to you by another player; `Staggered`
is done to you by your own failed action.**

**THE TWO MISSING `Dead` EDGES WERE ADR-0017's RECOMMENDATION AND ARE NOW CLOSED
(2026-09-02) — AND THE RECOMMENDATION UNDERSTATED THEM.**  See the section below.

**SIX PLANTED DEFECTS, ALL RED, EACH NAMING THE RIGHT TEST**: the state declining a
stun, the ceiling fallback deleted, the camera taken, the total written *after* the
transition, `Tuning.ticks` where `step_ticks` belongs, and the graph losing its edge
into the state — that last one reddens the whole file, which is what the premise
assertion at the top of it is for.

## US-0097 IS DONE, TWELVE OF TWELVE: A HUNT CAN BE SURVIVED AND BOTH SIDES WATCH IT HAPPEN

**Be careless within `TUN-COMPASS-WARN-RADIUS` of your prey and you open a chase**,
and as of 2026-09-01 **both parties see the bar**. Sight refreshes it, absence
drains it, and after `TUN-PURSUIT-DURATION` **10.72 s** without seeing them the
hunter **loses the contract**. The prey is paid `SCORE-ESCAPE` +100, and +50 more
if the hunter was within 5 m at the last sighting.

**TWO BYTES, AND THE STORY ASKED FOR ONE — AND THE CASE THAT BREAKS ONE BYTE IS
THE ORDINARY CASE.** US-0097's criterion reads *"the hunter's own-gameplay block
and the prey's each carry `pursuit_fraction:u8`"*, written as though a player were
either a hunter or a prey. **They are never either**: a Hamiltonian cycle gives
every player exactly one outgoing edge and exactly one incoming one, so everybody
is always both, both chases can be live at once, and they mean opposite things —
`hunt_fraction` drains toward losing your contract and `hunted_fraction` drains
toward escaping. One byte would have been ambiguous **always**, not rarely.

**NEITHER NAMES ANYBODY**, which is what keeps them inside never-do #12, and the
test fixture is built so a transposition of the two is *visible*: Alice is made a
hunter and a prey at once with the bars at deliberately different values. Two
adjacent bytes of the same width holding two fractions of the same bar is exactly
the shape `ScoreAward` was extracted to avoid, and there is no type that separates
them — equal fixtures would agree whichever way round they were written.

**`NOBODY` IS ZERO AND ZERO IS A DICTIONARY KEY LIKE ANY OTHER.** The prey's bar
needs a reverse lookup and `PursuitBoard.hunter_of` answers `ContractCycle.NOBODY`
— **0** — for a player nobody hunts. No engine peer id is ever 0, so the lookup
would miss anyway; resting a rule on that is `CompassBoard.NO_CONTRACT`'s hazard
exactly, so `_fill_pursuit` **states** the default rather than inheriting it from a
coincidence about the id space. Deleting the guard reddens one test and nothing else.

**A SEPARATE WIDGET, BECAUSE THE COMPASS DRAWS NOTHING WITHOUT A CONTRACT.**
`CompassWidget._draw` returns early on `has_contract()`, and the most important
moment this element has — a hunter about to lose you while you are inside the
reassign breath — is exactly when that early-out fires. Folding the bars in would
have meant deleting a guard that is correct for the Compass. `ChaseRingWidget`
derives its centre from `CompassWidget`'s own constants, so moving one moves both.

**AND LOOKING AT IT FOUND TWO THINGS NO TEST HERE COULD.** `tools/hud_probe.tscn`
captures nineteen states now, five of them the chase:

- **A BAR WITH NO TRACK IS NOT A BAR.** Without the unfilled remainder drawn behind
  it, 0.95 and 0.6 both read as *an arc with a gap in it* and the fraction is not
  judgeable at a glance — which is the entire value of an element whose question is
  *how long have I got*. It matters more here than on the lock arc, which fills in
  1.6 s against this one's 10.72.
- **DIRECTION OF TRAVEL ONLY SEPARATES THE TWO ARCS IN MOTION.** The first version
  claimed three non-hue channels — radius, direction, colour — and a **still**
  capture shows an arc with a gap: which way it wound is not recoverable from a
  frame. The monochrome-palette argument was resting on two channels rather than
  three. **Weight is the fourth**, and it is a design call rather than a patch: the
  hunted bar is the heavier, because a hunter is already looking at the Compass and
  the prey is looking at the world. UI_UX_SPEC §5.2 states that requirement for the
  score feed and gives the same answer.

**AND THE PROBE CANNOT CATCH A TRANSIENT AT ITS DEFAULT SETTLE, WHICH IS SAID
RATHER THAN FAKED.** Ninety frames is right for a *state* — it makes a capture
reproducible — and exactly wrong for the 0.45 s re-acquisition pulse, which has
decayed to nothing by then. `_state` takes an optional settle now and frames 16b
and 16c are taken mid-pulse. Captioning a decayed pulse as a pulse would have been
an instrument wrong in a plausible direction, which this corpus already calls worse
than no instrument.

**THE RAYCAST MEASUREMENT IS OWED NO LONGER: 6 CASTS PER TICK, AT THE TOP OF THE
BAND.** `test_pursuit_raycast_budget.gd` drives a six-player ring through the real
`DetectionSystem`. Worst case is **6 for 6 hunters** against TDD-07 §4.3's
published **2-6** — the ceiling rather than the middle — and at **35 degrees off
axis**, inside the pursuit cone and outside the lock's, the chase spends **six
where the lock alone would have spent zero**. That band is why *"no raycast the
lock has not already spent"* was never achievable alongside a 90 degree cone
against a 25 degree one. A hunter facing away still spends nothing.

**AND THE PREMISE ASSERTION IN THAT FILE IS NOT DECORATION.**
`_clear_of_geometry` answers *nothing blocks* and returns **before** it increments
when there is no `World3D`, so a fixture out of the tree measures zero for every
arrangement and every assertion in the file would pass over nothing.

**`snapshot.gd` IS NOW 167 LINES; `SnapshotCodec` IS 261.** PR #214 keeps the
value object and its public API in `Snapshot`, with ordered encoding, decoding and
quantised fingerprints together in the codec. The cost is one more navigation hop
from fields to wire. Three packet fixtures captured before the split pin exact
bytes, alongside the existing size and round-trip tests; static `deserialise` stays
static. See [the decision](docs/40_backlog/SPLIT_THE_SNAPSHOT.md).
**THIS WAS NOT A BLOCKER FOR US-0079:** `phase` and `ticks_remaining` already exist.
The initial dependency claim was wrong; this is a standalone size/seam refactor.

**AND TWO PROSE COUNTS IN THIS FILE WERE STALE AND HAVE SELF-CORRECTED.** The
unticked-criteria figure read **fifty** while the truth was fifty-two (US-0097 was
`in-progress` with two); closing both makes the printed number right again by
accident. And `EventBus` was described as having **twenty** signals when it had
nineteen; it has twenty now, and twenty `EVT-` ids, which agree exactly for the
first time. **Regenerate a count, never edit it** — sixth instance.

## M4 IS COMPLETE. M5 IS AT THE HUD AND THE ABILITIES, AND ONE OF THEM WORKS.

**AND US-0067 IS DONE, SEVEN OF SEVEN: `ABIL-CINDERFALL` IS THE FIRST ABILITY IN
THIS GAME THAT CHANGES THE WORLD.** Press it and 0.45 s later a 5 m cloud lands
where you threw it, blocks every line of sight through it for 4 s, forbids kill
initiation inside it **for everybody including you**, costs +40 suspicion and
sends every NPC within 9 m running.

**`CinderfallEffect` IS ELEVEN LINES, AND THAT IS THE STORY RATHER THAN A
SHORTCUT.** `CinderfallVolumes` was built at US-0056 and sharpened at US-0060,
`SYS-DETECTION` has consulted it in the project's one line-of-sight query since,
`SYS-KILL` has refused initiation inside one since US-0060, and `SYS-ABILITY` has
run the pipeline around it since US-0066. **`add()` was the one entry point with
nothing behind it** — the shape `CrowdAlarm.startle_at` had through all of M3.

**THE 0.45 s CAST WAS NOBODY'S AND IS NOW THE PIPELINE'S.**
`TUN-CINDERFALL-CAST-TIME` had **no reader**: `_commit` began the effect on the
press tick. `LiveAbility` holds a cast that is *pending* until `begins_at` and
*live* afterwards, and it sits in the system rather than the effect because
`AbilityData.cast_time` is used by Second Face too. **TDD-09 §1's sequence diagram
has no cast phase and is amended** — twice now, since US-0066 already moved the
tell ahead of `begin`.

**AND THE WIND-UP IS WHAT MAKES THE TELL WORTH SENDING.** The tell fires at the
press and the cloud lands 0.45 s later, so design law 3's *perceivable chance to
react* is a measurable window rather than a claim. **A caster killed during it
drops no cloud**, and the cooldown and the +40 stay spent — so a victim who read
the tell and acted is paid for reading it.

**A STUN DOES NOT CANCEL A CAST, AND THAT IS LEFT RATHER THAN DECIDED.** Nothing
in GDD-04 gives a stun that power and §3.1 names the counter to Cinderfall as
**patience** — wait at the cloud's edge. Adding one would change the ability's
counterplay on my own judgement. **Sixth thing waiting on the owner.**

**THE STARTLE IS THE SYSTEM'S, NOT THE EFFECT'S**, because `startle_radius` is
Lunge's too: it sits beside the suspicion cost and leaves through
`ability_startled`, which `server_root` wires to `CrowdDirector.startle_at` — the
shape `SYS-KILL`'s consequences already use. **It fires at the burst and is
centred on the pot**, because GDD-04 §3.1 lists the 0.45 s underarm throw and the
crack as *separate* tell channels, and a wave at the caster's feet would announce
them however far they threw.

**`end()` MUST NOT REMOVE THE CLOUD, WHICH IS THE OPPOSITE OF WHAT "DEREGISTERED
ON EXPIRY" SOUNDS LIKE.** `CinderfallVolumes.expire` deliberately lags the
burn-out by `RewindClamp.max_ticks()`, because a kill is validated in the past and
a cloud that was up when the attacker pressed must still block that validation
100-200 ms later.

**AND THE ENGINE FOUND A DEFECT NO REVIEW HERE WOULD HAVE: CODE WAS ABOUT TO GO
ON THE WIRE.** The tick `cinderfall.tres` gained an `effect_script`,
`test_tuning_serialise_roundtrip.gd` went red with *"Class CinderfallEffect hides
a global script class"*. `TuningProfile.serialise` is
`var_to_bytes_with_objects`, so **an `AbilityData` field holding a `Script` is
sent as a script** — and TDD-09 §3 makes effects server-only, with
`scripts/systems/` excluded from every client export. The parse error was the
symptom; the defect was the payload. `_wireable` strips `effect_script` and
`tell_vfx` now: **numbers travel, code does not.** The hash is untouched, because
`compute_hash` has never walked abilities — asserted, since a moved hash would
make `Handshake` refuse peers for an unexplainable reason.

**THREE OF FOUR PLANTED DEFECTS WENT RED AND THE FOURTH IS THE FINDING.**
Measuring the effect's deadline from the press rather than from the burst left
`test_the_duration_runs_from_the_burst_and_not_from_the_press` **green**, because
the cloud's lifetime is `CinderfallVolumes`' own arithmetic and the test only
asked about the cloud. **The effect and the volume keep two clocks and the defect
lives in the gap**: the effect would be dead for the last 0.45 s of its own cloud,
which nothing about the cloud reveals.

**AND A TEST IN US-0066 COULD NEVER HAVE FAILED.**
`test_a_refused_cast_announces_nothing` counted into a **lambda-captured `int`** —
GDScript captures a local by *value*, so `told += 1` incremented a copy and `told`
was zero however many tells went out. Found because the same shape failed in a
test that expected *one* rather than *none*. A scan of `test/` found no third
instance; the only other lambda counter mutates a class member, which is captured
through `self`. **Second US-0066 test repaired here** — the other cast Cinderfall
to prove a null-effect property and kept passing for a completely different reason
once Cinderfall had an effect.

**AND `AbilityEffect.tick` RETURNING FALSE NEARLY MADE THE CLOUD INERT.** The base
returns false because *"return false to end early"* and a no-op's honest lifetime
is one tick — which is right, and is why the first `CinderfallEffect` ended on the
tick after it began. **The first effect with a duration is the first that must
override it**, exactly as US-0066's note predicted.

**AND IT IS VERIFIED ON A REAL SERVER RATHER THAN ONLY AGAINST THE SYSTEM.**
`tools/ability_probe.tscn` boots `server_root.tscn`, joins a peer and presses slot
0 — the unit tests drive `AbilitySystem` directly and cannot see the wiring, which
is the gap US-0074 lost a whole integration run to. Measured: **0 clouds during
the wind-up, 1 after it, 1 startle wave over 78 NPCs, suspicion 45.2, 1 325 ticks
of cooldown left.**

```bash
godot --headless --path . res://tools/ability_probe.tscn
```

**ITS FIRST VERSION READ THE WRONG NUMBER**, printing `SuspicionImpulses.pending`
and getting `0.0` — which reads exactly like a cost never charged, and is
`SYS-SUSPICION` having drained the queue a tick later. It reads
`PawnContext.suspicion` now.

**AND A GREEN SUITE WAS RUNNING ONE FILE FEWER THAN EXISTS.**
`CombatTargets.is_dead` takes a pawn and I called it with a context and a peer — a
**parse error**, which GUT answers by *ignoring the whole file*.
`test/unit/systems/combat` printed **"All tests passed!"** over six scripts of
seven, and the full unit suite reported 1 463 passing over **174 of 175**. The file
it dropped held this story's own new assertion. **Only `.ci/run_gut.sh`'s script
count could see it** — trap 10's family, seventh instance.

**THE CLOUD IS DRAWN AS OF 2026-09-03** — `CinderfallView`, and it is the first
thing in `scripts/presentation/vfx/`. It draws the **gameplay volume exactly**:
same centre, same `TUN-CINDERFALL-RADIUS`, same `TUN-CINDERFALL-DURATION`, no fade
and no generous edge, because GDD-04 §3.1 prices the counter as *wait at the
cloud's edge* and an edge drawn anywhere else is a counterplay that lies. See the
section at the top of this file.

## M4 IS COMPLETE. M5 HAS STARTED AT THE HUD, AND A KILL IS NOW PAID FOR ON SCREEN.

**M4's fifteen stories are built and its gate is run and split.** The whole loop
resolves on the server — contracts, suspicion, all four blends, detection, the
Compass's server half, the prey warning, kill, stun, spawn.

**AND FOUR HUD STORIES LATER A PLAYER CAN SEE THE COMPASS, THEIR TIER AND WHY,
WHETHER A KILL WOULD LAND, AND — AS OF US-0074 — WHAT THEY WERE JUST PAID FOR.**
A patient blend kill now arrives as four named lines, `TUN-UI-SCOREFEED-STAGGER`
0.12 s apart, on the right above centre. **Still invisible**: the match timer, the
ability slots, the results screen, and **any animation clip on either rig**. A kill
is a state change, a log line and now a feed.

**US-0074 IS DONE, EIGHT OF EIGHT, AND `NET-S2C-SCORE-EVENT` IS WHAT IT ACTUALLY
COST.** The bus signal `EVT-SCORE-EVENT-APPENDED` was declared at M0 with no
emitter and **no story claimed the wire message**, so the feed was inert until this
one built it: `ScoreWire` owns the catalogue's sixteen-byte row, `MatchAnnouncer`
addresses it, `HudBridge` forwards it, `ScoreFeedVm` queues it.

**THE COURIER IS A CURSOR OVER THE LOG RATHER THAN A HOOK ON EACH APPEND.** Two
systems append today — the kill and the stun — and ADR-0014's escape will be a
third; a courier wired to each call site is a list that goes stale in silence, and
the symptom is one bonus that quietly stopped reaching the feed. `ScoreLog.tail`
is the seam, and **a cursor cannot miss an append whoever made it**.

**AND THE RECIPIENT IS A FIELD OF THE EVENT, WHICH MAKES NEVER-DO #12 STRUCTURAL.**
Every other S2C message takes a recipient list its caller assembled; this one takes
`ScoreEvent.actor_id`, so there is **no list to widen by accident**. A global feed
would hand every player the shape of the contract cycle for free.

**`SCORE-DEATH` IS THE ONE KIND WITHHELD, FOR TWO REASONS THAT AGREE.** It pays
nothing, so a feed whose question is *"what did I just get paid for?"* has nothing
to draw — and it is the **only** score event whose `subject` names somebody the
recipient has not earned: `ScoreLog.mark_death` records the victim as actor and the
**killer** as subject. `NET-S2C-KILL-RESULT` already tells a victim who killed them
and is the message designed to; a second channel for the same fact is one nobody
would think to audit.

**`gdlint` REFUSED THE MESSAGE AND WAS RIGHT FOR THE SECOND TIME IN THREE
STORIES.** Eight loose RPC arguments exceeded the six-argument cap, so the row is
**hand-packed** — which is US-0095's lesson applied before it cost anything (Godot
Variant-encoded `NET-C2S-INPUT` at **56 bytes against a budgeted 9**) and, more
importantly, makes `base:i16` a real width instead of an assumed one. Eight
positional integers in which transposing `actor` and `subject` is invisible is
exactly the shape `ScoreAward` was extracted to avoid.

**AND THE ROW IS SIXTEEN BYTES, NOT THE FOURTEEN I WROTE IN TWO PLACES.** My own
arithmetic, caught by the size assertion on its first run — which is the entire
reason to assert a declared width rather than trust it.

**THREE BONUSES HAD NO NAME AND NOTHING CHECKED.** `SCORE-HALFSEEN` (2026-08-27)
and `SCORE-ESCAPE`/`SCORE-CLOSECALL` (2026-08-26) had no row in
`data/strings/en.csv` — **fourteen of seventeen**, which is the shape of a table
that looks complete. The display key is **derived** now (`SCORE-FROMABOVE` →
`bonus.fromabove`) rather than tabulated, so a second seventeen-row list cannot
drift from the first, and `test_bonus_names_exist.gd` harvests the ids from `Ids`
and refuses a kind with no name.

**AND MY UNIT TEST DROVE THE DECISION AND NOT THE WIRING, WHICH COST A WHOLE
INTEGRATION RUN.** `MatchDirector.tick_completed(ctx, dt)` carries two arguments
and `flush_score()` took none; `connect` accepts that happily and fails at **every
emission**, once a tick, in a message that names the callable rather than the story
that added it. The pure-decision/thin-system split is right and this is its price:
**the seam has to be tested from both sides.** `test_score_courier.gd` now calls
the loop as well as the rule.

**AND LOOKING AT IT FOUND THREE THINGS NO TEST HERE COULD.** Run
`godot --path . res://tools/hud_probe.tscn` windowed after any HUD change — it
captures fourteen states now, three of them the feed:

- **THE BLOCKS TOUCHED.** A block was exactly as tall as its own two rows, so four
  bonuses read as one eight-row ladder rather than as four things — and the penalty
  plate, which is padded, drew **straight over the line above it**.
- **THE NAME WAS DIM AND THE VALUE BRIGHT**, which is backwards for an element
  whose stated purpose is that *the name is the lesson* (GDD-06 §3.2). The value
  keeps its dominance by **size**, a channel a colourblind palette cannot undo.
- **ONLY THE PENALTY HAD A PLATE.** UI_UX_SPEC §5.2 prices a penalty as *"different
  plate, different weight"* — which says every line has one. White text over the
  district's pale sky is at the edge of legible at the fovea and gone in the
  periphery, and this element's requirement is to be read **without being looked
  at**.

**AND THE PENALTY TREATMENT HAS NO PRODUCER, WHICH IS WORTH KNOWING BEFORE
SOMEBODY LOOKS FOR IT.** ADR-0013 took `TUN-SCORE-RECKLESS` to **zero**, so no
shipped bonus pays below zero: §5.2's treatment is built, tested and dormant, and
`SCORE-RECKLESS` draws in the **neutral** treatment because a zero is not a fine.

**AND THE FIRST TIME SOMEBODY PLAYED IT, THE COMPASS POINTED THE WRONG WAY — TWO
ERRORS THAT PARTLY CANCELLED.** The owner walked toward the cone and it led them
away: *"when I turn right the cone should be on top, but it is weirdly on the
bottom."* **This game's yaw 0 faces +Z and a Godot node's faces −Z**, and
`HudRoot` handed `CompassVm` the camera node's heading unconverted — half a turn
out. Separately the widget mapped a **world** angle straight onto a **screen**
angle, and the two run opposite ways: this game's yaw increases toward a turn to
the *left* (`InputSampler` subtracts the mouse's x, `ProbeLayout.right` is
`forward × up` = −X at yaw 0) while a screen angle increases clockwise because
+Y is down.

**COMPOSED, THEY ARE A FRONT-TO-BACK FLIP, AND THAT IS WHY IT SURVIVED A REVIEW
AND A PROBE.** A contract at either shoulder drew **correctly**; only ahead and
behind were swapped. **A defect that is right at two of four cardinal points is
worse than one that is wrong at all of them**, because it looks like an
instrument that works. `CameraArm.yaw_from_camera` and `CompassWidget.screen_angle`
own the two conversions and each says why.

**AND THE MEASUREMENT CAME FIRST, WHICH IS THE ONLY REASON THE SECOND ERROR WAS
FOUND.** A throwaway script built the rig the way `CameraRig` builds it and read
`global_rotation.y` back: exactly 180° from the yaw it was built with, at every
yaw. That named the first error — and then the *test* written from it went red on
left/right, which named the second. **Reasoning from the report alone would have
fixed half of it and shipped a cone that was wrong at the shoulders instead.**

**THE ARC ALSO WIDENS AS YOU CLOSE NOW, AND THE FIXED CONE WAS A DESIGN DEFECT
RATHER THAN A MISSING FEATURE.** TUNABLES has said since M0 that the cone tells
you *"which part of the plaza, never which body"*, and reasoned it at 30 m. **At
the 2.85 m a kill lands from, a fixed 12° arc spans 1.06 m** — narrower than two
people standing side by side, so it picks one, for free, at exactly the moment the
1.6 s lock exists to charge for. The arc covers **ground rather than an angle**
now, so the ambiguity never shrinks as you approach and it becomes a **whole ring
at `TUN-COMPASS-CONE-FULL-RADIUS` 6.0 m**. The falloff flattens as the arc opens,
because a full ring has no edges to fade.

**AND US-0066 IS SEVEN OF EIGHT: `SYS-ABILITY` EXISTS AND NOTHING IT CASTS DOES
ANYTHING.** Press an ability and the whole pipeline runs — five validations, an
integer-tick cooldown, the suspicion cost, and a **reliable broadcast of the tell
to everybody inside the ability's own radius**. `AbilityData.effect_script` is
null for all four, so the world does not change. **That is the story, not a gap
in it**: Cinderfall, Lunge and Second Face are US-0067, US-0070 and US-0069.

**THE TELL IS THE ONE BROADCAST IN THIS GAME, AND IT IS THE ONLY MESSAGE WHOSE
RECIPIENT LIST EXISTS TO INCLUDE PEOPLE.** Every other one withholds — a kill
result goes to two players because a global feed would convert an inference into a
fact. Design law 3 is the opposite shape: *no ability resolves without the victim
having had a perceivable chance to read it*, so the failure mode is somebody **not**
being told. It is **reliable**, which is not the default choice for a cosmetic: a
dropped snapshot costs a frame of smoothness and a dropped tell costs the victim
their only warning.

**AND THE TELL GOES OUT BEFORE `effect.begin`**, two adjacent lines in `_commit`.
Reversed, the victim would receive it after the thing it warns about, which is not
a tell but a notification.

**COOLDOWNS RESET ON DEATH, AND NOT WHERE US-0062 EXPECTED THEM TO.** That story
left the criterion open with a note pointing at `PawnContext.reset_for_spawn` —
which is **replayed during prediction reconciliation**, so a cooldown living there
would be rewound and re-applied on every correction. `AbilitySystem.on_death` owns
them. **Third time this finding has appeared** after the suspicion impulse queue
and the patient speed ring, and it closes US-0062's last open criterion.

**THE DENIAL CARRIES ITS REASON, WHICH IS THE OPPOSITE OF THE STUN REFUSAL.** The
difference is who the reason is about: a stun refusal that named its cause would be
a free identity probe, while every ability denial is a fact about **the presser's
own kit, cooldown, state or aim**. There is nothing in it to learn about a stranger,
which is what makes it safe to be helpful — asserted by a scan refusing the words
*contract*, *pursuer*, *target*, *persona* and *tier* anywhere in the reason list.

**`Tuning` DID NOT EXPOSE THE ABILITIES DICTIONARY AND THREE CALL SITES WANTED
IT.** It mirrors twelve section resources as fields and leaves `abilities` and
`passives` on the profile, which is right — they are keyed data rather than
sections, and mirroring would be a second copy to keep in step with `adopt()`.
`Tuning.ability_data(id)` is the one guarded reader, so no call site writes its own
null check.

**AND MY OWN ORDERING TEST WAS WRONG IN THE INSTRUCTIVE DIRECTION.** It asserted
`is_effect_active` after a cast and read **false** — which looks exactly like an
effect that never started, and is in fact an effect that **finished**:
`AbilityEffect.tick` returns false, which is the documented *end early* signal, so a
base no-op ends inside the tick it began. The ordering is guarded on the source
until US-0067 provides an effect that outlives its first tick.

**AND THERE ARE BOTS NOW, WHICH THIS PROJECT HAS NEVER HAD.**
`tools/bot_client.tscn` is **the real client scene** joined over the real wire with
its movement actions pressed from a script — so the contract cycle, suspicion, the
Compass, a kill, a stun and a score all run for it exactly as they do for a person.
`play.bat` starts a server, N of them and your own client from cmd, and closing the
game window shuts the rest down.

**IT RUNS HEADLESS, AND `drive_probe.gd` SAYS THAT IS IMPOSSIBLE.** That file
refuses with *"headless cannot deliver an input action"* — **and it is wrong.**
Trap 13's evidence is about *reading a device*: a joypad axis and mouse motion need
a windowing layer, which `tools/input_probe.gd` measured. `Input.action_press` is a
**synthetic** press into the Input singleton and needs none. Measured: a headless
bot walked **12.5 m in fifteen seconds** with the server agreeing. The refusal in
`drive_probe` is over-broad and its stated reason is not the real one.

**WHAT A BOT STILL CANNOT DO IS LOOK WITH A MOUSE.** Turning goes through
`input_look_left`/`-right`, which exist for the pad, so a bot sweeps rather than
aims. It does not press kill or stun and does not pretend to: **it is a moving,
blending, killable player, not an opponent.**

**AND THE FOUR DEBUG OVERLAYS TURN OFF WITH `F3`.** They cover the top-left
quarter of the screen and repaint the whole district, with the HUD drawn
underneath. **A raw key, deliberately not an `InputMap` action**: every `INPUT-`
id is harvested from `docs/` and guarded both ways, so one for a debug toggle would
put a developer convenience into the published control scheme. **And the world
tint comes off with the map** — hiding the `CanvasLayer` alone would leave the
district still painted, which reads as a rendering fault rather than as a tool
somebody switched off. Verified by looking at it.

**AND US-0065 IS DONE, NINE OF NINE: THE SCORING TABLE IS LIVE.** Thirteen
bonuses, every one judged at **initiation** and paid at the contact frame. A
patient blend kill is worth 750 in a running match, not in a spreadsheet.

**THE SUSPICION LADDER IS A PARTITION NOW, AND THAT IS ASSERTED.** Exactly one of
Silent, Halfseen and Reckless fires on every kill — the hole the 2026-08-27
re-audit found was that a kill at Noticed paid *neither*, so being glimpsed and
being caught in the open scored identically. **`SCORE-RECKLESS` fires at zero
rather than not firing**, because the feed line saying *you were seen* is the half
that teaches.

**`SYS-SCORE` IS NOT A `GameSystem`, FOR THE FOURTH TIME AND A FOURTH REASON.**
Every bonus is judged at kill initiation, which is the `combat` stage; a system at
the `score` stage would answer every question **one tick late**. The two windows
ride passes that already exist — `SYS-SUSPICION` (stage 4) already reads
horizontal speed and `SYS-DETECTION` (stage 5) already asks the Compass lock's
sight question — so the `score` stage stays empty and nothing was added to a hot
loop.

**TDD-10 §2.1 PUTS THE SPEED RING ON `PawnContext`, AND THAT WOULD HAVE BEEN
WRONG.** That object is **replayed during prediction reconciliation**, so a client
replaying twenty commands would push twenty duplicate samples into a gameplay
buffer — and the ring would then say a patient player sprinted. It is US-0052's
finding about the suspicion impulse queue in a second place: *a system reaching
another system's state does it through the context.*

**`SCORE-FOCUS` COSTS NO RAYCAST AND CLOSES US-0056's LAST OPEN CRITERION.** It
rides `can_lock` — the same ordered pair the Compass lock already queries — which
means it asks for unbroken **watching** rather than TDD-10 §2's literal *unbroken
LOS*. A bare sight test at any angle would be a seventh cast per tick against a
budget of 2-6, to answer a question about a player who is not looking, and GDD-07
§3 prices this bonus for *"tracking one person in a moving crowd"*.

**AND THE PATIENT WINDOW READS AS CLEAN BEFORE IT FILLS, DELIBERATELY RATHER THAN
BY ZERO-INITIALISATION.** *"Never exceeded the speed in the 10 s before
initiation"* is true of a player who has only existed for three of them, and
denying the bonus for the first ten seconds of every life would punish a respawn
for the timing of its own death. Trap 17's family, designed out instead of
inherited.

**`gdlint` PUSHED BACK TWICE MORE AND WAS RIGHT BOTH TIMES.** A twenty-method test
file was one object's four windows, and splitting it produced exactly the file
names US-0065's own test notes asked for. And **trap 11 fired twice in one run**:
three functions went over 40 lines because of comments I had added, and the second
message named `_read_the_compass` when the cause was the docstring on the function
*after* it. **A function is charged for the next one's docstring and not for its
own**, which is where the reasoning moved.

**AND MY OWN GRACE TEST WAS WRONG BEFORE THE CODE WAS.** It opened with a
line-of-sight lapse against a grace no sighting had armed, read 27 where it
expected 39, and looked exactly like a grace that does not re-arm. The mechanism
was right and the arithmetic was mine; the test starts with a sighting now and
asserts the streak never resets rather than only its total.

**AND US-0064 IS DONE, SEVEN OF SEVEN: A KILL IS PAID FOR.** `ScoreEvent`,
`ScoreLog` and the pure `ScoreFold` exist, and **the shipped server appends to
them** — `SCORE-CONTRACT` on every kill and the `SCORE-DEATH` marker, sharing a
group. `test_the_m4_loop_resolves.gd` asserts the payment through the real
`MatchDirector`, because `NpcPool`'s lesson is that **a criterion can be true of a
class and false of the game**. Nothing draws a score yet; that is US-0074.

**THE FOLD REPRODUCES ALL SEVEN OF GDD-07 §3.2's REFERENCE KILLS EXACTLY**, from
100 for a sprinting tackle to 2 000 for a perfect final-phase kill, with no server
standing up. That is event sourcing's whole claim in TDD-10 §1.3: the most
bug-prone part of the design becomes the part a test can hold.

**`ScoreEvent` IS IMMUTABLE IN THE ENGINE RATHER THAN IN A COMMENT.** Every field
is a getter-only property over a private backing value, so `event.tick = 9` is a
**parse error** — which is why the test asserts through `set()`, the only route the
engine leaves open. A plain `var` with a docstring saying *never mutate this* is
exactly the shape that gets mutated two milestones later.

**AND THE MULTIPLIER CANNOT DISAGREE WITH ITS OWN TICK, BECAUSE THERE IS ONE
CONSTRUCTOR AND IT TAKES THE TICK.** TDD-10 §1.2 asks for it frozen at append;
passing the multiplier in would permit an inconsistent event, so `ScoreEvent`
derives it. **The final phase is a property of the clock rather than of a state
machine** — `TUN-MATCH-DURATION` minus `TUN-MATCH-FINALPHASE-DURATION` — so
scoring is **not blocked on `SYS-MATCH`**. When US-0079 lands it must *read* this
rather than decide it again, or the phase the HUD announces and the phase the
points are paid at will drift.

**TDD-10 §1.3 CONTRADICTED ITSELF AND THE SKETCH LOST.** Its signature is
`fold(events, tuning)` while §1.2 and the struct both freeze the points on the
event — so a fold that re-read the tuning could produce **a different total from
the one the feed already showed the player**, which is the two-sources-of-truth
defect §1.1 exists to prevent. The `tuning` argument is dropped and §1.3 says why.

**AND `gdlint` REFUSED AN EIGHT-ARGUMENT CONSTRUCTOR, WHICH WAS RIGHT.**
`.gdlintrc` caps a signature at six and says the limit is *"a design signal, not a
style preference — if it is genuinely wrong for a case, that is an ADR, not a
`gdlint:ignore`"*. It was not wrong: `ScoreEvent.new(id, tick, kind, actor,
subject, points, rules, group)` is a call site where transposing the actor and the
subject is invisible, twelve times per kill in US-0065. **`ScoreAward` is the
record that answers it** — an award is a *claim* a system makes, an event is what
the log made of it, and the seam between them is the append.

**`server_root.gd` PASSED 400 LINES AND WAS SPLIT**, and the seam is *boot* versus
*announcements*. `MatchAnnouncer` owns every message the server sends and is **the
one place a peer id becomes a wire slot** — a rule that file was already asserting
in three separate comments without a class to hold it. 419 → 339 lines, and the
integration suite boots the real scene, so the move is verified end to end.

**MY OWN COUNTERFACTUAL WENT RED ON CORRECT CODE, AND THAT IS THE FINDING.**
`test_score_no_direct_mutation.gd` scanned `ScoreFold` for the same `score +=`
needles as the guard, and the fold accumulates into a **dictionary**. **A
counterfactual written as a string match is only as good as the guard's
vocabulary**; it folds two events and checks the sum now. The guard itself is
falsified against a `_score += 1` planted in `SuspicionSystem` and names the file
and line.

**AND THE CONE'S MOTION IS CHASED NOW, BECAUSE THE WIRE QUANTISES IT.** Reported
from the controls: *"when I am walking in one direction and the cone is moving for
example to the left, it's not as smooth as I would like. I wouldn't say it
stutters."* **That is a quantisation staircase, not a dropped frame**, and the
distinction is what named it: `Quantise.YAW_STEP` is **1.41 degrees**, which is
2.4 px at the cone's outer rim, arriving at 30 Hz and drawn at 144. Worse, the
wobble alone moves the bearing about 8 deg/s — **under one quantum per server
tick** — so the value sits still for five ticks and then twitches.

**THE DRAWN BEARING AND THE DRAWN WIDTH CHASE THE AUTHORITATIVE ONES OVER
`TUN-NET-INTERP-BUFFER`.** Not a new number: every other remote thing on screen is
already drawn that far behind, so the cone and the body it points at move on one
clock. **This is not prediction and the distinction is the whole point** —
UI_UX_SPEC §3.3 forbids information *newer* than the simulation, and an exponential
chase is strictly *older*: it starts behind, converges, never leads, never
overshoots. TDD-04's own sentence, in a new place: **the simulation snaps; the
visual blends.**

**THE CAMERA'S YAW IS DELIBERATELY NOT SMOOTHED**, and that is asserted. Only the
world bearing is chased; smoothing the yaw would put the one HUD element whose job
is to track the player's head behind their mouse.

**A NEW CONTRACT IS ADOPTED RATHER THAN SWEPT TOWARD**, and
`TUN-CONTRACT-REASSIGN-DELAY` is what makes that safe: a cone sliding from the old
bearing to the new one would draw every angle in between — a bearing that was never
true, reading as the contract sprinting around you.

**AND A GUARD THAT BANNED A FUNCTION NAME BECAME ONE THAT ASSERTS THE PROPERTY.**
`test_compass_invents_nothing.gd` forbade the string `lerp_angle` in the view
model. **A name-ban cannot tell smoothing from extrapolation, and cannot catch
extrapolation written without the banned word.** It asserts instead that the drawn
bearing never crosses the value it was given and always arrives — strictly
stronger, and falsified against a chase with `alpha` tripled. **Third guard
narrowed this way in a week**, all three by the first client that ever needed to
*draw* gameplay state.

**AND THE ARC WIDTH IS CHASED TOO, WHICH NOBODY REPORTED.** The distance arrives in
0.5 m buckets and **near the ring one bucket is nine degrees of half-width**, so it
would have been the next thing noticed. Same defect, same channel, same constant —
said here rather than folded in silently.

**AND THE RING RADIUS WAS WIDENED TWICE MORE, BOTH TIMES AT THE CONTROLS, AND IT
IS NOW `TUN-COMPASS-LOCK-RANGE` 20 m.** 4.0 m, then 6.0 m, then 20.0 — and the
judgement each time was the same sentence: *"currently i have to stand right next
to the pray."* **The arc stops saying which way at exactly the range the lock
starts working**, so a player learns one boundary rather than two: outside it the
instrument points, inside it you look, and looking is what the 1.6 s lock is for.
`TUN-COMPASS-LOCK-RANGE`'s own docstring already said it — *"a lock always means 'I
am in the same space as them'"* — which is the sentence the ring needed.

**THE SECOND MISS IS THE INTERESTING ONE, BECAUSE 6.0 m WAS DERIVED AND STILL
WRONG.** `TUN-SUSPICION-OPEN-RADIUS` is a real answer to *the space you are
standing in* and it is the wrong space: it is the radius at which the **crowd**
stops hiding you, not the radius at which **you** can pick a face out of it. A
derivation is not a justification, and a well-argued number can still be the wrong
one — which is the whole reason the third value came from somebody walking toward
somebody rather than from a better argument.

**AND THE PRICE OF GUESSING IT TWICE IS A READOUT.** Both misses were reported as
a screenshot, and pricing the second one meant **estimating the distance from
apparent capsule height** — 60° over 1030 px against a 1.8 m capsule, ~16 m ± 2.5.
`net_readout.gd` prints the contract's bucket, the arc it produces and how far the
ring still is, so the next judgement is a reading. Debug-only, and
`scripts/debug/` is out of all three release presets: a player is told *nearer*,
never *how far*.

**AND THE FIRST CUT CLOSED THE RING AT 4.0 m, WHICH THE OWNER JUDGED TOO TIGHT AT
THE CONTROLS** — *"currently i have to stand right next to the pray."* That version
had **one** anchor: it held the arc at a constant length of ground, so the ring
radius fell out of `HALFWIDTH × RANGE-MAX / 180` and could not be moved without
moving the far arc with it. It has **two** now — the far half-width and the ring
radius — and the exponent between them is computed to pass through both, so **no
third number exists to disagree with the first two**. `TUN-COMPASS-CONE-HALFWIDTH`
did not move.

**20.0 m IS DERIVED AND NOT CHOSEN: IT IS `TUN-COMPASS-LOCK-RANGE`.** **Invariant
33 is that equality**, amended twice on the day it was added, and it keeps its kill
clause as well: the second is implied by the first at the shipped ranges and is the
clause that would fire if either band widened.

**AND THE CURVE IS THE PULSE CURVE'S SHAPE, WHICH NOTHING ASKED FOR AND IS THE
POINT.** It opens **12.4 degrees over the first fifteen metres of the approach and
134.7 over the last** — GDD-03 §8.2's *"long, flat approach followed by a sudden
sense of imminence"*, said a second time in a second channel. **A straight line
between the two anchors passes every other test in the file** and would be 96
degrees at 40 m, deleting the directional reading over most of a hunt;
`test_the_approach_is_flat_and_the_arrival_is_steep` is what refuses it.

**NO SOURCE GIVES THE REFERENCE'S RADIUS IN METRES**, and that is said rather than
papered over. What the sources give is the *semantics* — a complete circle means the
target is **within range**, i.e. close enough to engage rather than touching — which
is what rules 4.0 m out and leaves the number to our own geometry.

**IT IS THE REFERENCE'S OWN BEHAVIOUR, WHICH IS WHERE THE SHAPE CAME FROM.** Its
compass arc expands as the target nears and fills the whole ring when they are
nearly on top of you — sourced before acting, per the standing rule, rather than
recalled. The owner asked for it in the same message as the pointing defect.

**AND A FALSIFICATION RUN THREW AWAY THREE FILES' WORTH OF WORK.** `git checkout --
<file>` to remove a planted defect reverts to **HEAD**, not to the pre-plant state,
so it deleted the whole change to `compass_math.gd`, `camera_arm.gd` and
`compass_widget.gd` — and the next test run read like the fix not working. **Copy
the file aside before planting**; the restore must come from the copy.

**`EventBus` HAD TWENTY SIGNALS AND ZERO EMITTERS UNTIL NOW.** It was declared at
M0, guarded ever since, and wired to nothing; `SIGNAL_AND_EVENT_BUS.md` said
throughout that the bridge *"belongs to the first presentation node that wants
it"*. `HudBridge` is that node. It emits **on change, never on arrival** — a
snapshot lands 30 times a second and a tier changes a handful of times a match —
and **the Compass is the deliberate exception**, because its bearing moves almost
every tick by construction.

**AND US-0073 IS EIGHT OF ELEVEN: THE TIER, THE PORTRAIT, THE CROSSHAIR AND THE
VIGNETTE.** A player can now see how visible they are and **why** — the source
list is the half that teaches — whether a kill or a stun would land, and whether
they have identified their contract. **Two criteria are blocked on things that do
not exist**: ability slots need `SYS-ABILITY` (US-0066) and the timer needs
`SYS-MATCH` (US-0079, M6). The third is ASM-0030's, below.

**AND THEN SOMEBODY LOOKED AT IT, WHICH FOUND FOUR DEFECTS NO TEST HERE COULD.**
`tools/hud_probe.tscn` boots the real client and captures eight scripted states —
run it after any HUD change, windowed:

```bash
godot --path . res://tools/hud_probe.tscn
```

**THE TIER INDICATOR WAS COMPLETELY INVISIBLE.** The debug district map is on
layer **127**, the HUD on layer 1, and its opaque panel sat exactly on the tier
block. **The debug tool moved, not the HUD** — it is stripped from every release
preset and UI_UX_SPEC §1 owns the placement. Same call as
`DistrictMap.RESERVED_WIDTH`, one layer out.

**THE CONE READ AS A NEEDLE, WHICH §3.1 FORBIDS IN AS MANY WORDS.** It is only 24°
wide and the falloff was `across²`, putting four fifths of it under a quarter
alpha. `sqrt` now. **A needle drawn from a wobbled bearing communicates the
opposite of what the wobble means.**

**AND THE VIGNETTE TINTED THE WHOLE FRAME AND DREW AS A WIREFRAME.**
`Color(r, g, b)` defaults to **opaque**, so the alpha that is the entire tuning
shipped at 1.0 by omission — trap 17's family, in a colour rather than a `.tres`.
And `draw_rect(..., false, width)` strokes a line per band, so a "vignette" read
as nested rectangles. Four per-edge gradients at 0.5 alpha now, and `REACH` 0.22 →
0.18 because two edges at 0.22 leave only 56 % clear against §1's *centre 60 %*.

**AND THE PROBE'S FIRST READING WAS WRONG, WHICH IS WORTH MORE THAN THREE OF THE
FOUR.** It captured the cone pointing **down** for a bearing of zero, which reads
exactly like a widget inverted by π. **The widget was right**: the cone is
camera-relative and the scene's rig has its own yaw. The probe unhooks the camera
before its two cone diagnostics now. **An instrument that is wrong in a plausible
direction is worse than no instrument.**

**THE CROSSHAIR CANNOT LIE BECAUSE IT CANNOT COMPUTE.** It holds two server
booleans and is guarded against naming a distance, a range, a position or
`KillRules`. GDD-02 §9's failure mode 7 is *"kill feels unresponsive"*, and the
shape it takes is a player pressing a button the HUD promised would work.

**THE PORTRAIT SHOWS THAT YOU KNOW, NOT WHO, AND THAT IS ASM-0030 RATHER THAN A
STUB.** The persona is not on the wire and must not be — a client learns its
contract's appearance by *looking*, which is what the 1.6 s lock is charging for.
The honest source is the mesh the client already draws (US-0046's `PersonaBody`),
and it needs the lock to name a slot.

**`Palette` DID NOT EXIST AND NEITHER DID `test_no_colour_literals.gd`.**
UI_UX_SPEC §7 has claimed both since M0 — trap 14 in a bible section — which is
why the Compass shipped four colour literals a day earlier. Both exist now, the
Compass is retrofitted, and **the guard caught this story's own vignette on its
first run**. Only the `DEFAULT` palette is authored; the three colourblind
variants are US-0083's at M6, and they are a *data* question because this seam
now exists.

**AND AN ARCH GUARD FORBADE THE HUD FROM NAMING A TIER.**
`test_suspicion_is_never_predicted.gd` banned any `SuspicionMath.` in client code,
and the tier indicator has to name `Tier.EXPOSED` to compare against a tier the
server sent. **Neither that nor `SuspicionSources.SPRINT` is arithmetic; both are
vocabulary** — and the distinction is the guard's own, since its note on writes
already reads *"a client may read what the snapshot gave it"*. It now tests the
**case of the first character after the dot**: functions are `snake_case` and
constants are not, and `gdlint` holds that in CI, so `evaluate_tier(` is still
caught and `Tier.EXPOSED` is not. **Second guard narrowed this way in two days**,
both by the first client that ever needed to *read* gameplay state.

**THE M4 GATE WAS RUN AS WRITTEN, AND ONE OF ITS TEN CRITERIA WAS MET.** Six
could not be run at M4 **by construction**: a playtest needs a match
(`SYS-MATCH`, US-0079, **M6**), a lobby (US-0078, M6), a HUD (US-0072/0073, M5)
and a score (US-0064/0074, M5), and M4's own story list contains none of them.
ROADMAP's M4 row read *"the game is playable end-to-end"* and was never true of
that list. **The gate did not fail — it was unrunnable when it was written**, and
nobody had checked, because a gate is the one story only read at the end.

**ADR-0016 SPLIT IT.** US-0063 is the M4 technical exit and is **done**; the human
playtest is **US-0098, at M6**. **Running it now was rejected as worse than not
running it**: Q7 — *"did you understand why you died"* — would score near zero
against a build that does not tell a player they died, and a number that low gets
quoted later as a legibility failure of a design that has no legibility layer yet.
The tag `m4-the-loop` is **not pushed**; it is the owner's and should follow the
split.

**`test_the_m4_loop_resolves.gd` IS THE FIRST TEST EVER TO RUN M4'S SYSTEMS
TOGETHER.** Every one of them was proven against its own fixture and
`test_the_loop_closes.gd` is M2's — it proves the *transport*. This drives one
contract from a press to a respawn through the real `MatchDirector` with the crowd
live, and asserts the ordering rather than any system's return value.

**AND IT FOUND THAT `PawnStateId.DEAD` IS NEVER OBSERVABLE FROM OUTSIDE A TICK.**
GDD-02 §3.1 gives `Respawning` the entry *"death resolved"* and the exit
*"`TUN-RESPAWN-DELAY` 5.0 s"*, and §3's diagram draws `Dead --> Respawning: corpse
spawned` — the corpse spawns **at** the contact frame, so `SYS-KILL` sets `Dead` at
`combat` and `SYS-SPAWN` moves it on at `contract`, one stage later, in the same
tick. **The code is correct and my first version of the test was wrong**, reading
`Respawning` where it expected `Dead` and looking exactly like a rule that does not
work. It asks `CombatTargets.is_dead` now. **Anything client-side that keys a death
screen on `Dead` will never fire** — know this before US-0073.

**THE SERVER TICK WITH ALL FIFTEEN SYSTEMS LIVE: 2.16 ms MEAN, 2.27 p95, 2.6-2.9
p99, AGAINST A BUDGET OF 8.0.** Reproducible over three runs (2.151/2.171/2.175).
**27 % of budget.** One run reported a 6.000 ms max against 3.056 and 2.722 after
it — recorded as an outlier rather than explained.

**AND 28 OF 29 DOCUMENTED TELEMETRY EVENTS HAVE NO EMITTER.** GDD-07 §8 is a
29-event catalogue and exactly one call reaches `TelemetrySink.append`.
`test_telemetry_catalogue.gd` is that count and **it did not exist** — the M4
gate's `test_crowd_bandwidth.gd`. So **THE TURN is unmeasured rather than absent**
and the gate is evidence for neither. `TelemetrySink`'s own docstring warned in
M0: *"a sink that appears late is a sink whose call sites were never written."*

**AND `--record` IS PARSED INTO `LaunchConfig.record_path` AND READ BY NOTHING**,
while `playtests/README.md` tells a facilitator to attach the export it produces.
**AND `US-0084` WAS CITED AS "THE HUD" IN TWELVE PLACES** — it is *Accessibility*,
**M6**; the HUD is US-0072/0073/0074, **M5**. Both corrected. **AND THE 180 s
INTEGRATION BUDGET IS ASSERTED IN THREE DOCUMENTS AND ENFORCED NOWHERE** — the
suite is at **183.5 s** now. Four drift findings in one afternoon, which is why
`RISK-AGENT-DRIFT` is the highest-frequency risk in the register.

**`RISK-NOT-FUN-SOLO` IS FIRST MEASURABLE AT M6, TWO MILESTONES LATER THAN
PLANNED.** Probability and impact unchanged — no new evidence about fun either way
— and a risk found two milestones late is a worse risk at the same score.

---

## M5'S ABILITY CHAIN IS BLOCKED THREE WAYS, AND US-0097 IS WHAT IS LEFT

**CHECKED 2026-08-29, BEFORE WRITING ANY CODE, AND IT CHANGED WHAT M5 LOOKS LIKE.**

- **US-0070 (Lunge) IS DONE, 2026-09-02.** Six of six. The dash got its own state
  (`Lunging`, wire index 15) because 6 m of unpredicted movement is 6 m of rubber-band —
  the question ADR-0017 delegated, answered. It also closed **US-0061's ninth
  criterion**, open since M4.
- **US-0071 (passives and loadout) IS HALF BLOCKED.** Four of its six criteria are
  the three passives and are buildable; the other two are *"loadouts lock at
  countdown"* and *"the lobby buffer is cleared"*, which need `SYS-MATCH` (US-0079)
  and the lobby (US-0078) — both **M6**. Its own `depends_on` also puts US-0070
  first.
- **US-0075 (audio) HAS NOTHING TO PLAY.** `assets/audio/` holds four empty
  directories and **there is not one sound file in the repository**. A dispatcher
  would be real, testable and silent, and the four criteria across US-0023,
  US-0046 and US-0059 that wait on `Audio.play()` would stay blocked, because they
  wait on *sounds*. Assets need a licence row (never-do #11) and are the owner's.
- **US-0069 (Second Face) SWAPS AN IDENTITY NO CLIENT DRAWS.** No NPC wears a
  persona — `CrowdRoster` derives identity from `match_seed` and no client is told
  it — so the effect would be invisible in the same way Cinderfall's cloud is.

**SO US-0097 WAS THE ONE UNBLOCKED M5 STORY THAT ADDS A MECHANIC**, and it is now
**done**. It was also the largest thing ADR-0013's audit found missing: a hunt that
can be **survived**.

**THAT DECISION IS TAKEN: ADR-0017 ADDED THE STATE ON 2026-09-01**, and it was the
single highest-value unblock — it releases **US-0070 (Lunge)**, which releases
**US-0071's `depends_on`** and its four buildable criteria, and it closes the three
staggers that had no state to live in since M4. **US-0070 was the buildable M5 story
and it is DONE, 2026-09-02** — the dash got its own state, which is the design question
that paragraph left open, answered.

**WHAT STILL SITS BEHIND SOMETHING ELSE**: US-0071's three passives are buildable now and
its other two criteria need M6's lobby and countdown; US-0075 has no sound file in the
repository at all; US-0069 swaps an identity no client draws; and US-0077's results screen
needs a match to end — **which is no longer a blocker: decision 1 was settled on 2026-09-08 and `SYS-MATCH` is M5.**

## US-0097 IS DONE. WHAT FOLLOWS IS THE RULE ITSELF, BUILT AT #184 AND #185

**Be careless within `TUN-COMPASS-WARN-RADIUS` of your prey and you open a chase.**
Sight refreshes it, absence drains it, and after `TUN-PURSUIT-DURATION` **10.72 s**
without seeing them the hunter **loses the contract** and is reinserted elsewhere.
The prey is paid `SCORE-ESCAPE` +100, and +50 more if the hunter was still within
5 m at the last sighting.

**IT IS DESIGN LAW 5's SECOND TOOTH, AND THE ONE THAT FITS THE THESIS.** ADR-0013
took away the stun's ability to interrupt a committed kill, leaving "the prey must
have teeth" carried by one mechanic. An escape is **won by restraint rather than
by a button** — and `TUN-PURSUIT-DURATION` is derived so that escaping never
requires running.

**REFRESH, NOT INCREMENT, AND THE DUTY CYCLE IS THE ONLY THING THAT PROVES IT.**
The obvious test — *a chase ends after 10.72 s of no sight* — passes against a
refreshing bar, an incrementing bar **and** a bar that never refreshes at all. What
separates them: a hunter looking once per `window - 1` holds a chase open over ten
cycles, one looking once per `window` loses it every time.

**AND OPENING A CHASE IS NOT REFRESHING ONE.** Collapsing the two would mean *near
and careless* holds a chase open — so a hunter standing beside their prey facing
the wrong way would never lose them. `_open_a_chase` is the condition;
`PursuitTracker.advance` is the sight.

**THE ANTI-REPEAT HISTORY RECORDS WHAT WAS *DEALT*, NOT WHAT WAS *HELD*.** US-0097
says `_choose_index`'s `killer` constraint generalises — **it does not**: that one
forbids a *predecessor* and an escape must forbid a *successor*. The right
mechanism is `_held_recently`, and **that alone still was not enough**:
`_remember` is called from `insert` and `open` only, so a contract held through a
chase is invisible to it. Measured — over six escapes in one fixture **one player
was re-handed their escapee**. `report_escape` calls `cycle.remember` first now.

**THE SAME GAP EXISTS FOR AN INHERITED CONTRACT AND IS REPORTED RATHER THAN
CLOSED.** A killer inherits their victim's contract without `_remember`, so
`TUN-CONTRACT-ANTI-REPEAT-DEPTH` does not protect a later respawn from re-handing
it. That changes what a *kill* does, which is US-0049's fuzzed territory.

**THE RAYCAST HAD TO MOVE, AND US-0097'S OWN CRITERION CONTRADICTS ITS OWN
TUNABLES.** The story asks for *no raycast the Compass lock has not already
spent*, and specifies a **90°** pursuit cone against the lock's **25°** — a cast
gated on the lock leaves the chase blind through most of its own cone. What is
true and asserted: **one query site, at most one cast per hunter per tick**. The
per-tick count rises. The measurement is owed.

**THE FUZZ GENERATES 597 ESCAPES OVER 10 000 EVENTS**, and its coverage guard
**fired on its first run at zero** because the counter was never initialised —
which is exactly the failure the story predicted the guard would catch.

**AND `SCORE-CLOSECALL` IS MEASURED AT THE LAST SIGHTING, NOT AT THE EMPTY BAR.**
By definition the hunter has not seen their prey for the whole window, so the
distance when it empties is one nobody observed.

**NOTHING IS LEFT: THE BAR SHIPPED AT #186** — as `hunt_fraction` and
`hunted_fraction`, two bytes rather than one, for the reason at the top of this
file. Both parties already *perceived* an escape through channels that existed;
what the field added is the anticipatory half.

## FIVE THINGS WAIT ON THE OWNER, AND NONE BLOCKS M5

*Eight rows, five live. Struck through rather than deleted, because a list with a vanished row
invites somebody to re-open it: decision 1 was settled on 2026-09-08 (`SYS-MATCH` moved to M5),
decision 8 on 2026-09-03, and decision 3 by ADR-0017 on 2026-09-01 — which raised decision 7 in
its place. **A new open decision arrived with decision 1's answer**: whether US-0098 can run on
the direct-IP launch rather than waiting for the lobby. It is not listed as a ninth row yet
because it is the same question decision 1 half-answered, and splitting it would double-count.*

1. ~~**Move `SYS-MATCH` (US-0079) M6 → M5?**~~ **SETTLED 2026-09-08: moved.** The
   stated dependency on the lobby was re-examined rather than assumed, criterion by
   criterion, and does not hold: US-0079 needs tick arithmetic, `Net.player_count()`,
   the already-built `ScoreEvent` multiplier and the already-M5 results screen. The
   one real coupling is the COUNTDOWN **trigger**, which a minimum-player rule
   satisfies and the lobby later *replaces* rather than enables. **US-0098 did not
   move with it** — the M4 gate named four blockers and the lobby is still M6, so a
   match becomes playable at M5 while the formal playtest stays put. Whether it can
   run on the direct-IP launch instead is a **separate open decision.** Struck
   through rather than deleted, because a list with a vanished row invites somebody
   to re-open it.
2. **The 180 s integration budget**: enforce it or raise it. It is at 183.5 s.
3. ~~**A sixteenth pawn state for the three staggers.**~~ **SETTLED 2026-09-01 by
   ADR-0017** — `Staggered` is the fifteenth state (the count was fifteen at M0,
   fourteen after the `Jog` rung was deprecated, and is fifteen again). Struck through
   rather than deleted, because a decision list with a silently vanished row invites
   somebody to re-open it. **Replaced by decision 7 below**, which the same ADR raised.
4. **`NET-S2C-PLAYER-JOINED`'s persona field.** Joined with
   `NET-S2C-CONTRACT-ASSIGNED` a client can read its contract's persona with no
   lock, defeating ASM-0030. Neither message is implemented, so nothing leaks
   today.
5. **The tag `m4-the-loop`.**
9. ~~**SHOULD A LUNGE INTO YOUR PURSUER STUN THEM?**~~ **SETTLED 2026-09-03 by
   ADR-0018: yes**, and design law 5 was revamped with it. The reference resolves the
   dash against whoever it connects with; ours did nothing to a pursuer, so the
   defensive half was missing. `TUN-SCORE-STUN` also went **100 → 200**, the
   reference's own number, and invariant 19 from `==` to `>`.

7. **`TUN-KILL-CONTEST-STAGGER` MODELS A MECHANIC THE REFERENCE TITLE DOES NOT
   HAVE.** Raised by ADR-0017's fidelity check: the contested kill and its bonus are
   the **sequel's**, not the reference's, where the loser is *"dazed for a short
   while"*. Under ADR-0013 the reference wins where a rule here diverges — but this is
   a merged `TUN-` ID **and** a merged rule (`KillContest`), and nothing in ADR-0017
   depends on it. **Reported rather than acted on.** My recommendation is to keep it:
   it is a good rule, the divergence is a *feature the reference lacks* rather than one
   it contradicts, and removing it would delete a mechanic for fidelity's own sake.
8. ~~**SHOULD THE LUNGE AUTO-KILL BE JUDGED OVER THE DASH RATHER THAN AT ITS END?**~~ **SETTLED 2026-09-03: yes, over the corridor** (`KillRules.resolve_swept`), and neither candidate below was the reason. Sweeping the *angle* rather than the distance found the real defect — **two degrees of aim tolerance at a 6 m approach**, because a cone is an angle and the ground it covers shrinks to nothing as you close. The corridor closes the overshoot as a side effect, so **the lateral steering was not needed** and GDD-04 §3.4's *unsteerable* clause stands. Struck through rather than deleted; the original reasoning follows, and the two divergences it raised are still live.
   Raised 2026-09-02 by *"the autokill on lunge does not work"*. GDD-04 §3.4 and
   `TUN-LUNGE-AUTO-KILL` both say the kill fires if the dash **ends** in range and
   cone, and the dash is a fixed 5.85 m — so lunging from under ~5.5 m passes
   through the contract and refuses `OUT_OF_CONE` at a measured 1.85 m gap, inside
   a 2.85 m reach. **The usable band is ~5.5-8.7 m** and nothing on screen says so.
   **MY RECOMMENDATION CHANGED ON 2026-09-03, AND WHAT CHANGED IT IS THE
   REFERENCE.** I first recommended judging the arrival at the closest approach
   along the dash — *you dashed through them* — which is server-side only and
   invents a rule. **Asked whether this ability exists in the reference at all, I
   sourced it instead of recalling it, and it does: the reference's equivalent of
   `ABIL-LUNGE` keeps a small amount of lateral control through the dash.** That is
   almost certainly the mechanism that makes it usable at close range there, and it
   is the same failure measured here at 4.0 m. Under ADR-0013 the reference wins
   where a rule here diverges.

   **So the recommendation is now: give the dash a little lateral steering**, and
   it is the *cheaper* of the two as well as the faithful one. Steering lives in
   `LungingState`, is deterministic, stays inside `scripts/pawn/`, and is predicted
   by the client exactly as the rest of the dash already is — where a swept
   judgement is server-only rule work that no document anywhere describes.

   **THE COST IS REAL AND IT IS THE OWNER'S TO PAY.** GDD-04 §3.4 prices the
   counterplay as *"0.92 s of telegraphed, **unsteerable** approach against a 0.7 s
   stun"*, so steering trades away part of the prey's read. **It is not never-do
   #13**, which forbids weakening *stun*: a steered dash is stunnable for its whole
   wind-up and dash exactly as an unsteerable one is. It is a design trade, which is
   why it is here rather than done.

   The alternatives are unchanged: leave it and teach the band through a HUD
   indicator, or the swept judgement above. **Ending the dash on arrival stays the
   wrong answer** — the dash is client-predicted, so stopping it early is up to
   2.85 m of rubber-band on the most decisive action in the game, which is the whole
   reason US-0070 gave it a state.

   **THE SAME CHECK FOUND TWO MORE DIVERGENCES, REPORTED RATHER THAN ACTED ON.**
   The reference's version resolves against **whoever it connects with** — a kill on
   your contract *and* a **stun on a pursuer** who is hunting you; one of its unlock
   challenges is stunning your pursuer with it. Ours does nothing at all if you
   arrive at your pursuer, so **half the ability is missing and it is the defensive
   half** — which is design law 5's own territory and, being a strengthening of the
   prey, is not forbidden by anything. It also bashes civilians it runs through,
   where ours passes through the crowd untouched apart from the startle wave.

   **AND WHAT NO SOURCE GIVES IS AS IMPORTANT AS WHAT THEY DO.** The distance, the
   speed, the cooldown, whether the caster can be stunned mid-dash and what a miss
   costs are **not sourceable** — so `TUN-LUNGE-DISTANCE` 6.0, `TUN-LUNGE-SPEED`
   9.0, `TUN-LUNGE-COOLDOWN` 30 s, `TUN-LUNGE-STUNNABLE` and
   `TUN-LUNGE-WHIFF-STAGGER` are **ours rather than fidelity**, and must not be
   defended as faithful. Same honest limit the Compass ring radius hit, and the
   reason that number came from somebody walking toward somebody instead.

   **THE SOURCES ARE DELIBERATELY NOT IN THIS REPOSITORY.** Every one of them names
   the franchise and `ip-guard` fails hard on that (never-do #5); §2.4 also makes
   the reference's own name for this ability a discouraged term whose replacement is
   **Lunge**. They live in the chat log and the owner's design notes, which is
   already where ADR-0013's full audit table lives for exactly this reason.

6. **Does a stun cancel an ability's wind-up?** US-0067 gave every cast a
   `TUN-<ABIL>-CAST-TIME`, and nothing interrupts one but death. GDD-04 §3.1 names
   the counter to Cinderfall as **patience**, not a stun, so adding one would
   change a documented counterplay — and never-do #13 only forbids *weakening*
   stun, so this is a real choice rather than a rule. `AbilitySystem._end_all` is
   where it would go.

---

## The state of the build

*What is true right now, in one screen. The narrative that explains **why** each of
these numbers is what it is lives above, for the recent work, and in
`docs/00_meta/history/` for everything before M5.*

| | |
|---|---|
| CI | 7 jobs. **Running again as of 2026-08-07 after a two-day outage** — run `31200490320`, all seven green. The seven commits merged during the outage were never through it, see trap 6. `.ci/run_gut.sh` fails if a suite runs fewer scripts than exist on disk |
| Tests | **57 arch + 196 unit + 33 integration scripts**, holding 224 + 1675 + 243 tests and 1 278 + 29 789 + 679 assertions (unit and arch remeasured 2026-09-08 after rebasing #214 onto #215: 196 unit scripts, 1675 tests and 29789 assertions; 57 arch scripts, 224 tests and 1278 assertions; the frozen-byte compatibility tests pass alongside MatchClock and the ScoreEvent delegation. The earlier baseline carried BOTH #211 and #212 — neither PR's own row was right after the other landed, and `test_claude_md_counts_are_current.gd` is what said so; integration counts retained from 2026-09-05; the new unit script is `test_match_clock.gd`, whose last assertion is the one that matters: it sweeps twenty profiles to prove the tick `MatchClock` opens `FINAL` at is the tick `ScoreEvent` pays double from — two independent derivations of one instant until 2026-09-08, which agree until either moves. The one before it is `test_pawn_navigation.gd`, which pins the pawn capsule and step height to exact navmesh cell multiples so Recast's ceiling quantisation cannot change the agent in silence. The new arch script is `test_claude_md_stays_findable.gd`, which caps this file at 4 000 lines and refuses an archived document it does not link — the file was 6 594 lines with the traps and the local environment filed under 3 301 lines of history. The one before it is `test_agent_entry_points_are_pointers.gd`, which resolves the target of every agent entry point rather than only capping its length — a short file can still name a document that does not exist, and `AGENTS.md` did exactly that. The one before it is `test_a_script_tool_gets_no_autoloads.gd`, which walks the class closure of every `-s` tool and refuses one that reaches a class calling the `Tuning` autoload — it found `input_probe.gd` unloadable, which reasoning had not. The one before it is `test_the_ability_writer_holds_no_tunables.gd`, which refuses a `TUN-`-backed field in the `.tres` writer's hand-written table. The two unit scripts before it are ADR-0019's — `test_the_stun_costs_the_contract.gd` and `test_match_consequences.gd`, which are the rule and the hop respectively. **The integration suite read 184.2 s against 183.8 s before this change**, so the wiring assertion added to `test_the_m4_loop_resolves.gd` costs about 0.4 s — it raises the signal rather than earning a stun, and deliberately does not settle through `TUN-CONTRACT-REASSIGN-DELAY`, which the first version did for **+3.8 s**) — the assertion count tripled at US-0049, because `test_contract_cycle_fuzz.gd` checks the invariant after every one of 10 000 events. **Nine are `pending` by design** — **eight in the unit suite and one in the integration suite**, which reports that an NPC aimed into the void never gives up. The island `pending` beside it **turned green by itself** when the alley mouths were built, which is what a `pending` naming its own blocker is for. The three numbers this row used to call assertions were **test** counts — corrected at US-0041 by reading both off the runner. The integration suite measured **183.8 s** on 2026-09-02 and again on 2026-09-01, **174.6 s** twice on 2026-08-28 and **183.5 s** the day before that, with **no test removed** — **three readings within 0.1 s of each other now, so the 174.6 s pair is the outlier rather than the figure** — so the 9 s is machine variance and neither number should be quoted as *the* figure; what is real is that the suite sits within a few seconds of its limit either way. The 180 s it is 'allowed' is **enforced nowhere** — TEST_PLAN §3, TEST_PLAN §10 and TDD-12 §17 all assert it and no job checks it, which is the M4 gate's fourth drift finding. `test_the_m4_loop_resolves.gd` cost 13.1 s of that and is the first test ever to run M4's systems together. It was 162-172 s, up from 87.7 s at M2 — **under 9 s of headroom left, and the next integration test has to justify itself hard against that**. `test_server_tick_budget.gd` cost 9.8 s of it and is a gate line; the one before it, the 2 s pass A/B, samples ninety ticks **twice** — US-0044's three suites are deliberately *unit* tests for that reason: `test_crowd_moves.gd` walks a crowd for sixty net ticks eight times over, and physics frames run in real time even headless. **The six are**: `test_upstream_bandwidth.gd` reporting the 145 % upstream miss, `test_crowd_bandwidth.gd` the 112 % downstream projection, `test_crowd_wire_cost.gd` the 112 % it actually costs, **`test_spawn_points.gd` twice — GDD-05 §2.7 rule 6's nine unoccluded spawn pairs and rule 8's S3 4, S4 1, S5 6 of 8 seats** — and `test_clone_animation_parity.gd` the missing clip library. **Two entries this row carried are gone because their findings closed**: `test_circuit_separation.gd`'s 0.51 m circuits (re-authored, now 21.20 m) and `test_cull_radius_price.gd`'s flat curve, which asserts rather than pends. Each reports a finding the code cannot fix rather than going red, the same choice `test_snapshot_size.gd` made. A `pending` that turns green by itself the day its blocker is authored is the point. The *script* counts are guarded by `test_claude_md_counts_are_current.gd`; the assertion counts are a snapshot and are not. This line read `119 + 515 + 132` for **twelve PRs** — every update to it was an unasserted `str.replace` that silently matched nothing. See trap 15 |
| Tuning | **296** tunables across 14 resource classes; all **37** cross-field invariants assert. **Six were added on 2026-08-29 for US-0097's escape verb** — four `TUN-PURSUIT-*` on `ContractTuning` (a pursuit ends by removing and reinserting a contract, so §7 is its section and no new resource was needed) and `TUN-SCORE-ESCAPE`/`-CLOSECALL` on `ScoringTuning`. **Invariant 34 fired on its first run against the story's own proposed value**: `TUN-PURSUIT-DURATION` is `warn_radius / blend_walk` = 10.7143, US-0097 wrote **10.7**, and that asks the prey for 1.402 m/s — fractionally faster than a blend walk, in exactly the direction the invariant forbids. Shipped at **10.72**, with the tolerance tightened to a true floor rather than widened to admit it. **A rounded derivation is not a derivation.** **`TUN-COMPASS-CONE-FULL-RADIUS` 20.0 m was added on 2026-08-27** — where the Compass arc becomes a whole ring — and **invariant 33 is the reason it is not a chosen number**: it pins the radius equal to `TUN-COMPASS-LOCK-RANGE`, so the arc stops pointing exactly where the lock starts working, and separately outside the validated kill reach. It was **set three times in one day and only ever by somebody playing it** — 4.0 m derived from the half-width alone, 6.0 m at `TUN-SUSPICION-OPEN-RADIUS`, then 20.0 — and the second is the one worth remembering, because it was **derived and still wrong**. **`TUN-SCORE-HALFSEEN` +50 was added on 2026-08-27** by the fidelity re-audit — the stealth ladder had no middle rung, so a kill at **Noticed** and one at **Exposed** scored identically; invariant 32 keeps it strictly descending and strictly positive, and the `> 0` clause is the load-bearing half because every ordering check passes over a zero. `TuningInvariantsScore` was split out when that pushed the file past 400 lines — tech is how the game is *transmitted*, score is what it *pays*, and what is left is how it *plays*, with one entry point still. **Four scoring values were re-priced on 2026-08-26 (ADR-0013)** — `TUN-SCORE-SILENT` 100 → 200, `TUN-SCORE-PATIENT` 150 → 100, `TUN-SCORE-FOCUS` 100 → 150, `TUN-SCORE-RECKLESS` −50 → **0**, and invariant 18 rewritten from an ordering to a floor — split across `TuningInvariants` and `TuningInvariantsTech` since the first file hit 400 lines, with one entry point still. **Eight IDs are deprecated** and recorded in TUNABLES §19 — never reused |
| Autoloads | All eight. `Tuning` precomputes 89 durations into **two** tick tables — see trap 7 |
| Strings | `data/strings/en.csv`, 56 keys, no user-facing literal anywhere else |
| Boot | Branches on `--server`; 7 CLI flags parsed in pure Core; 5 export presets |
| Map | `MAP-VETRAIO` greybox, 120 × 120 m. Client loads 28 meshes, server loads none. **The street surface is exactly `STREET_Y`** — floors used to straddle their declared height, putting every walkable top 0.1 m high, which made the 0.9 m stalls unvaultable and three spawn points float over nothing. **Lit as of US-0091** — one key light and a sky, because nothing in the project had ever created either and the district rendered near-black. **The navmesh is baked at build time and committed** (US-0041): **255 polygons across 12 floors and 14 blocks**, with a derived `H_VAULT` parapet on every floor edge that borders a drop, and it sits **0.400 m above the street**, which is why steering applies gravity rather than trusting the snap |
| Pawn | **16 states declared** — fifteen at M0, fourteen when **the Jog rung was removed in US-0090** (`Jog` is a retired ID absent from `ALL`), fifteen again since **ADR-0017 added `Staggered`** on 2026-09-01 for the three `TUN-*-STAGGER` rules that had nowhere to live, and **sixteen since US-0070's `Lunging`** — the committed dash, which is a state because 6 m of unpredicted movement is 6 m of rubber-band. **`ALL`'s order is the WIRE and is append-only** — `Snapshot.state_index` indexes into it, `Staggered` holds index 14 and `Lunging` holds 15, and `test_pawn_state_count.gd` refuses an insertion before either. Transition edges asserted against the normative diagram. **All sixteen implemented**: five locomotion + `Vault`, `Climb`, `Drop`, `KillAnim`, `StunAnim`, `Stunned`, `Blended`, `Dead`, `Respawning`, `Staggered`, `Lunging`. **`Blended` is declared, registered and UNREACHABLE** — nothing in `scripts/` transitions into it, because the entry condition is server-only knowledge the client cannot predict; `SYS-BLEND` writes `blend_state` on the context instead. So ANIMATION_SPEC §5's `Loco --> Blended` node can never fire. **`Dead` has an exit at last.** **`Staggered` is interruptible where the other three combat states are not** — never-do #13, since a whiffed lunger would otherwise be in a stunnable locomotion state — and **it keeps the camera**, because taking it is `Stunned`'s signature. **Every living state can reach `Dead` as of 2026-09-02** — `Drop` and `StunAnim` could not until then, and `test_every_living_state_can_reach_dead` asserts the property rather than the two names, because the machine gained two states in two days |
| Traversal | **Complete.** Probes cast, all seven §7.2 cases resolve from real geometry, both forgiveness windows open, and vault, mantle, climb, drop and gap jump all perform. **Case 7 hops as of US-0093** — an impulse, not a state, scaled by the speed rung and adding nothing horizontal. **The action buffer arms on the PRESS, not the hold** — arming from the held bit spent a traverse every frame a finger stayed down |
| Crowd | 90 bodies pre-allocated, 78 active, each with a brain and a `CrowdContext` allocated beside it. One `SpatialHash` on `MatchContext`, rebuilt at the **top** of the crowd stage so the brains and every downstream system read the same grid — 0.0561 ms, allocating nothing. `CrowdDirector` ticks them at the `crowd` stage and translates the five flags `NpcBrain.step()` deliberately does not read into `handle()` calls; `Steering` moves the bodies from the **avoidance callback**, on the physics frame, and knows nothing about states — it takes a point and a speed. Repath is FIFO and capped at three a tick. **Four processions of four walk the map's circuits** (US-0043), each with a fifth slot no NPC may take, at a pace throttled by its worst straggler. **Banded by distance** as of US-0045 — 20/45/70 m, strides 1/3/15, staggered by index — and `CrowdBands` also scales each agent's `path_max_distance` by its band's stride (US-0041's last line), which is the one path query `RepathQueue` does not stagger. **All five states are reachable** as of US-0044: a sprinting player startles the crowd once a second, a wave propagates one hop at 0.4, and a corpse gathers six onlookers who walk to it and disperse before it fades. Violence has an entry point and no caller until M4. **On the wire as of US-0030/US-0031**: `SnapshotBuilder._fill_crowd` sends each observer the NPCs within `TUN-NET-NPC-CULL-RADIUS`, positionally and never visually, at `TUN-NET-NPC-RATE-LOD-HZ` beyond `TUN-NET-NPC-RATE-LOD-RADIUS` and staggered by `(tick + index) % stride`, delta-encoded per NPC against the client's **ack**. **Drawn on a client** as of US-0045 by `NpcView`, which culls at the same radius one margin wider, treats absence as "no update" rather than "gone", and dresses nobody. **Departure is a value, not silence** — one out-of-range record — and `CrowdWire.is_farewell()` holds that rule for both `NpcView` and `SnapshotAssembler`, which must agree on it: when only the view knew it, the assembler carried one goodbye forward into every later snapshot and the view created and freed a body from it once per tick. **Clone-parity layer 4 hangs off the same 2 s pass as the formations** (US-0047): `CloneBalance` holds the clones already near a player and fetches one when a persona is short, always to a map anchor and never at the player. **The floor is decided on clones that have ARRIVED**: crediting one still walking satisfied the minimum in expectation while the player was short in fact for the eighteen seconds of the journey |
| Blend | `SYS-BLEND` is a pure `RefCounted` the suspicion system owns and resolves at **step 1 of its pass** — not a stage, because `MatchDirector` permits one system per stage and both TDD-07 §1's diagram and TDD-01 §4.1's rationale already file blend-pocket validity under stage 4. **All four kinds are built** — pocket and group at US-0053, the two prop blends at US-0054.
The **twelve lean spots are derived from the six market stalls** rather than hand-listed, and
`is_standable` was the wrong question to ask of one: it erodes a stall by the agent radius, so
`Rect2.has_point`'s inclusive minimum face rejected every stall's north side and accepted every
south side — 6 of 12, split by a convention. **The most specific thing you are standing at
wins**: five hiding spots, then twelve lean spots, then a formation, then any four NPCs.
`PropOccupancy` holds capacity 1 and a per-(player, prop) re-entry window, and a refusal reaches
`NET-S2C-BLEND-DENIED` — **the one refusal in this game that reports its reason**, because a
prop's occupancy is level geometry rather than a fact about a stranger. The concealment prop is
the **one exception to "blend protects anonymity, never the body"**, and GDD-03 §4.1.4 is where
it comes from: its occupant leaves `present_slots` entirely and both combat systems answer
`TARGET_CONCEALED` at no cost to the presser. A blend is a **condition re-validated every tick**, never a state you keep: `TUN-BLEND-POCKET-MIN-NPC` within `TUN-BLEND-POCKET-RADIUS` asked of this tick's `crowd_hash`, or a formation slot held within `TUN-BLEND-GROUP-SLOT-TOLERANCE`. Entry 0.35 s and exit 0.30 s are phases the server owns; the wire carries the **kind** only, `blend_state:u4`, five values with `NONE` at zero. **The crush runs in `HELD` alone** — entry is visibly transitioning and exit is standing up, and neither buys anonymity. A **break is not an exit**: it lands the tick the condition lapses, with no 0.30 s. `report_damage()` breaks rather than absorbs, and has no caller until `SYS-KILL`. **The slot walks and the player keeps up** — nothing here moves a pawn, because the server does not own a predicted position |
| Kill | `SYS-KILL` ticks at the `combat` stage, **before `contract`**, so the cycle is repaired in the tick a death resolves. The decisions are pure and separable — `KillRules` (target, range, cone), `KillContest` (who was first), `RewindClamp` (how far back) — and the system holds the sequencing and the consequences. **Range is 3D and the cone is horizontal**: a horizontal reach would put the roof stratum inside kill range of the street. It reads the **announced** contract, so a press during the reassign breath is a rejection rather than a free kill. **Contact frames resolve before new presses**, or a victim dying this tick could still be claimed. **A press is edge-detected in this system's own map**, never from `PawnContext.held_buttons`, which `step()` rewrites at 60 Hz. Consequences leave through `killed`, wired in `server_root`: contract repair, blend break, corpse, startle, witnesses, `NET-S2C-KILL-RESULT` to the two involved. **A rejection is answered with a victim slot of zero** — silence is the worst answer a kill can give |
| Stun | `SYS-STUN` is **not a `GameSystem`** — TDD-01 §4's box 7 is one node reading "Kill / Stun", so `KillSystem` owns it and ticks it, `SuspicionSystem`/`BlendSystem`'s shape. **The kill is judged first within the tick**, which is where ADR-0013's contested initiation is decided rather than in a comment. Target is the stunner's own pursuer by reverse lookup on the **announced** contracts. `StunRules` is pure geometry and reads **one yaw**, the stunner's; it shares `TUN-KILL-VALIDATION-GRACE` with the kill, so the two reaches shift together. A stun at a hunter already in `KillAnim` is `TARGET_COMMITTED` and **costs nothing**. **Every other refusal costs the same and looks the same**, because a refusal that reported its reason would be a free identity probe. `stun_ready` carries the tier gate for that same reason |
| Spawn | `SYS-SPAWN` is **not a `GameSystem`** — TDD-01 §4's diagram has no spawn box and stage 8 is *"repair cycle after deaths"*, so `ContractSystem` owns it and **ticks it first**: the placement and the cycle insertion land in one tick. `SpawnRules` is pure — 40 m from the killer, 12 m from **every** living player, and a fallback that draws nothing at all because it runs at the worst moment in a match. **The point is chosen when the timer expires**, never at the contact frame. `TUN-RESPAWN-INVULN` is a third `CombatLockouts` shape: it shields a *target* where the stagger and the exile restrain an *initiator*, and both combat systems answer `TARGET_PROTECTED` at **no cost to the presser**. **Both respawn edges are completions rather than interruptions** — trap 8 |
| Kill commits | **`KillAnimState.is_interruptible` returns false** (ADR-0013). A stun landing after the hunter has pressed kill saves nobody; the prey's counterplay is the approach, where a revealed hunter is stunnable from 3.0 m and cannot strike until 2.5. **FATAL still gets through** — a third party killing the killer — because `transition` compares priorities, which is the asymmetry `test_the_kill_commits.gd` asserts both halves of. `KillSystem.report_interrupt` is **deleted rather than left as a no-op**: a cancel entry point that silently does nothing is worse than none |
| Compass lock | `CompassLock` is pure and holds the arc, the reveal window, the cooldown and the portrait; `SYS-DETECTION` supplies the yes-or-no its conditions come to. **`has_los()`'s first and only caller**, last in the early-out ladder — a hunter facing away spends zero raycasts, one watching spends one, against TDD-07 §4.3's budget of 2-6. The cone is gated on the hunter's **own yaw**, never the wobbled bearing. **The arc is not reset on completion**: a held view keeps a full arc and `TUN-COMPASS-REVEAL-COOLDOWN` is what stops chain-locking. **It resets on reassignment, tracked separately from the portrait** — inferring one from the other let a half-filled arc cross to the next contract. `NOBODY` is not a reassignment, or the breath would destroy an earned portrait. `PASV-COLDREAD` is an argument with no reader until a loadout exists |
| Compass | **The cone points at the contract and widens as you close** (2026-08-27), to a whole ring at `TUN-COMPASS-CONE-FULL-RADIUS` 20.0 m — which is `TUN-COMPASS-LOCK-RANGE`, invariant 33, rather than a number anybody chose: outside it the instrument points, inside it you look. Two conversions stand between a world bearing and a pixel and **neither existed**: `CameraArm.yaw_from_camera` (this game's yaw 0 faces +Z, a Godot node's faces −Z) and `CompassWidget.screen_angle` (this game's yaw increases to the left, a screen angle increases clockwise). They partly cancelled, so the shoulders drew correctly and ahead drew behind. `CompassMath.cone_halfwidth_for` holds the arc at a constant **length of ground** rather than a constant angle — a whole ring at 4.0 m, invariant 33 — and the widget's edge falloff flattens as it opens. **The server half lives in `SYS-DETECTION`**, at steps 9-10 of its pass, because the Compass is about the observer's *contract* — the same relationship the render state is computed from — and TDD-07 §1's diagram draws it there. `CompassMath` is pure Core: `period_for()` reproduces TUNABLES §4.2's twelve rows to **0.40 ms**, and the reciprocal exponent makes the rate **58x steeper close in than far out**. One reading per hunter into `ctx.compass`: a **world** bearing with `TUN-COMPASS-CONE-WOBBLE`'s drift already applied server-side, and a `Quantise.BUCKET_STEP` 0.5 m distance bucket, so nothing downstream holds the exact metres. The wobble is a sine of `(contract, tick)` — deterministic and learnable, never RNG — with its phase **mixed**, or adjacent peer ids would drift in step. **A missing reading is `NO_CONTRACT` 255, never bucket 0**, which is a real reading. `lock_fraction` and `portrait_revealed` are US-0058's and read zero; nothing draws any of it |
| Detection | `SYS-DETECTION` ticks at the `detection` stage, **after `suspicion`**, because the render state is computed from *tier* and a tick of lag makes the silhouette disagree with the tier indicator. One pass over 30 ordered pairs, **costing zero raycasts**: GDD-03 §2.1's rule is `tier × relationship` and §2.3 draws the Exposed outline through geometry, so occlusion must not gate it. The early-out ladder drops ~70 % of pairs on the tier check alone. It reads the **announced** contract from `ctx.announced_contracts`, never the graph's, so a tint cannot arrive before the Compass does. `RenderMatrix` carries the answer to `SnapshotBuilder` four stages later and **absent means `PLAIN`**, which is the safe direction. **It also holds the only line-of-sight query in the project** — `WORLD`-masked, so NPCs and players cannot block it by construction; Cinderfall is a sphere tested against the segment; the rewound form is **still refused**, and US-0060 sharpened the reason rather than clearing it — kill validation asks no line-of-sight question at all, so there is still no caller for a past one. **`has_los()` has two callers**: the Compass lock (US-0058) and the witnessed-kill check (US-0060). `cinderfall` is `MatchContext`'s list, adopted by reference, and every liveness query takes the tick it is asked about. **It also owns the prey warning** (US-0059): `_resolve_pair` already computes `hunted_by`, so the warning is a distance, a tier comparison and a cooldown lookup on pairs the ladder has already admitted — no second pass and no raycast. `PreyWarning` holds only the cooldown, and **a new pursuer defeats it**, or a repair would silence the prey's one warning for 2.5 s |
| Abilities | **`SYS-ABILITY` at the `abilities` stage, and one of the four now does something** (US-0066, US-0067). `AbilityRules` is pure — five validations answering with the first rung that fails, and an aim that is **clamped rather than refused** because the client's aim and the server's differ by a rounding error on every cast. Cooldowns are **integer tick deadlines started at ACTIVATION**, reset on death by `AbilitySystem.on_death` rather than by `PawnContext.reset_for_spawn`, which prediction replays. The tell is **the one broadcast in this game** — reliable, to everybody inside `TUN-<ABIL>-TELL-AUDIO-RADIUS`, and emitted **before** `effect.begin`. A denial **carries its reason**, unlike the stun's, because every reason is a fact about the presser's own kit. **A cast has a wind-up as of US-0067**: `LiveAbility` holds it *pending* until `TUN-<ABIL>-CAST-TIME` has passed and *live* afterwards, the duration runs from the burst rather than from the press, and a caster killed mid-throw drops nothing. `AbilityData.startle_radius` is raised by the **system** beside the suspicion cost, because Lunge carries one too, and leaves through `ability_startled` for `server_root` to wire. `effect_script` is set for **Cinderfall** and null for the other three — and it is **stripped from `TuningProfile.serialise`**, because `var_to_bytes_with_objects` would otherwise send a server-only `Script` to every client |
| Cinderfall | **`ABIL-CINDERFALL` IS THE FIRST ABILITY THAT CHANGES THE WORLD** (US-0067). `CinderfallEffect` is eleven lines and calls `CinderfallVolumes.add`, which had been built, tested and callerless since US-0056. The cloud **forbids kill initiation inside it including the caster's own** — GDD-04 §3.1's *"design detail that carries the ability"*, and without it the dominant play is *cloud, then kill inside it*. **`end()` deliberately does not remove the cloud**: `expire` lags the burn-out by `RewindClamp.max_ticks()` so a kill validated in the past still meets a cloud that was up when it was pressed, and clearing it here would delete exactly that window. **Nothing draws it** — there is no VFX pass, so on a client a Cinderfall is an absence of information |
| Score | **Thirteen bonuses, judged at initiation and paid at the contact frame** (US-0065). `ScoreBonuses` is pure — facts in, awards out — and `KillScoring` is the thin half that reads the world; `KillSystem` captures a `KillScoreFacts` at `_begin` and carries it on the pending row for 0.9 s, so a hunter keeps Silent through an animation they cannot cancel and cannot launder recklessness by standing still after it. **The suspicion ladder is a partition**: exactly one of Silent, Halfseen and Reckless fires, and Reckless fires at **zero** rather than not firing. `ScoreWindows` holds the four facts one tick cannot answer — the speed ring, the focus streak, the hunt clock and the vendetta debt — **on `MatchContext` rather than `PawnContext`, which TDD-10 §2.1 is amended for**, because a pawn is replayed by prediction. **Sampled upstream of the `combat` stage** by `SYS-SUSPICION` and `SYS-DETECTION`, which is why **`SYS-SCORE` is not a `GameSystem`** — the fourth such call for a fourth reason. Focus rides `can_lock` and costs **no raycast**, closing US-0056's last criterion. **Masked and Poisoned are dormant**: no `AbilitySystem` to ask, and no MVP ability that poisons | 
| Score log | **`SYS-SCORE` does not exist yet and the log does** (US-0064). `ScoreLog` lives on `MatchContext` beside `lockouts` and `impulses`, adopted by reference; `ScoreEvent` is immutable in the engine — getter-only properties, so an assignment is a parse error — and freezes `TUN-MATCH-FINALPHASE-MULT` from its **own tick** inside its one constructor, which is why no inconsistent event can be built. **The final phase is a property of the clock**, so this is not blocked on `SYS-MATCH`; US-0079 must read `ScoreEvent.multiplier_at` rather than decide it again. `ScoreFold` is pure and takes **no tuning** — TDD-10 §1.3's signature is amended, because points frozen on the event and points re-read at fold time are two sources of truth. `ScoreAward` is the claim a system makes and `ScoreEvent` is what the log made of it; the seam exists because eight constructor arguments is a design signal `.gdlintrc` refuses to let anybody suppress. **Two events are appended in a live match** — `SCORE-CONTRACT` and the `SCORE-DEATH` marker, sharing a group — and the other eleven bonuses are US-0065's, because each is judged at *initiation* against state the kill handler no longer holds |
| Score feed | **THE FIRST THING IN THIS GAME THAT TELLS A PLAYER WHY THEY WERE PAID** (US-0074). `NET-S2C-SCORE-EVENT` did not exist and no story claimed it; `ScoreWire` owns the catalogue's **sixteen-byte** row, hand-packed because `gdlint` refused eight loose RPC arguments and was right twice — Variant encoding, and eight positional integers where transposing `actor` and `subject` is invisible. **The courier is a cursor over the log**, `ScoreLog.tail`, rather than a hook on each append, so a third append site (ADR-0014's escape) is covered by existing. **The recipient is `ScoreEvent.actor_id` — a field of the event, not a list a caller assembles**, which is what makes never-do #12's no-global-kill-feed structural. **`SCORE-DEATH` is the one kind withheld**: it pays nothing and it is the only event whose `subject` names somebody the recipient has not earned. `ScoreFeedVm` owns the stagger, the cap and the lifetimes — **a line's lifetime starts when it is SHOWN, not when it was told**, or the fourth bonus of a kill would be readable for 3.64 s against a documented 4.0. The display key is **derived** from the id (`SCORE-FROMABOVE` → `bonus.fromabove`), which is how three bonuses with no name at all were found. `ScoreFeedWidget` draws each value digit by digit at the widest digit's advance, which is right-alignment and tabular spacing in one operation |
| Suspicion | `SYS-SUSPICION` ticks at the `suspicion` stage, **after `crowd`** — the boundary `SystemOrder` calls the most damaging silent failure in the game, since a stale crowd lets a player accrue *alone* suspicion inside a pocket that has re-formed. One pass over six pawns: the world is read from `ctx.crowd_hash` (never a physics query), impulses drain first and re-arm `TUN-SUSPICION-DECAY-DELAY`, then the integrator, then the tier with hysteresis. **The value lives on `PawnContext`, not in the system** — the builder reads it, so a copy here would be a second authority. `suspicion`, `tier` and `active_sources` go out in the own-gameplay block **to the owner alone**; there is no field anywhere in the format for another player's, which is the rule living in the wire rather than in a widget. `SuspicionSources.of()` is the only place the five conditions are applied and `gain_rate()` is their sum, so the HUD's source list cannot drift from the number it explains. **The impulse queue is `MatchContext`'s** as of US-0060, adopted by reference rather than mirrored, because a system reaching another system's state does it through the context. It has two live callers now — a failed kill and a witnessed one. **The bump still has none**, because pawn and NPC both mask `WORLD` and there is no contact to report; `has_stillness` still needs a loadout |
| Pawn body | `GreyboxBody`, procedural — capsule, head and a chest marker on `+Z`, measured from the collider so the two cannot drift. **`PersonaVisuals` was empty through US-0021, 0022 and 0023**: three stories of camera work built around a pawn that did not render, every suite green. Not a persona — ART_BIBLE §6.1's four constructions are US-0039's |
| Camera | Real spring arm: 2.6 m, **pawn centred** (US-0092 — the 0.45 m offset never changed the composition, because the rig aims at the pawn's own axis; `INPUT-SHOULDER` retired with it), occlusion that pulls **in** and never sideways, `WORLD`-masked so a crowd cannot push it. The FOV ladder is bound to the **state**, never to `ctx.velocity`: the rung is a consequence of the decision, not of the physics that follows it. Crowd-scan narrows to 48° and grants nothing. **Positive pitch LOWERS the arm** — the rig looks *at* the pivot, so a raised arm looks down; it shipped inverted from US-0021 until somebody played it |
| Input | 20 `InputMap` actions from 14 live `INPUT-` IDs — `INPUT-SHOULDER` is retired via `InputActions.DEPRECATED`, still in the corpus and bound to nothing, KBM + pad. Chain GDD-02 → `Ids` → `InputActions` → `project.godot`, guarded on every hop, both directions. **Sampled once per physics frame by `LocalPawnDriver`, the only caller** — see trap 12. The mouse is **captured** on boot; `INPUT-MENU` releases, a click takes it back. **Only a mapped gamepad holds the joypad bindings** — `PadSelection`, applied through the one `InputMap` writer, because a set of sim pedals was steering |

## What is deliberately unticked

**Forty-eight criteria are deliberately unticked**, each blocked by something real —
regenerated on **2026-09-02**, when US-0070 closed US-0061's ninth line after four
milestones. It went 47 → 56 → 48
in one day on 2026-08-27 and both moves are US-0063: running the M4 gate made it
`in-progress`, so its nine unmet lines began counting, and **ADR-0016's split then
closed six of them and re-homed the rest to US-0098** (a `draft`, so its ten do not
count). **The +2 since is US-0066 and US-0073 being marked `done` while one and
three of their lines are honestly unmet** — the count was not regenerated in either
story's checkpoint, which is the fifth time a prose count here has drifted. Six of
the fifty are still US-0048's M3 gate lines. US-0074 added none: it is eight of
eight. A prose
count of these has drifted four times, so they are a table — and the story files
are the source of truth, not this. Regenerate the count rather than editing it:

```bash
total=0; for f in docs/40_backlog/stories/*.md; do
  case "$(grep -m1 '^status:' "$f")" in *done|*in-progress)
    total=$((total + $(grep -c '^- \[ \]' "$f")));; esac; done; echo "$total"
```

| Story | Unticked | Blocked by |
|---|---|---|
| US-0002/3/4/5 | four "required check on `main`" lines | branch protection needs GitHub Pro on a private repo. TDD-12 §1.3 |
| US-0019 | root motion for hand and foot placement | there are no animation clips |
| US-0022 | motion-reduction's compensating indicator | the FOV **lock** is done and tested; the persistent speed indicator is motion reduction's compensating channel, US-0084 (M6) |
| US-0023 | ambience ducked, footsteps sharpened | `Audio.play()` is an empty stub until US-0075 |
| US-0024 | input→animation measured; ≤ 80 ms with prediction | no clips. **The prediction half is now measured** — 33.3 ms at every latency profile — but the chain is still three stages of five, so the number is a lower bound. The feel-gate checklist is DONE (2026-08-13) |
| US-0025 | ping/pong RTT proven over a real wire | the client half needs two processes. `RttTable` is unit-tested and the server half reads ENet directly |
| US-0029 | "remote pawn is 14 B, NPC is 7 B" | **false as written.** Measured at 10 and 8; TDD-04 §4 and §7.1 were amended instead of rewording the criterion |
| US-0030 | `render_state` per observer | **the three culling criteria are DONE** — US-0030's cull landed once M3 gave it a crowd. `render_state` needs `SYS-DETECTION`, which is M4's |
| US-0036 | "every netcode test runs at all four profiles" | true only of the harness's own agreement test; the rest are pure and have no wire to give a latency to |
| US-0037 | match end below minimum players | `SYS-MATCH`'s, in M4. **The timeout criterion was ticked at the M2 gate** — a hard-killed client took the same `peer left` → `pawn freed` path across four real processes |
| US-0056 | Focus tracking as a `has_los` consumer | **three of the four arrived and only Focus is left.** The Compass lock (US-0058), the witnessed-kill check (US-0060) and — as of ADR-0015, 2026-08-27 — **kill validation itself**. Focus is US-0064's |
| US-0054 | the occupant can see nothing while inside | **no client renders a blend at all.** The server half is done — `blend_state` reaches the occupant's own snapshot block, which is what a widget will black the screen out from — and the widget is US-0073 in M5. A guard over zero call sites would be vacuously green |
| ~~US-0061~~ | **CLOSED 2026-09-02 by US-0070**, after four milestones. The old note read: **`ABIL-LUNGE` is US-0070, so there is still no state to be mid-** — and US-0067 sharpened the question rather than answering it: every cast now has a wind-up, and **nothing but death interrupts one**. Whether a stun should is the sixth owner decision above. The way it stays true when the ability arrives is that `StunSystem._is_busy` and `_is_stunnable` never grow a case for it, and both name the criterion. Everything else in the story is built and falsified |
| US-0059 | the client-side rotation; the mono sting | **the server halves are done and neither client half exists.** A world bearing needs `CompassVM` to rotate it (US-0072, M5) — US-0057's seventh line, again — and the sting has **no call site at all**: `Audio.play()` is a stub until US-0075 and `EventBus` may hold no `func`, so a guard over zero call sites would be vacuously green |
| US-0060 | NPCs rewound (**the movement stagger is DONE** — ADR-0017) | **both are reported rather than blocked.** ADR-0010's two reasons for rewinding NPCs are false of the built game, so a rewound crowd has no consumer and would cost ~100 KB of ring to be read by nothing. **The stagger criterion is TICKED as of 2026-09-01**: ADR-0017 added `Staggered`, so the loser enters a state for `TUN-KILL-CONTEST-STAGGER` 1.5 s of step ticks and the initiation lockout stays beside it as the rule the combat systems ask |
| US-0057 | the cone's half-width, camera-relative | **the server's half is done and the drawn half does not exist.** `TUN-COMPASS-CONE-HALFWIDTH` is asserted wider than the wobble, so the true bearing is always inside the arc — but nothing renders an arc, because `CompassVM` and the HUD are US-0072/0073 in M5 |
| US-0056 | `at_tick` rewind; the three named consumers | **all four blockers are other stories**: `RewoundWorld` is paired with the query by `SYS-KILL` (US-0060), and lock progression, Focus tracking and kill validation are US-0058, US-0064 and US-0060. The rewound form is **refused rather than faked**, because against static geometry a fake would answer correctly and be wrong about the players |
| US-0053 | the persona-appropriate clone idle | **there are no animation clips in this project, on either rig** — M3's exit blocker. Separately, `PawnStateId.BLENDED` is still unreachable and the clip is not why: the pawn state machine is predicted, and a transition depending on how many NPCs are within 3.5 m is one the client cannot reproduce |
| US-0052 | the NPC bump has no contact to report | **the witnessed-kill criterion is TICKED as of US-0060** — both its blockers cleared, and `server_root._charge_for_witnesses` charges the killer once if any living player has a clear line to the body at the contact frame, **present-tense rather than rewound**, because a witness did not act. What stays unticked is nothing here; the **NPC-bump criterion IS ticked on the rule** — the debounce is built and falsified both ways — while nothing calls it, because both pawn and NPC mask `WORLD` only |
| US-0047 | "always had 2 within 25 m"; "does not read as following" — **and rule 3's scoping is not what ticks the first one** | **"Always" is not achievable and the reason is a walk**: a fetched clone crosses 25 m in ~18 s, so a player who loses one is short for that walk. Supply is not the constraint — 4.27 clones of each persona on average against a floor of 2. **47 of 11 544 readings under the floor after the grace, 0.41 %**, never below 1, and of the short pairs the pass saw, most already had a clone coming and the rest were dispatched: the rule never ignores a breach, and that is what is asserted. The second criterion's readable half needs a client that has ever rendered a clone |
| US-0046 | layers 2 and 3, footstep parity, the idle cycler | **there are no animation clips in this project, on either rig.** Layer 2's declaration half asserts and its library half reports; layer 3's check exists with no call site because a call site needs an `AnimationTree`; footsteps need `Audio.play()`, a stub until US-0075. ANIMATION_SPEC §8 costs the parity set at 14 × 4 personas × 2 rigs |
| US-0045 | the three client-LOD lines | **US-0046.** `NpcView` exists now and draws the crowd; what is missing is the **mesh and the `AnimationTree`**, so animation LOD, the silhouette-fairness check and mesh LOD still have nothing to band. There are no animation clips on either rig |
| US-0063 | nine of the ten M4 gate lines | **the gate is RUN and six of them cannot be run at M4 by construction** — a playtest needs a match (`SYS-MATCH`, US-0079, **M6**), a lobby (US-0078, M6), a HUD (US-0072/0073, M5) and a score (US-0064/0074, M5). Two more need telemetry that does not exist: **28 of 29 GDD-07 §8 events have no emitter**, so THE TURN is *unmeasured rather than absent*. The one met is the risk re-score. **Recommendation: split the gate**, technical exit at M4 and the human playtest beside US-0088 at M6 |
| US-0048 | six of the ten M3 gate lines | **the gate is RUN.** Four are met — `test_crowd_perf.gd`, `test_clone_local_min.gd`, the risk re-score, and **server tick p99 at 2.15 ms of 8.0**, measured here by booting the real `server_root.tscn`. Of the six left, `test_crowd_bandwidth.gd` is a **measured miss** at 112 % and not a blocked line; the rest wait on clone meshes on the wire, animation clips, and an owner at a windowed client. **The tag is the owner's call** |
| US-0044 | startle waves read directionally **to a human observer** | needs rendered clones and an owner at a windowed client. **NPC meshes are US-0046.** The mechanical half is measured — 13 of 13 startled NPCs sent away from the violence — and the criterion is not rounded up on it |
| US-0043 | the circuits' declared periods; the 8 m circuit separation | **both are the level's, not the code's.** The routes are 150–237 m, so 55–75 s implies 2.6–3.2 m/s; and CIRC-A and CIRC-B share the z=45 spine, passing within **0.51 m** against a rule of 8 m — geometry, so no re-timing fixes it. Re-authoring four routes against six competing rules is the owner's |
| US-0038 | frame-rate independence; downstream "measured"; the 180 ms feel check | impossible headless (the structural substitute is accepted, not ticked); the entity counts in the projection need M3's crowd; the feel check is the owner's and needs a windowed client |
| US-0031 | downstream measured within 96 kbit/s | **rate LOD is DONE** and NPC-only by design, since a *player* at 46 m at 10 Hz would be visibly coarse. The measurement is now real and it **misses**: 112 % with culling, rate LOD and the NPC delta all built, charged against a lagging ack. The remaining 12 % is ADR-0007's or a tuning change, neither priced |
| US-0035 | NPC transforms recorded; memory "around 23 KB" | **the reason changed at US-0060, from "no crowd yet" to "nothing would read them".** ADR-0010 rewinds NPCs because they occlude sight and decide blend membership; neither is true of the built game, and kill validation asks no sight question at all. 78 NPC transforms a tick would take the ring from 28.1 KB to ~130 KB for no consumer. Memory measured at **28.1 KB** — 20 B per record, not §8.3's 16, because the entity id is stored rather than implied by slot. TDD-04 §8.3 amended |

Two more things are owed and are **not** acceptance criteria, so they are not in
the count: the navmesh **bake** (recorded in US-0012) and
**`test_frame_rate_independence.gd`** (US-0036's test notes) — the latter cannot
exist headless, because there is no display rate to vary. Do not go looking for
it as an unticked line; it is a missing *test*, not a missing tick.

**Nothing here is forgotten and nothing is half-ticked** — a story marked done
over a criterion that is not true makes the whole backlog unreadable as a status
view.

## Eighteen things that will cost you an hour if you do not know them

1. **THREE things are GENERATED, and the third is the one that has bitten.**
   `scripts/core/ids.gd`, `scripts/core/tuning/*.gd` and `tuning_index.gd` come
   from `tools/tuning_codegen/run_all.py`; **`data/tuning/default/**/*.tres` come
   from `tools/generate_default_tuning.gd`**, which must be run after the first;
   the map scenes and `MapData` come from `tools/generate_map_vetraio.gd` and
   `generate_map_sandbox.gd`, whose sources are `vetraio_layout.gd` and
   `sandbox_layout.gd`. Hand-edits to any of them are silently reverted on the next
   run. **Change the layout table, not the scene.**
   **THIS TRAP WAS FALSE AS WRITTEN FROM ADR-0018 UNTIL 2026-09-04**, and following
   it literally destroyed shipped gameplay — the codegen dropped two tunables and
   the `.tres` writer reverted `TUN-CINDERFALL-THROW-RANGE`, dropped
   `TUN-CINDERFALL-DURATION` and dropped `effect_script` from both live abilities,
   from a run that printed success. Both halves are fixed and both reproduce
   byte-identically; the section near the top of this file has the measurements.
   **The lesson that outlives it: the `.tres` are generated too, so a hand-edited
   one is a change with a countdown on it.** `cinderfall.tres`'s hand-typed
   `id="2_cndrf"` is what a hand-edit looks like — no generator writes a mnemonic.
   **AND THE `.tres` WRITER IS A SCENE RATHER THAN A `-s` SCRIPT, WHICH IS A
   CORRECTNESS FIX AND NOT A STYLE CHOICE (2026-09-05).** A `-s` script is compiled
   **before the autoloads are registered**, so `Tuning` is unresolvable — and it is
   the **one autoload Core is permitted** (ADR-0005), read by **sixteen Core
   classes**, every one of which then fails to compile *and stays broken for the
   rest of the process*, because GDScript caches the failure. The symptom is a
   runtime *"Nonexistent function X in base 'GDScript'"* naming a class that is
   perfectly correct, **four files from the cause**. It cost this tool **invariant
   33** from M0 until it was fixed. `tools/anchor_census.gd` was converted for the
   same reason. **Any tool that touches a Core class needs a `.tscn`.** The two map
   generators are `-s` and are fine — their layout classes read no autoload — and
   that was measured rather than assumed.
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
6. **`main` IS server-protected — this trap's opening line said the opposite until
   2026-08-26 and was stale for five days.** `.github/main-ruleset.json` was applied
   on 2026-08-21 and re-verified at this checkpoint: `gh api repos/<owner>/<repo>/rulesets`
   returns *"main is protected"*, `active`, with all seven job **names** as required
   contexts. §1.3 of `docs/20_tdd/12_build_and_ci.md` was right and this line was
   not, which is the shape of every stale claim in this corpus: the *newer* section
   below already said so and nobody read both. Still run
   `git config core.hooksPath .githooks` in a fresh clone — the hook is the fast
   answer, the ruleset is the real one — and wait for a run to report
   `completed success` before merging. `gh run watch` can return while a run is
   still queued.
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
   **AND A SLOW QUEUE LOOKS EXACTLY LIKE AN OUTAGE, WHICH COST A WRONG CALL ON
   2026-08-26.** A run took **about thirteen minutes to be scheduled** against the
   usual near-instant; twelve polls found nothing and this session concluded the
   pipeline would not fire and pointed at billing. The owner said *"the CI should
   be green, check again"* — and it was, passing in 3 m 55 s. **The check that
   distinguishes the two is the annotation, not the wait**: a refused job appears
   and completes in the same second with zero steps, where a queued one simply has
   not appeared. If no run has appeared at all, wait longer before concluding
   anything; three later runs the same day appeared within 45-75 s.
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
    refuses to pass over a short run. **It has now caught SEVEN silent skips**,
    the last on 2026-08-28 (US-0067): `CombatTargets.is_dead` takes a pawn and I
    called it with a context and a peer, which is a **parse error** — and GUT
    answers a parse error by *ignoring the whole file*. `test/unit/systems/combat`
    reported **"All tests passed!"** while running six scripts of seven, and the
    full unit suite reported 1 463 passing tests over 174 of 175 scripts. **The
    file it skipped was the one holding this story's own new assertion.** Nothing
    but the script count could see it, and the failing call sits at the very line
    the run's *first* error names — which is 2 700 lines above the summary, so
    **capture the run to a file and read the top**, not the tail.
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
    NOTHING ABOUT ONE — BUT IT CAN STILL *PRESS* ONE.** Narrowed 2026-08-28.
    `Input.action_press` is a **synthetic** press into the Input singleton and
    works headless; `tools/bot_client.gd` walks a real client 12.5 m in fifteen
    seconds with no window, and the server agrees. What headless cannot do is
    *read* a physical device, which is what the evidence below is about.
    `drive_probe.gd` refused headless with the over-broad reason and now says
    the real one. There is no windowing layer to poll a pad or deliver
    mouse motion, so every reading is a zero — and a zero from a probe that
    cannot see is indistinguishable from a zero from a quiet machine. A tool
    written to find the spinning camera reported "connected joypads: 0 — a
    spinning camera is NOT coming from a stick" under `--headless`, on a machine
    where a pair of sim pedals was holding three actions at full deflection. It
    was believed for a day. **`tools/input_probe.tscn` — a scene since 2026-09-05,
    because as a `-s` script it could not load at all; see trap 1** — refuses to
    run headless, and
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
    which was luck rather than process. **`test/metrics/` was the same shape and is
    gone as of 2026-09-02** — declared in TDD-02 from M0, holding a `.gdkeep`, and
    named in `TEST_PLAN` §9's *before every PR* list. Its assertions had been written
    into `test/unit/core/map/` all along, so the coverage was real and the directory
    was theatre.
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

17. **A MISSING ROW IN A `.tres` IS INDISTINGUISHABLE FROM A DELIBERATE ZERO.**
    Godot writes only the properties that differ from a script's defaults, so a
    tunable nobody set reads back as `0.0` with no error, no warning and no failing
    test. `TUN-CINDERFALL-DURATION` was **0.0 from M0 against a published 4.0** —
    a cinder cloud that lasted one tick — because the `duration` line is simply
    absent from `cinderfall.tres`, and it surfaced only when `SYS-KILL` became the
    first code to ask how long a cloud lives. **`test_tunables_match_the_document.gd`
    now compares 283 of the 288 published values against the shipped profile**, which
    is the check that did not exist. Its `@export_range` sibling cannot cover
    abilities or passives: `AbilityData` is one class holding four abilities' fields,
    so `duration` means 4 s for Cinderfall and 15 s for Second Face and no single band
    is right for both. **If you add a tunable, add its row to the `.tres` explicitly**,
    even when the value equals the script default.

18. **THE LAG-COMP RING RETURNS THE *STALE* FRAME IF A TICK IS RECORDED TWICE.**
    `LagCompHistory._frame_at` walks the ring and returns the **first** frame whose
    tick matches. `record()` never overwrites in place — it advances `_next` — so a
    test fixture that places a pawn, fills the ring, **moves the pawn** and fills
    again leaves both frames present, and the rewind resolves against the **older**
    one. Every geometry assertion in the file is then about where the pawn used to
    be, and it reads exactly like a rule that does not work: a stun lands on a
    stranger, a target behind you is somehow in cone. Cost an hour in US-0061.
    **Clear the ring before refilling it** — `_settle()` in
    `test/unit/systems/combat/test_stun_system.gd` is the pattern, and it says why.

## Local environment

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

## The record before M5, and why it is not in this file

**THIS FILE WAS 6 594 LINES AND HALF OF IT WAS HISTORY.** One section — *"THE
FIFTEEN STORIES, AND WHAT THEY DO NOT ADD UP TO"* — held **3 301 lines**, the whole
build-up from M0 to M4, and underneath it sat the tables, the eighteen traps and
the local environment: the three things a cold session needs **first**, filed at the
bottom of a section about M4's story list. Moved to
[`docs/00_meta/history/M0-M4_the_build.md`](docs/00_meta/history/M0-M4_the_build.md)
on 2026-09-08.

**WHAT WAS ARCHIVED IS THE REASONING, NOT THE STATUS.** Every live fact those pages
carried is still here: the tables above hold the current numbers, the unticked table
holds what is blocked and by what, and the traps hold what will cost you an hour.
What went to the archive is *how each of them was found*, which is worth keeping and
is not worth reading before you start.

**AND THE ARCHIVE IS INDEXED RATHER THAN MERELY STORED**, because a document nobody
can find a route into is a document nobody reads — and this project has already paid
for exactly that: the fix for the `-s` autoload cascade **was already in this file**,
three sections above the error it explained, and went unconnected for four
milestones. The length was never the problem; the missing route was.

| In the archive | What it explains | Still live? |
|---|---|---|
| **M0-M1**, the pawn and the feel gate | why the speed ladder lost its Jog rung, why the camera's pitch shipped inverted, and the nine defects that only playing the game found | the feel gate passed 2026-08-13; US-0024's two open lines are in the unticked table |
| **M2**, the transport | prediction, reconciliation, delta encoding, the churn harness — and why the upstream budget read 253 % against a projected 112 % | **yes**: upstream sits at 145 %, coalescing unbuilt because it costs 16 ms of input latency |
| **M3**, the crowd | the pool, the brain, the navmesh, the four processions, LOD bands, clone parity — and the level-data findings | **yes**: downstream 112 % of budget, and GDD-05 §2.7 rule 8 still short at S3/S4/S5 |
| **M4**, the loop | contracts, suspicion, blend, detection, the Compass server half, kill, stun, spawn, and ADR-0013/0014/0015 | the systems are built; what is open is in the unticked table |

**Read it when you need the reason for a rule, not before.** If a number here
surprises you, the archive is where it was measured.

## Fresh session? Read these four first

1. This file.
2. `docs/00_meta/GLOSSARY.md` — every term has exactly one meaning.
3. `docs/50_tuning/TUNABLES.md` — every number.
4. Your story file in `docs/40_backlog/stories/`.

Then the routing table above for the one or two documents governing your system. **Do not read
the whole corpus** — read the `depends_on` chain of what you need.

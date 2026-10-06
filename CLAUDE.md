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

# A bot walks the crowd's walk (US-0102): anchor to anchor on the navmesh, at
# blend-walk, standing 8-25 s on arrival. --census 120 prints how the crowd, the
# other players and the bot itself move, side by side, after 120 s.
godot --headless --path . res://tools/bot_client.tscn -- --connect 127.0.0.1:27015 --bot 9 --census 120

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
12. **Never add a minimap, a kill-cam, or a name or marker over a body you have no
    relationship with.** Each would convert an earned inference into a given fact.
    **Narrowed 2026-08-26 (ADR-0013):** the hit-direction ban is lifted — the prey warning
    carries a bearing, as the reference's does — and a *relationship* marker on your own
    contract or your own revealed pursuer is permitted. **Narrowed again 2026-09-25
    (ADR-0024), by owner decision for reference fidelity:** the global kill feed, player names
    in the HUD (feed, portrait, death card, scoreboard) and your own placement on screen are
    lifted, because the reference has all three. Names over bodies stay banned — the reference
    has none — and the kill-cam is an open question in ADR-0024, not lifted.
13. **Never weaken stun** to make hunting feel better. If hunters are frustrated, make the
    *Anonymous approach* more reliable instead. **One exception, decided 2026-08-26 for
    reference fidelity (ADR-0013): a committed kill is not interruptible.** Range advantage,
    freeze and lockout are all untouched, and none of them may be traded away. **The tier gate
    went the other way on 2026-10-01 (ADR-0022 A, owner decision): any pursuer can be stunned,
    which strengthens the prey.**
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

*Updated 2026-09-30. **Kept short by rule**: a checkpoint adds at most a few lines here and
moves anything older than about two weeks to `docs/00_meta/history/` (CHECKPOINT.md §3.1).
This file is loaded into every agent request, so every line here is paid for on every turn.
How each thing below was found is in
[`M5_the_match_and_the_reference.md`](docs/00_meta/history/M5_the_match_and_the_reference.md),
which also holds this manual's long form as it stood before the rewrite.*

**THE GAME IS PLAYABLE END TO END BY THE OWNER AND BOTS, AND HAS NEVER HAD SEVERAL HUMANS IN
ONE MATCH.** `play.bat` starts a server, walking bots and a client: a countdown, dealt personas
and contracts, an eight-minute match with the Final Contract, kill, stun, escape, Cinderfall
and the Lunge, every bonus rule (two of them dormant), the HUD and a results screen. **What it does not have**: animation
clips (figures glide), any sound, a lobby screen, player names, a loadout, and a playtest with human hunters (US-0098). **The road from here to M6 — what the
owner calls the beta — is [ROADMAP §8.3](docs/40_backlog/ROADMAP.md)**, measured 2026-09-30.

### Recent, newest first

- **2026-10-06 — a net under every group and bench, and the grey over one's own (US-0107).**
  Reported from the controls: nothing said where a player could blend or whether they were. The
  owner's reading of the reference: a faint white honeycomb under every group and bench, always,
  and a blended player sees themselves and their group slightly greyed, on their screen alone.
  Groups come from `NET-S2C-CROWD-GROUPS` (`PROTOCOL_VERSION` 8), computed from civilians alone so
  no net marks a player.
- **2026-10-04 — the crowd gathers, leans and sits (US-0103).** NPCs lean at the stall
  counters through the occupancy players use (`LeanSpots`: one figure per counter, a player
  refused where a civilian leans) and stand in conversation circles started near where they
  are (`CrowdPlaces`); a full circle is a blend pocket (invariant 38). Measured: idle NPCs with
  a neighbour 27 % → 48–54 %, counters leaned at 7 % → 21–31 %. **Five benches added**,
  fifteen seats on the same record, so NPCs sit too. Walking apart is measured and parked.
- **2026-10-01 — any pursuer can be stunned (ADR-0022 A).** Reported from the controls: *only
  the smoke grenade could stun my pursuer.* `TUN-STUN-MIN-TIER` is neutralised at 0, so an
  Anonymous pursuer is stunnable by a press and by a Lunge, and restoring 30 restores the gate.
  Invariant 7 is now *stun floor ≤ warn floor*. **The `stun_ready` hint lights for any figure
  in reach, player or civilian** (owner decision), so it never points the pursuer out.
- **2026-09-30 — a killed prey escaped ten seconds after dying (#246).** Reported from the
  controls. `PursuitBoard.close`'s docstring named its callers and **nothing called it**, so
  the killer's chase on the prey they had just killed drained and scored as an escape: the
  killer lost the contract they had just been told, the corpse was paid `SCORE-ESCAPE`, and a
  stunned hunter's prey was paid twice. `ContractSystem.end_stale_chase` now ends every chase
  whose prey is no longer the announced contract, and the chase's last sighting now lives in
  its own row, so closing it cannot leave an unearned close call behind (found in review). Found
  by reproducing, not by reading.
- **2026-09-30 — the one-line notices (US-0105, #245).** *New pursuer on you.* and *You have
  taken the lead.* on `NET-S2C-NOTICE`, one byte to the one player concerned, naming nobody;
  `PROTOCOL_VERSION` 7. None at the countdown's first deal; the lead is the new **sole** top
  scorer above zero among players present, asked only when `points() != 0` were paid.
- **2026-09-29 — the Compass says up or down and glows in sight (US-0105, #244).** Three bits
  in the byte `portrait_revealed` had to itself; `PROTOCOL_VERSION` 6.
  `TUN-COMPASS-VERTICAL-THRESHOLD` 2.0 m is ours; in-sight is the chase's own sight. The word is
  `CompassWordWidget`'s, because `test_compass_invents_nothing.gd` forbids text in the ring.
- **2026-09-29 — the camera rests 13° down; the Compass is a flat ring round the legs (US-0105,
  #243).** Measured: a level view cut the feet off. `TUN-CAM-REST-PITCH` −13° by owner decision.
  The ring sits at a fixed screen spot as the reference's does (`CompassWidget.place`,
  `ground_scale`), held to the figure by `test_the_compass_rings_the_legs.gd`.
- **2026-09-29 — four guards (#239–#242).** A new pawn state needs a strictly newer
  `PROTOCOL_VERSION`; DATA_SCHEMA §3 is held to the tuning scripts; every ADR to DECISION_LOG
  §2.2's template; the crowd max-tick re-measures once rather than loosening.
- **2026-09-25 — Cinderfall catches everyone in it (US-0104, ADR-0023).** Everyone inside but
  the caster is `Choking` (state 16) until no cloud holds them; the caster's pursuer inside is
  stunned; the caster may kill there; NPCs are held too. **Open**: the cloud lasts 6.0 s against
  the reference's ~4 s (ADR-0023 C).
- **2026-09-25 — a reference match watched frame by frame: ADR-0022 (proposed), ADR-0023,
  ADR-0024.** The owner answered all three toward the reference. **Any pursuer can be stunned**
  and **no ability use is high-profile** are *decided and not built*; the per-(hunter,
  contract) meter is proposed. ADR-0024 narrowed never-do #12.
- **2026-09-24/25 — the district wears its personas (US-0100, US-0101), the bots walk like
  civilians (US-0102), the crowd walks in rows (US-0103).** Personas are dealt at the
  countdown; every figure is a `PersonaBody` in its hue; `Wardrobe` dresses nobody until it
  holds both the seed and the roster.
- **2026-09-15/22 — walking alone costs nothing (ADR-0020); the hunter knows the face from the
  start (ADR-0021).** `TUN-SUSPICION-GAIN-OPEN` neutralised at 0; ASM-0030 is void.

### How the work runs

- **Two agents.** Claude implements in `D:/Claude Code/sv-claude`, opens PRs and never merges;
  Codex reviews in `sv-codex` and releases merges. The owner's `project-sottovoce` checkout
  stays on `main` and is fast-forwarded (`--ff-only`, clean `main` only) after each merge. One
  worktree per agent, because a shared `.godot/` is trap 16 as a standing condition.
- **`main` is protected**: seven required checks and a strict up-to-date rule, so two green
  branches from the same `main` cannot both land untested against each other. Squash merge.
  A stacked branch is moved with `git rebase --onto origin/main <old-base-head>` once its base
  lands.
- **Every PR body ends with CHECKPOINT.md §9's handoff block.** `Commit` is the SHA the checks
  passed on.
- **Agent entry points are pointers.** `AGENTS.md`, `.claude/commands/save.md` and the Codex
  skill point at CHECKPOINT.md and hold no copy; `test_agent_entry_points_are_pointers.gd`.

### What this project has learned to do every time

1. **Sweep the repo, not the diff**, for the *consequence* of a rule change. A grep for an id
   finds where the rule is named, never where it is assumed — five ASM-0030 leftovers and the
   Cinderfall prose were each found only by reading around the change.
2. **Falsify one plant at a time, against the suite that owns it.** A plant that stays green is
   a finding. A loop over a whole suite once reported four real reds as green.
3. **A field nobody writes, or a rule only a docstring states, is indistinguishable from one
   that works.** Nine instances so far, #246 the latest. Find the writer; find the caller.
4. **Reproduce before reasoning; measure before quoting.** Instruments here have been wrong in
   a plausible direction seven times, and a claimed number has been wrong more often than that.
5. **What travels is append-only.** Enums and ordinals on the wire are appended, and a change
   of meaning bumps `PROTOCOL_VERSION`, with the reason written in `messages.gd`.
6. **`is_simulating` and `is_watched` are different questions**: `RESULTS` simulates nothing and
   is still described to every client. When one flag decides two things, split it.

## What waits on the owner

*Numbered, because ADRs, stories and code say "owner decision N"; a number is never reused. A
settled row stays, one line, so nobody re-opens it. The full reasoning is in the archive.*

| # | Question | State | Recommendation |
|---|---|---|---|
| 1 | `SYS-MATCH` to M5 | **Settled 2026-09-08: moved.** Whether US-0098 may run on the direct-IP launch is still open | yes — it answers the project's largest unknown |
| 2 | The 180 s integration budget | **Open.** The suite reads ~192 s; three documents assert the budget and nothing enforces it | raise it to what is measured, then enforce it |
| 3 | A state for the staggers | **Settled 2026-09-01**, ADR-0017 | — |
| 4 | A persona on `NET-S2C-PLAYER-JOINED` | **Closed 2026-09-22**, ADR-0021 | — |
| 5 | The tags `m3-crowd` and `m4-the-loop` | **Open** | the owner's call |
| 6 | Does a stun cancel an ability's wind-up? | **Open.** Only death interrupts a cast; `AbilitySystem._end_all` is where it would go | — |
| 7 | `TUN-KILL-CONTEST-STAGGER` models a mechanic the reference lacks | **Open** | keep: it adds to the reference rather than contradicting it |
| 8 | The Lunge auto-kill judged over the dash | **Settled 2026-09-03: over the corridor** (`KillRules.resolve_swept`) | — |
| 9 | A Lunge into your pursuer stuns them | **Settled 2026-09-03**, ADR-0018; `TUN-SCORE-STUN` 200 | — |
| 10 | The final warning: phase or announcement | **Settled 2026-09-13: an announcement** | — |
| 11 | Suspicion per relationship, gated on sight | **ADR-0022 proposed 2026-09-25.** Answered: any pursuer can be stunned (**built 2026-10-01**), no ability use is high-profile (not built) | the per-(hunter, contract) meter after the first human playtest |
| 12 | The Final Contract's `×2` has no counterpart in the reference | **Open.** The reference's only ×2 is a loss streak (US-0099) | keep it: the one lever against a leader parking out the clock |
| 13 | Deal the persona at M5 | **Settled 2026-09-24**, US-0100 | — |
| 14 | Identifying the target as the player's act | **Settled 2026-10-02: exactly as the reference** (ADR-0025). The hunter picks the figure, a civilian killed instead costs the contract, the lock confirms nothing. Built by US-0106 after US-0103 | — |
| 15 | How many pursuers a player may have (0–4, catch-up) | **Open.** A recorded match shows 0–3 on one HUD | after the first playtest with human hunters |
| 16 | Cinderfall as a pure escape or the reference's | **Settled 2026-09-25: the reference's**, ADR-0023 | — |
| 17 | Kill feed, names in the HUD, own placement | **Settled 2026-09-25: as the reference**, ADR-0024 | — |

**Also open, unnumbered:** ADR-0023 C, the cloud's 6.0 s against the reference's ~4 s.

---

## The state of the build

*What is true now, one row per system. How each came to be is in the archives.*

| | |
|---|---|
| CI | 9 jobs, of which 7 are required check contexts on `main`: the two suite partitions, `test / architecture + unit` and `test / integration`, run as well and are summarised by the required aggregator `test`. A job that starts and ends in the same second with zero steps is a **billing refusal, not a crash** — trap 6. `.ci/run_gut.sh` refuses a suite that ran fewer scripts than exist on disk |
| Tests | **63 arch + 237 unit + 33 integration scripts**, holding 260 + 1 987 + 245 tests and 1 716 + 33 730 + 687 assertions (measured 2026-10-06 for US-0107's net and grey and the reviews of #252; integration 192.7 s). **Nine are `pending` by design**, eight unit and one integration, each reporting a finding code cannot fix — among them upstream at 145 % and downstream at 112 % of budget, the crowd's wire cost, two spawn rules GDD-05 §2.7 is short of, the missing clip library, and an NPC aimed into the void. The script counts are guarded by `test_claude_md_counts_are_current.gd`; the rest is a snapshot. The 180 s integration budget is owner decision 2 |
| Tuning | **303** tunables in 14 resource classes; **38** cross-field invariants, all asserting. Eight IDs deprecated and never reused (TUNABLES §19); three neutralised at 0 with their IDs live: `TUN-SCORE-RECKLESS` (ADR-0013), `TUN-SUSPICION-GAIN-OPEN` (ADR-0020) and `TUN-STUN-MIN-TIER` (ADR-0022 A). `test_tunables_match_the_document.gd` holds the shipped profile to TUNABLES |
| Autoloads | Eight. `Tuning` precomputes durations into two tick tables, 30 Hz and 60 Hz — trap 9 |
| Strings | `data/strings/en.csv`, 109 keys |
| Boot | Branches on `--server`; 8 CLI flags parsed in pure Core; 5 export presets. The server boots into `LOBBY` and **simulates nothing** below `TUN-LOBBY-MIN-PLAYERS` 4 — `--min-players` lowers it, and `sandbox.bat` passes 1 |
| Map | `MAP-VETRAIO`, a lit greybox, 120 × 120 m; the navmesh is baked at build time and committed (281 polygons since the five benches, each carved out by an obstacle, 0.400 m above the street). `MAP-SANDBOX` is the 40 m debug bench. Both generated — trap 1 |
| Pawn | **17 states.** `PawnStateId.ALL`'s order is the wire and append-only (`Staggered` 14, `Lunging` 15, `Choking` 16), paired with `PROTOCOL_VERSION` by a test. `Blended` is declared and **unreachable** — its entry condition is server-only, so `SYS-BLEND` writes `blend_state` instead. Every living state can reach `Dead`. `Staggered` is interruptible and keeps the camera; `Choking` has no exit of its own and the server releases it |
| Traversal | Complete: vault, mantle, climb, drop, gap jump and the case-7 hop. The action buffer arms on the press, not the hold |
| Pawn body | `PersonaBody` for every figure, procedural, in its persona's hue once `Wardrobe` holds both the seed and the roster. **No animation clips on either rig** |
| Camera | Spring arm 2.6 m, resting 13° down, pawn centred, occlusion pulls in and never sideways, `WORLD`-masked. The FOV ladder follows the **state**, never the velocity. Positive pitch lowers the arm |
| Input | 20 actions from 14 live `INPUT-` IDs, KBM and pad. Sampled once per physics frame by `LocalPawnDriver` alone — trap 12. Only a mapped gamepad holds joypad bindings |
| Net | Server-authoritative ENet: 30 Hz tick, 60 Hz input, local-pawn prediction only, 100 ms interpolation, lag compensation for kill and stun. **`PROTOCOL_VERSION` 8**, every bump's reason in `messages.gd`. **Upstream 145 % and downstream 112 % of budget** — fine on a LAN, a risk over the internet. `Messages.CHANNEL_FOR` is held to every `@rpc` |
| Crowd | 90 pre-allocated, 78 active, one `SpatialHash` per tick; four processions of four; distance-banded LOD; startle, gawk and corpses; culled per observer and delta-encoded against the ack. `CloneBalance` keeps the clone floor for the dealt personas. **NPCs lean at the twelve stall counters and stand in conversation circles** (US-0103, `LeanSpots`, `CrowdPlaces`); NPCs sit at the fifteen seats of the five benches added on 2026-10-04; strollers still walk in rows (lanes measured and parked) |
| Blend | All four kinds — pocket, group, lean spot, hiding spot — as a condition re-validated every tick, never a kept state. `NET-S2C-BLEND-DENIED` is the one refusal that says why. **Drawn since US-0107**: a faint net under every group and bench (`BlendCues`, groups from `NET-S2C-CROWD-GROUPS`), and the blender's own group greyed on their screen alone; nothing yet blacks out a hiding spot |
| Match | `SYS-MATCH` rides `net_ticked` (it cannot be a `GameSystem`: the stage loop runs only while simulating). Lobby floor, countdown, eight-minute clock, the Final Contract's `×2`, results with a unanimous skip. `MatchClock` is the arithmetic both it and `ScoreEvent` use. Personas and contracts are dealt at the countdown from `MatchContext.rng`; the seed goes out on `NET-S2C-MATCH-START`. `RESULTS` is described to clients, `LOBBY` is silent. **Nothing follows `RESULTS` yet** — the lobby is US-0078 |
| Contracts | A Hamiltonian cycle, repaired in the tick a death resolves, reassigned after 3 s. **A chase lives only while its prey is the announced contract**; only an emptied bar is an escape (`SCORE-ESCAPE`, `SCORE-CLOSECALL`, US-0097) |
| Kill | `SYS-KILL` at `combat`, before `contract`; `KillRules`, `KillContest` and `RewindClamp` are pure. Range is 3D, the cone horizontal; it reads the **announced** contract. A committed kill is not interruptible (ADR-0013) except by a FATAL third party. A rejection answers with victim slot 0 |
| Stun | Owned and ticked by `KillSystem`, the kill judged first. The target is your own pursuer by reverse lookup on the announced contracts; every refusal costs the same and looks the same. **Any pursuer can be stunned**, Anonymous included (ADR-0022 A, `TUN-STUN-MIN-TIER` 0); what protects a patient hunter is that the prey must pick them out and a wrong press is penalised. **`stun_ready` lights for any figure in reach and cone, player or civilian**, so it names nobody. A Lunge into your pursuer stuns them (ADR-0018) |
| Spawn | Owned by `ContractSystem` and ticked first: 40 m from the killer, 12 m from every living player, the point chosen when the timer expires. `TUN-RESPAWN-INVULN` shields the target |
| Suspicion | One value per player, `SYS-SUSPICION` after `crowd`; impulses drain first; tiers with hysteresis; sent to its owner alone. Being alone costs nothing (ADR-0020); ADR-0022 proposes a meter per (hunter, contract) |
| Detection | `SYS-DETECTION` after `suspicion`: the render matrix (zero raycasts), the Compass reading, the lock, the prey warning, and the project's only line-of-sight query, `has_los`, `WORLD`-masked |
| Compass | A server-side world bearing with deterministic wobble and 0.5 m distance buckets. On screen, a flat ring round the legs whose cone widens to a whole ring at 20 m, the lock range (invariant 33); it says up or down and glows in sight. A lock outlines the true body for 1.5 s; the portrait shows the persona from assignment (ADR-0021) |
| Abilities | `SYS-ABILITY`: five validations, integer cooldown deadlines from activation, the tell broadcast before the effect, a wind-up per cast. **Built: Cinderfall and the Lunge. Not built: Second Face (US-0069). Whisperbolt deferred post-MVP.** One fixed kit — no loadout, no passives (US-0071) |
| Cinderfall | Everyone inside but the caster is `Choking`; the caster's pursuer is stunned; the caster may kill inside; NPCs are held. `CinderfallView` draws the cloud at exactly the gameplay radius and duration. *This row said nothing drew it until 2026-10-01; that had been false since US-0104.* |
| Score | Thirteen bonuses, judged at initiation and paid at the contact frame; Silent, Halfseen and Reckless partition the ladder. `ScoreEvent` is immutable and freezes the multiplier from its own tick; `ScoreFold` is pure. Each feed row goes to its actor alone and `SCORE-DEATH` is withheld; the results carry the whole log and are folded on the client. **Masked and Poisoned are dormant**: Second Face is not built and no MVP ability poisons, so eleven of the thirteen can be earned today |
| HUD | Compass, portrait with hue and persona name, tier, crosshair, vignette, score feed, pursuit bars, match timer, one-line notices, results screen. **Missing: ability slots, kill feed, player names, the death card, own placement** (US-0073, US-0105) |
| Audio | **`Audio.play()` is an empty stub and the repository holds no sound file** (US-0075, US-0076) |

## What is deliberately unticked

**Fifty-three criteria**, regenerated 2026-09-30 after US-0050's countdown line and US-0037's
below-the-floor line were found true and ticked. The story files are the source of truth;
regenerate rather than edit:

```bash
total=0; for f in docs/40_backlog/stories/*.md; do
  case "$(grep -m1 '^status:' "$f")" in *done|*in-progress)
    total=$((total + $(grep -c '^- \[ \]' "$f")));; esac; done; echo "$total"
```

A story marked done over a criterion that is not true makes the whole backlog unreadable, so
nothing here is rounded up. **Two lines look true and are not yet re-verified**: US-0030's
`render_state` (computed per pair and read by `SnapshotBuilder`; no test through the builder)
and US-0057's arc (the widget draws one now, but the half-width is no longer a fixed 12°).

| Story | # | Blocked by |
|---|---|---|
| US-0105 | 6 | own placement and pursuer icons; the contract's placement (a field and a protocol bump); kill feed, names and the death card (player names, US-0078); the civilian-kill line (US-0106, ADR-0025) |
| US-0048 | 6 | the M3 gate: client frame time, crowd bandwidth 112 %, animation and footstep parity, two human reads, the tag |
| US-0046 | 5 | no animation clips, no rig, no audio |
| US-0045 | 3 | no crowd mesh or `AnimationTree` to band |
| US-0038 | 3 | frame-rate independence cannot run headless; downstream bandwidth; the 180 ms feel check is the owner's |
| US-0073 | 2 | the portrait's silhouette (no 2D counterpart of `PersonaBody`); ability slots (a loadout, US-0071) |
| US-0077 | 2 | each player's persona, loadout and passive; killers by name — no persona in `MatchEndReport`, no player names |
| US-0047 | 2 | "always two clones within 25 m" is unachievable by a walk (0.41 % short); the readable half needs rendered clones |
| US-0035 | 2 | NPC transforms unrecorded because nothing would read them; memory 28.1 KB against 23 |
| US-0024 | 2 | no animation frame to measure input against |
| US-0059 | 2 | the client's rotation of the warning bearing; the mono sting (no audio) |
| US-0019, US-0053 | 1 each | no animation clips |
| US-0023, US-0050 | 1 each | no audio: the duck, and the audible reassignment |
| US-0022 | 1 | motion reduction's compensating indicator (US-0084) |
| US-0025 | 1 | RTT proven over a real wire |
| US-0029 | 1 | "14 B and 7 B" is false as written; measured 10 and 8, and TDD-04 was amended |
| US-0030 | 1 | `render_state` — probably true, see above |
| US-0031 | 1 | downstream at 112 % |
| US-0036 | 1 | "every netcode test at all four profiles" is true only of the harness |
| US-0044 | 1 | a human observer reading the startle waves |
| US-0054 | 1 | nothing draws the hiding spot's blindness |
| US-0056 | 1 | the rewound `at_tick` query is refused: nothing would consume it |
| US-0057 | 1 | the drawn arc — probably true, see above |
| US-0060 | 1 | NPCs rewound: nothing would read them |
| US-0063 | 1 | the tag `m4-the-loop`, owner decision 5 |
| US-0066 | 1 | a client-predicted tell: no client predicts a cast |
| US-0096 | 1 | the clone floor at every spawn point on the first tick: three of six have no room |

Two things are owed and are **not** criteria: the navmesh bake note in US-0012, and
`test_frame_rate_independence.gd`, which cannot exist headless.

## Nineteen things that will cost you an hour if you do not know them

*Short form. Each was paid for; the long form of every one is in the archive.*

1. **THREE THINGS ARE GENERATED, AND HAND-EDITS ARE SILENTLY REVERTED.** `scripts/core/ids.gd`,
   `scripts/core/tuning/*.gd` and `tuning_index.gd` come from
   `python tools/tuning_codegen/run_all.py`; the `.tres` under `data/tuning/default/` from
   `godot --headless --path . res://tools/generate_default_tuning.tscn`, run after it; the maps
   from `tools/generate_map_*.gd` over the layout tables. **A tool that touches a Core class must
   be a `.tscn`**: a `-s` script compiles before the autoloads exist, sixteen Core classes read
   `Tuning`, and the failure is cached for the process — a *"Nonexistent function"* four files
   from the cause. **`Ids` is harvested from `docs/`**: an id cannot be removed by deleting its
   row, nor quoted under `docs/` without being declared (`IdScanner.NOT_A_MEMBER`, mirrored in
   `gen_ids.py`); a retired id is declared dead (`InputActions.DEPRECATED`).
   `.ci/check_generated_code.sh` diffs against the index — stage first.
2. **`duplicate(true)` does not deep-copy a `TuningProfile`**; its sections are external
   resources. Use `TuningProfile.clone()`, or you write to the live profile.
3. **Verify against `git archive HEAD`, not the working tree.** Git keeps no empty directories,
   and the extraction has no `.git`, so a guard enumerating with `git ls-files` scans nothing
   there. Guards enumerate through `.ci/repo_files.sh`, which refuses an empty list.
4. **Both root scenes are booted by a test; nothing else is. Run the game after touching a
   scene.** A test that boots one must put the autoloads back in `after_each`. Assert the shape
   of a result, not its magnitude: *"moved more than half a metre"* was true of a pawn falling
   through the world.
5. **The Godot GUI editor rewrites `project.godot`**, deleting default-valued keys and every
   comment. `test_project_settings_pinned.gd` catches it; `git checkout project.godot` fixes it.
   `--headless --editor` is safe.
6. **A failed CI job with zero steps and no log is a billing refusal**, not a crash — read the
   annotation: `gh api repos/<owner>/<repo>/check-runs/<job-id>/annotations --jq '.[].message'`.
   A run that has not appeared at all may just be queued; it once took thirteen minutes.
7. **A state that writes `ctx.position` must return true from `drives_position()`**, or the
   driver's `move_and_slide()` overwrites it. Unit tests call `step()` and never see this.
8. **A state's own exit is not an interruption.** `step()` passes `interrupting = false`; gating
   completion on `is_interruptible()` freezes every uninterruptible state forever.
9. **Two tick domains.** `Tuning.ticks()` is the 30 Hz net tick; `Tuning.step_ticks()` the 60 Hz
   input rate. Anything counted inside `PawnState.step()` uses `step_ticks`; the wrong one
   halves a duration silently. Guarded under `scripts/pawn/`.
10. **GUT reports "nothing was run" as success.** Without `-ginclude_subdirs` it finds nothing,
    and a parse error makes it **skip the whole file**. Use `.ci/run_gut.sh`, which counts the
    scripts on disk; capture a run to a file and read the **top**, where the first error is.
11. **The function-length guard measures `func` to `func`**, so a function is charged for the
    docstring of the next one, and the message names the wrong function. The file guard counts
    a trailing newline: 400 lines by `wc` read as 401.
12. **`InputSampler.sample()` advances state and has exactly one caller**, `LocalPawnDriver`.
    Called twice a frame it ran input at 120 Hz and halved the sprint hold. Listen to
    `command_sampled` instead.
13. **`--headless` cannot read an input device**, so a headless diagnostic of one proves
    nothing; it can still *press* one (`Input.action_press`). `tools/input_probe.tscn` refuses
    to run headless and polls for twelve seconds.
14. **A document saying "X asserts Y" is not evidence that X exists.** Check it is a file and
    that something runs it. The claim is worse than the absence, because it stops the check.
15. **An unasserted scripted replace reports success by doing nothing.** Assert that the old
    text occurs exactly once before replacing. A stale count survived twelve PRs this way.
16. **Killing Godot mid-run corrupts `.godot/`**, and the symptom is a suite that prints its
    header and never finishes. Fix: `rm -rf .godot`, then
    `godot --headless --path . --editor --quit-after 600`. Stop only your own process ids —
    never by image name, which once ended every Godot process on the machine. Buffered stdout
    makes a healthy run look silent too.
17. **A missing row in a `.tres` reads as zero**, with no error. Write every tunable's row
    explicitly, even when it equals the script default.
18. **The lag-comp ring returns the older frame if a tick is recorded twice.** Clear the ring
    before refilling it in a test — `_settle()` in `test_stun_system.gd`.
19. **A pulled `.gd` has no `class_name` until Godot has imported it**, and the game does not
    import at runtime: the root script fails to parse, the window stays grey, and the errors
    name an autoload four files away. `play.bat` and `sandbox.bat` import first and stop on a
    parse error in the log, because Godot returns 0 from an import that failed. By hand:

    ```bash
    godot --headless --path . --editor --quit-after 300
    ```


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

`gdformat` writes CRLF on this machine; normalise with `sed -i 's/
$//' <file>`. A file that
shows as modified with an identical hash is stat-dirty: `git update-index --refresh`.

---

## The record before M5, and why it is not in this file

*The heading keeps its name because `test_claude_md_stays_findable.gd` pins it; the archive
now reaches past M5.*

This file is loaded into **every agent request**. It reached 6 594 lines by 2026-09-08 because
every checkpoint prepended a section and none removed one, with the tables and traps filed at
the bottom; and 204 KB — about 51 000 tokens a turn — by 2026-09-30, when the owner asked for it
to be made lean. **The archive holds the reasoning; this file holds what is true now.** An
archive nothing routes into is one nobody reads, so every file in `docs/00_meta/history/` is
linked here, and the guard refuses one that is not.

| In the archive | What it explains | Still live? |
|---|---|---|
| [`M0-M4_the_build.md`](docs/00_meta/history/M0-M4_the_build.md), moved 2026-09-08 | the pawn and the feel gate, the transport, the crowd, the loop, ADR-0013/0014/0015 | **yes**: upstream 145 %, downstream 112 %, GDD-05 §2.7 rule 8 short |
| [`M5_the_hud_and_the_abilities.md`](docs/00_meta/history/M5_the_hud_and_the_abilities.md), moved 2026-09-13 | the Compass that pointed the wrong way, the score feed, `SYS-ABILITY`, Cinderfall and the Lunge, ADR-0017/0018/0019, the pursuit, the bench, the `-s` autoload cascade, the codegen that destroyed shipped gameplay, the tick gate's estimator | **yes**: decisions 2 and 7; no animation clips |
| [`M5_the_match_and_the_reference.md`](docs/00_meta/history/M5_the_match_and_the_reference.md), moved 2026-09-30 | `SYS-MATCH`, the results and the skip vote, the seed and the multiplier on the wire, ADR-0020/0021, the persona deal, the dressed district, the bots, the reference match and ADR-0022/0023/0024, Cinderfall's catch, the camera and the Compass ring, the notices, the chase that outlived its contract — **and this manual's long form**: the owner decisions with their full reasoning, the state rows with their history, and the traps as first written | **yes**: decisions 11, 12, 14 and 15, ADR-0023 C |

**Read it when you need the reason for a rule, not before.** If a number here surprises you,
the archive is where it was measured.


## Fresh session? Read these four first

1. This file.
2. `docs/00_meta/GLOSSARY.md` — every term has exactly one meaning.
3. `docs/50_tuning/TUNABLES.md` — every number.
4. Your story file in `docs/40_backlog/stories/`.

Then the routing table above for the one or two documents governing your system. **Do not read
the whole corpus** — read the `depends_on` chain of what you need.

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

*Updated 2026-08-12. Keep this section current — it is the first thing a fresh
session reads, and a stale one is worse than none.*

**M0 IS COMPLETE. M1 IS 11 OF 12 AND CANNOT CLOSE YET.** US-0013 to US-0023 are
`status: done`; **US-0024 is `in-progress` and everything buildable in it is
built.** One of its four criteria is met (the commitment ceiling). The other
three are blocked, each by something real:

- **Input→animation cannot be measured.** `test_feel_latency.gd` exists and
  reads 16.7 ms slowing down, 33.3 ms accelerating from rest — three of the five
  stages `FeelChain` declares. `ANIMATE` has no clip to change pose and `PRESENT`
  has no display in headless CI. **The number is a lower bound and says so.**
  `test_feel_chain.gd` holds a tripwire that goes red the day a clip lands.
- **"With prediction active" needs prediction**, which is US-0032, in M2.
- **The feel-gate checklist is the owner's, and TWO OF ITS THREE LINES ARE NOW
  JUDGED.** On 2026-08-13 the owner logged *slowing is instant* and *the FOV
  ladder is perceptible without discomfort*, and settled
  `TUN-SPEED-RUN-RESOLVE` at 0.15 s — the one number in US-0090 chosen rather
  than derived. **The vault count is the only line left.** Ten sloppy vaults,
  tallied by the readout, and the criterion says *run and logged*, so it stays
  unticked until that number exists. The centred framing from US-0092 was judged
  with the lens and accepted.

**M1's remaining work is not code.** It is one human sitting down with the game.

**TWO STORIES ARE WRITTEN AND DELIBERATELY NOT BUILT**, both queued behind the
gate for the same reason: they change what `INPUT-TRAVERSE` does, and the gate's
second line *counts traverse presses*. Once Space always produces something,
"nothing happened" stops being observable and the vault tally stops meaning what
the checklist says.

- **US-0093** — a speed-scaled hop on §7.2's no-match case. An impulse rather
  than a fifteenth state, so the resolver stays the only owner of Space. **Open
  question: does a hop cost anonymity?** Raised, never ruled on, recorded rather
  than invented.
- **US-0094** — the steered wall cling. **It reverses GDD-02 §7's "assisted, not
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

**PLAYING THE GAME HAS FOUND SIX DEFECTS, ALL FIXED, NONE REACHABLE BY ANY TEST.**
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
| Tests | 103 architecture guards + 387 unit + 101 integration, all three counted in CI |
| Tuning | 277 tunables across 14 resource classes; all 23 cross-field invariants assert. **Eight IDs are deprecated** and recorded in TUNABLES §19 — never reused |
| Autoloads | All eight. `Tuning` precomputes 86 durations into **two** tick tables — see trap 7 |
| Strings | `data/strings/en.csv`, 56 keys, no user-facing literal anywhere else |
| Boot | Branches on `--server`; 7 CLI flags parsed in pure Core; 5 export presets |
| Map | `MAP-VETRAIO` greybox, 120 × 120 m. Client loads 28 meshes, server loads none. **Lit as of US-0091** — one key light and a sky, because nothing in the project had ever created either and the district rendered near-black |
| Pawn | 14 states declared — **the Jog rung was removed in US-0090** and `Jog` is a retired ID absent from `ALL`. Transition edges asserted against the normative diagram. **Eleven implemented**: five locomotion + `Vault`, `Climb`, `Drop`, `KillAnim`, `Stunned`, `Blended`. `Respawning`, `StunAnim` and `Dead` are M4 |
| Traversal | **Complete.** Probes cast, all seven §7.2 cases resolve from real geometry, both forgiveness windows open, and vault, mantle, climb, drop and gap jump all perform |
| Pawn body | `GreyboxBody`, procedural — capsule, head and a chest marker on `+Z`, measured from the collider so the two cannot drift. **`PersonaVisuals` was empty through US-0021, 0022 and 0023**: three stories of camera work built around a pawn that did not render, every suite green. Not a persona — ART_BIBLE §6.1's four constructions are US-0039's |
| Camera | Real spring arm: 2.6 m, **pawn centred** (US-0092 — the 0.45 m offset never changed the composition, because the rig aims at the pawn's own axis; `INPUT-SHOULDER` retired with it), occlusion that pulls **in** and never sideways, `WORLD`-masked so a crowd cannot push it. The FOV ladder is bound to the **state**, never to `ctx.velocity`: the rung is a consequence of the decision, not of the physics that follows it. Crowd-scan narrows to 48° and grants nothing. **Positive pitch LOWERS the arm** — the rig looks *at* the pivot, so a raised arm looks down; it shipped inverted from US-0021 until somebody played it |
| Input | 20 `InputMap` actions from 14 live `INPUT-` IDs — `INPUT-SHOULDER` is retired via `InputActions.DEPRECATED`, still in the corpus and bound to nothing, KBM + pad. Chain GDD-02 → `Ids` → `InputActions` → `project.godot`, guarded on every hop, both directions. **Sampled once per physics frame by `LocalPawnDriver`, the only caller** — see trap 12. The mouse is **captured** on boot; `INPUT-MENU` releases, a click takes it back. **Only a mapped gamepad holds the joypad bindings** — `PadSelection`, applied through the one `InputMap` writer, because a set of sim pedals was steering |

**Ten criteria are deliberately unticked**, each blocked by something real. A
prose count of these has now drifted three times, so they are a table — and the
story files are the source of truth, not this:

| Story | Unticked | Blocked by |
|---|---|---|
| US-0002/3/4/5 | four "required check on `main`" lines | branch protection needs GitHub Pro on a private repo. TDD-12 §1.3 |
| US-0019 | root motion for hand and foot placement | there are no animation clips |
| US-0022 | motion-reduction's compensating indicator | the FOV **lock** is done and tested; the persistent speed indicator belongs to the HUD, US-0084 |
| US-0023 | ambience ducked, footsteps sharpened | `Audio.play()` is an empty stub until US-0075 |
| US-0024 | input→animation measured; ≤ 80 ms with prediction; the feel-gate checklist | no clips; prediction is US-0032 (M2); the checklist is the owner's to run |

The navmesh **bake** is likewise owed and recorded in US-0012. **Nothing here is
forgotten and nothing is half-ticked** — a story marked done over a criterion
that is not true makes the whole backlog unreadable as a status view.

### Thirteen things that will cost you an hour if you do not know them

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
4. **The CLIENT scene is booted by a test now; the server scene is not.**
   `test/integration/test_client_boot_walks.gd` drives the real client through
   the real bindings. Everything else is still unbooted, and this trap has bitten
   twice: `change_scene_to_file` from `_ready()` failed with 92 tests green, and
   spawning through `transition()` into an unimplemented state failed with 222.
   **Run the game after touching anything scene-related.**
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

### Local environment

Godot and gdtoolkit are not on `PATH` on this machine:

- `C:\Users\Slimex\Desktop\Godot_v4.7.1-stable_win64.exe`
- `C:\Users\Slimex\AppData\Roaming\Python\Python314\Scripts\gdlint.exe`

`.ci/run_gut.sh` invokes a bare `godot`, so shim it before running a suite:

```bash
printf '#!/usr/bin/env bash\nexec "/c/Users/Slimex/Desktop/Godot_v4.7.1-stable_win64.exe" "$@"\n' > /tmp/shim/godot
chmod +x /tmp/shim/godot
export PATH="/tmp/shim:/c/Users/Slimex/AppData/Roaming/Python/Python314/Scripts:$PATH"
```

---

## Fresh session? Read these four first

1. This file.
2. `docs/00_meta/GLOSSARY.md` — every term has exactly one meaning.
3. `docs/50_tuning/TUNABLES.md` — every number.
4. Your story file in `docs/40_backlog/stories/`.

Then the routing table above for the one or two documents governing your system. **Do not read
the whole corpus** — read the `depends_on` chain of what you need.

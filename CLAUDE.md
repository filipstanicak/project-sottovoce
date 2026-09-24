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

### 2026-09-24 — the district wears its personas, US-0101

**ASKED FROM THE CONTROLS THE TICK US-0100's PLAYTEST PASSED: *"Du kannst bereits
den NPCs unterschiedliche Farben geben."*** The portrait named a persona and
nothing on screen looked like one. ART_BIBLE §3 had reserved four identity hues
since M0 and `data/personas/*.tres` had held them since US-0046, **read by
nothing**; `PersonaBody` had built the four silhouettes since US-0046 and been
instantiated by one tool. Every figure — player and clone — is a `PersonaBody`
now, clothing in its hue and props neutral. `GreyboxBody` is retired: an
undressed `PersonaBody` draws the same generic figure.

**THE CROWD CANNOT BE DRESSED WITHOUT THE PLAYERS, AND THAT IS THE WHOLE DESIGN.**
Coloured clones around grey players name every player, and so does the reverse.
The two halves arrive in two messages at two moments — the roster at the
countdown, the seed at `ACTIVE` — so `Wardrobe` dresses **nobody** until it holds
both, then everybody in one pass. The seed alone and the roster alone are each a
test; so is `NpcView` never dressing a body itself, which would go round the gate.
The crowd is derived with the **server's** arguments (`CrowdRoster.PLAYABLE`,
`TUN-LOBBY-MAX-PLAYERS`), never the dealt set, and a test holds the client to
`server_root`'s call site.

**THE ROSTER IS `NET-S2C-LOBBY-STATE`, AN M0 ROW, NOT A NEW ID.** It has read
`players[]{peer_id, persona, ready}` since M0, which is US-0078's criterion 4;
`ready` is left out until the lobby gives it a writer. Re-sent on the deal, every
join and every departure. `PROTOCOL_VERSION` 3 → 4 — and 3 had no line in
`messages.gd` saying why, which it has now.

**TWO GUARDS SPOKE BEFORE ANY PLANT DID.** `.gdlintrc`'s twenty-public-method cap
split `SessionWire` out of `EventWire` — along a line that was already there,
because `NET-S2C-MATCH-START` rode `SESSION` in the class that called itself the
`EVENT` doorway. And `test_a_script_tool_gets_no_autoloads.gd` found
`tools/persona_lineup.gd` unloadable: `PersonaBody` now reaches `CrowdRoster`,
which reads `Tuning`. It is `persona_lineup.tscn` now, trap 1's fourth tool.

**AND THE FIFTH ASM-0030 LEFTOVER, IN THE SAME FILE AS THE SECOND.**
`EventWire.contract_assigned`'s docstring still said a hunter learns nothing about
who they hunt *"until a Compass lock earns it"*. Found while moving code past it,
which is how every one of the five has been found — never by a grep for the id.
Also fixed on the way: US-0100's `depends_on` named `BIBLE-NETWORK-PROTOCOL` and
`GDD-03-SOCIAL`, neither of which exists. Corpus-wide it is **five** such links, not
the 42 first written here — that count was a substring grep matching every correct
`GDD-03-SOCIAL-STEALTH` too. The guard for them is #233.

**AND THE REVIEW FOUND THE GATE COULD BE HELD OPEN BY THE LAST MATCH.**
`GameState.clear()` said *"called on disconnect"* from M0 and **had no caller under
`scripts/`**; `Net.stop()` cleared peers and pings and left the seed and the roster
standing. Harmless while nothing drew them — and from this story a lost server left
both halves of the gate true, so the next lobby's undealt roster would reopen it and
dress the crowd from the old seed around undressed players. `Net.stop()` calls it
now, and the test that proved it goes through ENet's own `server_disconnected`: the
old one called `clear()` directly, so it proved a function nobody ran.

**WHAT IS STILL NOT THE DESIGN.** Colour is a placeholder for costume. The Noticed
tint and Exposed outline are unbuilt on the client, so every figure of a persona is
the same colour at every tier — which is the safe direction.

Falsified, seven plants one at a time, all red by name. Local: unit 216 / 1 835 /
1 827 / 32 685; arch 60 / 238 / 1 537; integration 33 / 244 / 243 / 189.1 s.

### 2026-09-24 — the persona is dealt at the countdown, US-0100

**OWNER DECISION 13, TAKEN.** `PawnContext.persona` is declared under *Identity*
two lines below `peer_id` and **had no writer under `scripts/`** — the eighth
instance of this corpus's most-repeated shape, and four things waited on it.
`MatchConsequences.deal_personas` is its first, dealt from `MatchContext.rng` in
the same breath as the contract cycle, duplicates permitted because US-0078
already calls them *good: they add a candidate to each other's crowd*.

**THE SPLIT TOOK NO CRITERION FROM US-0078**, which is the correction #229's
review forced: what moved is a *precondition* the story implies without stating.
`NET-C2S-LOADOUT` replaces the deal at M6 rather than enabling it — decision 1's
argument about the countdown trigger, applied a second time.

**THE HUNTER IS TOLD THE FACE, AND `PROTOCOL_VERSION` IS 3.**
`NET-S2C-CONTRACT-ASSIGNED` carries a `PersonaWire` index, which makes
`CrowdRoster.PLAYABLE`'s order a **protocol** as well as a derivation input — it
already decided every roster every seed produces, and now it decides what a client
draws. Append-only, guarded the way `PawnStateId.ALL` is. `NONE` is 255 and a real
reading: nobody has a persona before the countdown, and an index a client cannot
resolve draws the featureless bust rather than a plausible wrong face.

**THE CLONE FLOOR IS REAL FOR THE FIRST TIME.**
`CrowdDirector.personas_in_use` defaulted to all four because nothing could say
which were played; narrowed to the dealt set, the 2 s rebalance pass fetches
clones for the personas actually in the district. **The boot roster is
deliberately not re-derived** — `CrowdRoster.derive` runs before any player has a
persona, and re-rolling it at the countdown would churn the whole district in
front of the lobby.

**AND THE REVIEW THEN FOUND A DEFECT IN *BOTH* UNTICKED CRITERIA, WHICH IS THE
STRONGEST ARGUMENT FOR NOT TICKING THEM.** Three ordering defects, each code that
ran inside a green suite and did the wrong thing across a boundary no single unit
could see. **The countdown announced the persona from the previous deal**:
`ContractSystem.open` announces synchronously and the deal ran on the line after
it, so every hunter was told a face the target was not wearing while the server
and `CloneBalance` already used the new one. **A lobby join was dealt to**, against
this story's own rule that nobody holds a persona before the countdown — and it
**spent the match generator**, so the recorded seed stopped reproducing the
district, which is the one property `PersonaDeal` exists to keep.
**And a departure never refreshed `personas_in_use`**, so the last wearer of a
persona leaving left the 2 s pass fetching clones nobody wore for the rest of the
match. The deal runs first now, `MatchPhase.is_simulating` gates the join, and
`MatchConsequences.peer_left` closes the third; both criteria are ticked on tests
rather than on the implementation.

**AND THE SAME ASM-0030 SENTENCE SURVIVED A SECOND SWEEP, ONE FILE OVER.**
`match_announcer.gd` still read *"no persona, no position, no tier … the cheapest
possible way to give that away"* — the argument ADR-0021 voided, stated without
naming the assumption, exactly as `event_wire.gd` had. **A grep for the id found
neither.** Two instances now say what they used to say.

**AND THE DOCSTRING I WROTE FOR THE RESPAWN RULE WAS THE ONLY THING ASSERTING
IT.** US-0100's third criterion says the deal survives death; `pawn_context.gd`
explains why in four lines; and planting `persona = &""` inside `reset_for_spawn`
ran **the whole unit suite green**. Trap 14's family in my own work, caught by
falsifying rather than by reading. `test_a_respawn_keeps_the_persona.gd` exists
now and the same plant reads *"a respawn took the player's identity away"*.

**AND #228's SWEEP HAD MISSED ONE PASSAGE, IN THE FILE THIS STORY CHANGES.**
`event_wire.gd`'s `s2c_contract_assigned` docstring argued *"a persona field here
would collapse [seventy-eight candidates] to twelve, silently, in every match"* —
ASM-0030's argument, void since ADR-0021. Both the reviewer and I grepped for the
**id**; this passage states the rule without naming it, which is the half a grep
cannot find. Corrected here, with what it used to say.

**DELIBERATELY NOT IN THIS STORY: the results table's personas.**
`MatchEndReport` carries `anonymous_ticks`, `kits` and `events` and no persona, so
`ResultsRoot` could not draw one if it wanted to. That needs its own transport and
**a second `PROTOCOL_VERSION` bump** — the cheaper mistake, because shipping the
field here with no reader is the very shape this story just gave a writer.

Six plants, one at a time: `randi` for the seeded generator, `PLAYABLE` reordered,
the respawn clearing the persona, and the review's three — the deal after
`contracts.open`, the join gate removed, `peer_left` refreshing nothing. Each red
by name.

Local: unit 212 scripts / 1 809 tests / 1 801 passing / 32 500 assertions;
arch 60 / 238 / 1 540; integration 33 / 244 / 243 passing / 189.0 s.

### 2026-09-23 — `PawnContext.persona` has never had a writer, and four things wait on it

**PREPARING OWNER DECISION 13 FOUND IT.** ADR-0021 was the fourth thing to end
up waiting on US-0078, so the story was read criterion by criterion the way
decision 1 read US-0079 — and the field the whole question turns on is declared
in `pawn_context.gd` under *Identity*, two lines below `peer_id`, **with no
writer anywhere under `scripts/`**. The only assignments in the tree are to
`PersonaBody.persona`, in a test and a tool. Eighth instance of this corpus's
most-repeated shape: *a field nobody reads and nobody writes is
indistinguishable from one that works.*

**THE FOUR ARE THE PORTRAIT (ADR-0021), THE RESULTS SCREEN'S SLOT LABELS
(US-0077), `CloneBalance` BEING TOLD ALL FOUR PERSONAS ARE IN USE, AND
US-0073's PORTRAIT CRITERION** — and **none of them wants a lobby**. They want
a player to *have* a persona, which `MatchSystem.countdown_opened` could deal
from `MatchContext.rng` in the same breath as the contract cycle. The lobby then
**replaces** the deal rather than enabling it, which is decision 1's own
argument about the countdown trigger, applied a second time.

**AND THE REVIEW CORRECTED THE SHAPE OF THE PROPOSAL, WHICH IS WORTH MORE THAN
THE PROPOSAL.** My first write-up read as though criteria *moved* from M6 to M5.
None do: what the split extracts is a **precondition** — that a player has a
persona — and all nine criteria stay. It also understated the wire: one byte on
`NET-S2C-CONTRACT-ASSIGNED` feeds the portrait and nothing else, because
`MatchEndReport` carries no persona field, so the **results table needs its own
transport** and *persona selections are VISIBLE to all players* needs a roster
that one per-contract byte can never be. And the three US-0071 blockers had one
reason between them where they have three. Decision 13 says all of that now;
splitting a story is still the owner's call.

### 2026-09-22 — the hunter knows the face from the start, ADR-0021

**REPORTED FROM THE CONTROLS AFTER THE ALONE-GAIN PLAYTEST PASSED ON EVERY POINT:
*"der Contract zeigt Unknown und wenn ich in der Nähe bin, identified. Wie mein Opfer
aussieht muss ich von Anfang an wissen … Wie macht das Original es?"*** The reference
shows the target's picture from the moment the contract is assigned; its uncertainty
is *which of the identical figures is the human*, never *which persona*, and its lock
is a targeting act. Ours (ASM-0030) showed `UNKNOWN` until a 20 m / 1.6 s Compass
lock, on GDD-03 §8.5's strongest row: *"if you knew your target was a Lucerna, the
crowd would collapse from 60–90 candidates to 8–13."*

**THAT COLLAPSE IS THE GAME, AND M3 WAS BUILT FOR IT.** `CloneBalance`,
`TUN-CROWD-CLONE-LOCAL-MIN` and the clone-parity rules exist so that the 8–13 are
indistinguishable from the player; US-0078 says duplicate personas are *good*. The
hidden persona was a second protection against the same threat — and it fell on the
skill the game is about: a player cannot learn whose gait to read if they do not know
whose gait to compare against, so the hardest read was unlearnable until the lock did
it for them, which inverts design law 4. **ASM-0030 is void**, §8.5 loses its persona
row (struck, with the reason), GDD-06 §B and UI_UX_SPEC row B say *from assignment*,
and owner decision 4 closes with it.

**NOTHING CHANGES ON THE WIRE HERE, BECAUSE THERE IS NOTHING TO SEND.** A player has
no persona server-side until US-0078's lobby; when they do, the persona travels with
the contract — one byte on `NET-S2C-CONTRACT-ASSIGNED`, a `PROTOCOL_VERSION` bump —
recorded on that row when it lands. The lock keeps its 1.5 s silhouette reveal (the
only thing that names the *body* among the clones), `SCORE-FOCUS`, `PASV-COLDREAD`
and the `portrait_revealed` latch, whose meaning narrows to *a lock has completed for
this contract*. US-0073's portrait criterion is reworded and stays unticked, blocked
on US-0078 rather than on an assumption.

**THE REVIEW OF THIS CHANGE FOUND THE HALF I HAD NOT SWEPT, AND IT IS THIS
CORPUS'S MOST-REPEATED SHAPE.** I voided the assumption and amended the documents
that *state* the rule — and left every document, comment and test that *depends*
on it saying the old thing: the bus catalogue's "never appears" row,
NETWORK_PROTOCOL §9's checklist line, TDD-07 §4.5.2's recorded leak, and nine
source files whose comments and test names defined the latch as an identity
earned by looking. **A decision that is not swept is a decision the next reader
finds twice, in two versions.** All of them converge now; the wire rows still say
no persona is carried *today*, marked as US-0078's gap rather than a prohibition.

**AND THE EVENT HAD A PAYLOAD NOBODY COULD FILL.**
`EVT-CONTRACT-PORTRAIT-REVEALED` was declared `(persona: StringName)` against a
`PERSONA-*` id — and `HudBridge` emitted `&""` while `PortraitWidget` ignored the
value. Under ASM-0030 that was an honest placeholder for something the lock would
one day earn; under ADR-0021 it is a lock-completion fact with nothing to carry,
so **the signal is parameterless** and the guard is its own arity. The `EVT-` id
stays, because ids are immutable, and so does the snapshot's `portrait_revealed`,
which stored a per-contract completion latch all along. Planted, the parameter
back: red by name.

**AND THE CLONE CLAIM IS NOW QUALIFIED RATHER THAN ASSERTED.** The ADR leant on
*"the clone system already covers it"*; the reviewer asked which clone system.
The **designed** one — and today's is short in two measurable ways, both
release-blocking: the local floor is scoped by `CloneParity.grace_seconds()`
19.86 s, and animation parity is half-built because neither rig has clips, so a
clone and a player are identical partly *because neither is animated*. Written
into the ADR, because a decision resting on a protection should say which
protection it means.

**AND THE REVIEW OF #227 LEFT TWO TEXT NOTES, BOTH TAKEN.** ADR-0020 said the
crowd-query tests ran *on a copy*; the Core tests do, the system test writes the live
profile for its own duration, and the sentence says so now. Three comments still
priced sprint-on-a-roof-alone at 49/s and sprinting alone at 31/s — the old figures
are kept beside the new ones, marked as history.

Local: unit 208 scripts / 1 782 tests / 1 774 passing / 32 424 assertions;
arch 58 / 231 / 1 457; integration 33 / 244 / 243 passing / 189.7 s — remeasured
because the bus signal changed shape, not because a count did.

### 2026-09-15 — walking alone costs nothing, ADR-0020

**REPORTED FROM THE FIRST TIMED MATCH: *"Ich bin bereits exposed wenn ich mal
alleine laufe ohne Gruppe. Das ist ja im Original auch nicht so."*** It was true
and it was designed. `TUN-SUSPICION-GAIN-OPEN` paid 6/s whenever no NPC stood
within 6 m, at any speed including standing still, and because no decay runs while
any source pays, a stroll with nobody near reached **Noticed in 5 s and Exposed in
11.7 s** — GDD-03 §3.2 published both numbers as the feature. **The reference
charges nothing for being alone**: its meter moves on high-profile actions in the
other player's sight, and walking is low profile wherever it happens. Sources in
the chat log of 2026-09-15, never in the repo (never-do #5).

**NEUTRALISED TO 0, NOT REMOVED — `TUN-SCORE-RECKLESS`'S PATTERN.** The ID, the
field, the radius and the condition all stay; `SuspicionSources.of()` lists the
`OPEN` bit **only while its rate is above zero**, because a HUD word beside a value
that is not rising is the drift that file exists to refuse. Bit 3 keeps its wire
slot. Restoring the number restores the mechanic in one edit, and the tests that
prove the crowd query is wired run with the number restored on a copy — or, at the
system's seam, on the live profile for the test's own duration, put back in
`after_each`, the one write to `Tuning` under `test/`.

**WHAT IT COSTS IS SAID IN THE ADR RATHER THAN SMOOTHED OVER.** Design law 2 loses
the background pressure toward company on an ordinary walk; the reference shows
the pressure is that a lone figure is *readable*, which is law 6's kind of
uncertainty. Piazza Secca and the Campanile are visually dangerous now rather than
charged; the Campanile still pays the roof toll. `TUN-CROWD-COUNT-MIN`'s rationale
stands on the blend argument alone.

**AND REGENERATING THE TUNING FOUND A MIRROR THAT HAD DRIFTED IN TWO DAYS.**
`gen_ids.py` carries a Python copy of `IdScanner.NOT_A_MEMBER`; #225 added
`ANIM-CINDERFALL-CAST` to the GDScript one and not to the copy, so the next
`run_all.py` minted a constant for the id the guard had refused.
`test_the_codegen_mirror_of_the_exemptions_is_current` holds the two sets equal now.
Three plants, one at a time: 6.0 back in the profile, the rate gate removed, the
mirror entry removed — each red by name.

**TWO OWNER DECISIONS RAISED, NEITHER TAKEN HERE.** The reference's meter is per
(pursuer, target) and gated on sight where ours is one number per player read by
everybody — decision 11. And the Final Contract's `×2`, asked about from the
controls the same day, has no counterpart in the reference, whose clock merely turns
red at one minute — decision 12.

Local: unit 208 scripts / 1 782 tests / 1 774 passing / 32 424 assertions;
arch 58 / 231 / 1 457; integration 33 / 244 / 243 passing / 189.7 s.

### 2026-09-13 — the match timer is on the HUD, US-0073's timer line

**A PLAYER CAN SEE HOW LONG IS LEFT FOR THE FIRST TIME.** `MatchTimerWidget`,
top-centre, 120 × 48: `M:SS` rounded *up* so the last tick reads `0:01`, a thin
bar that fills through the last `TUN-MATCH-FINALPHASE-WARNING` before the Final
Contract, and the phase treatment with a persistent `×2` through `FINAL`. Blocked
since 2026-09-06 on *"there is no match"*; US-0079 gave the three wire fields a
writer and this is the reader.

**THE BAR IS DERIVED FROM THE AUTHORITATIVE CLOCK AND NEVER COUNTED DOWN HERE.**
The server's warning is a signal that reaches no client, so `MatchVm` reads the
snapshot's `ticks_remaining` against the same two tunables `MatchClock.warning_at`
reads — arithmetic over a number the server sent, not a prediction (never-do #3),
and nothing advances between snapshots (UI_UX_SPEC §3.3). **The tick the bar is
full is the tick `FINAL` opens**, asserted from both derivations, and it holds only
because `ACTIVE`'s remainder already includes the whole of `FINAL`: the plant that
forgets that subtraction fills the bar thirty seconds late.

**THE CLOCK REACHES THE HUD THE WAY THE RESULTS SCREEN'S DOES** — a local
`HudBridge.match_time_changed`, on change, for `ACTIVE` and `FINAL` only, wired by
the root; the phase and the multiplier still ride `EVT-MATCH-PHASE-CHANGED`. A
global event carrying a number that moves thirty times a second is the one thing
the bus was built not to carry.

**AND THE SPEC DISAGREED WITH ITSELF BY THE HEIGHT OF THE BAR.** §2 listed the timer
at the 48 px `DISPLAY` scale; §1.1 gives the element 48 px of height. The digits are
`HEADING` 32 px, sized to the plate. My first pass *named* the contradiction in §1.1
and left §2 standing; the review asked for the table to be settled rather than
annotated, so §2 carries the timer under `HEADING` now, with the old row and the
reason preserved. **The same review counted the string table**: 105 keys, not the
106 I had written — I had counted the CSV header as a key.

Captured as `hud_21`–`hud_23` in `tools/hud_probe.tscn` and looked at: all three
faces draw as designed. What is still open on US-0073 is the ability slots, which
wait on US-0071's loadout, and the portrait's persona, which is ASM-0030's. Unticked
criteria: 49, regenerated.

Local: unit 208 scripts / 1 779 tests / 1 771 passing / 32 047
assertions; arch 58 / 230 / 1 454; integration 33 / 244 / 243
passing / 189.1 s — measured rather than carried, because
`test_client_boot_walks.gd` boots the real client root and the root now builds the
timer.

### 2026-09-13 — the M5 narrative is archived, 3 976 → 1 516 lines

**TWENTY-EIGHT SECTIONS, 2 471 LINES, MOVED TO
[`docs/00_meta/history/M5_the_hud_and_the_abilities.md`](docs/00_meta/history/M5_the_hud_and_the_abilities.md)**
— everything from the tick gate's second failure (2026-09-04) back to US-0097,
in the order it held here so *"the section at the top of this file"* still means
what it meant. The four 2026-09-08/09 sections on the match, the results and the
seed stay at the root because this section points at them. Nothing live moved:
the tables, the unticked table and the traps hold every fact those pages carried.

**AND THE MOVE ITSELF FOUND ONE THING.** The archived prose quotes
`ANIM-CINDERFALL-CAST` — the id `test_ids_match_glossary.gd` *refused* on
2026-09-03 — and under `docs/` the harvester reads it as a declaration. Trap 1's
own rule, from the other side: an id cannot be removed by deleting its row, and it
cannot be *mentioned* under `docs/` without being harvested. `IdScanner.NOT_A_MEMBER`
carries it with the reason.

### 2026-09-13 — US-0079 is done: the final warning is an announcement, by owner decision

**OWNER DECISION 10, TAKEN.** The story's first criterion read *"All six phases"* from
the day it was written; `MatchPhase.Phase` has five members and their ordinals are
the wire, so a sixth name for something the next criterion says changes no rules
would have remapped every client's phase. It was built as an announcement on
2026-09-08 and **left unticked for five days rather than reworded**, because
rewriting a criterion to match what was built is the owner's call. The owner took
it; the criterion now says five phases and one announcement, and US-0079 is
**eight of eight**. Unticked criteria: 50, regenerated. Five things wait on the
owner now.

### 2026-09-13 — the snapshot's multiplier carries tenths, protocol version 2

**A LINE, AND A FORMAT CHANGE, AND SAYING WHICH IS THE POINT.** `Snapshot.multiplier`
was a whole-number byte from US-0079 and could not carry `TUN-MATCH-FINALPHASE-MULT`'s
own `@export_range(1.5, 3.0, 0.1)` — a re-priced 1.5 would have been announced to
every HUD as 2 while scoring paid 1.5. `ScoreWire.MULT_STEP` had sent tenths one file
over since US-0074; the snapshot codec uses the same conversion now, so the two rows
agree about how one value is encoded. Reported on 2026-09-08 rather than fixed, because
the format had been frozen the same day; fixed now, deliberately, with the two things
a format change owes.

**THE FROZEN BYTES WERE RE-FROZEN BY HAND, ONE BYTE PER FIXTURE.**
`test_snapshot_wire_compatibility.gd` says *never regenerate from the new codec*, and
regenerating would have proved only the codec's opinion of itself. The multiplier
byte sits after `ticks_remaining`: `01`→`0a` in EMPTY, `02`→`14` in the other two,
and every other byte is still `81f38d4`'s.

**AND `PROTOCOL_VERSION` IS 2**, because the width did not change and the meaning did:
an old client reads **20** for 2.0, which is precisely the misreading the handshake
exists to refuse at the door. Planted, the reader forgetting the step reads exactly
that.

**THE GUARD WENT FROM A TIME BOMB TO A PROPERTY, AND MY FIRST VERSION OF IT PROVED
THE WRONG CODEC.** `test_the_announced_multiplier_is_the_one_that_pays` used to go
red the day the tunable stopped being whole; it now round-trips every value in the
band. The first draft round-tripped through `ScoreWire`'s helper — green whether or
not the snapshot encoder called it. It goes through `Snapshot.serialise` /
`deserialise` now, and the encoder reverted to whole numbers reads *"1.5 …
misannounced"* by name.

Local: unit 207 scripts / 1 767 tests / 1 759 passing / 32 011
assertions; arch 58 / 230 / 1 438; integration 33 / 244 /
243 passing / 189.2 s.

### 2026-09-13 — the seed reaches every client, US-0079's last open criterion

**`NET-S2C-MATCH-START` HAS A SENDER AFTER FIVE MILESTONES ON THE WIRE.** It is
sent at the transition into `ACTIVE` to every player, and from `peer_joined` to a
late joiner, because *once* in the catalogue is per recipient: the crowd is
replicated positionally and never by identity, so nothing else carries what
`CrowdRoster` derives from this. The seed travels as a true `u64` in a thirteen-byte
hand-packed row — a Variant-encoded argument would have let a 32-bit encoder pass
every playtest seed under four billion and fail the top bit in silence.

**IT IS ON `SESSION` AND NOT `EVENT`, FOR THE ORDER.** A late joiner is welcomed
from the handshake and told the seed a moment later; only the same ordered channel
as `NET-S2C-WELCOME` guarantees the second lands after the first. The catalogue
has said X since M0 and my parked draft said `EVENT` — reading the row before
applying the draft is what caught it. The same read found my own drift the other
way: `NET-C2S-SKIP-RESULTS` documented on X and built on `EVENT` at US-0077.
Both catalogues corrected.

**THE SINGLE-WRITER GUARD LISTED ITS MUTATORS, THEN DERIVED THEM FROM A
SIGNATURE, AND THE REVIEW BROKE THAT IN ONE MOVE.** `GameState` gained
`adopt_match`, its third mutator, and `test_game_state_single_writer.gd` held
`replace` and `clear` in a two-entry constant — so the new one would have joined
the file without joining the guard. My first derivation read every `-> void`
function as a mutator. Codex gave `adopt_match` a `bool` to return, kept every
write, added a call from a presentation script, and the guard passed: **a
signature is a convention; a write is a fact.** It classifies by what a function
writes now — a top-level `var` assigned in the body, or a call to a function
that does, closed to any depth, which is what keeps `clear()`. Pure over the
source text, so his counterexample is a test rather than a story, and the same
plant on the real tree reads `hud_bridge.gd:260 calls GameState.adopt_match()`
with the `bool` in place.

**AND THE CHANNEL TABLE WAS A THIRD SOURCE IN DISAGREEMENT, WHICH THE REVIEW
ALSO FOUND.** `Messages.CHANNEL_FOR` calls itself the place a channel is
*declared once* — and every `@rpc` declares it again as a constant, because an
annotation cannot read a table. Nothing held the two together, so
`NET_C2S_SKIP_RESULTS` said `SESSION` in the table while the handler ran on
`EVENT`, and correcting both catalogues had left the table behind.
`test_rpc_channels_match_the_table.gd` reads the channel off every `@rpc` under
`scripts/net/`, derives the id from the handler's name, and holds the table to
it — and on its first run it found a **second** row: `NET-S2C-BLEND-DENIED`,
built at US-0054, had **no row at all**, which `channel_for` had been answering
with -1 for as long as nobody asked. No plant was needed; `main` was the plant.

**AND A DRAFT DOCSTRING CLAIMED EXACTLY THE DERIVATION THAT DID NOT EXIST.** The
parked `adopt_match` note said the guard *"derives its mutator list from this
file rather than listing it"* — trap 14 in my own prose, caught by reading the
guard before trusting the sentence about it.

**`MatchContext.crowd` ALREADY HELD THE POOL, AND THE FIRST DRAFT WIRED A SECOND
ROAD TO IT.** A `Callable` from `server_root` into `MatchConsequences` — one more
line, which took `server_root.gd` to **401** and the length guard asked the
question. The announcer reads the context it already holds; the `Callable` is
gone, and `server_root` is 399.

**FIVE PLANTS, ONE AT A TIME AGAINST THE SUITE THAT OWNS EACH.** The one that
matters: `MatchSystem._enter` writes `active_started_at` on the line before it
emits `phase_changed`, and `started_for` refuses a match with no start tick —
swap those two lines and every live client goes untold while a hand-raised
transition stays green. The test drives the real `MatchSystem` for that reason,
and reads **0 of 6** under the swap.

Local: unit 207 scripts / 1 767 tests / 1 759 passing /
31 995 assertions; arch 58 / 230 / 1 438; integration 33 / 244 /
243 passing / 189.1 s.

### 2026-09-09 — a grey window after a pull, and the launcher now imports first

**REPORTED FROM THE CONTROLS THE TICK AFTER US-0077 LANDED: *"wenn ich play.bat 3
ausfuehre bekomme ich dauerhaft diesen Fehler und anschliessend einen greyscreen
von godot"*.** The error quoted was `Net.assembler` on a base of type `Nil`, in
the debug readout — **four files from the cause and not the defect at all**. The
head of the log carried it: *"Parse Error: Could not find type `ResultsRoot`"*,
and then `client_root.gd` failing to load outright. A root scene whose script
will not parse still **instantiates**, so the window opens, nothing builds the
map or the camera, and every later reader of an autoload shouts about a `Nil`.

**A `class_name` DOES NOT EXIST UNTIL GODOT HAS IMPORTED THE FILE, AND THE GAME
DOES NOT IMPORT AT RUNTIME.** #217 brought five new presentation scripts; the
pull brought the files and not the cache entry. `play.bat` and `sandbox.bat`
import first now — 4.4 s warm — because with two agents **every pull is somebody
else's new script**, and trap 1 only ever covered the committing end of it.

**AND I NEARLY MISSED IT BY FIXING IT.** The first command of the investigation
was the import pass, which repaired the owner's checkout before I had reproduced
anything — three later runs came back clean and the report looked unreproducible.
What settled it was the *other* worktree, which had not been imported since the
merge: same grey, same parse error, first line of the log. **Trap 19.**

### 2026-09-09 — PR #217 reaches the clients and ends on the server clock

The results presentation now consumes the full report with ScoreFold and
ScorePlacement, including explicit shared winners. ClientRoot connects the skip
button to Net.requests.send_skip_results. HudBridge forwards RESULTS time; zero
hides the surface without inventing a lobby or restarting gameplay.

After rebasing onto #220, one server and three real clients pass both paths:
staggered votes keep the screen open until unanimity, and a separate no-vote run
ends at natural expiry. The earlier snapshot-delivery blocker is resolved.
The reproducible scene is tools/results_network_probe.tscn; --natural-expiry on
all clients selects the second path. ACTIVE/FINAL alone are accelerated fixtures.

US-0077 remains in-progress: persona/passive and player names are unavailable.
The shipped kit, death counts and Anonymous time are shown against slot labels.
No vote tally is transmitted, so none is invented. The server stays in RESULTS
after expiry; the next lobby is US-0078's work.
### 2026-09-09 — the results screen was receiving no snapshots at all

**A DEFECT IN WHAT I SHIPPED THE SAME DAY, FOUND BY THE SECOND AGENT.**
`MatchDirector` emitted the end of a tick only while `MatchPhase.is_simulating`,
so the instant a match reached `RESULTS` the snapshots stopped: every client's
last one said `FINAL`, `ticks_remaining` froze on whatever the final tick
carried, and **the unanimous skip I had just built had no channel to end the
screen through**. I had told Codex his screen could simply read the field it
already reads. It stops arriving.

**`MatchPhase.is_watched` IS THE DISTINCTION THAT WAS MISSING.** *Nothing
advances* and *nobody is told* are different questions. Stages still run only
while simulating; `tick_completed` now fires in `RESULTS` too, and the one
consumer that must not run outside play says so itself — `LagCompRecorder`
guards on `is_simulating`, because the ring holds what a kill may be validated
against. `LOBBY` stays silent: there is no world to describe yet.

Local: unit 202 scripts / 1 739 tests / 1 731 passing / 30 534 assertions; arch
57 / 224 / 1 285; integration 33 / 244 / 243 passing / 189.3 s.

### 2026-09-09 — the results can be skipped, and a tie is not broken

**`NET-C2S-SKIP-RESULTS` IS BUILT AND IT COST THE SPLIT `net.gd` PREDICTED AT M4.**
`RequestWire` is the `EVENT`-channel C2S doorway; `NET-C2S-INPUT` deliberately
stayed behind, being the one C2S message on the `STATE` channel and not a request.
The vote carries no payload, is refused outside `RESULTS` by two independent
checks, and **leaves with a player who disconnects** — without which two players
where one votes and leaves satisfies unanimity over a lobby of one who never
pressed.

**AND PLACEMENT IS DELIVERED AS A RULE RATHER THAN AS A FIELD.** `ScorePlacement`
is pure Core, so the server and the client derive identical standings from the
same events — the choice the multiplier already made. **Ties share the higher
place and the next distinct total skips: 1, 1, 3**, because a tie-break is a
scoring rule invented at the results screen, and this game is decided by score.

Local: unit 201 scripts / 1 733 tests / 1 725 passing / 30 527 assertions; arch
57 / 224 / 1 285; integration 33 / 243 / 242 passing / 189.1 s.

### 2026-09-08 — the results reach the client, US-0077's server half

**THE MATCH NOW ENDS AND EVERY PLAYER IS TOLD EVERYTHING.** `NET-S2C-MATCH-END`
carries the whole `ScoreEvent` log, each slot's kit and each slot's ticks spent
Anonymous, sent once on the transition into `RESULTS`. The client runs the same
`ScoreFold` the server does, over the same events — so US-0077's third criterion
(*the breakdown and the totals cannot disagree*) is structural rather than a
promise.

**AND THE ANONYMOUS TIME WAS COUNTED BY NOBODY.** The story calls that line the
cheapest onboarding fix this design has; there was no accumulator anywhere.
`ScoreWindows.sample_tier` rides the pass `SYS-SUSPICION` already makes.

**Two criteria cannot be met by any amount of wire, and they are reported rather
than worked around**: a player has **no persona server-side at all** (no lobby,
`NET-C2S-LOADOUT` is US-0071's) and **there is no player name anywhere in this
project**. Codex builds the screen in `scripts/presentation/`; `NET-C2S-SKIP-RESULTS`
is deliberately not in this change.

Local: unit 200 scripts / 1 714 tests / 1 706 passing / 30 487 assertions.

### 2026-09-08 — `SYS-MATCH` runs the clock, US-0079

**THE SERVER HAS A LOBBY, A COUNTDOWN, AN EIGHT-MINUTE CLOCK AND A RESULTS
PHASE**, and the placeholder that set `ACTIVE` in `_ready` is gone after four
milestones. `MatchSystem` rides `MatchDirector.net_ticked` — before the
`is_simulating` gate, which is why it cannot be a `GameSystem` — and every
transition is `MatchClock` arithmetic. `ContractSystem.open` has a caller under
`scripts/` for the first time since US-0050, so the contract graph is a uniformly
random permutation dealt at the countdown rather than a ring in join order.
`ticks_remaining` has its first writer after five milestones on the wire.

**RUN IT**: `play.bat 3` starts at four players and counts you in;
`sandbox.bat` passes `--min-players 1` because a bench holding out for four peers
would simulate nothing at all. Six of eight criteria are ticked; the two that are
not say exactly what is missing.

Local verification: unit 199 scripts / 1 702 tests / 1 694 passing / 30 448
assertions; arch 57 / 224 / 1 285; integration 33 / 243 / 242 passing / **189.2 s**.

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

## `is_simulating` AND `is_watched` ARE DIFFERENT QUESTIONS, AND I SHIPPED THE WRONG ONE

**THE SECOND AGENT FOUND IT, AND IT IS A DEFECT IN CODE I HAD MERGED AN HOUR
EARLIER.** `MatchDirector._net_tick` emitted `tick_completed` only while
`MatchPhase.is_simulating(ctx.phase)`, and `RESULTS` is not simulating — so
**every snapshot stopped the instant a match ended.** A client's last one said
`FINAL`. `ticks_remaining` froze on whatever the final tick carried. The results
screen — the one phase whose entire content is the snapshot's match block — was
the one phase never described.

**AND IT MADE TWO THINGS I HAD JUST TOLD THE SECOND AGENT FALSE.** I wrote that
the server ends the results screen by letting `ticks_remaining` run to zero, *"so
your screen just reads the field it already reads"* — the field stops arriving.
And I offered `MatchSystem.skips()` as something to draw *3 of 4* from; it is
server-side and reaches nobody. Both corrected to him in writing rather than
quietly fixed, because he built against them.

**THE DEFECT IS ONE CONFLATED QUESTION.** *Nothing advances* and *nobody is told*
are not the same thing, and the original comment argued only the first: *"a
lag-comp history filled with identical lobby frames would answer a rewind with a
world that never happened, and a snapshot of a match that has not started
describes nothing."* Both clauses are true — **of the lobby**. Neither is true of
a results screen, which is a phase in which nothing may change and everything
must still be visible.

**`MatchPhase.is_watched` IS THE SECOND QUESTION, AND THE GUARD MOVED TO THE
CONSUMER THE RULE IS ABOUT.** The stages still run only while simulating;
`tick_completed` fires in `RESULTS` as well; and `LagCompRecorder.record` now
guards itself on `is_simulating`, because **the ring holds what a kill may be
validated against, which is play.** Leaving that guard in the director would have
been one flag deciding two unrelated things — which is what it had been.

**`LOBBY` IS DELIBERATELY STILL SILENT**, and saying which of the two
non-simulating phases changed is the whole precision of the fix. There is no
world to describe before a match: no pawns, no crowd placed, nothing. What a
lobby screen needs is a roster and a player count, which is US-0078's message
rather than this format.

**NO VOTE COUNTER REACHES THE CLIENT, AND THAT IS REPORTED RATHER THAN BUILT.**
US-0077's criterion asks for a *unanimous* skip and not for a tally. The snapshot
has no field for one and `NET-S2C-MATCH-END` is sent once, so *3 of 4* needs a new
field or a new message — a nicety, and adding wire format for a nicety is the
owner's call rather than mine. Codex reached the same conclusion independently and
left the counter out.

**THE PLANT THAT MATTERS IS THE DEFECT ITSELF.** Reverting `is_watched` to
`is_simulating` reddens `test_the_results_screen_is_still_described` by name — so
the test would have caught the thing that shipped. Two more: widening it to every
phase reddens the lobby's silence, and removing the recorder's guard reddens the
ring. One at a time, against the suite that owns each.

**AND A DOCSTRING SLID ONTO THE WRONG FUNCTION WHILE I WAS WRITING THE TESTS FOR
IT** — `test_a_builder_with_no_match_system_still_builds`'s explanation ended up
over my new results test, which is trap 11's shape in prose and the second
instance in two days. Caught by reading the file back rather than by any tool.

## A TIE IS NOT BROKEN, AND THE ARCH GUARD CAUGHT ME BEFORE ANY PLANT DID

**ASKED BY THE SECOND AGENT, AND THE ANSWER IS THE ONE THE CORPUS ALREADY GAVE
TWICE.** *May the display sort by points and show equal totals as a shared place?*
Yes — and the reason is worth more than the yes: **a tie-break is a scoring rule
invented at the results screen.** This game is *"decided by score, not kills"*, so
breaking a tie on deaths would make the match partly decided by deaths, and
breaking it on time spent Anonymous would decide it on a number printed beside the
placement as a separate fact. TDD-10 §3.1 refused the two obvious tie-breaks for
the kill contest on exactly these grounds — join order hands one player every tie
for a whole match, a coin makes the most decisive moment random — and **here there
is a third answer neither of those had: say that the game did not separate them.**

**IT IS A RULE RATHER THAN A FIELD, WHICH IS THE MULTIPLIER'S CHOICE AGAIN.**
`ScorePlacement` is pure Core and nothing about it goes on the wire:
`NET-S2C-MATCH-END` already carries every event and every slot, so both peers
derive the standings from identical inputs with identical code. Sending a computed
rank would be a second source of truth for something two fields already imply, and
the first disagreement would put a place on screen that the totals beside it
contradict.

**AND THE CASE THAT A RANKING LOOP GETS WRONG IS NOT THE TIE — IT IS THE ROW AFTER
IT.** Two players share first and the third is **third**; an incrementing counter
says second unless it also remembers how wide the tie was. The place is written as
*the count of players strictly ahead, plus one*, which has no counter to forget.
The other case is a player the log never mentions: `ScoreFold` only knows about
actors who earned something, so somebody who died six times and scored nothing has
**no event at all** and a table built from the events alone drops them off the
screen.

**THE SKIP VOTE'S REAL HAZARD IS THE ONE WHOSE COUNT LOOKS RIGHT.** Two players,
one presses skip and disconnects: the lobby is one, the votes are one, and
unanimity is satisfied over somebody who never pressed — the rule *inverted*, and
invisible because the arithmetic is correct. `MatchSystem.forget` is wired into the
same handler that forgets every other per-peer thing, and
`test_a_departed_voter_does_not_carry_the_lobby` is what says so.

**AND THE MESSAGE CARRIES NOTHING, WHICH IS THE PAYLOAD.** There is no yes-or-no to
send: pressing is the yes, and a vote that could be withdrawn would hand the last
player to change their mind a veto over a screen everybody else has finished
reading. A skip also **ends the screen rather than starting anything** —
`MatchClock.next_phase` returns `RESULTS` to itself deliberately, so the vote runs
the phase clock out and `ticks_remaining` reaches zero on every client. What
follows a results screen is still nothing at all, and that is US-0078's.

**`RequestWire` IS THE SPLIT `net.gd` HAS PREDICTED SINCE M4, IN ITS OWN WORDS.**
*"The C2S doorway below could move the same way if this file grows again."* It
grew — 398 of 400 — and this was the message that would not fit. **`NET-C2S-INPUT`
deliberately did not move**: it is the one C2S message on the `STATE` channel, it
runs at 60 Hz where everything else there is a keypress, and moving it would make
the new class's name a lie — an input is not a request, it is the simulation's
clock.

**AND THE ARCH GUARD CAUGHT MY OWN CODE, WHICH IS BETTER EVIDENCE THAN THE PLANT
WAS.** `test_authorisation_happens_before_the_work` permits **only** the sender
lookup before `authorise()`. My first handlers fetched the router into a local
first — one line of nothing — and it reddened, correctly: **the rule is *first*,
not *early*.** The router is handed to `RequestWire` by `Net.bind_router` now, so
the handlers are `net.gd`'s own shape. That the guard fired at all is the finding:
it scans **the whole of `scripts/net`** rather than a file list, so two handlers
leaving `net.gd` did not hollow it out — which a named-file guard would have done
silently. Falsified as well, by deleting `c2s_skip_results`'s authorise call.

**SIX PLANTED DEFECTS, ONE AT A TIME AGAINST THE SUITE THAT OWNS THEM**, which is
yesterday's lesson applied rather than repeated: the shared place, the scoreless
player dropped, one vote carrying the lobby, a vote banked before the results, a
`forget` that forgets nothing, and the doorway skipping authority. All six red,
each naming its own test.

**AND MY PATCH SCRIPT'S OWN ASSERTION FIRED ON MY OWN PROSE.** It refused to write
unless the string `Net.router()` was gone — and the docstring I had just written
*quotes that line to explain why it was removed*. Trap 15's assertion working
exactly as designed and pointing at the wrong thing: **an assert over source text
cannot tell code from the comment about it.** Narrowed to the indented call.

## THE RESULTS TRAVEL, AND MY OWN FALSIFICATION LOOP LIED ABOUT THEM FIRST

**FIVE PLANTED DEFECTS, AND THE FIRST RUN REPORTED FOUR OF THEM AS GREEN.** The
plants were real and each one does redden the test that names it — by name and by
number. What was wrong was the **loop**: it ran the whole unit suite and grepped
`^- test_` for the failures, and that grep does not match what GUT prints for a
single failing script inside a large run. Re-run one at a time against the suite
that owns them, all five are red.

**THAT IS THE INSTRUMENT-WRONG-IN-A-PLAUSIBLE-DIRECTION FINDING FOR THE SEVENTH
TIME, AND THE FIRST TIME IT HAS BEEN THE *FALSIFICATION* ITSELF.** Every previous
instance was a probe: the hud probe's camera, the cinderfall probe's frame count,
the lunge probe's yaw, the ability probe's suspicion field, the guard that named
the wrong tunable, the district map drawing the wrong district. This one was the
thing that checks the checks — **so a hole it invents is a hole nobody can rule
out except by re-measuring**, and I nearly reported four of them. *Falsify one
plant at a time, against the suite that owns it.*

**WHAT THE MESSAGE ACTUALLY CARRIES, AND WHY IT IS THE ONE THAT WITHHOLDS
NOTHING.** Every other server-to-client message in this catalogue is built around
never-do #12 — a kill result reaches two players, a score row reaches its actor
alone, the snapshot has no field anywhere for another player's suspicion. That
rule is about converting an **earned inference into a given fact while the match
is running**; when it is over there is nothing left to earn, and US-0077 asks in
as many words for every player's breakdown, their kit and who killed them.
`SCORE-DEATH` travels here where the score feed deliberately withholds it, and
that is criterion 5 rather than an oversight.

**THE MULTIPLIER IS NOT ON THE WIRE, AND LEAVING IT OFF IS THE STRONGER CHOICE.**
`ScoreEvent` has one constructor and it freezes `TUN-MATCH-FINALPHASE-MULT` from
the event's own tick — which is exactly why no inconsistent event can be built
(US-0064). A client rebuilding events from the log therefore reaches the same
number the server paid, from the same `MatchTuning`, because the handshake refuses
a peer whose profile hash differs. Sending it as well would be a second source of
truth for a value two fields already imply.

**AND `ScoreWire` ALREADY SOLVES THE `multiplier:u8` PROBLEM I REPORTED YESTERDAY,
ONE FILE OVER.** The snapshot's `multiplier` is a whole number and cannot carry
`TUN-MATCH-FINALPHASE-MULT`'s own 1.5–3.0 range; `ScoreWire.MULT_STEP` is **0.1**
and has sent tenths since US-0074. So the fix is not a design question, it is a
line — and the finding is now *the snapshot disagrees with the score row about how
to encode one value*, which is a better statement of it than the one I filed.

**TWO OF US-0077's CRITERIA CANNOT BE MET BY ANY AMOUNT OF WIRE.** *Each player's
persona, loadout and passive*: **a player has no persona server-side at all** —
`server_root._stand_the_crowd_up` says so in its own comment, because there is no
lobby and every persona is therefore treated as in use — and nothing assigns a
passive either. The **loadout** half is delivered and it is the placeholder kit,
which is worth sending anyway: the field has to exist for a screen to be built
against. And *your killers by name*: **there is no player name anywhere in this
project** — no field, no protocol row, no lobby to type one into. A slot number is
what a results screen can honestly draw today. Both are reported to the owner
rather than faked.

**THE ANONYMOUS CLOCK RIDES A PASS THAT ALREADY EXISTS, AND LIVES WHERE THE OTHER
THREE LEARNED TO.** `SYS-SUSPICION` decides the tier and samples the patient speed
ring on adjacent lines, so `ScoreWindows.sample_tier` costs no second pass. It is
on `MatchContext` rather than `PawnContext` because that object is **replayed
during prediction reconciliation** — a client replaying twenty commands would add
twenty ticks of patience nobody spent. Fourth instance, after the suspicion
impulse queue, the patient speed ring and the ability cooldowns.

**AND THE HOP IS TESTED FROM BOTH SIDES, WHICH IS THIS PROJECT'S MOST EXPENSIVE
RECURRING GAP.** `MatchEndWire` is proven against its own fixture and `MatchSystem`
against its own; **neither runs the two together**, so a `phase_changed` handler
that forgot its `RESULTS` branch would leave both green and the screen would simply
never arrive. That is exactly what left `NET-C2S-ABILITY-REQUEST` with no caller
under three completed stories and `ContractSystem.open` with none under five.

## `SYS-MATCH` EXISTS, AND THE PLACEHOLDER IT REPLACED HAD BEEN HIDING TWO THINGS

**THE SERVER SET `ACTIVE` IN `_ready` FROM M2 UNTIL 2026-09-08, AND SAID SO.** The
comment was honest — *"there is no lobby to leave, and a server stuck in LOBBY would
authorise no input and simulate nothing, which would make M2 unobservable"* — and it
was right for four milestones. What it also did was make two different numbers equal,
so nothing in this project could tell them apart.

**`ctx.tick` IS COUNTED FROM BOOT AND ITS OWN DOCSTRING SAYS "SINCE MATCH START".**
While the match began at boot both readings were the same integer, and every score
event froze `TUN-MATCH-FINALPHASE-MULT` from the right one **by accident**. Add a
lobby and a countdown and they differ by however long players took to arrive, which
is unbounded — so a kill thirty seconds into play would have paid **double** because
the process had been up for eight minutes. `MatchContext.match_tick()` is the origin
now, and `test_the_score_origin_is_the_match_clock.gd` arranges exactly that: a boot
tick past the boundary and a match tick short of it.

**AND `ticks_remaining` HAD NO WRITER AT ALL, FOR FIVE MILESTONES.** It is in
`Snapshot`, in NETWORK_PROTOCOL §4 and in the codec, and **nothing under `scripts/`
had ever assigned it** — every client of every match was told zero ticks left.
Nothing drew it, which is the only reason it was survivable and precisely why it went
unfound: *a field nobody reads and nobody writes is indistinguishable from one that
works.* Seventh instance of this corpus's most-repeated shape.

**IT CANNOT BE A `GameSystem`, AND THIS IS THE FIFTH SUCH CALL AND THE STRONGEST.**
`MatchDirector` walks the stage loop only when `MatchPhase.is_simulating(ctx.phase)`,
so a system at a stage **could never leave `LOBBY`** — it would be waiting to be run
by the gate it exists to open. It rides `net_ticked`, which fires immediately before
that gate and had no listener at all. TDD-10 §6's sketch says `extends GameSystem`;
§6.2 records that and two more places the sketch is a sketch.

**THE SIXTH PHASE IS AN ANNOUNCEMENT, NOT A PHASE.** US-0079 asks for six and its own
next criterion says the warning changes no rules — and `MatchPhase`'s ordinals **are**
the wire, so a sixth name would remap every client's idea of what is happening, which
is `PawnStateId.ALL`'s hazard in a second enum. **The criterion is left unticked
rather than reworded**, because rewriting a criterion to match what was built is how
a backlog stops being a status view.

**`ACTIVE` AND `FINAL` SHARE ONE COUNTDOWN**, derived from the two phase clocks rather
than from `TUN-MATCH-DURATION` so there is no third number to disagree. Per-phase
clocks would make the match timer **jump back up to 30 s** when the Final Contract
opened, and a timer that gains time reads as a bug in the one minute of a match
nobody can afford to distrust. It is also the only reading under which TDD-10 §6's own
sketch is arithmetically right.

**THE CONTRACT GRAPH WAS A RING IN JOIN ORDER AND NOBODY HAD NOTICED.**
`ContractSystem.open` — the uniformly random Fisher-Yates deal — was written at
US-0050 and reached **only from tests**; a live server grew its cycle one
`report_join` at a time, so the first peer to connect always hunted the second, every
match, on every seed. `MatchSystem.countdown_opened` is its first caller under
`scripts/`.

**AND THREE THINGS BROKE ON THE WAY, ALL OF THEM THE SAME SHAPE.** Booting into
`LOBBY` means `MatchDirector` runs **no stage at all** until a match starts, so
anything with fewer than `TUN-LOBBY-MIN-PLAYERS` 4 peers now simulates nothing and
comes back dead with no error — trap 3, three times over. `--min-players` is the flag
(`sandbox.bat` passes 1, `play.bat` passes this session's own peer count); the two
`tools/` probes set the floor themselves; and **`MatchSystem` now says out loud what
it is waiting for**, every five seconds, because the corpus's answer to a silent
failure is always to make the silence speak.

**THE PLAYER COUNT IS THE PAWN COUNT, WHICH WAS NOT THE OBVIOUS SOURCE.**
`Net.player_count()` reads **zero** while six players stand in the district, because
every probe in `tools/` and both integration tests raise `peer_joined`
**synthetically** and the registry behind it holds nobody. A pawn in the world is what
a player *is*.

**AND THE CLOCK IS ARMED WHEN THE WORLD EXISTS RATHER THAN IN `_ready`, WHICH WAS
MEASURED AND NOT REASONED.** `ContractSystem.cycle` is built at the end of a deferred
chain that waits two navigation-map iterations, so a lobby that filled during that
wait dealt its contracts into a null: *"Invalid assignment of property `tick` on a
base object of type Nil"*, four files from anything mentioning a match.
`test_server_tick_budget.gd` joins six players the moment the crowd reports itself
active — which is before it has been placed — and failed on exactly that.

**`multiplier:u8` CANNOT CARRY ITS OWN TUNABLE'S RANGE, AND THAT IS REPORTED RATHER
THAN FIXED — FIXED 2026-09-13, tenths and protocol version 2; see the top of this file.** `TUN-MATCH-FINALPHASE-MULT` is `@export_range(1.5, 3.0, 0.1)` and the
wire is a whole number: the shipped **2.0** is exact, and a re-priced **1.5** would be
announced to every HUD as **2** while scoring paid 1.5. Widening it is a format change
and the format was frozen against pre-split bytes the same day (PR #214), so
`test_the_announced_multiplier_is_the_one_that_pays` goes red the day the value stops
being whole rather than the day somebody looks.

**TWO SPLITS, BOTH FORCED BY THE LENGTH GUARD AND BOTH HONEST.** `server_root.gd`
reached 424 lines: the four phase handlers went to `MatchConsequences`, whose own
docstring already says *every method here is a signal handler and none of them decides
anything*, and the two logging readings became `ServerDiagnostics` — **and their
docstrings had merged into one**, so the file explained input starvation over the
function about the fallen crowd and `_log_starvation` carried none at all. Trap 11's
shape in prose, already paid for. Sixth and seventh files this guard has usefully
split.

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
**Made on 2026-09-13**: the file reached 3 976 of the 4 000 the guard allows, and
the twenty-eight M5 sections between the tick gate's second failure (2026-09-04)
and US-0097 — 2471 lines — moved to
[`docs/00_meta/history/M5_the_hud_and_the_abilities.md`](docs/00_meta/history/M5_the_hud_and_the_abilities.md),
indexed below. The 2026-09-08/09 sections on the match, the results and the seed
stay at the root, because the state section still points at them.

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

## FIVE THINGS WAIT ON THE OWNER, AND NONE BLOCKS M5

*Twelve rows, six live — two arrived with ADR-0020 on 2026-09-15 (decisions 11 and 12),
decision 4 closed with ADR-0021 on 2026-09-22, and decision 13 arrived with it and was
taken on 2026-09-24 (US-0100). The heading keeps its number because the section above it points
at it by name. Struck through rather than deleted, because a list with a vanished row
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
4. ~~**`NET-S2C-PLAYER-JOINED`'s persona field.**~~ **CLOSED 2026-09-22 by
   ADR-0021**: the hunter is told the persona from assignment, as the reference
   does, so there is no lock left for a joined message to defeat. The row read:
   *joined with `NET-S2C-CONTRACT-ASSIGNED` a client can read its contract's
   persona with no lock, defeating ASM-0030. Neither message is implemented, so
   nothing leaks today.* Struck through rather than deleted.
5. **The tag `m4-the-loop`.**

10. ~~**IS THE FINAL WARNING A SIXTH PHASE OR AN ANNOUNCEMENT?**~~ **SETTLED 2026-09-13 by the owner: an announcement.** The criterion is amended to five phases and one announcement and ticked; US-0079 is **done, eight of eight**. Struck through rather than deleted. The original reasoning follows. Raised 2026-09-08 by US-0079, whose description asks for six phases and whose next criterion says the warning changes **no rules**. `MatchPhase.Phase` has five members and **their ordinals are the wire** — `NET-S2C-PHASE-CHANGED` carries `phase:u8` — so a sixth name inserted for something that changes nothing would silently remap every client's idea of what is happening, which is `PawnStateId.ALL`'s hazard in a second enum. **It is built as an announcement** (`MatchClock.warning_at` and `MatchSystem.final_warning_announced`) and the criterion is left **unticked** rather than reworded, because rewriting a criterion to match what was built is how a backlog stops being a status view. **My recommendation is to amend the criterion to five phases and one announcement**: nothing in the design wants a phase that changes no rules, and the wire cost of one is real.
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

11. **SHOULD DETECTION BE PER RELATIONSHIP AND GATED ON SIGHT, AS THE
    REFERENCE'S IS?** Raised 2026-09-15 by ADR-0020. The reference keeps one meter per
    (pursuer, target) pair, moved only by the pursuer's high-profile actions *while
    the target can see them*; ours is one suspicion value per player, moved by the
    player's own actions wherever they happen, and read by the Compass warning, the
    stun gate and the render matrix alike. ADR-0020 removed the one source the
    reference plainly lacks; this is the structural difference underneath it, and it
    is `SYS-SUSPICION`'s model rather than a tunable. **My recommendation is to
    leave it until the first playtest with human hunters**: design law 1 is written
    as *speed is spent anonymity* globally, and a sight-gated meter would make a
    sprint behind your target's back free — a change to the thesis, not to a rule.
12. **THE FINAL CONTRACT'S `×2` HAS NO COUNTERPART IN THE REFERENCE.** Asked from
    the controls on 2026-09-15 (*"welche Mechanik hat die ×2?"*).
    `TUN-MATCH-FINALPHASE-MULT` doubles every score event through `FINAL`; the
    reference's session clock turns red at one minute and changes nothing. Under
    ADR-0013 the reference wins where a rule diverges, but this one is GDD-07's and
    TDD-10's own, built at US-0064 and US-0079 and on the wire as `multiplier`.
    **My recommendation is to keep it**: it is the one lever the design has against
    a runaway leader parking out the clock, and removing it is a format change
    (`PROTOCOL_VERSION`) for fidelity's own sake.
13. ~~**SHOULD THE PERSONA BE SPLIT OUT OF US-0078 AND DEALT AT M5?**~~ **SETTLED
    2026-09-24 by the owner: yes**, and built as US-0100 — the deal at the
    countdown, the clone floor narrowed to the dealt set, and the persona on
    `NET-S2C-CONTRACT-ASSIGNED` at `PROTOCOL_VERSION` 3. The results table's
    personas are deliberately a second story and a second bump. Struck through
    rather than deleted; the original reasoning follows. Raised
    2026-09-23 by ADR-0021, which is the fourth thing now waiting on one story.
    **My recommendation is yes, and it is decision 1's own shape**: split
    US-0078 into the *persona* and the *lobby screen*, deal the persona
    server-side at the countdown at M5, and let the lobby **replace** that deal
    at M6 rather than enable it.

    **FOUR THINGS WAIT ON US-0078 AND ONLY ONE OF THEM WANTS A LOBBY.**
    ADR-0021's portrait has nothing to draw; US-0077's results screen shows slot
    labels because *"a player has no persona server-side at all"*; `CloneBalance`
    is told every persona is in use, because `server_root` cannot ask which four
    were chosen; and US-0073's portrait criterion is blocked behind all three.
    None of those needs a player to have *picked* anything. They need a player to
    **have** a persona.

    **AND `PawnContext.persona` HAS EXISTED SINCE M1 WITH NO WRITER UNDER
    `scripts/`** — the field is declared under *Identity*, two lines below
    `peer_id`, and the only assignments in the tree are to `PersonaBody.persona`
    in a test and a tool. That is this corpus's most-repeated shape for the eighth
    time: *a field nobody reads and nobody writes is indistinguishable from one
    that works.*

    **THE DEAL IS THE CONTRACT DEAL, ONE STAGE EARLIER.**
    `MatchSystem.countdown_opened` already hands `ContractSystem.open` the peer
    list at the countdown, and `MatchContext.rng` is the seeded server-side source
    gameplay randomness must come from (never-do #8). Dealing a persona there is
    the same call with a four-element set and **duplicates permitted**, which
    US-0078 already calls *GOOD: they add a candidate to each other's crowd*.
    `NET-C2S-LOADOUT`'s `persona:u8` later overrides the deal for players who
    chose; that is *"a minimum-player rule satisfies it and the lobby later
    replaces it rather than enabling it"*, decision 1's exact argument.

    **THE SPLIT TAKES NO CRITERION AWAY FROM US-0078, WHICH IS THE CORRECTION THE
    REVIEW FORCED.** My first write-up listed criteria as *moving*; they do not.
    What the split extracts is a **precondition** the story implies without
    stating: that a player has a persona at all. All nine criteria stay at M6,
    and the lobby's own selection replaces the deal when it arrives.

    **THE WIRE COST IS TWO THINGS, NOT ONE.** ADR-0021's route — the persona with
    the contract on `NET-S2C-CONTRACT-ASSIGNED`, `PROTOCOL_VERSION` 2 → 3 — feeds
    the **portrait** and nothing else: that message reaches one hunter and names
    one contract. **The results table needs its own transport**, because
    `MatchEndReport` carries `anonymous_ticks`, `kits` and `events` and no persona
    at all, so `ResultsRoot` builds a slot label, abilities and Anonymous time and
    could not draw a persona if it wanted to. Either a persona per result row or a
    **stable persona roster** is owed, and the roster is the one that also answers
    criterion 4 — *persona selections are VISIBLE to all players* — which a
    per-contract byte cannot, at M5 or ever.

    **WHAT STAYS AT M6 IS THE WHOLE STORY, AND THE THREE BLOCKERS HAVE THREE
    DIFFERENT REASONS.** Criterion 3 (*every passive shows its exact numeric
    effect*) waits on **US-0071**, because a passive cannot state a number before
    it has a reader. Criterion 9 (*a recommended default loadout is pre-selected*)
    waits on US-0071 for a different reason — there is no loadout to recommend
    until `NET-C2S-LOADOUT` defines one. Criterion 2 (*every ability shows
    cooldown, suspicion cost and its tell*) waits on **neither**: `AbilityData` and
    TUNABLES hold every figure today, and what is missing is the screen and one
    string per ability. Criterion 6 (*duplicate personas are permitted*) is a rule
    of the **selection**, so it stays even though the deal already allows
    duplicates. Criterion 7 and the countdown half of 8 are **already built** by
    US-0079 — `TUN-LOBBY-MIN-PLAYERS` with `--min-players`, and
    `TUN-LOBBY-COUNTDOWN`; only the unready cancel is missing.

    **THE COST, SAID PLAINLY.** A dealt persona is not a *chosen* one, so the M5
    build still cannot test the thing the lobby exists for — a player living with
    a pick for eight minutes. And it makes the clone floor real for the first time:
    `CloneBalance` currently serves all four personas because it must; served four
    real ones it will be measured against `TUN-CROWD-CLONE-LOCAL-MIN` in a live
    match rather than in `test_clone_local_min.gd`, which may well find something.
    **That is a reason to do it earlier, not later.**

---

## The state of the build

*What is true right now, in one screen. The narrative that explains **why** each of
these numbers is what it is lives above, for the recent work, and in
`docs/00_meta/history/` for everything before M5.*

| | |
|---|---|
| CI | 7 jobs. **Running again as of 2026-08-07 after a two-day outage** — run `31200490320`, all seven green. The seven commits merged during the outage were never through it, see trap 6. `.ci/run_gut.sh` fails if a suite runs fewer scripts than exist on disk |
| Tests | **61 arch + 216 unit + 33 integration scripts**, holding 246 + 1 835 + 244 tests and 1 548 + 32 685 + 680 assertions (arch remeasured 2026-09-24 after rebasing onto US-0101, for `test_depends_on_resolves.gd`, which holds every `depends_on` in `docs/` to a document that exists — it found five dangling ids, each a prefix of a real one, and **its own premise caught its first draft passing over zero edges**, because appending to a `PackedStringArray` read out of a Dictionary appends to a copy. Unit and integration as measured for US-0101 — the four new unit scripts are `test_wardrobe.gd`, whose load-bearing pair is the seed alone and the roster alone each dressing **nobody**, `test_persona_body.gd`, `test_lobby_state_wire.gd` and `test_the_personas_reach_every_client.gd`; integration 189.1 s, unchanged. Measured before that for US-0100's persona deal and the three ordering defects its review found — the fourth new unit script is `test_the_persona_deal_ordering.gd`, which holds the three seams no single unit could see: the announcement reading the persona the deal had not yet written, a lobby join being dealt to and spending the match generator, and a departure leaving the clone pass fetching for somebody who had gone. Before it, three new unit scripts: `test_persona_deal.gd`, whose load-bearing pair is that one seed deals one district and that duplicates are legal; `test_persona_wire.gd`, which pins `CrowdRoster.PLAYABLE`'s order as append-only now that it is a protocol; and `test_a_respawn_keeps_the_persona.gd`, which exists because the rule had only a docstring and the plant ran the whole suite green. Measured before that remeasured 2026-09-23 for the CI rebuild — `test_ci_required_checks.gd` binds workflow security and all seven names to the strict ruleset; `test_export_excludes.gd` parses all five presets and refuses the `.mcp.json` leak the first real PCK export exposed; architecture 11.507 s, unit 45.643 s, integration 188.998 s. Remeasured before that on 2026-09-15 for ADR-0020 — no new script; three unit tests carry the report from the controls as assertions on the shipped profile, and the arch suite gained `test_the_codegen_mirror_of_the_exemptions_is_current`, which found `gen_ids.py`'s copy of `NOT_A_MEMBER` two days stale. Measured before that on 2026-09-13 for the match timer — the new script is `test_match_vm.gd`, whose load-bearing assertion is that the tick the bar is full is the tick `MatchClock` opens `FINAL`; arch carries #225's exemption assertion; integration remeasured too, because the client-boot test builds the new widget. Measured before that for the multiplier's tenths — no new script; `test_the_announced_multiplier_is_the_one_that_pays` sweeps sixteen values through the snapshot codec where it used to pin one. Measured before that on the tree rebased onto #221, after the review of `NET-S2C-MATCH-START` — the new arch script is `test_rpc_channels_match_the_table.gd`, which holds every `@rpc`'s declared channel to `Messages.CHANNEL_FOR` and found a stale row and a missing one on its first run, and `test_game_state_single_writer.gd` gained the reviewer's counterexample as two tests: a `bool`-returning mutator must still be one, and a caller of a writer is a writer; **integration read 189.1 s**. The two new unit scripts are `test_match_start_wire.gd`, whose seed sweep is the three values a 32-bit encoder drops — `1 << 40`, the top bit and `-1` — beside the three it would pass, and `test_game_state.gd`, the mirror's first test of its own, whose last two drive the real handler on the real autoload. The arch test is the premise of `test_game_state_single_writer.gd`'s derivation, which reads the mutators off `game_state.gd` instead of a list. The measurement before it, 2026-09-09 from the clean archive after rebasing US-0077 onto #220: all 57/205/33 scripts ran; 224 arch, 1747 unit and 243 integration tests passed, with eight unit and one integration test already pending. Integration measured 189.226 s. The three presentation scripts exercise the shared ScoreFold, packet delivery and phase/clock handoff. #220's `test_the_director_outside_play.gd` separates the clock's order from phases where simulation does not run. The assertions that matter there are `test_match_director.gd`'s three — a results screen **is** described, nothing simulates in it, and the lobby is still silent — of which the first reddens under the exact defect that shipped. The new script is `test_score_placement.gd`, whose load-bearing pair is the row **after** a tie — 1, 1, **3** — and the player the log never mentions, who has no event at all and must still appear on nought. The one before it is `test_match_end_wire.gd`, whose load-bearing test folds the payload on the client side and asserts the totals equal the server's own, which is US-0077's third criterion made structural rather than promised. The three before it are US-0079's; **the integration suite read 189.2 s**, up from 184.2, and it is over its own 180 s budget as it has been for three stories — the machine's own spread is 174.6-189.2 so no single reading is *the* figure. The three new unit scripts are US-0079's: `test_match_system.gd` drives the phase machine end to end and asks `ScoreEvent` what a kill on the tick `FINAL` opens is worth — two derivations of one instant, at the same moment; `test_the_score_origin_is_the_match_clock.gd` is the one that would have caught the defect, arranging a **boot** tick past the boundary and a **match** tick short of it; `test_the_match_clock_reaches_the_wire.gd` is the hop onto the format, which nothing had ever proven because nothing wrote the field. The one before them is `test_snapshot_wire_compatibility.gd`, which freezes the pre-split encoder's exact bytes — a symmetric writer/reader reorder passes a round trip and fails those. The earlier baseline carried BOTH #211 and #212 — neither PR's own row was right after the other landed, and `test_claude_md_counts_are_current.gd` is what said so; integration counts retained from 2026-09-05; the new unit script is `test_match_clock.gd`, whose last assertion is the one that matters: it sweeps twenty profiles to prove the tick `MatchClock` opens `FINAL` at is the tick `ScoreEvent` pays double from — two independent derivations of one instant until 2026-09-08, which agree until either moves. The one before it is `test_pawn_navigation.gd`, which pins the pawn capsule and step height to exact navmesh cell multiples so Recast's ceiling quantisation cannot change the agent in silence. The new arch script is `test_claude_md_stays_findable.gd`, which caps this file at 4 000 lines and refuses an archived document it does not link — the file was 6 594 lines with the traps and the local environment filed under 3 301 lines of history. The one before it is `test_agent_entry_points_are_pointers.gd`, which resolves the target of every agent entry point rather than only capping its length — a short file can still name a document that does not exist, and `AGENTS.md` did exactly that. The one before it is `test_a_script_tool_gets_no_autoloads.gd`, which walks the class closure of every `-s` tool and refuses one that reaches a class calling the `Tuning` autoload — it found `input_probe.gd` unloadable, which reasoning had not. The one before it is `test_the_ability_writer_holds_no_tunables.gd`, which refuses a `TUN-`-backed field in the `.tres` writer's hand-written table. The two unit scripts before it are ADR-0019's — `test_the_stun_costs_the_contract.gd` and `test_match_consequences.gd`, which are the rule and the hop respectively. **The integration suite read 184.2 s against 183.8 s before this change**, so the wiring assertion added to `test_the_m4_loop_resolves.gd` costs about 0.4 s — it raises the signal rather than earning a stun, and deliberately does not settle through `TUN-CONTRACT-REASSIGN-DELAY`, which the first version did for **+3.8 s**) — the assertion count tripled at US-0049, because `test_contract_cycle_fuzz.gd` checks the invariant after every one of 10 000 events. **Nine are `pending` by design** — **eight in the unit suite and one in the integration suite**, which reports that an NPC aimed into the void never gives up. The island `pending` beside it **turned green by itself** when the alley mouths were built, which is what a `pending` naming its own blocker is for. The three numbers this row used to call assertions were **test** counts — corrected at US-0041 by reading both off the runner. The integration suite measured **183.8 s** on 2026-09-02 and again on 2026-09-01, **174.6 s** twice on 2026-08-28 and **183.5 s** the day before that, with **no test removed** — **three readings within 0.1 s of each other now, so the 174.6 s pair is the outlier rather than the figure** — so the 9 s is machine variance and neither number should be quoted as *the* figure; what is real is that the suite sits within a few seconds of its limit either way. The 180 s it is 'allowed' is **enforced nowhere** — TEST_PLAN §3, TEST_PLAN §10 and TDD-12 §17 all assert it and no job checks it, which is the M4 gate's fourth drift finding. `test_the_m4_loop_resolves.gd` cost 13.1 s of that and is the first test ever to run M4's systems together. It was 162-172 s, up from 87.7 s at M2 — **under 9 s of headroom left, and the next integration test has to justify itself hard against that**. `test_server_tick_budget.gd` cost 9.8 s of it and is a gate line; the one before it, the 2 s pass A/B, samples ninety ticks **twice** — US-0044's three suites are deliberately *unit* tests for that reason: `test_crowd_moves.gd` walks a crowd for sixty net ticks eight times over, and physics frames run in real time even headless. **The six are**: `test_upstream_bandwidth.gd` reporting the 145 % upstream miss, `test_crowd_bandwidth.gd` the 112 % downstream projection, `test_crowd_wire_cost.gd` the 112 % it actually costs, **`test_spawn_points.gd` twice — GDD-05 §2.7 rule 6's nine unoccluded spawn pairs and rule 8's S3 4, S4 1, S5 6 of 8 seats** — and `test_clone_animation_parity.gd` the missing clip library. **Two entries this row carried are gone because their findings closed**: `test_circuit_separation.gd`'s 0.51 m circuits (re-authored, now 21.20 m) and `test_cull_radius_price.gd`'s flat curve, which asserts rather than pends. Each reports a finding the code cannot fix rather than going red, the same choice `test_snapshot_size.gd` made. A `pending` that turns green by itself the day its blocker is authored is the point. The *script* counts are guarded by `test_claude_md_counts_are_current.gd`; the assertion counts are a snapshot and are not. This line read `119 + 515 + 132` for **twelve PRs** — every update to it was an unasserted `str.replace` that silently matched nothing. See trap 15 |
| Tuning | **296** tunables across 14 resource classes; all **37** cross-field invariants assert. **Six were added on 2026-08-29 for US-0097's escape verb** — four `TUN-PURSUIT-*` on `ContractTuning` (a pursuit ends by removing and reinserting a contract, so §7 is its section and no new resource was needed) and `TUN-SCORE-ESCAPE`/`-CLOSECALL` on `ScoringTuning`. **Invariant 34 fired on its first run against the story's own proposed value**: `TUN-PURSUIT-DURATION` is `warn_radius / blend_walk` = 10.7143, US-0097 wrote **10.7**, and that asks the prey for 1.402 m/s — fractionally faster than a blend walk, in exactly the direction the invariant forbids. Shipped at **10.72**, with the tolerance tightened to a true floor rather than widened to admit it. **A rounded derivation is not a derivation.** **`TUN-COMPASS-CONE-FULL-RADIUS` 20.0 m was added on 2026-08-27** — where the Compass arc becomes a whole ring — and **invariant 33 is the reason it is not a chosen number**: it pins the radius equal to `TUN-COMPASS-LOCK-RANGE`, so the arc stops pointing exactly where the lock starts working, and separately outside the validated kill reach. It was **set three times in one day and only ever by somebody playing it** — 4.0 m derived from the half-width alone, 6.0 m at `TUN-SUSPICION-OPEN-RADIUS`, then 20.0 — and the second is the one worth remembering, because it was **derived and still wrong**. **`TUN-SCORE-HALFSEEN` +50 was added on 2026-08-27** by the fidelity re-audit — the stealth ladder had no middle rung, so a kill at **Noticed** and one at **Exposed** scored identically; invariant 32 keeps it strictly descending and strictly positive, and the `> 0` clause is the load-bearing half because every ordering check passes over a zero. `TuningInvariantsScore` was split out when that pushed the file past 400 lines — tech is how the game is *transmitted*, score is what it *pays*, and what is left is how it *plays*, with one entry point still. **Four scoring values were re-priced on 2026-08-26 (ADR-0013)** — `TUN-SCORE-SILENT` 100 → 200, `TUN-SCORE-PATIENT` 150 → 100, `TUN-SCORE-FOCUS` 100 → 150, `TUN-SCORE-RECKLESS` −50 → **0**, and invariant 18 rewritten from an ordering to a floor — split across `TuningInvariants` and `TuningInvariantsTech` since the first file hit 400 lines, with one entry point still. **Eight IDs are deprecated** and recorded in TUNABLES §19 — never reused — **and two are neutralised at 0 with their IDs live**: `TUN-SCORE-RECKLESS` (ADR-0013) and, since 2026-09-15, `TUN-SUSPICION-GAIN-OPEN` (ADR-0020, walking alone costs nothing) |
| Autoloads | All eight. `Tuning` precomputes 89 durations into **two** tick tables — see trap 7 |
| Strings | `data/strings/en.csv`, 105 keys, no user-facing literal anywhere else — the count read 56 from M0 until 2026-09-13 while the table grew past a hundred, which is this file's prose-count drift in a fourth row; and the correction said 106, counting the header line, until the reviewer of #226 counted 105 |
| Boot | Branches on `--server`; **8** CLI flags parsed in pure Core; 5 export presets. `--min-players` was added 2026-09-08 with `SYS-MATCH`: the server now boots into `LOBBY` and `MatchDirector` runs no stage outside a match, so a bench holding out for four peers would simulate **nothing** and come back dead with no error |
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
| Match | **Every client is told the seed as of 2026-09-13** — `NET-S2C-MATCH-START` at the transition into `ACTIVE` and to each late joiner, on `SESSION` so it cannot overtake `NET-S2C-WELCOME`; `GameState.adopt_match` is the mirror's third mutator and `has_match()` is a flag because zero is a legal seed. **The results screen received no snapshots at all until 2026-09-09**, because `MatchDirector` emitted the end of a tick only while `MatchPhase.is_simulating` and `RESULTS` is not — so a client's last snapshot said `FINAL` and its clock froze there. `MatchPhase.is_watched` is the distinction (*nothing advances* against *nobody is told*); stages still run only while simulating, and `LagCompRecorder` guards itself because the ring holds what a kill may be validated against. `LOBBY` stays silent — no world to describe. **The results can be skipped as of US-0077 (2026-09-09)**: `NET-C2S-SKIP-RESULTS` on `RequestWire`, counted by `MatchSystem`, unanimous or nothing. The vote carries no payload — pressing is the yes — is refused outside `RESULTS` by both `Authority` and the rule, and **leaves with a player who disconnects**, without which one vote plus one departure carries a lobby of one who never pressed. A skip runs the phase clock out rather than starting anything; what follows `RESULTS` is still nothing, and that is US-0078's. **`SYS-MATCH` runs the phase as of US-0079**, and it is **not a `GameSystem`** — the fifth such call and the strongest: `MatchDirector` walks the stage loop only when `MatchPhase.is_simulating`, so a system at a stage could never leave `LOBBY`. `MatchSystem` rides `net_ticked`, which fires before that gate and had no listener at all. `MatchClock` is the pure arithmetic and takes a `MatchTuning` rather than reading `Tuning`, so it and `ScoreEvent.multiplier_at` **cannot** disagree about the instant `FINAL` opens. Five phases, and the "sixth" is an announcement at `MatchClock.warning_at` — the ordinals are the wire. `ACTIVE` and `FINAL` share one countdown, derived from the two phase clocks. The countdown trigger is a player count — **the pawn count**, because `Net.player_count()` reads zero under a synthetic join — against `TUN-LOBBY-MIN-PLAYERS`, overridable with `--min-players` so the bench still runs; below the floor a match ends **with results shown**, and that rule is armed only for a match this system started, because half the probes in `tools/` set `ctx.phase` by hand. The clock is armed at the end of the deferred world build, not in `_ready`: `ContractSystem.cycle` does not exist before that |
| Kill | `SYS-KILL` ticks at the `combat` stage, **before `contract`**, so the cycle is repaired in the tick a death resolves. The decisions are pure and separable — `KillRules` (target, range, cone), `KillContest` (who was first), `RewindClamp` (how far back) — and the system holds the sequencing and the consequences. **Range is 3D and the cone is horizontal**: a horizontal reach would put the roof stratum inside kill range of the street. It reads the **announced** contract, so a press during the reassign breath is a rejection rather than a free kill. **Contact frames resolve before new presses**, or a victim dying this tick could still be claimed. **A press is edge-detected in this system's own map**, never from `PawnContext.held_buttons`, which `step()` rewrites at 60 Hz. Consequences leave through `killed`, wired in `server_root`: contract repair, blend break, corpse, startle, witnesses, `NET-S2C-KILL-RESULT` to the two involved. **A rejection is answered with a victim slot of zero** — silence is the worst answer a kill can give |
| Stun | `SYS-STUN` is **not a `GameSystem`** — TDD-01 §4's box 7 is one node reading "Kill / Stun", so `KillSystem` owns it and ticks it, `SuspicionSystem`/`BlendSystem`'s shape. **The kill is judged first within the tick**, which is where ADR-0013's contested initiation is decided rather than in a comment. Target is the stunner's own pursuer by reverse lookup on the **announced** contracts. `StunRules` is pure geometry and reads **one yaw**, the stunner's; it shares `TUN-KILL-VALIDATION-GRACE` with the kill, so the two reaches shift together. A stun at a hunter already in `KillAnim` is `TARGET_COMMITTED` and **costs nothing**. **Every other refusal costs the same and looks the same**, because a refusal that reported its reason would be a free identity probe. `stun_ready` carries the tier gate for that same reason |
| Spawn | `SYS-SPAWN` is **not a `GameSystem`** — TDD-01 §4's diagram has no spawn box and stage 8 is *"repair cycle after deaths"*, so `ContractSystem` owns it and **ticks it first**: the placement and the cycle insertion land in one tick. `SpawnRules` is pure — 40 m from the killer, 12 m from **every** living player, and a fallback that draws nothing at all because it runs at the worst moment in a match. **The point is chosen when the timer expires**, never at the contact frame. `TUN-RESPAWN-INVULN` is a third `CombatLockouts` shape: it shields a *target* where the stagger and the exile restrain an *initiator*, and both combat systems answer `TARGET_PROTECTED` at **no cost to the presser**. **Both respawn edges are completions rather than interruptions** — trap 8 |
| Kill commits | **`KillAnimState.is_interruptible` returns false** (ADR-0013). A stun landing after the hunter has pressed kill saves nobody; the prey's counterplay is the approach, where a revealed hunter is stunnable from 3.0 m and cannot strike until 2.5. **FATAL still gets through** — a third party killing the killer — because `transition` compares priorities, which is the asymmetry `test_the_kill_commits.gd` asserts both halves of. `KillSystem.report_interrupt` is **deleted rather than left as a no-op**: a cancel entry point that silently does nothing is worse than none |
| Compass lock | `CompassLock` is pure and holds the arc, the reveal window, the cooldown and the portrait; `SYS-DETECTION` supplies the yes-or-no its conditions come to. **`has_los()`'s first and only caller**, last in the early-out ladder — a hunter facing away spends zero raycasts, one watching spends one, against TDD-07 §4.3's budget of 2-6. The cone is gated on the hunter's **own yaw**, never the wobbled bearing. **The arc is not reset on completion**: a held view keeps a full arc and `TUN-COMPASS-REVEAL-COOLDOWN` is what stops chain-locking. **It resets on reassignment, tracked separately from the portrait** — inferring one from the other let a half-filled arc cross to the next contract. `NOBODY` is not a reassignment, or the breath would destroy an earned portrait. `PASV-COLDREAD` is an argument with no reader until a loadout exists. **The portrait latch means *a lock completed* as of ADR-0021 (2026-09-22)**, not *the persona is known* — the persona is shown from assignment once players have one (US-0078) |
| Compass | **The cone points at the contract and widens as you close** (2026-08-27), to a whole ring at `TUN-COMPASS-CONE-FULL-RADIUS` 20.0 m — which is `TUN-COMPASS-LOCK-RANGE`, invariant 33, rather than a number anybody chose: outside it the instrument points, inside it you look. Two conversions stand between a world bearing and a pixel and **neither existed**: `CameraArm.yaw_from_camera` (this game's yaw 0 faces +Z, a Godot node's faces −Z) and `CompassWidget.screen_angle` (this game's yaw increases to the left, a screen angle increases clockwise). They partly cancelled, so the shoulders drew correctly and ahead drew behind. `CompassMath.cone_halfwidth_for` holds the arc at a constant **length of ground** rather than a constant angle — a whole ring at 4.0 m, invariant 33 — and the widget's edge falloff flattens as it opens. **The server half lives in `SYS-DETECTION`**, at steps 9-10 of its pass, because the Compass is about the observer's *contract* — the same relationship the render state is computed from — and TDD-07 §1's diagram draws it there. `CompassMath` is pure Core: `period_for()` reproduces TUNABLES §4.2's twelve rows to **0.40 ms**, and the reciprocal exponent makes the rate **58x steeper close in than far out**. One reading per hunter into `ctx.compass`: a **world** bearing with `TUN-COMPASS-CONE-WOBBLE`'s drift already applied server-side, and a `Quantise.BUCKET_STEP` 0.5 m distance bucket, so nothing downstream holds the exact metres. The wobble is a sine of `(contract, tick)` — deterministic and learnable, never RNG — with its phase **mixed**, or adjacent peer ids would drift in step. **A missing reading is `NO_CONTRACT` 255, never bucket 0**, which is a real reading. `lock_fraction` and `portrait_revealed` are US-0058's and read zero; nothing draws any of it |
| Detection | `SYS-DETECTION` ticks at the `detection` stage, **after `suspicion`**, because the render state is computed from *tier* and a tick of lag makes the silhouette disagree with the tier indicator. One pass over 30 ordered pairs, **costing zero raycasts**: GDD-03 §2.1's rule is `tier × relationship` and §2.3 draws the Exposed outline through geometry, so occlusion must not gate it. The early-out ladder drops ~70 % of pairs on the tier check alone. It reads the **announced** contract from `ctx.announced_contracts`, never the graph's, so a tint cannot arrive before the Compass does. `RenderMatrix` carries the answer to `SnapshotBuilder` four stages later and **absent means `PLAIN`**, which is the safe direction. **It also holds the only line-of-sight query in the project** — `WORLD`-masked, so NPCs and players cannot block it by construction; Cinderfall is a sphere tested against the segment; the rewound form is **still refused**, and US-0060 sharpened the reason rather than clearing it — kill validation asks no line-of-sight question at all, so there is still no caller for a past one. **`has_los()` has two callers**: the Compass lock (US-0058) and the witnessed-kill check (US-0060). `cinderfall` is `MatchContext`'s list, adopted by reference, and every liveness query takes the tick it is asked about. **It also owns the prey warning** (US-0059): `_resolve_pair` already computes `hunted_by`, so the warning is a distance, a tier comparison and a cooldown lookup on pairs the ladder has already admitted — no second pass and no raycast. `PreyWarning` holds only the cooldown, and **a new pursuer defeats it**, or a repair would silence the prey's one warning for 2.5 s |
| Abilities | **`SYS-ABILITY` at the `abilities` stage, and one of the four now does something** (US-0066, US-0067). `AbilityRules` is pure — five validations answering with the first rung that fails, and an aim that is **clamped rather than refused** because the client's aim and the server's differ by a rounding error on every cast. Cooldowns are **integer tick deadlines started at ACTIVATION**, reset on death by `AbilitySystem.on_death` rather than by `PawnContext.reset_for_spawn`, which prediction replays. The tell is **the one broadcast in this game** — reliable, to everybody inside `TUN-<ABIL>-TELL-AUDIO-RADIUS`, and emitted **before** `effect.begin`. A denial **carries its reason**, unlike the stun's, because every reason is a fact about the presser's own kit. **A cast has a wind-up as of US-0067**: `LiveAbility` holds it *pending* until `TUN-<ABIL>-CAST-TIME` has passed and *live* afterwards, the duration runs from the burst rather than from the press, and a caster killed mid-throw drops nothing. `AbilityData.startle_radius` is raised by the **system** beside the suspicion cost, because Lunge carries one too, and leaves through `ability_startled` for `server_root` to wire. `effect_script` is set for **Cinderfall** and null for the other three — and it is **stripped from `TuningProfile.serialise`**, because `var_to_bytes_with_objects` would otherwise send a server-only `Script` to every client |
| Cinderfall | **`ABIL-CINDERFALL` IS THE FIRST ABILITY THAT CHANGES THE WORLD** (US-0067). `CinderfallEffect` is eleven lines and calls `CinderfallVolumes.add`, which had been built, tested and callerless since US-0056. The cloud **forbids kill initiation inside it including the caster's own** — GDD-04 §3.1's *"design detail that carries the ability"*, and without it the dominant play is *cloud, then kill inside it*. **`end()` deliberately does not remove the cloud**: `expire` lags the burn-out by `RewindClamp.max_ticks()` so a kill validated in the past still meets a cloud that was up when it was pressed, and clearing it here would delete exactly that window. **Nothing draws it** — there is no VFX pass, so on a client a Cinderfall is an absence of information |
| Score | **Thirteen bonuses, judged at initiation and paid at the contact frame** (US-0065). `ScoreBonuses` is pure — facts in, awards out — and `KillScoring` is the thin half that reads the world; `KillSystem` captures a `KillScoreFacts` at `_begin` and carries it on the pending row for 0.9 s, so a hunter keeps Silent through an animation they cannot cancel and cannot launder recklessness by standing still after it. **The suspicion ladder is a partition**: exactly one of Silent, Halfseen and Reckless fires, and Reckless fires at **zero** rather than not firing. `ScoreWindows` holds the four facts one tick cannot answer — the speed ring, the focus streak, the hunt clock and the vendetta debt — **on `MatchContext` rather than `PawnContext`, which TDD-10 §2.1 is amended for**, because a pawn is replayed by prediction. **Sampled upstream of the `combat` stage** by `SYS-SUSPICION` and `SYS-DETECTION`, which is why **`SYS-SCORE` is not a `GameSystem`** — the fourth such call for a fourth reason. Focus rides `can_lock` and costs **no raycast**, closing US-0056's last criterion. **Masked and Poisoned are dormant**: no `AbilitySystem` to ask, and no MVP ability that poisons | 
| Score log | **`SYS-SCORE` does not exist yet and the log does** (US-0064). `ScoreLog` lives on `MatchContext` beside `lockouts` and `impulses`, adopted by reference; `ScoreEvent` is immutable in the engine — getter-only properties, so an assignment is a parse error — and freezes `TUN-MATCH-FINALPHASE-MULT` from its **own tick** inside its one constructor, which is why no inconsistent event can be built. **The final phase is a property of the clock**, so this is not blocked on `SYS-MATCH`; US-0079 must read `ScoreEvent.multiplier_at` rather than decide it again. `ScoreFold` is pure and takes **no tuning** — TDD-10 §1.3's signature is amended, because points frozen on the event and points re-read at fold time are two sources of truth. `ScoreAward` is the claim a system makes and `ScoreEvent` is what the log made of it; the seam exists because eight constructor arguments is a design signal `.gdlintrc` refuses to let anybody suppress. **Two events are appended in a live match** — `SCORE-CONTRACT` and the `SCORE-DEATH` marker, sharing a group — and the other eleven bonuses are US-0065's, because each is judged at *initiation* against state the kill handler no longer holds |
| Score feed | **THE FIRST THING IN THIS GAME THAT TELLS A PLAYER WHY THEY WERE PAID** (US-0074). `NET-S2C-SCORE-EVENT` did not exist and no story claimed it; `ScoreWire` owns the catalogue's **sixteen-byte** row, hand-packed because `gdlint` refused eight loose RPC arguments and was right twice — Variant encoding, and eight positional integers where transposing `actor` and `subject` is invisible. **The courier is a cursor over the log**, `ScoreLog.tail`, rather than a hook on each append, so a third append site (ADR-0014's escape) is covered by existing. **The recipient is `ScoreEvent.actor_id` — a field of the event, not a list a caller assembles**, which is what makes never-do #12's no-global-kill-feed structural. **`SCORE-DEATH` is the one kind withheld**: it pays nothing and it is the only event whose `subject` names somebody the recipient has not earned. `ScoreFeedVm` owns the stagger, the cap and the lifetimes — **a line's lifetime starts when it is SHOWN, not when it was told**, or the fourth bonus of a kill would be readable for 3.64 s against a documented 4.0. The display key is **derived** from the id (`SCORE-FROMABOVE` → `bonus.fromabove`), which is how three bonuses with no name at all were found. `ScoreFeedWidget` draws each value digit by digit at the widest digit's advance, which is right-alignment and tabular spacing in one operation |
| Suspicion | `SYS-SUSPICION` ticks at the `suspicion` stage, **after `crowd`** — the boundary `SystemOrder` calls the most damaging silent failure in the game, since a stale crowd lets a player accrue *alone* suspicion inside a pocket that has re-formed. **Being alone costs nothing as of ADR-0020 (2026-09-15)** — `TUN-SUSPICION-GAIN-OPEN` is 0 and `SuspicionSources.of()` lists the bit only while it pays; the nearest-NPC reading is still taken. One pass over six pawns: the world is read from `ctx.crowd_hash` (never a physics query), impulses drain first and re-arm `TUN-SUSPICION-DECAY-DELAY`, then the integrator, then the tier with hysteresis. **The value lives on `PawnContext`, not in the system** — the builder reads it, so a copy here would be a second authority. `suspicion`, `tier` and `active_sources` go out in the own-gameplay block **to the owner alone**; there is no field anywhere in the format for another player's, which is the rule living in the wire rather than in a widget. `SuspicionSources.of()` is the only place the five conditions are applied and `gain_rate()` is their sum, so the HUD's source list cannot drift from the number it explains. **The impulse queue is `MatchContext`'s** as of US-0060, adopted by reference rather than mirrored, because a system reaching another system's state does it through the context. It has two live callers now — a failed kill and a witnessed one. **The bump still has none**, because pawn and NPC both mask `WORLD` and there is no contact to report; `has_stillness` still needs a loadout |
| Pawn body | **`PersonaBody` for every figure, player and clone, as of US-0101** — undressed (the old generic figure) until `Wardrobe` holds both the seed and the roster, then ART_BIBLE §6.1's silhouette with its identity hue on the clothing. `GreyboxBody` is retired. Procedural — capsule, head and a chest marker on `+Z`, measured from the collider so the two cannot drift. **`PersonaVisuals` was empty through US-0021, 0022 and 0023**: three stories of camera work built around a pawn that did not render, every suite green. The four constructions render side by side in `tools/persona_lineup.tscn` |
| Camera | Real spring arm: 2.6 m, **pawn centred** (US-0092 — the 0.45 m offset never changed the composition, because the rig aims at the pawn's own axis; `INPUT-SHOULDER` retired with it), occlusion that pulls **in** and never sideways, `WORLD`-masked so a crowd cannot push it. The FOV ladder is bound to the **state**, never to `ctx.velocity`: the rung is a consequence of the decision, not of the physics that follows it. Crowd-scan narrows to 48° and grants nothing. **Positive pitch LOWERS the arm** — the rig looks *at* the pivot, so a raised arm looks down; it shipped inverted from US-0021 until somebody played it |
| Input | 20 `InputMap` actions from 14 live `INPUT-` IDs — `INPUT-SHOULDER` is retired via `InputActions.DEPRECATED`, still in the corpus and bound to nothing, KBM + pad. Chain GDD-02 → `Ids` → `InputActions` → `project.godot`, guarded on every hop, both directions. **Sampled once per physics frame by `LocalPawnDriver`, the only caller** — see trap 12. The mouse is **captured** on boot; `INPUT-MENU` releases, a click takes it back. **Only a mapped gamepad holds the joypad bindings** — `PadSelection`, applied through the one `InputMap` writer, because a set of sim pedals was steering |

## What is deliberately unticked

**Forty-nine criteria are deliberately unticked** — regenerated 2026-09-24, back to 49 once US-0100's late joiner and clone floor were ticked on tests rather than on the implementation, each blocked by something real —
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

## Nineteen things that will cost you an hour if you do not know them

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
   needs to be increased`. **At that run all seven jobs were `ubuntu-22.04`, and the two refused
   were the only two that declared `needs: [version, import]`** — so they started last and were
   the ones the allowance runs out under, which is why a partial green is the
   symptom rather than a silent pipeline. A rerun reproduced it exactly. **Read the
   annotation before believing a failed job with no log:**

   ```bash
   gh api repos/<owner>/<repo>/check-runs/<job-id>/annotations --jq '.[].message'
   ```

   **Both refused jobs reproduced locally.** `test` was the three suites against a
   `git archive HEAD` extraction; `export` was two greps over `export_presets.cfg`,
   so its substitute was one line. Since 2026-09-23 export builds three release
   PCKs and boots the stripped server pack; use `.ci/export_packs.sh` locally.
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

19. **A PULLED `.gd` HAS NO `class_name` UNTIL GODOT HAS IMPORTED IT, AND THE
    SYMPTOM IS A GREY WINDOW.** Global script classes live in
    `.godot/global_script_class_cache.cfg`, and **the game does not import at
    runtime** — it expects the cache to be there. So the first launch after a
    `git pull` that brings in somebody else's new script cannot resolve that
    `class_name`, `client_root.gd` fails to **parse**, and the root scene loads
    *without its script*: nothing builds the map, the camera or the pawn driver.
    What you see is a grey window and a scrolling wall of errors about whatever
    read an autoload next — *"Invalid access to property or key 'assembler' on a
    base object of type 'Nil'"*, in `scripts/debug/net_readout.gd`, **four files
    from the cause**. Reported from the controls on 2026-09-09, the tick after
    #217 added five presentation scripts.
    **Trap 1 already said a new `.gd` needs an import before committing; with two
    agents the expensive half is the other direction**, because every pull is
    somebody else's new script and the person pulling wrote none of it.
    `play.bat` and `sandbox.bat` import first now, unconditionally, for **4.4 s
    warm and 6 s cold** — **and stop if the import fails**, because the first
    version did not: it sent the output to `nul` and proceeded to the grey window
    it existed to prevent, hiding the one line that named the cause. **Godot
    returns 0 from an import that could not parse a script** (the reviewer of
    #221 measured it against a malformed autoload), so the launchers keep the log
    at `%TEMP%\sottovoce-import.log`, search it for `SCRIPT ERROR`, `Parse
    Error`, `Compile Error`, `Failed to load script` and `Failed to create an
    autoload`, and abort on either signal before any process starts, printing the
    numbered lines. Verified over both launchers and three outcomes — a parse
    error with exit 0, a silent exit 23, and the real import — on neutered copies
    whose every `start` is an `echo`. A check for whether the cache is current would be a
    second answer to the question the cache itself answers, and this corpus has
    paid seven times over for an instrument that is wrong in a plausible
    direction. By hand:

    ```bash
    godot --headless --path . --editor --quit-after 300
    ```

    **The engine cannot tell you this itself and that is the whole cost.** A
    parse failure prints an engine error and then *nothing of its own*, which is
    trap 3's family: the scene still instantiates, so the window opens and the
    process keeps running. Falsified by deleting the class cache — the client
    then fails to resolve `TuningProfile` and every tuning section — and the
    import step alone brings it back to a clean boot.


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

*Two archives now: M0-M4, moved 2026-09-08, and M5's HUD-and-abilities stretch, moved
2026-09-13 when this file came within 24 lines of its cap. The heading keeps its name
because `test_claude_md_stays_findable.gd` pins it, and a guard is not renamed to
match a sentence.*

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
| **M5, the HUD and the abilities** — [`M5_the_hud_and_the_abilities.md`](docs/00_meta/history/M5_the_hud_and_the_abilities.md), moved 2026-09-13 | the Compass that pointed the wrong way, the score feed, `SYS-ABILITY`, Cinderfall and the Lunge, the three staggers (ADR-0017), the prey's teeth (ADR-0018), the stun's cost (ADR-0019), the pursuit (US-0097), the 40 m bench, the `-s` autoload cascade, the codegen that destroyed shipped gameplay, and the tick gate's estimator | **yes**: `TUN-KILL-CONTEST-STAGGER` is owner decision 7; the 180 s integration budget is decision 2; the animation clips are still absent on both rigs |

**Read it when you need the reason for a rule, not before.** If a number here
surprises you, the archive is where it was measured.

## Fresh session? Read these four first

1. This file.
2. `docs/00_meta/GLOSSARY.md` — every term has exactly one meaning.
3. `docs/50_tuning/TUNABLES.md` — every number.
4. Your story file in `docs/40_backlog/stories/`.

Then the routing table above for the one or two documents governing your system. **Do not read
the whole corpus** — read the `depends_on` chain of what you need.

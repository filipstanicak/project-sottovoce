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

*Updated 2026-08-26 (ADR-0013, scoring re-price). Keep this section current — it is the first thing a
fresh session reads, and a stale one is worse than none.*

## M4 IS FOURTEEN OF FIFTEEN, AND NOTHING IS PLAYABLE YET

**Built:** `SYS-CONTRACT` (US-0049, US-0050), `SYS-SUSPICION` (US-0051, US-0052),
`SYS-BLEND`'s two crowd blends (US-0053), `SYS-DETECTION` (US-0055, US-0056),
the whole of `SYS-COMPASS`'s server half (US-0057, US-0058), `SYS-KILL`
(US-0060), the prey warning (US-0059), `SYS-STUN` (US-0061), `SYS-SPAWN`
(US-0062), `SYS-BLEND`'s two prop blends (US-0054).

**Not started:** the gate (US-0063), and nothing else.

**A PLAYER CAN NOW BE KILLED, AND STILL CANNOT PERCEIVE ANY OF IT.** The server
validates a kill against the lag-compensated world, commits the killer for 1.4 s,
kills the victim at the 0.9 s contact frame, repairs the cycle, spawns a corpse,
startles the crowd and charges the witnesses. **There is no HUD (US-0084, M5), no
Compass, no reticle, no whiff animation, no score and no match end**, and there
are **no animation clips in this project on either rig** — so a kill is a state
change and a log line. **Do not read the sections below as progress toward
something visible.**

**AND `Dead` HAS AN EXIT AS OF US-0062**, which is the last thing that stood
between the loop and a match that degrades as it runs. **All fifteen pawn states
now exist.**

**AND FOUR SYSTEMS NOW TICK THAT DID NOT AT THE M3 GATE**, so US-0048's server-tick
figure is superseded — see the re-measurement under US-0055 below.

---

**THE SCORING TABLE IS RE-PRICED, AND THE RE-PRICING WENT THE OTHER WAY.** ADR-0013
moved thesis enforcement out of mechanics; this moves it into scoring, which is where
the reference keeps it. Four values, each matching the reference's own:
`TUN-SCORE-SILENT` **100 → 200**, `TUN-SCORE-PATIENT` **150 → 100** (the pair now sums
to 300, the reference's top stealth rung), `TUN-SCORE-FOCUS` **100 → 150**, and
`TUN-SCORE-RECKLESS` **−50 → 0**. `TUN-SCORE-BLENDED` needed no change: the reference
pays exactly 200 for the same thing.

**AND A FULL PATIENT KILL IS NOW WORTH 750, WHICH IS THE REFERENCE'S OWN PUBLISHED
EXAMPLE.** Reached by a different split of the same total — ours is
100 + (200 + 100) + 200 + 150, theirs is 100 + 300 + 200 + 150.

**THE EXPECTED RATIO FELL RATHER THAN ROSE: 2.68 : 1 → 2.55 : 1 PER KILL.** That was
not what the re-pricing was expected to do, and the cause is isolable — **removing
`SCORE-RECKLESS` is worth +27.5 per kill to the Aggressor and +1.0 to the Patient**,
which eats most of the stealth uplift. **Converging on the reference makes this game
LESS punishing of aggression, not more**, because it under-pays carelessness rather
than charging for it. Best case fell 13:1 → **7.5:1**, much closer to the brief's
3–5×.

**READ TOGETHER WITH ADR-0013, AGGRESSION GOT BETTER ON BOTH AXES** — more per kill,
and kills that a stun can no longer stop. The counterweight is the stealth ladder at
three base kills, which is **invariant 18**, rewritten from `BLENDED > PATIENT >
SILENT` (an ordering the reference does not have) to
`SILENT + PATIENT >= 3 × CONTRACT` (a floor it does). Falsified against a halved
ladder.

**AND THE BALANCE MODEL'S KILLS-PER-MATCH FIGURES ARE STALE, DELIBERATELY LEFT SO.**
§4.3 models a **45 % stun-per-attempt rate**, which was measured against the old rule
where a stun could interrupt a committed kill. That window is gone, so the rate must
fall — and re-deriving it means guessing a number, then guessing three more that
depend on it. **The point values in §4.4/§4.5 are correct; what they are multiplied by
is not.** `TEL-STUN-RATE` settles it and nothing should be re-derived before then.

**ONE MORE THING THE AUDIT ANSWERED FOR FREE: `SCORE-VARIETY`'s OPEN QUESTION.**
GDD-07 §3.1 has flagged since M0 that per-life Variety behaves as a flat uplift, and
offered two fixes. **The reference uses a third nobody proposed** — per **match**, paid
at thresholds of 5, 10 and 15 distinct bonus types. Not adopted, because the payout
values are not documented anywhere sourceable and inventing three numbers is not
fidelity. Recorded as the recommended fix ahead of the other two.

---

**ADR-0013: THE REFERENCE WINS. THE DESIGN DIRECTION CHANGED ON 2026-08-26.**
The owner set it plainly: **all mechanics — climbing, killing, perks — as close as
possible to the reference title this project is a homage to.** Where a rule here
diverges, the reference wins unless the owner has ruled specifically for the
divergence. **A design law is not exempt**, and three were amended on the strength
of it. `IP_GUARDRAILS.md` §1 already permitted this — mechanics are not
copyrightable — and the name still cannot appear in this repository, so the corpus
says *the reference*.

**AN AUDIT OF EVERY MECHANIC AGAINST IT FOUND 17 FAITHFUL, 12 DIVERGING, 7 MISSING
AND 4 BLOCKED BY RULES WE WROTE OURSELVES.** The full table names the reference in
every row and therefore lives outside the repo, in the owner's design notes. What
is in scope here is what changed and what is owed.

**THREE THINGS WERE AMENDED, AND ALL THREE WERE WELL-ARGUED BEFORE.**
Never-do #12 is narrowed — the hit-direction ban is lifted, the prey warning is
**directional**, and "nameplate" now means a *name* rather than any marker.
Never-do #13 is excepted once — **a committed kill is not interruptible** — while
stun keeps its range advantage, tier gate, freeze and lockout, none of which may be
traded away. And GDD-02 §3.2 rule 1 is reversed: `KillAnimState.is_interruptible`
returns **false**, so only a FATAL-priority third-party kill ends an animation.

**THE TIER GATE IS NOT A DIVERGENCE AND WAS NEARLY DELETED AS ONE.** My first
research said the reference has no carelessness gate on the reveal. **It has one**:
its threat meter depletes on high-profile actions taken *in the prey's line of
sight*, and the pursuer marker appears only once it has. `TUN-STUN-MIN-TIER` and
`TUN-COMPASS-WARN-MIN-TIER` are the faithful version — deleting them would have
moved the game **away** from the reference. Sourced before acting, after being
wrong twice from recall.

**THE THESIS HAS MOVED OUT OF MECHANICS AND HAS NOT YET LANDED IN SCORING, AND
THAT IS AN OPEN DEBT.** "Patience beats speed" was enforced by stun hard-countering
a reckless hunter. The reference enforces it by paying a stealthy kill several times
a careless one — its top stealth bonus is **3-3.5x** a base kill against our
`SCORE-SILENT` at **1x**. Until the scoring table is re-priced, speed is neither
mechanically punished nor financially discouraged. **Do not read the combat change
as finished work.**

**AND THE LARGEST MISSING THING IS A VERB NOBODY HAD NOTICED WAS ABSENT: ESCAPE.**
The reference lets prey break line of sight and stay hidden until a pursuit bar
empties, at which point **the hunter loses the contract**. Here a contract ends only
in a death, so a hunt can never be survived, only postponed — and three of the
reference's scoring bonuses have nothing to fire on.

**IT IS STORIED NOW: ADR-0014 AND US-0097, M5.** A chase opens on exactly the
prey-warning condition — no new trigger, which is what makes US-0059 load-bearing
rather than cosmetic — sight of the prey **refreshes** the bar rather than
incrementing it, and an empty bar removes the hunter from the cycle and reinserts
them under the constraints a respawn already uses. **Structurally an escape is a
respawn without a death**, so it reaches `ContractCycle` through the two calls
US-0049 already fuzzed over 10 000 events.

**`TUN-PURSUIT-DURATION` IS DERIVED RATHER THAN CHOSEN: 10.7 s.** It is
`TUN-COMPASS-WARN-RADIUS` over `TUN-SPEED-BLENDWALK`, so the chase ends at the
moment the prey **could have walked out of warning range at civilian speed** — which
means escaping never requires running. Design law 1 and ADR-0012 expressed as a
duration instead of asserted about one.

**AND BLENDING IS NOT FREE, WHICH IS THE RULE WORTH KNOWING.** A hunter with a clear
line to a player in a held blend cannot pick them out of the pocket — **unless they
had unbroken sight at the instant the blend began**, in which case they watched it
happen. So the prey's line is *break the corner first, then blend*; blending in front
of somebody looking straight at you buys nothing. That is GDD-03 §9.2's "the crowd
hides you by being confusing, never by being solid" applied to a new consumer.

**IT COSTS NO RAYCASTS.** The sight test asks about the hunter and their own contract
— the same ordered pair the Compass lock already queries — so the wider pursuit cone
runs first and the lock's narrower one is a pure angle test on the same result.

**AND THE SCOPE DEBT IT OPENED IS PAID: `ABIL-WHISPERBOLT` IS DEFERRED TO POST-MVP
(2026-08-27).** `SCOPE_FENCE.md` IN #4 reads **three abilities**, OUT #18 carries the
reasoning, §1.1 records the payment as collected, and the file is at **0.3.0**. US-0068
is re-milestoned rather than deleted.

**IT WAS CHOSEN ON ENGINEERING COST RATHER THAN DESIGN MERIT, AND THE ARGUMENT IS
STRONGER THAN THE ADR'S OWN.** Whisperbolt is not merely the largest of the four —
it is the only one that needs **netcode this project does not have**: a replicated
moving entity (a third kind, after pawns and NPCs), client interpolation for it, and
**hit validation at an impact 0.55 s after the press**. `RewindClamp` clamps to
100-200 ms of RTT at the moment of the *press*, which is the only moment lag
compensation here has ever been asked about, and **no rule anywhere says what a
half-second-later impact resolves against.** US-0068's fifth acceptance criterion is
that open question written as a criterion. It is also the only one of the four that
costs **downstream bandwidth, already at 105 %** of a budget missed since M2.

**AND IT IS THE CHEAPEST CUT TO REVERSE, WHICH IS THE PROPERTY A GOOD CUT SHOULD
HAVE.** Nothing is deleted: GDD-04 §3.2's full specification, every
`TUN-WHISPERBOLT-*` value, invariant 11, four `SFX-` IDs, two `ANIM-` IDs and the
`ABIL-` ID all stay exactly as written, so restoring it once `SYS-ABILITY` exists is
a `.tres` and a behaviour. Cutting **escape** instead would have cost a rewrite of
the contract system's assumptions across four documents. That asymmetry is the whole
reason this is the right way round.

**TWO COSTS, RECORDED RATHER THAN HIDDEN.** Loadout variety **halves** — two
abilities of four with three passives is 18 builds, two of three is 9 — which is a
*retention* property rather than a *loop* one, and the fence's own test is "is the
loop fun with six humans". And **nothing in the MVP can reach a player on a roof**:
Lunge is 6 m and horizontal, Cinderfall is area denial, Second Face is identity.
GDD-04 §3.2 gives reaching the roof as Whisperbolt's entire reason to exist, so the
roof stratum is priced **economically rather than mechanically** now —
`TUN-SUSPICION-GAIN-ROOF` +18/s holds a camper permanently Exposed while they score
nothing for sitting there. **Revisit if `TEL-TIME-BY-STRATUM` shows roof time
rising.**

**ONE OF US-0097's THREE CANDIDATES WAS ALREADY DEAD AND THE TABLE DID NOT KNOW.**
Deferring US-0054's two prop blends **shipped on 2026-08-26**. Struck through rather
than deleted, because a decision table with a dead row in it invites somebody to
re-pick the row.

**TWO OF THE REFERENCE'S ESCAPE BONUSES CAN NEVER FIRE HERE AND THAT IS KEPT.** Its
multi-escape bonuses need two and three simultaneous pursuers; a Hamiltonian cycle
gives every player exactly one incoming edge. The single-pursuer guarantee is what
makes GDD-03 §7.4's validity proof work and is not for trading.

**AND THE ADR INDEX HAD BEEN THREE ROWS SHORT SINCE 2026-08-05.** DECISION_LOG §2
stopped at ADR-0011 while ADR-0012, 0013 and 0014 existed as files and as §1 log
lines. Trap 14's shape in a table rather than in a claim: the index a reader consults
to find a decision did not list it.

---

**US-0054 IS DONE, FIVE OF SIX: ALL FOUR BLEND ACTIONS ARE LIVE.** Lean on a
market stall in an empty street and suspicion crushes with no crowd at all; climb
into one of the five hiding spots and you are **not rendered, not killable and
not stunnable**, at the price of seeing nothing and being somewhere everybody has
learned.

**THE TWELVE LEAN SPOTS ARE DERIVED FROM THE STALL TABLE, NEVER HAND-LISTED.**
Two per stall, one on each long side, `NAV_AGENT_RADIUS` clear of the counter.
Six stalls give **twelve** and GDD-03 §4.2's table says *"~12 props"* — the
number follows from the market now rather than being asserted about it.

**AND `is_standable` IS THE WRONG QUESTION TO ASK OF A LEAN SPOT, WHICH COST SIX
OF THE TWELVE.** The first version used it and got **6**. That predicate erodes
every stall by `NAV_AGENT_RADIUS` because an *agent* cannot path into contact
with a counter — but a player leaning on one is in contact by definition, and
their centre sits exactly on the eroded boundary. `Rect2.has_point` **includes**
the minimum face and excludes the maximum, so every stall's north side was
rejected and every stall's south side accepted: **6 of 12, split by a convention
rather than by geometry.** Same hazard as the `AABB`/`Rect2` disagreement that
made an illegal spawn site look legal.

**THE MOST SPECIFIC THING YOU ARE STANDING AT WINS, AND GDD-03 §4.1 GIVES NO
ORDERING.** A hay cart in a market is inside a crowd pocket and beside a counter
at once. Five exact spots, then twelve, then a formation within 2.5 m, then
*anywhere with four NPCs*. A press at a hiding spot that silently took the pocket
would spend a walk the player made deliberately, and they would not find out
until a hunter looked at them.

**THE CONCEALMENT PROP IS THE ONE EXCEPTION TO "BLEND PROTECTS ANONYMITY, NEVER
THE BODY", AND IT IS THE GDD'S RATHER THAN THIS STORY'S.** §4.1.4: *"cannot be
broken from outside; a player inside cannot be killed"*. Enforced by `SYS-KILL`
and `SYS-STUN` reading `PawnContext.blend_state` — written at `suspicion`, read
at `combat` three stages later in the same tick — and
`test_concealed_is_untouchable.gd` asserts **the exception and the rule it is an
exception to**, so the line is visible rather than inferred.

**"NOT RENDERED" MEANS LEAVING `present_slots`, NOT OMITTING THE RECORD.** Delta
encoding made absence mean *unchanged* (US-0031), so a concealed player left in
the mask would be drawn **motionless at the door of the prop they climbed into**
— exactly where a hunter would look.

**`NET-S2C-BLEND-DENIED` IS A NEW MESSAGE BECAUSE THERE WAS NO ANSWER AT ALL.**
`NET-C2S-BLEND-REQUEST` had no S2C counterpart, so a press at an occupied hay
cart and a press at an empty street produced the same nothing. **It is the one
refusal in this game that reports its reason**: a prop's occupancy is level
geometry with somebody in it, not a fact about a stranger, so it cannot be used
as an identity probe the way a kill or stun refusal could.

**AND THE MAP GENERATOR WAS AT 399 OF ITS 400 LINES**, so three new lines needed
a split. `tools/map_data_builder.gd` is it, and the seam is honest: the generator
writes **two artefacts** — scenes with a baked navmesh, and a resource the systems
read — and only the second is what any rule is written against. The map
reproduces byte-identical apart from the new field.

**THE ONE OPEN CRITERION IS *the occupant can see nothing*.** No client renders a
blend at all; the server half is done and `blend_state` reaches the occupant's own
snapshot block, which is what a widget will black the screen out from (US-0084).

---

**US-0062 IS DONE, SEVEN OF EIGHT: `SYS-SPAWN` EXISTS, AND `Dead` FINALLY LEADS
SOMEWHERE.** Five seconds after a death the victim is placed on a declared spawn
point at least 40 m from their killer and 12 m from everybody alive, comes back
at `TUN-RESPAWN-SUSPICION`, is untargetable for `TUN-RESPAWN-INVULN` 1 s, and is
reinserted into the cycle **in the same tick as the placement**.

**IT IS NOT A `GameSystem`, FOR THE THIRD TIME AND FOR A THIRD REASON.** TDD-01
§4's diagram has **no spawn box at all**, and its stage 8 is *"Contract — repair
cycle after deaths"*. A respawn is a repair after a death, so `ContractSystem`
owns and ticks it — and ticks it **first**, so nobody ever stands on the map
holding no contract.

**BOTH RESPAWN EDGES ARE COMPLETIONS, NOT INTERRUPTIONS — TRAP 8, AND IT COST THE
FIRST RUN.** `Dead` and `Respawning` are both FATAL and both decline every
interruption, so an interrupting request at FATAL priority is refused by
`priority <= current.interrupt_priority()` and **the pawn stays dead forever** —
the exact symptom this story exists to fix, reproduced by the fix for it.
`transition()`'s `interrupting` flag is what `step()` already passes false for,
because *a state asking to leave is completion*. **The server holds these two
clocks** because the position a respawn lands at is chosen from the live lobby at
the moment the timer expires, and a client cannot know it.

**THE POINT IS CHOSEN WHEN THE TIMER EXPIRES, NEVER WHEN THE PLAYER DIED.** Five
seconds is long enough for the whole lobby to move, and a point chosen at the
contact frame would satisfy the 12 m rule against a world that no longer exists.

**AND THE FALLBACK IS DETERMINISTIC, WHICH IS THE OPPOSITE OF THE SKETCH.** TDD-10
§6 writes `candidates.pick_random(ctx.rng)` — not a Godot signature, and
`Array.pick_random()` draws from the **global** RNG, which is never-do #8. The
legal set is picked from with `rng.randi_range`; the *fallback* draws nothing at
all, because it runs at the worst moment in a match and the least bad answer is a
property of the world rather than a draw.

**`TUN-RESPAWN-SUSPICION` HAD NO READER AND NOW HAS ONE.**
`PawnContext.reset_for_spawn` writes a literal `0.0` that **agrees** with the
tunable without reading it, so retuning it would have changed nothing anywhere.
Trap 17's family: a value that is correct by coincidence.

**AND THE ANTI-CAMP ANALYSIS IS CONFIRMED WHILE ITS EVIDENCE IS RETIRED.** GDD-05
§2.7 concludes *"worst case: three valid spawns remain"* from **four hand-picked
positions**. Swept over **3 721 on a 2 m grid** the answer is the same — 3 — and
the worst position is **(0, 58)**, the map's western edge, which is none of the
four.

**AND THE "TWO CAMPERS REDUCE IT TO ONE" FINDING THIS FILE PUBLISHED ON 2026-08-26
IS RETRACTED: THE ANSWER IS TWO, AND IT WAS MEASURED AGAINST A RULE THIS GAME DOES
NOT HAVE.** `test_spawn_anticamp.gd` asked `clear_of_killer` — the **40 m** rule —
of *both* campers. `SpawnRules.candidates` applies 40 m to exactly one position,
the killer's, and rule 3's **12 m** to everybody else, because **at any one
respawn there is exactly one killer** however many players stand still. Planting
the 40 m radius back into `clear_of_everyone` reproduces the retracted "1"
exactly, which is how the origin was confirmed rather than guessed.

**AND THE SWEEP WAS MODELLING THE RULE INSTEAD OF CALLING IT, WHICH IS WHY NOTHING
CAUGHT IT.** The masks came from a radius passed in as an argument, so the
conspiracy figure was a measurement of the rule I believed in. It asks
`SpawnRules` now, and all three planted defects redden — including the tunable,
raised past half the spawn separation.

**ONE BODY CAN NEVER DENY TWO SPAWNS, AND RULE 1 IS WHAT DOES IT.** Two spawns fall
inside one 12 m exclusion only if they are within **24 m**, and the closest pair is
**30.86 m**. So each extra camper costs exactly one spawn and it takes the whole
surviving lobby to empty the set.

**AND WHEN IT IS EMPTY, RULE 7 BEATS RULE 2: 61.5 m.** With a body on *every* spawn
point — the worst arrangement that exists — the fallback still places the victim
61.5 m from their killer against the 40 m rule 2 asks for. **A conspiracy buys
nothing, so the analysis needs no rule for one.** What it does need is for somebody
to know that **rule 7 is doing more work than it is documented to do**: it is
written as a safety valve and is also the floor under the anti-camp guarantee, and
that is a property of where these six points are rather than of the rule. Asserted
now, so moving a spawn point reddens it instead of quietly costing it.

**AND THE ANTI-CAMP TEST COULD NOT SEE ITS OWN RULE BEING DELETED.** Planting
`clear_of_killer` to always return true left the whole file **green** — every
assertion in it is *"at least three remain"*, which a rule that excludes nothing
satisfies perfectly. It opens with a counterfactual now, and that plant reddens
it.

**`PawnHost`'s ROUND-ROBIN PLACEHOLDER IS GONE.** A join and a respawn go through
the same `SpawnRules.choose`, differing only in that a joiner has no killer to
stay away from, so the two cannot drift apart.

---

**US-0061 IS DONE, TEN OF ELEVEN: `SYS-STUN` EXISTS, AND THE PREY HAS TEETH
AGAIN.** Press stun inside a 120° cone at 3.0 m + 0.35 m of the player who has
been announced you as their contract, while they are at least Noticed, and they
freeze for 4 s, are held at maximum suspicion for it, and are **exiled from you
specifically for 12 s**. Press it at anybody else — or at a pursuer who is being
careful, or at empty air — and it costs 2.0 s of initiation lockout and +20
suspicion, and the target feels nothing.

**IT IS NOT A `GameSystem`, AND TDD-01 §4's DIAGRAM DECIDED THAT.**
`MatchDirector` permits one system per stage and box 7 of that diagram is a
single node reading **"Kill / Stun"**, so `StunSystem` is a plain object
`KillSystem` owns and ticks — `SuspicionSystem`/`BlendSystem`'s shape. A new
`stun` stage was considered and rejected for the reason the blend stage was: it
would amend a normative diagram six documents reference, to express an ordering
that diagram already expresses.

**THE KILL RESOLVES FIRST WITHIN A TICK, AND THAT IS WHERE ADR-0013 IS ACTUALLY
DECIDED.** `KillSystem.tick` judges its own presses and *then* calls the stun, so
a hunter and their prey pressing on the **same tick** resolve for the hunter —
the reference's contested initiation, expressed as sequencing rather than as a
comment. **A stun at a committed hunter costs the prey nothing**: the press was
correct and merely late, and charging for correct play at the last instant is the
shape of weakening stun that never-do #13 forbids.

**THE `stun_ready` HINT NEEDED THE TIER GATE, AND LEAVING IT OUT WAS AN ANONYMITY
LEAK RATHER THAN A COSMETIC BUG.** The first version gated the hint on
relationship, range and cone alone — so it would have lit up for an **Anonymous**
pursuer standing in a crowd, saying *that one is hunting you*, for free, with no
lock and no warning. Found by a test rather than by review. The bit has existed
in `Snapshot` since US-0029 with no writer.

**EVERY REFUSAL COSTS THE SAME AND LOOKS THE SAME, WHICH IS A RULE.** A refusal
that reported its reason would make the stun button a **free identity probe** —
press it at each stranger and read whether the answer means *not your pursuer* or
*your pursuer, being careful*. So `TOO_CALM` and a swing at empty air are
penalised alongside `WRONG_TARGET`, and `NET-S2C-STUN-RESULT` carries a target
slot of **zero on every rejection**. GDD-03 §10.3's stated case is a non-pursuer;
its stated *reason* is that mashing must never be optimal.

**I NEARLY SHIPPED A STATE THAT CONTRADICTED A NORMATIVE TABLE.**
`StunAnimState` first returned `true` from `is_interruptible`, reasoned from
ADR-0013 being "exactly one state wide". GDD-02 §3.1's interrupt column has read
**"No below FATAL"** for `StunAnim` since M0. The table is normative and the
inference was not.

**THE PUBLISHED BAND IS 2.5–3.0 m AND THE VALIDATED ONE IS 2.85–3.35 m.** Both
rules add `TUN-KILL-VALIDATION-GRACE`, so the window shifts outward — **and its
width is identical at 0.50 m, which is only true because the grace is shared.** A
second grace for the stun would be one that gets retuned alone, and the day it
drifted the range advantage would quietly narrow.

**AND THE LAG-COMP RING RETURNS THE *STALE* FRAME IF A TICK IS RECORDED TWICE.**
`LagCompHistory._frame_at` returns the **first** frame it finds for a tick, so a
test that placed a pawn, filled the ring, moved the pawn and filled again rewinds
to where the pawn **used to be** — and every geometry assertion in the file is
then about the wrong position. It reads exactly like a rule that does not work.
Cost an hour. `_settle()` clears before refilling; **anything that repositions a
pawn mid-fixture must do the same.**

**TWO LOCKOUT SHAPES, ONE TABLE ON `MatchContext`.** A **stagger** is per player
and blocks every initiation; an **exile** is per `(hunter, target)` pair and
blocks one kill. `SYS-STUN` writes both and `SYS-KILL` reads both, so
`CombatLockouts` is adopted by reference — and `KillSystem._locked_until` moved
into it, which is why the contest stagger and the flail stagger are now the same
mechanism.

**THE ONE OPEN CRITERION NEEDS AN ABILITY THAT DOES NOT EXIST.** *"A player
mid-Lunge is stunnable for the entire wind-up and dash"* — `ABIL-LUNGE` is M5, so
there is no state to be mid-. What keeps it true when it arrives is that
`_is_busy` and `_is_stunnable` never grow a case for it, and both name the
criterion.

---

**US-0059 IS DONE, SEVEN OF NINE: THE PREY WARNING EXISTS, AND IT IS
DIRECTIONAL.** A pursuer inside `TUN-COMPASS-WARN-RADIUS` 15 m at Noticed or
above puts a **world bearing and a 0.5 m distance bucket** on the prey's ring,
re-triggering no faster than `TUN-COMPASS-WARN-COOLDOWN` 2.5 s.
`NET-S2C-PREY-WARNING` is two fields where it was one, and it goes **to the prey
alone**.

**IT COSTS NOTHING, BECAUSE IT RIDES A PASS THAT WAS ALREADY LOOKING.**
`_resolve_pair` already computes `hunted_by` for the render state, which is
exactly the relationship the warning is about. A distance, a tier comparison and
a cooldown lookup on pairs the early-out ladder has already admitted — no second
pass, **no raycast**, `raycasts_last_tick` unmoved.

**THE COOLDOWN RE-ARMS WHEN THE PURSUER CHANGES, AND NO CRITERION ASKED FOR IT.**
`CompassLock`'s own US-0058 lesson in a second place: keyed on the prey alone, a
repair handing them a new pursuer would leave the new one **silenced for up to
2.5 s** — the prey's only warning, suppressed by a relationship that no longer
exists. Bounded so alternating pursuers cannot produce a warning every tick.

**THE BEARING IS WOBBLED, ON THE SAME RULE THE HUNTER'S OWN READING USES.** One
ring, one rule — a prey whose warning arrow was exact while their hunting arrow
drifted would learn that the instrument means two different things depending on
which way it points. Keyed on the **pursuer**, so the lie told about one hunter
is uncorrelated with the next. It conceals nobody: at 15 m the drift is about a
metre of lateral error.

**`Tuning.ticks()` TAKES THE `TUN-` ID, NOT THE SECONDS — TRAP 7, AND IT COST A
WHOLE ARCH RUN.** The symptom was *"`DetectionSystem` has no ray query to
inspect"* in a test that never mentions the Compass: the autoload's signature
throws a **parse** error, so every dependent script fails to compile and the
failure surfaces four files away. **Capturing the whole run to a file before
grepping it is what named it** — the corpus carried that note from an
unattributed integration failure and this is the first time it has paid.

**AND ONE OF FOUR PLANTED DEFECTS CHANGED NOTHING, WHICH IS THE FINDING.**
`within := true` reddened the range assertion, `_is_new_pursuer` returning false
reddened two cooldown assertions, a `slot: int` on the RPC reddened two arch
assertions — and **planting `>= ANONYMOUS` into the tier gate left every test
green.** Invariant §17.8 pins `TUN-COMPASS-WARN-MIN-TIER` equal to
`TUN-SUSPICION-TIER-NOTICED`, so no profile `Tuning.adopt()` accepts can separate
the warn floor from `_resolve_pair`'s Anonymous early-out. The gate is **kept
anyway**: the rung above it is an early-out *for cost*, and resting the warning's
correctness on a performance optimisation means widening the ladder later would
warn prey about Anonymous pursuers with nothing failing.

**A THREE-PLAYER RING HAS NO STRANGERS, AND THIS TEST DID NOT KNOW THAT EITHER.**
The first version placed a "nearby stranger" beside the prey and read one warning
where it expected none — in a cycle of three, everybody is somebody's hunter and
somebody's prey. Four players now, counted **per recipient** rather than in
total. Same finding as `test_detection_system.gd`'s at US-0055, second instance.

**THE TWO OPEN CRITERIA ARE BOTH SOMEBODY ELSE'S.** Client-side rotation of the
world bearing needs `CompassVM` (US-0084, M5) — the same blocker as US-0057's
seventh line — and the mono sting has **no call site at all**: `Audio.play()` is
a stub until US-0075 and `EventBus` may hold no `func`, so a guard over it today
would be vacuously green.

---

**US-0060 IS DONE, EIGHT OF TEN: `SYS-KILL` EXISTS.** Press kill inside a 60°
cone at 2.5 m + 0.35 m of your announced contract, measured against the world
rewound by a clamped 100-200 ms, and 0.9 s later they are dead — cycle repaired
in the same tick, corpse registered, crowd startled, witnesses charged. Press it
at anybody else and it costs `TUN-SUSPICION-GAIN-FAILED-KILL` +30 and answers
with a whiff. **Four entry points that had no caller now have one**:
`ContractSystem.report_death`, `BlendSystem.report_damage`,
`SuspicionImpulses.queue` and `CrowdDirector.register_corpse`.

**AND THE CLIENT COULD NOT HAVE BEEN TOLD IT WAS KILLING ANYBODY.** `Reconciler`
compared the server's answer with `PredictedState.error_against`, which is
**position only** — correct for velocity, and false for state. Every state the
server can force (`KillAnim`, `Dead`, `Stunned`, `Respawning`) arrives at a pawn
that may be standing still, so the positional error is **0.000 m**, the
reconciler returned early, and `own_state` rode the snapshot and was never
applied. Nothing failed and nothing errored; the symptom would have been a player
pressing kill and watching their character keep walking. **US-0060 is the first
story that forces a state, which is why it is the first that could tell.** A
state disagreement is a divergence at any distance now, counted apart as
`Reconciler.forced`, and the integration suite still measures **zero replays** at
all four latency profiles.

**A SAME-TICK CONTEST TIE HAD NO HONEST TIE-BREAK AND BOTH OBVIOUS ONES WERE
WRONG.** Iterating `ctx.pawns` is **join** order, which hands the earliest-joined
player every tie for the whole match; a seeded coin makes the most decisive
moment in the game random. Server receive order exists in exactly one place in
the process — `MatchDirector.enqueue_input` — so it stamps a monotonic
`InputCommand.received_ordinal`. It is **never serialised**, so a client cannot
choose its own place in a race.

**`TUN-CINDERFALL-DURATION` HAS BEEN 0.0 SINCE M0 AGAINST A PUBLISHED 4.0.** The
`duration` row is simply **absent from `cinderfall.tres`**, so `AbilityData`'s own
default shipped and a cinder cloud lasted one tick. **Godot writes only the
properties that differ from a script's defaults, so a missing row is
indistinguishable from a deliberate zero** — trap 17 — and `SYS-KILL` is the
first code that ever asked how long a cloud lives.

**AND NOTHING COMPARED `TUNABLES.md` TO THE SHIPPED DATA.** 288 tunables, the
document this file calls "THE gameplay values", and the only checks were
`@export_range` bounds and §17's cross-field invariants — neither of which can
see a value that is simply the wrong one.
`test_tunables_match_the_document.gd` now compares **283 of them and finds
exactly one disagreement**, which is that one. The range sweep beside it **cannot
cover abilities at all**: `AbilityData` is one class holding four abilities'
fields, so `duration` means 4 s of smoke for Cinderfall and 15 s of a false face
for Second Face, and no single band is right for both.

**ADR-0010 SAYS TO REWIND NPCs AND BOTH OF ITS REASONS ARE FALSE OF THE BUILT
GAME.** They are rewound "because NPCs occlude line of sight and determine blend
membership": `has_los` masks `WORLD` only, so NPCs **cannot** occlude by
construction (GDD-03 §9.2), and a blended player is killable normally (GDD-02
§3.2 rule 3). **Kill validation performs no line-of-sight query at all** —
TDD-10 §3's flowchart is Cinderfall, contract, range, cone, contest. So a rewound
crowd has no consumer and would take the ring from **28.1 KB to about 130 KB** to
be read by nothing. Reported in ADR-0010 and TDD-04 §8.2, not built.

**AND THAT LEAVES A CONTRADICTION THE OWNER SHOULD SETTLE: A KILL THROUGH A
MARKET STALL AT 2.4 m IS LEGAL.** TDD-10 §3's flowchart has no line-of-sight gate;
TDD-04 §10's test table implies one. Adding it is a gameplay rule no criterion
asked for, so it is reported rather than invented — and it is also the thing that
would give the rewound crowd a reader.

**THE STAGGER IS AN INITIATION LOCKOUT, BECAUSE THE MACHINE DECLARES NO STAGGER
STATE.** GDD-02 §3's normative diagram has fifteen states and none of them is one,
while **three rules need it** — `TUN-KILL-CONTEST-STAGGER`,
`TUN-STUN-INVALID-STAGGER` and `TUN-LUNGE-WHIFF-STAGGER`. What is built matches
"losing a race should cost tempo, not the match": no points, no lockout, no
suspicion, and 1.5 s in which you cannot initiate. A sixteenth state amends a
normative diagram and is the owner's.

**AND TWO STATES CANNOT DIE AT ALL.** That same diagram has no `Drop -> Dead` and
no `StunAnim -> Dead`, so a player killed while falling or mid-stun-swing cannot
enter `Dead`. `KillSystem._enter` **reports the missing edge rather than
asserting past it**: the death still resolves and the pawn keeps walking.

**A DEAD PLAYER KEEPS THE CAMERA, AND AN EXISTING SWEEP DECIDED THAT.** The first
`DeadState` took it, on the reasoning that a dead player has nothing to aim.
`test_camera_control.gd` refused: `Stunned` is **the only** state allowed to take
the camera, and taking it on death is where a kill-cam starts — never-do #12.

**`RewoundWorld` MOVED INTO CORE**, from `scripts/net/server/`. It was always pure
by its own docstring; `KillRules` is a pure rule, Core may not reference Net, and
a value type one layer up made the rule that consumes it illegal.

**AND THE RANGE IS THREE-DIMENSIONAL WHERE THE CONE IS HORIZONTAL.** Different
questions: "can I reach you" is a distance and "am I facing you" is a bearing,
and there is no aim pitch in this game to put in a cone. A horizontal reach would
put the whole roof stratum, 3.5 m up, inside `TUN-KILL-RANGE` of the street.

---

**US-0058 IS DONE, SEVEN OF SEVEN: THE LOCK, THE REVEAL AND THE PORTRAIT.**
Stand still, keep your contract inside a 25° cone within 20 m with a clear line
for 1.6 s, and the arc completes: a 1.5 s silhouette, a 4 s cooldown before
another, and **ASM-0030's portrait filled permanently for that contract**. This is
`has_los()`'s first caller — one raycast for a hunter watching, **zero** for one
facing away.

**MY 50/50 PEEK TEST DID NOT PIN 1.4, AND FALSIFYING IT IS HOW THAT SURFACED.**
Planting a decay rate of 1.0 left `test_peeking_never_completes...` **green**: at
1.0 an alternating view nets exactly zero, which never reaches full either. That
test proves `decay >= fill` and nothing more.

**WHAT PINS THE NUMBER IS THE DUTY CYCLE.** At rate `r` the break-even is
`r / (1 + r)` — **0.583 at 1.4 and 0.500 at 1.0** — so a hunter watching **55 % of
the time** completes a lock under the weaker rule and never does under the tuned
one. That assertion goes red against the planted rate; the drain-rate measurement
beside it is the other half.

**THE ARC HAD TO TRACK ITS OWN CONTRACT, SEPARATELY FROM THE PORTRAIT.** The first
version inferred a reassignment from `portrait_for` alone, so a hunter who had
half-filled an arc and never completed it **carried that half onto their next
contract** — free progress toward identifying somebody they had stopped hunting.
Read 0.52 against an expected 0.

**AND `NOBODY` IS DELIBERATELY NOT A REASSIGNMENT.**
`TUN-CONTRACT-REASSIGN-DELAY` points a killer at nobody for three seconds;
clearing the portrait on that would make the breath itself destroy an
identification earned before it.

**THE CONE IS GATED ON THE HUNTER'S OWN YAW, NEVER THE COMPASS BEARING.** The
bearing carries `TUN-COMPASS-CONE-WOBBLE`'s lie; gating the lock on it would mean
a hunter aiming at the drifted cone fails to lock a contract standing exactly
where they are pointing. The wobble is a *display* of imprecision, never a change
to where anybody is.

**A TEST THAT ASSERTED NOTHING WAS COUNTED RISKY RATHER THAN PASSING.**
`test_completing_a_lock_fills_it` called a helper that returns on success and
asserted nothing itself. GUT reports a zero-assertion test as risky — the unit
suite's `pending` count went 7 to 8 with nothing red, which is the only signal
there was.

**AND THERE IS A PROTOCOL LEAK THAT WOULD DEFEAT ASM-0030 ENTIRELY, REPORTED
RATHER THAN FIXED.** `NET-S2C-PLAYER-JOINED` is specified as
`peer_id:u8, persona:u8` and `NET-S2C-CONTRACT-ASSIGNED` as `contract_peer:u8` —
so **a client holding both can join them and read its contract's persona
directly**, on the tick the contract is assigned, with no lock. That contradicts
GDD-03 §8.5, NETWORK_PROTOCOL §5's own "not sent" table, and §9's checklist line
*"No payload contains the contract's persona"*. **Neither message is implemented**
— both are lobby work in M5/M6 — so nothing leaks today, and changing a merged
`NET-` ID's payload is the owner's call. TDD-07 §4.5.2 carries two candidate
fixes; the cheaper is that `PLAYER-JOINED` carries no persona at all, since a
client learns appearance from the mesh it draws.

---

**US-0057 IS SIX OF SEVEN: THE COMPASS HAS A BEARING AND A PULSE.**
`SYS-DETECTION` makes one reading per hunter — a **wobbled world bearing** and a
**0.5 m distance bucket** — and both go out in every snapshot's compass block.
The seventh criterion is the rendered cone, and nothing renders anything.

**THE PUBLISHED CURVE IS CORRECT, WHICH IS THE FIRST TIME AN AUDIT HERE HAS FOUND
A TABLE ENTIRELY RIGHT.** All twelve rows of TUNABLES §4.2 reproduce from the four
shipped tunables to **0.40 ms** worst case, against US-0057's 1 ms criterion.

**AND THE CURVE IS 58x STEEPER CLOSE IN THAN FAR OUT** — 0.4593 Hz/m over the last
ten metres against 0.0079 over the first ten. GDD-03 §8.2's "long, flat approach
followed by a sudden sense of imminence" is that ratio, measured.

**A SHAPE TEST WOULD NOT HAVE CAUGHT THE ONE MISTAKE THIS CURVE INVITES.**
`pow(t, 2.2)` instead of `pow(t, 1/2.2)` is still monotone, still bounded by the
same two tunables, and exactly backwards — a long tense approach followed by
nothing. `test_compass_curve.gd` asserts every published row and the gradient
ratio, because either alone would pass over it.

**THE BEARING IS WORLD AND THE CONE IS CAMERA-RELATIVE, AND THOSE ARE NOT THE SAME
CRITERION.** The client rotates the arc by its own yaw every rendered frame; a
camera-relative bearing computed server-side would lag the mouse by the round trip
on the one HUD element that must track the player's head. The **wobble** stays
server-side because it is gameplay: two players standing together must be lied to
identically, or they could compare notes and average the lie away.

**`NO_CONTRACT` IS 255 RATHER THAN 0, AND BUCKET 0 IS WHY.** Zero is a real
reading — it is what a hunter standing on top of their contract gets, and the one
moment in a hunt where a wrong answer matters most. During
`TUN-CONTRACT-REASSIGN-DELAY` a killer has no announced contract and therefore no
Compass at all, which is what makes the breath a breath rather than three seconds
of a cone pointing due +Z at nothing.

**AND THE WOBBLE'S PHASE IS MIXED RATHER THAN USED RAW.** Adjacent contract ids
taken directly would drift almost in step, so two hunts would share a drift and it
would read as a property of the world rather than of the hunt — the one thing that
would make it *un*learnable, by teaching the wrong lesson. Measured: consecutive
ids land **2.23 rad apart**, and sixty of them cover six of eight octants.

**THE READING COSTS NO RAYCAST, LIKE THE RENDER MATRIX BESIDE IT.** Line of sight
gates the **lock**, which is US-0058's — a Compass that stopped pointing whenever
the contract stepped behind a stall would stop pointing for most of a hunt.

---

**US-0055 IS DONE AND US-0056 IS THREE OF FIVE: SUSPICION IS SOMETHING ANOTHER
PLAYER CAN SEE.** `SYS-DETECTION` computes a render state for every ordered pair
at the `detection` stage and the snapshot carries it **per observer**. A player
at 100 is `HARD` to their hunter and their prey and `PLAIN` to everybody else —
which is what stops the match collapsing into everyone converging on whoever is
currently visible.

**IT READS THE ANNOUNCED CONTRACT, NEVER THE GRAPH'S.** `SYS-CONTRACT` repairs
the cycle in the tick a death resolves and holds the *announcement* for
`TUN-CONTRACT-REASSIGN-DELAY`. Rendering from the graph would tint a player the
hunter has not been given yet — the silhouette arriving before the Compass, and
the breath worth nothing. `MatchContext.announced_contracts` is
`ContractSystem`'s own map **adopted by reference rather than mirrored**, so the
two cannot drift; the mirror version was written first and collapsed.

**THE MATRIX COSTS NO RAYCASTS AT ALL, AND TDD-07 §4.3 IS AMENDED.** That section
budgets 2–6 as though the render state needed one. It does not: §2.1's rule is
`tier × relationship`, and §2.3 draws the Exposed outline **through** geometry, so
occlusion must not gate it. The raycasts belong to the Compass lock and
`SCORE-FOCUS`, which are US-0058's and US-0064's. `raycasts_last_tick` publishes
the number rather than assuming it.

**THE REWOUND `has_los` IS REFUSED RATHER THAN FAKED.** Geometry does not move, so
a rewound query against the world alone answers exactly as a current one — and
would **look correct** while the players it is really about sat at today's
positions. It returns false, warns, and counts the refusal, because a caller
quietly receiving false for a match would look like a world with no sight in it.

**AND THE `WORLD` MASK IS THE RULE, NOT A FILTER.** NPCs, players and corpses are
all on `PAWN`/`NPC`, so `has_los` cannot see them however a caller writes it —
which is GDD-03 §9.2's "the crowd hides you by being **confusing**, never by being
**solid**" expressed as a collision mask. `test_los_single_query.gd` refuses a
second raycast under `systems/`, `net/` or `server/` **and asserts the chokepoint
still casts**, so it cannot pass by the query having been deleted. Falsified
against a planted query in `CrowdAlarm`.

**AND THE SERVER TICK IS RE-MEASURED WITH FOUR MORE SYSTEMS IN IT: 2.43 ms MEAN,
3.5-4.4 ms MAX, AGAINST A BUDGET OF 8.0.** US-0048 measured 1.58 mean / 2.27 max
with crowd and pawns alone; contract, suspicion, blend and detection have since
been registered, and `test_server_tick_budget.gd` boots the real
`server_root.tscn` with a full lobby. **Still under a third of budget**, and the
figure is reproducible across three consecutive runs to two decimal places on the
mean. Snapshot serialisation is separate and unchanged in kind at 1.6-2.2 ms for
six clients.

**ONE INTEGRATION ASSERTION FAILED ONCE IN FOUR CLEAN-CHECKOUT RUNS AND IS NOT
ATTRIBUTED.** 650 of 651 on the first run, 651 of 651 on the three after it, and
the failing test's name was not captured. It is recorded rather than explained:
the tick-budget gate was the obvious suspect and is comfortably green above, so
that is not it. **If it recurs, capture the whole run to a file before grepping
it** — that is what was missing here.

**A THREE-PLAYER RING HAS NO STRANGERS, AND MY FIRST TEST DID NOT KNOW THAT.**
`test_detection_system.gd` asserted a "stranger" saw an Exposed player as `PLAIN`
and read `HARD` — correctly, because in a cycle of three everybody is somebody's
hunter and somebody's prey, and that player was the subject's **prey**. Four is
the smallest lobby in which "everyone else" exists.

**AND A PARSE ERROR SKIPPED A WHOLE TEST FILE UNDER A GREEN SUITE.** A helper
named `_pass()` collides with GUT's own `_pass(Variant)`, so
`test_detection_system.gd` failed to parse, was skipped, and the run reported
**114 scripts passing** with nothing red. `.ci/run_gut.sh`'s script count is what
caught it — trap 10's family, sixth instance, and the check has now paid for
itself six times.

---

**US-0053 IS SEVEN OF EIGHT: THE CROWD PAYS OUT.** `SYS-BLEND` is live. Stand
still among `TUN-BLEND-POCKET-MIN-NPC` civilians, or step into the fifth
formation slot US-0043 reserved and never filled, and 0.35 s later suspicion
crushes 100 → 0 over 1.2 s. **The eighth criterion is the persona idle clip, and
there are no animation clips in this project on either rig** — the same blocker
as M3's exit.

**`PawnContext.peer_id` HAS HAD NO WRITER SINCE M1, AND THE FIRST READER WOULD
HAVE BEEN CONFIDENTLY WRONG.** `PawnHost._build_record` never set it and nothing
had ever read it, so nothing was broken. `SYS-BLEND` asking which formation slot
a player holds would have asked about peer **zero** — and
`CrowdFormations.group_of_peer(0)` matches the first group whose `player_peer` is
`NO_PEER`, so a player who never joined would have read as **standing in the
first unclaimed slot**. An empty answer is survivable; a plausible wrong one is
not. Filled, asserted, and `BlendSystem` takes the peer as an argument anyway.

**THE CRUSH BRANCH HAD NEVER EXECUTED.** `SuspicionMath.integrate()` has carried
a linear crush since US-0051 with `blending` permanently false — the one path
that reduces suspicion outside decay was dead code under a passing unit test.

**AND THE ASSERTION THAT CLOSED IT WAS OFF BY ONE TICK, NOT WRONG ABOUT THE
RULE.** It measured 97.22 against an expected 100.0, and **2.78 is exactly
`TUN-SUSPICION-MAX` over `TUN-BLEND-CRUSH-TIME` at one net tick**.
`blend.resolve()` is step 1 of the suspicion pass, so on the tick the entry
window closes the record is already `HELD` when the integrator reads it and the
crush legitimately runs that tick.

**`BlendSystem` IS NOT A `GameSystem`, AND THE DOCUMENTS DECIDED THAT.**
`MatchDirector` permits **one system per stage**. TDD-07 §1's diagram draws blend
resolution as step 1 *inside* the `SYS-SUSPICION` box, and TDD-01 §4.1's
rationale for crowd-before-suspicion already reads "…and **blend-pocket validity
depends on NPC positions**". So it is a pure `RefCounted` the suspicion system
owns — `ContractCycle`/`ContractSystem`'s shape. **A new `blend` stage was
considered and rejected**: it would amend a normative diagram six documents
reference to express an ordering both already express. TDD-07 §3.1.1.

**THE SLOT WALKS AND THE PLAYER KEEPS UP — NOTHING MOVES THE PAWN.** The group
blend *judges* rather than steers. Driving a blended player toward their slot
would put the server in charge of a position the client predicts, so every tick
of the blend would be a reconciliation; it would also take the agency GDD-03
§4.1.2 trades for mobility without charging for it.

**AND A BREAK ARMS THE SCORE GRACE, WHICH NO DOCUMENT DECIDED.** The alternative
— only a deliberate exit qualifies — hands a hunter a way to deny +200 by
sprinting past a pocket and scattering it, paying the reckless approach the whole
design exists to charge for. An interrupted *entry* arms nothing, or the bonus
would be reachable by tapping the key near a crowd.

**`PawnStateId.BLENDED` IS STILL UNREACHABLE AND THE MISSING CLIP IS NOT WHY.**
Nothing has ever transitioned into it. The server cannot simply put a pawn there:
the state machine is **predicted**, and a transition depending on server-only
knowledge — how many NPCs are within 3.5 m — is one the client cannot reproduce,
so it would diverge every tick of every blend. Either predict the *press*
optimistically on both peers and let the server break it, the way a vault is, or
never predict it and drive the pose from `blend_state`. A real decision with
prediction consequences, and not in this story's criteria.

**AND THE SECOND, WRONG SUSPICION LADDER IN `scripts/pawn/` IS GONE.**
`PawnState.suspicion_rate()` and twelve overrides implemented the whole thing
again — roof toll, decay, climb, vault, and `BlendedState`'s crush — and
**nothing in the shipped game ever called any of it**. It was not merely a
duplicate but one that **disagreed**: `scripts/pawn/` had no `gain_open`, no
`decay_delay`, no `stillness_mult` and no speed ceiling, so standing alone in an
empty plaza *recovered* anonymity at **−8/s** there against **+6/s** in
`SuspicionMath` — opposite signs on the mechanic that makes an empty plaza
dangerous — and tap-sprinting was free. Four unit-test files asserted it in
detail, which is exactly what made it look maintained.

**`StunnedState.enter()` WAS THE WORST OF IT, BECAUSE IT WAS A WRITE.**
`ctx.suspicion = Tuning.suspicion.max_value` in code that is **replayed during
prediction reconciliation** — a client deciding its own gameplay state, never-do
#3 — and it *set* the value once where TUNABLES §17 asks for it to be **held**
for `TUN-STUN-FREEZE`, so the decay it re-armed began eating the punishment on
the next tick. `SuspicionSystem._force_exposed_while_stunned()` holds it now,
after the integrator, which is a ceiling rather than a nudge.

**ONE DOCUMENTED RULE HAD TO BE CARRIED ACROSS RATHER THAN DELETED.** GDD-02
§6.1's cost table prices a **mantle** at "+11.4 (climb rate × duration)" and a
vault at nothing — and `PawnStateId.VAULT` is *both*, so the state alone cannot
say which. `SuspicionState.mantling` is that bit, and it reuses the `CLIMB`
source rather than claiming a sixth: hauling yourself onto a ledge is climbing to
anyone watching. Found by `test_vault_state.gd` failing on the deleted function
rather than by reading the table.

**`test_roof_toll.gd` WAS RE-AUTHORED, NOT DELETED.** Its eight properties are
real and only three were covered elsewhere; it moved to
`test/unit/core/suspicion/` and drives `SuspicionMath`. **And its first new
assertion was wrong in an instructive way**: "dropping off a roof is free" read
18.0, because a pawn falling from `ROOF_Y` is still above
`TUN-SUSPICION-ROOF-HEIGHT` and still paying the toll. The drop is free; the roof
you drop from is not. It compares against `IDLE` at the same height now.

**AND THE NEW GUARD'S FIRST VERSION HAD A HOLE THE SHAPE OF ITS OWN EXCEPTION.**
`test_pawn_holds_no_suspicion_rule.gd` allows `scripts/pawn/` exactly one
`Tuning.suspicion` field — `break_on_speed`, which is a state *transition*. The
first version asked whether the **file** mentioned an allowed field anywhere, so
`blended_state.gd` was waved through for every other field as well. Falsified
against a planted crush rate it stayed green while the function scan beside it
went red. It is per **line** now, and names the field and the line number.

---

**US-0052 IS SEVEN OF EIGHT: `SYS-SUSPICION` IS IN THE SHIPPED SERVER.** The
integrator has a driver. Six players are read from this tick's spatial hash — not
a physics query — integrated, tiered with hysteresis, and their value, tier and
**source bitfield** go out in the own-gameplay block of every snapshot. A tier
crossing is announced once.

**THE SOURCE LIST AND THE NUMBER ARE ONE DECISION NOW, NOT TWO.**
`SuspicionSources.of()` is the only place the five conditions are applied and
`gain_rate()` returns the sum of the rates of exactly the bits it sets. Written as
two functions they drift the first time a condition is retuned — no error, and the
symptom is a player reading "sprinting" while the value climbs because they are
alone, who then learns to stop reading the channel. The sweep covers all 48
combinations of state × roof × alone × blending **and asserts it reached every
bit**, because an `of()` that always returned nothing would satisfy the agreement
perfectly.

**THE SPEED READ IS HORIZONTAL, AND IN THREE AXES `PASV-STILLNESS` WOULD HAVE BEEN
DEAD ON ARRIVAL.** A grounded `CharacterBody3D` keeps a small downward velocity
from its floor snap, comfortably above `TUN-PASV-STILLNESS-SPEED-CEILING` 0.15 — so
every standing player in the game would silently lose the passive they equipped.
Nothing errors and no existing test touches it.

**AND THE TEST FOR THAT FAILED FIRST, ON THE HARNESS RATHER THAN THE CODE.** Run as
two sequential halves on one pawn it compares 42.00 against 37.20, because
`ticks_since_gain` survives a reset of the *value*: the second half decays for the
eighteen ticks the first spent arming the delay. **4.8 points is exactly
`TUN-SUSPICION-DECAY-BASE` over `TUN-SUSPICION-DECAY-DELAY`**, and it reads like a
finding about the axis under test. The halves run side by side in one pass now.

**AN IMPULSE RE-ARMS THE DECAY DELAY, WHICH NO DOCUMENT DECIDED.**
`ticks_since_gain` means *ticks since this player last did something suspicious*,
and without the re-arm a shove taken by an already-decaying player is refunded from
the tick it lands on. Two players sitting at 15, one from running and one from a
bump, must decay identically — a decay curve carrying information about how the
value was earned is a channel nothing in the design intends. TDD-07 §2.2.1.

**AND THE QUEUE IS THE SYSTEM'S, NOT THE PAWN'S, WHICH AMENDS TDD-07 §2.2.**
`PawnContext` is replayed during prediction reconciliation, so a client replaying
twenty commands would walk a queue of gameplay impulses twenty times — never-do #3
with a queue in front of it.

**NOTHING CAN BUMP AN NPC, AND THE BLOCKER IS PHYSICAL RATHER THAN A MISSING
CALLER.** `npc_server.tscn` and `pawn_server.tscn` **both mask `WORLD` only**, so a
pawn and an NPC pass through each other with no contact of any kind. The debounce
is built and tested both ways — five shoves in five ticks are one charge, five
spaced a cooldown apart are five — and `report_npc_bump()` has no caller. Charging
+15 for an overlap the player felt nothing from would be an impulse with **no
tell**, which design law 3 forbids as firmly for a cost as for an ability. Making
the crowd solid changes how a dense pocket feels to move through and is the
owner's. TDD-07 §9 question 5.

**THE ONE UNTICKED CRITERION IS BLOCKED TWICE OVER.** "Witnessed kill applies only
if another PLAYER had LOS at initiation" needs `has_los()`, which is US-0056's, and
a kill to witness, which is US-0060's.

**A GUARD SCANNED FOR A STRING LITERAL AND PASSED ON EVERY FILE.** The first
version of `test_suspicion_is_wired_into_the_server.gd` looked for `&"suspicion"`
in the system's source — and `SourceScanner` **blanks string literals** so a guard
is never tripped by its own documentation, which is exactly why it exists. It
matched the blank. Caught only because it failed on correct code; it asks the
object for its stage now.

**AND `MatchContext` GAINED `pawn_contexts`, WITH THE DRIFT ASSERTED RATHER THAN
HOPED FOR.** `ctx.pawns` holds `CharacterBody3D`s, which is what the four crowd
consumers want; a system wanting velocity, state and elevation had nowhere to reach
— `PawnHost.context_for()` is plumbing, not a dependency. The two are written and
erased on adjacent lines and `test_pawn_host.gd` asserts their key sets never
differ. **A peer present in one and not the other is a player whose suspicion never
moves while everything else about them works.**

**TDD-07's FILE AND TEST TABLES WERE AUDITED AND BOTH WERE PARTLY FICTION** — the
fifth time that audit has paid. Three of §6's six paths named directories nothing
occupies (`scripts/core/math/`, `scripts/systems/`), and of §7's twenty-three test
rows **eight exist**; two were never written under their given names and their
property lives in `test_suspicion_math.gd`. Both tables carry a state column now.

---

**US-0051 IS DONE, EIGHT OF EIGHT: THE SUSPICION INTEGRATOR EXISTS** — and it
found two things wrong with the documents it was built from.

**THE TAP-SPRINT EXPLOIT IS NOT CLOSED, AND THE NUMBER IS 4.3 %.** GDD-03 §3.3 and
TDD-07 §2.1 both say `TUN-SUSPICION-DECAY-DELAY` makes stop-start "strictly worse
than committing". Measured in suspicion **per metre**, which is what a player
actually spends to cross the district:

| | pts/m |
|---|---|
| Tap-sprint, no delay (the exploit as written) | 2.024 |
| Tap-sprint, with the delay | **2.976** |
| Committing to a run | **3.111** |

**The delay adds 47 % and leaves stop-start cheaper than committing.** Closing the
rest needs `TUN-SUSPICION-GAIN-SPRINT` at **26.1** rather than 25.0 — inside its own
20–32 band, and a `TUN-` change is the owner's — **or** the speed ladder already
closes it, since a real pawn cannot alternate at 4 Hz through
`TUN-SPEED-RUN-RESOLVE` and the sprint double-tap. **That half is unverified**: the
test drives `speed_state` directly and nothing yet drives real pawn states through
the integrator. Reported as `pending`.

**AND THE COUNTERFACTUAL CAUGHT THE PRIMARY TEST MEASURING THE WRONG THING.** The
first version ran twelve seconds; **both patterns saturate at 100 in that time**, so
`value / metres` collapses to `100 / metres` — a comparison of **distances**, which
tap-sprinting "wins" purely by being slower. It passed. What failed was the
counterfactual — defeat the delay and the exploit must reappear — because the
saturated measurement could not see the exploit either way. **A test whose
counterfactual fails is telling you the primary test is measuring something else.**

**GDD-03 §3.5's WORKED 45-SECOND TIMELINE CANNOT BE REPRODUCED.** US-0051's test
note asks for it to 0.1 points; it is driven by a **jog at +4/s**, and
`TUN-SUSPICION-GAIN-JOG` is **deprecated with no successor** along with the rung
itself (US-0090, 2026-08-12). On the current ladder the same actions reach
**Exposed at 7.9 s** rather than brushing Noticed — which inverts what the example
teaches, since its whole point is a hunter who was never noticed. Re-authoring a
worked example is design prose and is the owner's; the integrator is tested against
§3.3, which is unambiguous and current.

**AND `evaluate_tier` AMENDS TDD-07 §2.3's SKETCH: A RISE MAY SKIP A RUNG AND A
FALL MAY NOT.** That sketch walks one rung per tick in both directions, so a stunned
player — `TUN-STUN-FORCES-EXPOSED` sets the scalar to 100 outright — would read
Noticed for a tick first. **A rule that forces a tier is not kept if it lands a tick
late.** Nothing forces a tier downward, so a fall still passes through.

**US-0050 IS FOUR OF SIX: `SYS-CONTRACT` IS IN THE SHIPPED SERVER.** A peer that
joins is inserted into the cycle, a peer that leaves is removed in the tick it
leaves, and `NET-S2C-CONTRACT-ASSIGNED` goes out to the holder alone — a **wire
slot** and a reason, because peer ids never travel.

**"REPAIR IN THE SAME TICK" AND "BATCH INSIDE 0.25 s" LOOK CONTRADICTORY AND ARE
NOT.** A **removal is not a rebuild**: deleting a node from a cycle leaves a cycle,
so removals apply at once and cannot conflict with each other. What
`TUN-CONTRACT-REPAIR-DEBOUNCE` governs is the **announcement** and the
**insertions** — the operations that choose something. The graph is never behind
what a player has been told; it is sometimes ahead, and that is the breath.

**AND THE BREATH POINTED THE KILLER AT A CORPSE.** `TUN-CONTRACT-REASSIGN-DELAY`
was built as *hold the new contract*, which left the **old** one standing for three
seconds — a Compass aimed at the player they had just killed. A kill announces
**twice** now: the clear at once, the name after the breath, both as one message
kind because slot 0 is "nobody" on the wire. **Found by the one assertion that
swept every tick rather than the settled state**, and every other test in the file
passed straight over it.

**`net.gd` WAS 392 OF ITS 400 LINES**, with seven more M4 event messages still to
come, so the split its own comment predicted — *"the C2S doorway below could move
the same way if this file grows again"* — happened at the **first** of them rather
than the fifth. `EventWire` is a child of the `Net` autoload, which is at the same
path on every peer.

**TWO CRITERIA STAY UNTICKED AND BOTH ARE BLOCKED ON THINGS THAT DO NOT EXIST.**
`open()` is Fisher–Yates against the seeded generator and **nothing calls it**,
because there is no COUNTDOWN phase until `SYS-MATCH`; the live path is
`report_join`. And "announced audibly and visibly" needs `Audio.play()`, a stub
until US-0075, and `CompassVM`, which is US-0057.

**M4 HAS STARTED, AND THE OWNER SIGNED OFF THE LEVEL FIRST: "it looks and feels
great."** That is the judgement that closes three milestones of level work — the
piazza connected, the routes re-authored, the district walled, the interior massed,
rule 6 closed and rule 8 down to one spawn.

**US-0049 IS DONE, SEVEN OF SEVEN: `ContractCycle`.** GDD-03 §7's Hamiltonian cycle
as a pure Core type — `contract(pi) = p(i+1 mod n)`, the ordered list is the whole
representation, and **the repair is the removal**: deleting a node from a cycle
leaves a cycle, so the victim's pursuer inherits by construction and nobody is
contractless for an instant. That property is why a cycle beat a random matching,
and it is asserted rather than assumed.

**THE ANTI-REPEAT RULE WAS INERT, TWICE, AND ONLY ONE TEST COULD SEE IT.**
`remove()` cleared the departing peer's contract history — and **the only reader of
that history is the insertion that happens when they come back**. Then `open()` did
not record the deal it had just made, so the first respawn of a match had no
history either. Measured: **26 of 40 seeds avoided the repeat, 40 of 40 after.**
Both are the same shape — *a rule that is present and never reached* — neither
errored, and **the 10 000-event fuzz could not find either**, because a cycle with
no history is a perfectly valid cycle.

**`assert_valid()` RETURNS A STRING RATHER THAN ASSERTING**, because GDScript
strips `assert()` from release builds: a validity check written as an assertion is
one that does not exist in the shipped game. Empty means sound.

**AND A JOIN IS THE SAME CALL AS A RESPAWN**, with the constraints vacuous, rather
than §7.2's separate random insertion — so the two cannot drift apart. `apply()`
does every removal before any insertion, which is what stops a respawn landing
beside somebody who leaves in the same batch.

**THE FUZZ ASSERTS ITS OWN COVERAGE BEFORE IT ASSERTS THE INVARIANT.** 10 000
events over 200 sequences — 5 334 removals, 4 491 insertions, 1 222 batches —
visiting cycle sizes 0 to 9, and it fails if it never reached two players, one
player or a full lobby. A run that did nothing but joins would otherwise pass
every assertion in the file.

**GDD-05 §2.7 RULE 8 IS DOWN TO ONE SPAWN: S4 1 → 9 SEATS, S5 6 → 9, AND NOBODY
MOVED.** The market was zoned as a corner of itself. §2.3 gives
`LOC-MERCATOPICCOLO` **5–8 NPCs/6 m** and calls it "the second-safest ground — so
the map has two poles rather than one", and `MercatoStallRow` covered **72 m² of a
900 m² market**: six anchors against Piazza del Vetro's twenty. Same shape as
US-0096's `Fondaco` receiving zero — a zone whose extent does not match the space
it names.

**THE SIZE IS DECIDED BY THE ANCHOR BUDGET AND THE DIRECTION BY THE SPAWN
CENSUS.** 78 NPCs less the 16 walking circuits leaves ~62 idle, and
`test_navmesh_coverage.gd` refuses more than **70** anchors — *"a zone whose
anchors cannot be filled is not dense, it only claims to be"*. The map carried 67,
so the whole district could afford **three**. Spanning both stall rows wants 15,
measured at **76, and fails that assertion**. Extending north buys nothing (S4
stays 6); **z = 76 is the northernmost placement that reaches S4**. 12 × 6 →
12 × 10.

**AND IT MADE THE CROWD CHEAPER ON THE WIRE, WHICH NOBODY EXPECTED.** Spreading 78
NPCs over 70 anchors instead of 67 thins the worst-case cluster: downstream
**107.6 kbit/s (112 %) → 100.6 (105 %)** — the first movement on that budget since
M2, bought by a level-data fix rather than by anything in the netcode. It still
misses, and the cull curve is still flat, but the worst snapshot is dominated by
**how tightly the crowd stands**, not by how far the radius reaches. TDD-04
§7.1.2.

**S3 CANNOT BE FIXED THIS WAY AND THAT IS A DESIGN LIMIT.** It is in the Fondaco,
which §3 makes low-density on purpose, and no market is within 25 m. Closing it
needs a larger crowd — a `TUN-CROWD-COUNT` change with a bandwidth cost — or the
rule-3 grace, which is where it sits.

**RELOCATION WAS THE OTHER ROUTE AND IT IS CLOSED: THERE ARE ZERO LEGAL SITES**
for any of S3, S4 or S5, grading GDD-05 §2.7 rules 1, 4, 5, 6 and 8 together.

**AND THIS CORPUS BRIEFLY SAID "SEVEN", WHICH WAS WRONG.** PR #141 published
*"7 legal sites in a 4 × 4 m patch of the Loggia, so at most one of the three can
be relocated"*. **All seven were inside `LoggiaPier`** — the sweep walks floor
*rectangles*, and a floor rectangle includes whatever is built on top of it, so it
never asked whether a candidate was outside the building standing on it. That is
also why they looked so beautifully occluded: they were inside a wall.

**THE FIX FOR THAT HAD ITS OWN TRAP.** Asking
`VetraioGround.clear_of_obstacles(p) == p` still passed, because that function
**returns its input unchanged when it finds nowhere usable within four metres** —
deliberately, so a bad anchor stays findable rather than teleporting. So "already
fine" and "gave up" are the same value, and a point six metres inside a pier reads
as clear ground. `VetraioGround.is_standable()` is public now and is the question
to ask.

**AND THE CENSUS IS A SCENE NOW, NOT A `-s` SCRIPT.** A `-s` script gets no
autoloads, so `Tuning` does not exist and **every Core class that reads it fails to
compile along with everything depending on it** — which silently disabled the
ground check through `CrowdRoster`. It prints `Identifier not found: Tuning` among
the output and reads like noise. `tools/anchor_census.tscn`:

```bash
godot --headless --path . res://tools/anchor_census.tscn
```

**THE BINDING RULE IS 8, NOT 6, SO MORE MASSING WOULD NOT HELP.** Within 45 m of
each starved spawn there are sites satisfying rules 1, 4, 5 and 6 that fail only on
seats — best found: **S3 4, S5 6, S4 2, against 8 needed**. The lever is **density,
not mass**.

**WHICH MAKES S5 A LEVEL-DATA DEFECT AND S3/S4 A DESIGN LIMIT.** GDD-05 §2.3 gives
`LOC-MERCATOPICCOLO` **5–8 NPCs/6 m** and calls it "the second-safest ground — so
the map has two poles rather than one", and its only DENSE zone is **12 × 6 m
inside a 30 × 30 m market**: 72 m² of 900, six anchors against the Piazza's twenty.
Same shape as US-0096's `Fondaco` getting zero. Widening it is S5's fix and it
moves every crowd figure, so it is priced separately. S3 and S4 are in the Fondaco,
which §3 makes low-density on purpose, and they stay ❌ behind the rule-3 grace.

**AND (36, 98) WAS NEVER LEGAL FOR A SECOND REASON**: it is inside the
`PonteCortoApproaches` theatre space. The census had been reading the zones'
`is_theatre` flag, which finds only Piazza Secca — `PonteCortoApproaches` is in
`VetraioLayout.THEATRES` and in `MapData.theatre_spaces` and **is not a zone at
all**. `test_map_dead_ends.gd` has always enforced rule 5 against `theatre_spaces`,
so that is the list the census reads now.

**THE DISTRICT HAS INTERIOR MASSING NOW, AND GDD-05 §2.7 RULE 6 HOLDS FOR THE
FIRST TIME: 9 OF 15 SPAWN PAIRS IN CLEAR SIGHT → 0 OF 15.** The rule carried a ✅
and was false. `BLOCKS` held **seven** masses, four of them corner blocks, and the
district's whole middle had none at all — so **no spawn position could have
satisfied it**, and the anti-spawn-camp analysis was asserted against geometry the
greybox did not have. Seven masses now: 14 blocks, navmesh 211 → 255 polygons.

**NONE OF THE SEVEN IS INVENTED TO FIT A SIGHTLINE.** Each is something the corpus
already named and had never built: the wall §2.1 draws between Piazza Secca and
Mercato Piccolo; the warehouse blocks §2.1 row 105 draws interrupting the Fondaco;
a **pier** for the Loggia, which §2.1's legend calls a *covered arcade* and which
was a 90 × 18 m hall spanning the district; and the **weigh-house** GDD-03 §6.2
gives `PERSONA-PESATORE`'s clones as an idle anchor and which had no geometry.

**THE GAPS ARE LOAD-BEARING AND THE FIRST VERSION PROVED IT.** A wall that fully
spans a room turns it into an island: 1 099 orphaned cells of `MercatoPiccolo` and
`FondacoStreet`, and `CIRC-C` broken in ten places. Measured after: **100 % of
walkable ground reachable, all four circuits walkable, anchors unchanged at 67, and
every spawn's seat census unchanged — S6 still exactly 8 of 8.**

**IT WAS DESIGNED AGAINST A THROWAWAY HARNESS, NOT AGAINST THE SUITE.** A 0.5 m
flood fill plus a sightline sampler, cross-checked against the real test on the one
quantity both compute — it reproduced the 9 clear pairs exactly — and then iterated
in seconds instead of in three-minute bakes. **What it could not model is the agent
radius**, and that is where both of the real defects were.

**AND `clear_of_obstacles` WAS PLACING ANCHORS FLUSH AGAINST WALLS.** It required a
point to be *outside* an obstacle and the navmesh is eroded by
`NAV_AGENT_RADIUS` — so a point against a face is **off** the mesh, and
`map_get_closest_point` then answers with the isolated patch **inside** the block.
That is US-0041's `Npc003` standing on a market stall, in a new costume: an anchor
that looks placed, snaps to something, and can never be walked away from. The
massing put one 0.1 m from `LampeIsland`'s west face. It requires the radius as
clearance now, and the anchor count did not move.

**THE SAME DEFECT HAD ALREADY FOOLED THE CONNECTIVITY TEST, TWICE AND
DIFFERENTLY.** `test_the_district_is_one_connected_island` seeded each floor at its
raw **centre**, which is only walkable while no floor has a building in the middle
of it — `ViaDelleLampe` and `MercatoPiccolo` both reported **0 of 10**, a courtyard
reading as a severed island. Seeding at the nearest obstacle-free point fixed one
and left the other, because that point was `LampeIsland`'s east face **exactly** and
snapping it to the mesh pulled it onto the island *inside* the block. It seeds at a
navmesh point clear by the agent radius now, **and the nudge is guarded**: a floor
buried entirely under mass would otherwise seed onto its neighbour and report itself
perfectly connected, forever.

**ONE PUBLISHED NUMBER GOT WORSE AND IT IS NOT ONE A PLAYER PAYS.** The cull-radius
sweep's floor row read **93.4 kbit/s, 97 % — closing the budget** — and now reads
**100.0, 104 %**, so `test_cull_radius_price.gd` reports rather than asserts. **The
shipped figure is identical at 107.6 kbit/s, 112 %.** What was lost is a
hypothetical escape route nobody had chosen; the cause is seven masses rerouting a
strolling crowd, since only **4 of 67 anchors moved at all**. The sweep is
reproducible to 0.1 kbit/s, which is what makes the comparison worth reporting.
TDD-04 §7.1.2.

**THE CLONE-MINIMUM CONTRADICTION IS DECIDED: GDD-03 §6.3 RULE 3 NO LONGER BINDS
AT THE INSTANT A PLAYER IS PLACED.** The owner chose the third of three priced
options on 2026-08-21. Three documents each said something true and the three
could not all hold — §2.7 puts S3 and S4 in the Fondaco, §3 makes the Fondaco
empty on purpose, and rule 3 demanded eight clone seats at every spawn. **The map
seats 4, 1 and 6 of 8 at three of six**, and a permutation cannot conjure a seat
that is not there, so rule 3 was violated at the first tick of every match **by
the level**.

**A RELEASE BLOCKER NOTHING CAN SATISFY IS ONE NOBODY ACTS ON**, and this one sat
for two milestones being re-reported. Rule 3 binds from
`CloneParity.grace_seconds()` after placement now, and the opening arrangement is
**GDD-05 §2.7 rule 8's** — a level rule with a census, a `pending` test and a tool.

**THE GRACE IS DERIVED AND DELIBERATELY NOT A TUNABLE: 19.86 s, 596 ticks, 4.1 %
of a match.** One `TUN-CROWD-DIRECTOR-INTERVAL` — the soonest the crowd can notice
— plus one crossing of `TUN-CROWD-CLONE-LOCAL-RADIUS` at
`TUN-CROWD-NPC-SPEED-STROLL`. A fourth number here could be set to a value the
first three contradict.

**ONE NUMBER SERVES BOTH ENDS OF THE RULE, AND THAT IS INVARIANT 1 RATHER THAN
LUCK.** It is how long a fetched clone takes to reach the player *and* how long
the player takes to walk to the crowd, because stroll is forced equal to
blend-walk. **So a player placed in a thin corner never has to run to buy back
anonymity**, which design law 1 would charge them for.

**IT CHANGES NOTHING ABOUT S4's EXPOSURE AND MUST NOT BE READ AS IF IT DID.** A
player placed at (114, 97.5) still sees **one** NPC within 25 m and is still
uniquely identifiable for the grace. **Only the owner of the defect moved** — from
a design law no map could satisfy to a level pass somebody can run. The fix is to
**move a spawn point, not to fill the Fondaco** — and the three relocations are
**re-priced**, below.

**AND THE SCOPE IS ONLY HONEST WHILE ITS CONDITIONS HOLD, SO THEY ARE ASSERTED.**
`test_clone_parity_scope.gd` requires the grace to be at least one blend-walk of
the radius — otherwise the rule binds on a position the match chose and the only
escape costs speed — and strictly less than a match. Falsified against a halved
grace: two of five go red. Same shape as `test_the_district_is_enclosed.gd`.

**`test_clone_local_min.gd` ASSERTS THE SCOPED WINDOW NOW AND PRINTS THE WHOLE
POPULATION BESIDE IT** — §11.2.2's choice, so nothing looks dropped. **71 of
12 960 readings under the floor over the run, 47 of 11 544 after the grace, 0.41
%.** Its `settle` was `interval * 10` and landed within four ticks of the
derivation; **a multiplier that agrees with the answer is not one that follows
it**. US-0047's *always* criterion **stays unticked** — the scoping excuses the
opening arrangement, not the mid-match troughs, and no re-routing rule beats a
walk.

**AND THE THREE RELOCATIONS ARE RE-PRICED, BECAUSE THE INSTRUMENT THAT PRICED
THEM GRADED ONE RULE OF FOUR.** `tools/anchor_census.gd` scored candidate spawn
sites on seats and spawn separation only — not rule 4's circuit reach, and its
rule-5 filter excluded a *floor* named `PiazzaSecca` when the plaza is a **zone**
spanning several floors. It grades rules 1, 4, 5 and 8 now and prints a
zone-labelled shortlist per starved spawn.

| | Was published | **Measured** | Where it lands |
|---|---|---|---|
| S3 | not priced | **30.0 m** to (36, 98) | **stays in the Fondaco** |
| S4 | 55 m | **61.9 m** to (72, 52) | the Loggia, the centre |
| S5 | 10.8 m, "still Mercato Piccolo" | **18.0 m** to (100, 52) | the Loggia. **Not Mercato Piccolo** |

**S5 WAS NOT THE CHEAP ONE AND ITS 10.8 m SITE WAS ILLEGAL.** (90, 66) is Piazza
Secca's own eastern boundary, and `AABB.has_point` — what `MapZone.bounds` uses —
**includes** the maximum face where the `Rect2` test the tool asked **excludes**
it. One question, two conventions, and the answer would have put a spawn on the
empty plaza's edge. **S3 is the cheapest move now and it is the only one that
keeps a spawn's named location**; which spawn moves is the owner's.

**AND I CLAIMED RULE 5 WAS MEASURED NOWHERE, WHICH WAS WRONG.** It is asserted
twice — `test_map_dead_ends.gd` for the theatre half and
`test_street_is_where_it_says.gd` for the on-a-floor half. I had grepped
`test_spawn_points.gd` alone and concluded from one file. The test I had written
was a third copy and was reverted.

**AND AUDITING TDD-08's TABLES FOUND TWO ROWS STALE**, which is the fourth time
that audit has paid: the test table still said `test_circuit_separation.gd`
reported 0.51 m circuits (re-authored; **21.20 m** now) and quoted a clone-floor
figure from before the stall-anchor nudge. The test function itself was still
named `..._is_measured_and_currently_missed` while passing because the miss was
fixed — trap 3's reading hazard inside a test name.

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

**A TRAVERSAL IS PLANNED TO A LANDING THAT DOES NOT EXIST — DIAGNOSED, JUDGED
UNREACHABLE, AND DELIBERATELY LEFT.** Reported from the controls: *"when i am at a
edge into the abyss and move towards it and jump, my jump stops mid air so that my
speed goes down to 0 m/s"*. **Not US-0093's defect returning** — that was a held key
arming a traverse every frame; this happens on a single press.

The chain: the probes find no floor within `TUN-TRAVERSE-GAP-PROBE-DEPTH`, so
`drop_height` is `INF`; `_over_the_edge` classifies `DROP`, which is **§7.2 case 3
as written**; `_plan_drop` calls `_finite()`, which **substitutes the probe depth
and invents a landing ten metres down**; and `DropState` zeroes velocity,
interpolates to it, and sets `grounded = true` **in mid-air**.

**THE OWNER'S QUESTION WAS THE RIGHT ONE — DOES THE SHIPPED GAME EVEN HAVE AN
ABYSS?** It does not, and the case is **unreachable by construction**, on two
conditions that are now both asserted rather than assumed:

1. **Every legitimate fall is measurable.** Invariant 24 pins the probe depth at or
   above `TUN-TRAVERSE-CLIMB-MAX-HEIGHT` and the tallest façade is 8.5 m, so `INF`
   can only mean a true void.
2. **No void is reachable on foot.** `test_the_district_is_enclosed.gd` samples
   **2574 points** along every street-level floor edge and requires each to border
   floor, building mass or parapet. Falsified by removing the fencing: **1303 open
   edges**.

**THE RESOLVER STILL ARGUES WITH ITSELF AND THAT IS LEFT STANDING.**
`_over_the_edge`'s docstring says a fall the probes cannot measure "is not planned
at all"; `_finite` thirty lines below still does it. Fixing it means amending §7.2
case 3 or giving the pawn a state that **falls under gravity** rather than
interpolating to a plan — it has none, because every traversal here is a planned arc
that discards momentum. Neither is worth doing for a case the level cannot reach.

**AND I CHANGED THE CLASSIFICATION FIRST AND WAS WRONG TO.** Returning `NONE` fixed
the symptom and broke `test_a_long_fall_with_nothing_found_is_still_a_drop`, whose
own comment reads: *"§7.2 case 3 as written… An unmeasured drop is a poor thing to
plan — see the note on `_finite` — but the case is not in doubt."* The author had
already drawn the line at the planner. Reverted.

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

**AND EVERY IDLE ANCHOR IS ON GROUND SOMEBODY CAN STAND ON: 8 UNREACHABLE → 0.**
`_place_anchors` gridded each zone with no obstacle filter, so two anchors landed
inside each of StallA-D. `map_get_closest_point` hid it by answering with the
stall's own **top** — on the navmesh, 0.9 m up, unreachable from the street — which
is the disguise US-0041's `Npc003` wore.

**NUDGED, NOT DROPPED, AND THAT DISTINCTION IS THE WHOLE DECISION.** Deleting them
takes the count 67 → 59 and leaves **S6 short**: it has exactly
`TUN-CROWD-CLONE-LOCAL-MIN` seats of 8, and some of those eight are the stall ones.
So the fix for an unusable anchor would have created a starved spawn point.
`VetraioGround.clear_of_obstacles()` moves each to the nearest walkable half-metre
instead — count unchanged at 67, market density unchanged, **S6 still 8 of 8 and
now real rather than phantom**. Live trembling went to **0 body-seconds of 4680**.

**AND THE CORPUS SAID THIS COULD NOT BE DONE.** It has claimed since US-0041 that
filtering the stall anchors "changes the per-zone density a unit test asserts".
**The assertions are `no zone gets zero` and `anchors ≤ idle NPCs + 8`** — 59 would
have satisfied both. The real obstacle was S6's seat count, which nobody had
checked; the claim was true in spirit and wrong in its reason.

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

**`main` IS PROTECTED BY THE SERVER AS OF 2026-08-21, AND IT IS VERIFIED.** The
ruleset is applied and `active`, `current_user_can_bypass: never`. Tested by pushing
straight at `main` with `--no-verify` so the client hook could not answer for it:
*"Changes must be made through a pull request. 7 of 7 required status checks are
expected. push declined due to repository rule violations."* **US-0002/0003/0004/
0005's four "required check on `main`" criteria are true for the first time.**

**AND THE RULESET DID NOT EXIST.** TDD-12 said "the ruleset JSON is ready to apply
unchanged" from M0 onward and there was no such file in the repository — **trap 14
again**, and the claim is exactly what stopped anybody checking. It is
`.github/main-ruleset.json` now. The required contexts are the job **names** from
`ci.yml`, not job ids: a wrong name matches nothing and reports "expected" forever.

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

**THAT CONTRADICTION IS RESOLVED AS OF 2026-08-21 — SEE THE TOP OF THIS SECTION.**
GDD-05 §2.7, GDD-05 §3/§4.4 and GDD-03 §6.3 rule 3 can all hold now, and exactly
one of them is measured false: **§2.7 rule 8**, which is where the opening
arrangement's obligation went. The census below is still the outstanding level
work and the options were priced as: move S3/S4 out of the Fondaco (the nearest legal 8-seat site for S4 is
**61.9 m away at (72, 52)**, which drags it to the centre and is what the anti-camp
spread exists to prevent); raise the Fondaco's density; or scope rule 3 so it does
not bind at the spawn instant — **which is what was chosen**.

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
| Tests | **47 arch + 144 unit + 32 integration scripts**, holding 186 + 1223 + 239 tests and 837 + 27 015 + 651 assertions — the assertion count tripled at US-0049, because `test_contract_cycle_fuzz.gd` checks the invariant after every one of 10 000 events. **Eight are `pending` by design** — **seven in the unit suite and one in the integration suite**, which reports that an NPC aimed into the void never gives up. The island `pending` beside it **turned green by itself** when the alley mouths were built, which is what a `pending` naming its own blocker is for. The three numbers this row used to call assertions were **test** counts — corrected at US-0041 by reading both off the runner. The integration suite is at **162-172 s** of the 180 s it is allowed, up from 87.7 s at M2 — **under 9 s of headroom left, and the next integration test has to justify itself hard against that**. `test_server_tick_budget.gd` cost 9.8 s of it and is a gate line; the one before it, the 2 s pass A/B, samples ninety ticks **twice** — US-0044's three suites are deliberately *unit* tests for that reason: `test_crowd_moves.gd` walks a crowd for sixty net ticks eight times over, and physics frames run in real time even headless. **The six are**: `test_upstream_bandwidth.gd` reporting the 145 % upstream miss, `test_crowd_bandwidth.gd` the 112 % downstream projection, `test_crowd_wire_cost.gd` the 112 % it actually costs, **`test_spawn_points.gd` twice — GDD-05 §2.7 rule 6's nine unoccluded spawn pairs and rule 8's S3 4, S4 1, S5 6 of 8 seats** — and `test_clone_animation_parity.gd` the missing clip library. **Two entries this row carried are gone because their findings closed**: `test_circuit_separation.gd`'s 0.51 m circuits (re-authored, now 21.20 m) and `test_cull_radius_price.gd`'s flat curve, which asserts rather than pends. Each reports a finding the code cannot fix rather than going red, the same choice `test_snapshot_size.gd` made. A `pending` that turns green by itself the day its blocker is authored is the point. The *script* counts are guarded by `test_claude_md_counts_are_current.gd`; the assertion counts are a snapshot and are not. This line read `119 + 515 + 132` for **twelve PRs** — every update to it was an unasserted `str.replace` that silently matched nothing. See trap 15 |
| Tuning | 288 tunables across 14 resource classes; all 31 cross-field invariants assert. **Four scoring values were re-priced on 2026-08-26 (ADR-0013)** — `TUN-SCORE-SILENT` 100 → 200, `TUN-SCORE-PATIENT` 150 → 100, `TUN-SCORE-FOCUS` 100 → 150, `TUN-SCORE-RECKLESS` −50 → **0**, and invariant 18 rewritten from an ordering to a floor — split across `TuningInvariants` and `TuningInvariantsTech` since the first file hit 400 lines, with one entry point still. **Eight IDs are deprecated** and recorded in TUNABLES §19 — never reused |
| Autoloads | All eight. `Tuning` precomputes 89 durations into **two** tick tables — see trap 7 |
| Strings | `data/strings/en.csv`, 56 keys, no user-facing literal anywhere else |
| Boot | Branches on `--server`; 7 CLI flags parsed in pure Core; 5 export presets |
| Map | `MAP-VETRAIO` greybox, 120 × 120 m. Client loads 28 meshes, server loads none. **The street surface is exactly `STREET_Y`** — floors used to straddle their declared height, putting every walkable top 0.1 m high, which made the 0.9 m stalls unvaultable and three spawn points float over nothing. **Lit as of US-0091** — one key light and a sky, because nothing in the project had ever created either and the district rendered near-black. **The navmesh is baked at build time and committed** (US-0041): **255 polygons across 12 floors and 14 blocks**, with a derived `H_VAULT` parapet on every floor edge that borders a drop, and it sits **0.400 m above the street**, which is why steering applies gravity rather than trusting the snap |
| Pawn | 14 states declared — **the Jog rung was removed in US-0090** and `Jog` is a retired ID absent from `ALL`. Transition edges asserted against the normative diagram. **All fourteen implemented as of US-0062**: five locomotion + `Vault`, `Climb`, `Drop`, `KillAnim`, `StunAnim`, `Stunned`, `Blended`, `Dead`, `Respawning`. **`Dead` has an exit at last.** **Two states still cannot die at all**: the diagram has no `Drop -> Dead` and no `StunAnim -> Dead`, which `KillSystem._enter` reports rather than asserting past |
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
| Compass | **The server half lives in `SYS-DETECTION`**, at steps 9-10 of its pass, because the Compass is about the observer's *contract* — the same relationship the render state is computed from — and TDD-07 §1's diagram draws it there. `CompassMath` is pure Core: `period_for()` reproduces TUNABLES §4.2's twelve rows to **0.40 ms**, and the reciprocal exponent makes the rate **58x steeper close in than far out**. One reading per hunter into `ctx.compass`: a **world** bearing with `TUN-COMPASS-CONE-WOBBLE`'s drift already applied server-side, and a `Quantise.BUCKET_STEP` 0.5 m distance bucket, so nothing downstream holds the exact metres. The wobble is a sine of `(contract, tick)` — deterministic and learnable, never RNG — with its phase **mixed**, or adjacent peer ids would drift in step. **A missing reading is `NO_CONTRACT` 255, never bucket 0**, which is a real reading. `lock_fraction` and `portrait_revealed` are US-0058's and read zero; nothing draws any of it |
| Detection | `SYS-DETECTION` ticks at the `detection` stage, **after `suspicion`**, because the render state is computed from *tier* and a tick of lag makes the silhouette disagree with the tier indicator. One pass over 30 ordered pairs, **costing zero raycasts**: GDD-03 §2.1's rule is `tier × relationship` and §2.3 draws the Exposed outline through geometry, so occlusion must not gate it. The early-out ladder drops ~70 % of pairs on the tier check alone. It reads the **announced** contract from `ctx.announced_contracts`, never the graph's, so a tint cannot arrive before the Compass does. `RenderMatrix` carries the answer to `SnapshotBuilder` four stages later and **absent means `PLAIN`**, which is the safe direction. **It also holds the only line-of-sight query in the project** — `WORLD`-masked, so NPCs and players cannot block it by construction; Cinderfall is a sphere tested against the segment; the rewound form is **still refused**, and US-0060 sharpened the reason rather than clearing it — kill validation asks no line-of-sight question at all, so there is still no caller for a past one. **`has_los()` has two callers**: the Compass lock (US-0058) and the witnessed-kill check (US-0060). `cinderfall` is `MatchContext`'s list, adopted by reference, and every liveness query takes the tick it is asked about. **It also owns the prey warning** (US-0059): `_resolve_pair` already computes `hunted_by`, so the warning is a distance, a tier comparison and a cooldown lookup on pairs the ladder has already admitted — no second pass and no raycast. `PreyWarning` holds only the cooldown, and **a new pursuer defeats it**, or a repair would silence the prey's one warning for 2.5 s |
| Suspicion | `SYS-SUSPICION` ticks at the `suspicion` stage, **after `crowd`** — the boundary `SystemOrder` calls the most damaging silent failure in the game, since a stale crowd lets a player accrue *alone* suspicion inside a pocket that has re-formed. One pass over six pawns: the world is read from `ctx.crowd_hash` (never a physics query), impulses drain first and re-arm `TUN-SUSPICION-DECAY-DELAY`, then the integrator, then the tier with hysteresis. **The value lives on `PawnContext`, not in the system** — the builder reads it, so a copy here would be a second authority. `suspicion`, `tier` and `active_sources` go out in the own-gameplay block **to the owner alone**; there is no field anywhere in the format for another player's, which is the rule living in the wire rather than in a widget. `SuspicionSources.of()` is the only place the five conditions are applied and `gain_rate()` is their sum, so the HUD's source list cannot drift from the number it explains. **The impulse queue is `MatchContext`'s** as of US-0060, adopted by reference rather than mirrored, because a system reaching another system's state does it through the context. It has two live callers now — a failed kill and a witnessed one. **The bump still has none**, because pawn and NPC both mask `WORLD` and there is no contact to report; `has_stillness` still needs a loadout |
| Pawn body | `GreyboxBody`, procedural — capsule, head and a chest marker on `+Z`, measured from the collider so the two cannot drift. **`PersonaVisuals` was empty through US-0021, 0022 and 0023**: three stories of camera work built around a pawn that did not render, every suite green. Not a persona — ART_BIBLE §6.1's four constructions are US-0039's |
| Camera | Real spring arm: 2.6 m, **pawn centred** (US-0092 — the 0.45 m offset never changed the composition, because the rig aims at the pawn's own axis; `INPUT-SHOULDER` retired with it), occlusion that pulls **in** and never sideways, `WORLD`-masked so a crowd cannot push it. The FOV ladder is bound to the **state**, never to `ctx.velocity`: the rung is a consequence of the decision, not of the physics that follows it. Crowd-scan narrows to 48° and grants nothing. **Positive pitch LOWERS the arm** — the rig looks *at* the pivot, so a raised arm looks down; it shipped inverted from US-0021 until somebody played it |
| Input | 20 `InputMap` actions from 14 live `INPUT-` IDs — `INPUT-SHOULDER` is retired via `InputActions.DEPRECATED`, still in the corpus and bound to nothing, KBM + pad. Chain GDD-02 → `Ids` → `InputActions` → `project.godot`, guarded on every hop, both directions. **Sampled once per physics frame by `LocalPawnDriver`, the only caller** — see trap 12. The mouse is **captured** on boot; `INPUT-MENU` releases, a click takes it back. **Only a mapped gamepad holds the joypad bindings** — `PadSelection`, applied through the one `InputMap` writer, because a set of sim pedals was steering |

**Forty-seven criteria are deliberately unticked**, each blocked by something real — counted
from the `done` and `in-progress` stories on **2026-08-25**. It was also forty on
2026-08-16, which is a coincidence rather than a stall: US-0055 closed seven and
US-0052/0053/0056 opened four between them. Nine of the forty are US-0048's M3
gate lines, which count because a story with work in it is not a draft. A prose
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
| US-0022 | motion-reduction's compensating indicator | the FOV **lock** is done and tested; the persistent speed indicator belongs to the HUD, US-0084 |
| US-0023 | ambience ducked, footsteps sharpened | `Audio.play()` is an empty stub until US-0075 |
| US-0024 | input→animation measured; ≤ 80 ms with prediction | no clips. **The prediction half is now measured** — 33.3 ms at every latency profile — but the chain is still three stages of five, so the number is a lower bound. The feel-gate checklist is DONE (2026-08-13) |
| US-0025 | ping/pong RTT proven over a real wire | the client half needs two processes. `RttTable` is unit-tested and the server half reads ENet directly |
| US-0029 | "remote pawn is 14 B, NPC is 7 B" | **false as written.** Measured at 10 and 8; TDD-04 §4 and §7.1 were amended instead of rewording the criterion |
| US-0030 | `render_state` per observer | **the three culling criteria are DONE** — US-0030's cull landed once M3 gave it a crowd. `render_state` needs `SYS-DETECTION`, which is M4's |
| US-0036 | "every netcode test runs at all four profiles" | true only of the harness's own agreement test; the rest are pure and have no wire to give a latency to |
| US-0037 | match end below minimum players | `SYS-MATCH`'s, in M4. **The timeout criterion was ticked at the M2 gate** — a hard-killed client took the same `peer left` → `pawn freed` path across four real processes |
| US-0056 | Focus tracking and kill validation as `has_los` consumers | **two arrived and the third is not coming as written.** The Compass lock calls it (US-0058) and so does the witnessed-kill check (US-0060). **Kill validation never asks**: TDD-10 §3's flowchart has no line-of-sight node, so a kill through a market stall at 2.4 m is legal today. TDD-04 §10's test table implies otherwise — reported, the owner's. Focus is US-0064 |
| US-0054 | the occupant can see nothing while inside | **no client renders a blend at all.** The server half is done — `blend_state` reaches the occupant's own snapshot block, which is what a widget will black the screen out from — and the widget is US-0084 in M5. A guard over zero call sites would be vacuously green |
| US-0062 | ability cooldowns reset on death | **there are no ability cooldowns.** `SYS-ABILITY` is M5 and `PawnContext` has no cooldown field, so there is nothing to reset. `reset_for_spawn` is the one call site and will honour them when they exist |
| US-0061 | a player mid-Lunge is stunnable | **`ABIL-LUNGE` is M5, so there is no state to be mid-.** The way it stays true when the ability arrives is that `StunSystem._is_busy` and `_is_stunnable` never grow a case for it, and both name the criterion. Everything else in the story is built and falsified |
| US-0059 | the client-side rotation; the mono sting | **the server halves are done and neither client half exists.** A world bearing needs `CompassVM` to rotate it (US-0084, M5) — US-0057's seventh line, again — and the sting has **no call site at all**: `Audio.play()` is a stub until US-0075 and `EventBus` may hold no `func`, so a guard over zero call sites would be vacuously green |
| US-0060 | NPCs rewound; the contest loser's movement stagger | **both are reported rather than blocked.** ADR-0010's two reasons for rewinding NPCs are false of the built game, so a rewound crowd has no consumer and would cost ~100 KB of ring to be read by nothing. And GDD-02 §3's fifteen-state diagram declares no stagger state while three rules need one, so the loser gets an **initiation** lockout: no points, no lockout, no suspicion, 1.5 s in which they cannot press again |
| US-0057 | the cone's half-width, camera-relative | **the server's half is done and the drawn half does not exist.** `TUN-COMPASS-CONE-HALFWIDTH` is asserted wider than the wobble, so the true bearing is always inside the arc — but nothing renders an arc, because `CompassVM` and the HUD are US-0084 in M5 |
| US-0056 | `at_tick` rewind; the three named consumers | **all four blockers are other stories**: `RewoundWorld` is paired with the query by `SYS-KILL` (US-0060), and lock progression, Focus tracking and kill validation are US-0058, US-0064 and US-0060. The rewound form is **refused rather than faked**, because against static geometry a fake would answer correctly and be wrong about the players |
| US-0053 | the persona-appropriate clone idle | **there are no animation clips in this project, on either rig** — M3's exit blocker. Separately, `PawnStateId.BLENDED` is still unreachable and the clip is not why: the pawn state machine is predicted, and a transition depending on how many NPCs are within 3.5 m is one the client cannot reproduce |
| US-0052 | the NPC bump has no contact to report | **the witnessed-kill criterion is TICKED as of US-0060** — both its blockers cleared, and `server_root._charge_for_witnesses` charges the killer once if any living player has a clear line to the body at the contact frame, **present-tense rather than rewound**, because a witness did not act. What stays unticked is nothing here; the **NPC-bump criterion IS ticked on the rule** — the debounce is built and falsified both ways — while nothing calls it, because both pawn and NPC mask `WORLD` only |
| US-0047 | "always had 2 within 25 m"; "does not read as following" — **and rule 3's scoping is not what ticks the first one** | **"Always" is not achievable and the reason is a walk**: a fetched clone crosses 25 m in ~18 s, so a player who loses one is short for that walk. Supply is not the constraint — 4.27 clones of each persona on average against a floor of 2. **47 of 11 544 readings under the floor after the grace, 0.41 %**, never below 1, and of the short pairs the pass saw, most already had a clone coming and the rest were dispatched: the rule never ignores a breach, and that is what is asserted. The second criterion's readable half needs a client that has ever rendered a clone |
| US-0046 | layers 2 and 3, footstep parity, the idle cycler | **there are no animation clips in this project, on either rig.** Layer 2's declaration half asserts and its library half reports; layer 3's check exists with no call site because a call site needs an `AnimationTree`; footsteps need `Audio.play()`, a stub until US-0075. ANIMATION_SPEC §8 costs the parity set at 14 × 4 personas × 2 rigs |
| US-0045 | the three client-LOD lines | **US-0046.** `NpcView` exists now and draws the crowd; what is missing is the **mesh and the `AnimationTree`**, so animation LOD, the silhouette-fairness check and mesh LOD still have nothing to band. There are no animation clips on either rig |
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

### Eighteen things that will cost you an hour if you do not know them

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

# The record, M5: the HUD and the abilities

**Moved out of `CLAUDE.md` on 2026-09-13**, when that file reached 3 976 lines against
the 4 000 `test_claude_md_stays_findable.gd` allows. Twenty-eight sections, in the
order they held at the root — **newest first** — so *"the section at the top of this
file"* and *"the section directly above"* still mean what they meant. They cover
2026-08-26 to 2026-09-05: the HUD stories (US-0072/0073/0074), `SYS-ABILITY` and
Cinderfall (US-0066/0067), the Lunge (US-0070), the three staggers (ADR-0017), the
prey's teeth (ADR-0018), the stun's cost (ADR-0019), the pursuit (US-0097), the
bench (`MAP-SANDBOX`), the `-s` autoload cascade, the tuning codegen's two defects,
and the tick gate's estimator.

**What was archived is the reasoning, not the status.** Every live fact these pages
carried is in `CLAUDE.md`'s tables, its unticked table and its traps. Read this when
you need the reason for a rule, not before.

---

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


# MAP-SANDBOX — the bench

*Added 2026-09-04. Owner: whoever is reproducing something.*

**A 40 × 40 m walled courtyard that exists only to reproduce defects.** It is not a
place, it is not part of the fiction, and it does not ship: every export preset
excludes it and `test_sandbox_is_debug_only.gd` refuses a reference to it from any
shipped script.

---

## 1. Why it exists

`MAP-VETRAIO` is 120 × 120 m with 78 civilians, six spawn points and four
processions. That is the game, and it is the wrong instrument for a defect. Every
report from the controls in the week before this map was built cost minutes of
walking to reach the arrangement that showed the problem — and one of them, a
hunting bot wedged in a corner, needed a corner with a known shape to be
reproduced at all.

**A bench is a place where you can be standing in the situation within ten
seconds.**

---

## 2. Running it

```bash
sandbox.bat              REM a server, 1 hunter, 12 civilians, and you
sandbox.bat 2            REM two hunters
sandbox.bat 1 0          REM one hunter and an EMPTY district
sandbox.bat 1 12 3       REM one hunter, 12 civilians and 3 QUARRY bots
sandbox.bat 0 12 3       REM nobody hunting you — three to stalk
sandbox.bat 1 12 3 42    REM ...with a fixed match seed
```

**Hunters** pursue their contract and cast on cooldown; **quarry** bots join the
same lobby and stroll in random legs, hunting nobody. The seed is the **fourth**
argument as of 2026-09-04, where it used to be the third.

By hand, which is the same processes:

```bash
godot --headless --path . -- --server --port 27015 --max-players 6 --map sandbox --crowd 12
godot --headless --path . res://tools/bot_client.tscn -- --connect 127.0.0.1:27015 --map sandbox --bot 1 --hunt --reckless
godot --headless --path . res://tools/bot_client.tscn -- --connect 127.0.0.1:27015 --map sandbox --bot 2
godot --path . -- --connect 127.0.0.1:27015 --map sandbox
```

**A quarry bot is a hunter's command line with `--hunt --reckless` removed**, and
its `--bot` number continues the hunters' rather than restarting at 1: that number
is the bot's own RNG seed and nothing else, so two bots given the same one walk the
same legs at the same moments and read as one body with a shadow.

### 2.1 What the third number can and cannot buy

**IT CANNOT GIVE YOU TWO PURSUERS OR TWO PREY, AND THAT IS GDD-03 §7 RATHER THAN A
LIMIT OF THE SCRIPT.** The contract graph is a single Hamiltonian cycle over the
living players, so every player has exactly **one** outgoing edge — their contract
— and exactly **one** incoming edge — their pursuer. So at most one bot holds a
contract on you however many hunt, exactly one player is yours to kill at any
instant, and **which one is the cycle's to decide, not the launcher's.**

What it buys is the **odds** and the **tempo**. With one hunter and three quarry
your contract is a passive bot three times in four, so you can practise a stalk and
an approach without being chased through it; `sandbox.bat 0 12 3` removes the chase
entirely. In a `3 0` run the two hunters not assigned to you are hunting **each
other**, which is worth knowing before reading anything into what they do.

**AND A QUARRY BOT CANNOT BE STUNNED, BY DESIGN RATHER THAN BY OMISSION.**
`TUN-STUN-MIN-TIER` makes an Anonymous player unstunnable, a strolling bot never
leaves Anonymous, and that is the rule making *"an Anonymous hunter cannot be
stunned — patience is genuinely safe"* true. A quarry bot is there to be killed;
practise stunning against `--reckless` hunters.

**`--map` must be given to every process, including each bot.** A bot instantiates
the client root itself rather than going through `boot.gd`, so without it the bot
loads the district while the server runs the courtyard — and what you see is a bot
walking through geometry that is not there, which reads as a broken navmesh.

And look at it from above after any change to the layout:

```bash
godot --path . res://tools/map_probe.tscn -- --map sandbox
```

---

## 3. What is in it, and why each thing is there

| | Where | Why |
|---|---|---|
| The courtyard | 40 × 40 m, flat | Two spawns 15.3 m apart: about **11 s** at `TUN-SPEED-BLENDWALK`, so an encounter happens rather than being travelled to |
| `CentreBlock` | 6 × 6 m at (17, 17), 4 m tall | Something to lose sight of somebody behind. Without it the Compass never points around anything and a chase can never be broken, so `TUN-PURSUIT-DURATION` is unreachable |
| The nook | `NookWall` + `NookSide`, one 2 m mouth at x 38–40 | A corner trap with a known shape. `--hunt` steers on the Compass bearing and nothing else; this is where that walks it into a wall |
| Two stalls | (8, 12) and (28, 12), `H_VAULT` 0.9 m | The vault band. In the district the only geometry in that band is a market stall, which is how a 0.1 m floor error hid for three milestones |
| Perimeter walls | Outside the floor, 3 m | The walkable width stays exactly 40 m. `MAP-VETRAIO` shipped with none and lost nineteen NPCs a minute over the edge |
| 4 spawn points | (5,5) (35,5) (5,35) (20,8) | Marked in red by `tools/map_probe.tscn` |
| 32 idle anchors | 6 m grid, filtered | Derived, never listed — a hand-listed point inside a wall is an NPC that can never walk away |

---

## 4. What you must NOT measure here

**This is the section that matters.** A number taken on the bench and quoted about
the game is the shape of every retracted figure in this corpus.

- **Spawn separation and anti-camping.** `SpawnRules` wants 40 m between a victim
  and their killer, which a 40 m courtyard cannot give — so **every respawn here
  takes rule 7's fallback**. That is useful (the fallback is exercised on every
  death) and it is not the shipped behaviour.
- **Crowd density, clone parity, blend pockets.** There are no zones, so no zone
  carries a density. `TUN-BLEND-POCKET-MIN-NPC` can still be satisfied by standing
  in a cluster, but nothing here reproduces the district's distribution.
- **Processions and circuit separation.** There are no circuits.
  `CrowdFormations.form()` correctly refuses to make a group, and the server logs
  `processions formed: 0 NPCs across 0 of 0 circuits`.
- **Performance.** 12 civilians in a courtyard is not 78 in a district, and
  `test_server_tick_budget.gd` and `test_crowd_perf.gd` both run on
  `MAP-VETRAIO` deliberately.

Use `play.bat` for all of the above.

---

## 5. Changing it

`scripts/core/sandbox_layout.gd` is the single source. **Trap 1 applies**: the
scenes and both `.tres` files are generated, and hand-edits to them are silently
reverted on the next run.

```bash
godot --headless --path . -s res://tools/generate_map_sandbox.gd
```

Then run `test/unit/core/map/test_sandbox_layout.gd`, which compares the generated
`MapData` against the table — that is what goes red when the two drift — and look
at the result with `map_probe`.

**The navmesh bake settings are `MapBuild`'s and are shared with the district on
purpose.** A bench baked with a different agent radius, cell size or climb height
is a bench the pawn traverses differently, so a defect reproduced on it would not
be the defect.

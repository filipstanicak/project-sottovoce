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
sandbox.bat            REM a server, 1 hunting bot, 12 civilians, and you
sandbox.bat 2          REM two bots
sandbox.bat 1 0        REM one bot and an EMPTY district
sandbox.bat 1 12 42    REM ...with a fixed match seed
```

By hand, which is the same three processes:

```bash
godot --headless --path . -- --server --port 27015 --max-players 6 --map sandbox --crowd 12
godot --headless --path . res://tools/bot_client.tscn -- --connect 127.0.0.1:27015 --map sandbox --bot 1 --hunt --reckless
godot --path . -- --connect 127.0.0.1:27015 --map sandbox
```

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

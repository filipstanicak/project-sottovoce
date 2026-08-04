---
id: BIBLE-SCENE-CONVENTIONS
title: Scene and Node Conventions
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-01-ARCHITECTURE, TDD-06-PAWN, ADR-0009]
---

# Scene and Node Conventions

> **Why this document exists:** `.tscn` files are the worst-merging artefacts in a Godot
> project. They are text, so they diff — badly. A three-way merge on node ordering or
> sub-resource IDs produces files that *load* and are *subtly wrong*, which is the most
> expensive category of defect. Most of the rules here exist to reduce how often two people
> touch the same scene.

---

## 1. Scene versus script

| Make a **scene** when | Make a **script only** when |
|---|---|
| It is instantiated more than once at runtime | It is a system, a service or an algorithm |
| It has a node structure worth authoring visually (a pawn, an NPC, a widget) | It has no visual structure |
| An artist or designer needs to edit it without code | Only programmers touch it |
| It needs a distinct collision shape, mesh or animation tree | — |

**Default to script-only.** A scene is a merge liability; a script is a diff. If a node could be
`add_child`-ed in five lines of clear code, it does not need a scene.

### 1.1 Systems are never scenes

Every `GameSystem` is a plain `Node` with a script, added by `MatchDirector` in code
([`../20_tdd/01_architecture.md`](../20_tdd/01_architecture.md) §3.1). This is deliberate: it
puts the system inventory and its tick order in **one readable file** rather than in a scene
whose node order silently determines behaviour.

---

## 2. Scene granularity

| Rule | Reason |
|---|---|
| One scene per *reusable thing*, not per *screen region* | A HUD split into eight widget scenes merges better than one HUD scene, and each widget becomes independently testable |
| A scene should fit on one editor screen | If you scroll the scene tree, it wants splitting |
| Never nest more than 4 levels deep in one scene file | Deeper nesting belongs in a sub-scene |
| Prefer composition over inheritance for scenes | Godot's scene inheritance produces the worst merges of all |

### 2.1 Composition over inheritance

`pawn_server.tscn`, `pawn_local.tscn` and `pawn_remote.tscn` are **three separate scenes sharing
scripts**, not one inherited from another.

```
pawn_server.tscn   CollisionShape3D + PawnStateMachine + TraversalProbes
pawn_local.tscn    the same three + PersonaVisuals + CameraMount + FootstepEmitter
pawn_remote.tscn   PersonaVisuals + InterpolationTarget + FootstepEmitter   (no physics body)
```

Inheritance would have coupled them so that a camera change on the local pawn could alter the
server's collision capsule — which would break prediction parity silently. Three flat scenes
mean a change to one cannot reach the others.

`test_local_server_pawn_parity.gd` asserts the two that *must* agree still do: identical
collision shape, layers and state-machine script.

---

## 3. Node naming

| Rule | Example |
|---|---|
| `PascalCase` | `CompassWidget`, `TraversalProbes` |
| Node name matches its script's `class_name` where one exists | `SuspicionSystem` node ← `suspicion_system.gd` |
| Instance names carry their identity | `Pawn_1`, `Npc_047` |
| Mark nodes accessed from script with `%` (scene-unique) | `%CompassWidget` |
| No `Node2D`, `Node3`, `Control2` — name the responsibility | |

### 3.1 Access

```gdscript
# Correct — scene-unique name, typed, own subtree
@onready var _compass: CompassWidget = %CompassWidget

# Correct — declared external dependency
@export var crowd_director: CrowdDirector

# WRONG — breaks the moment anyone reorders the tree
var hud = get_node("../../Presentation/HUD")
```

`%UniqueName` survives reparenting within its scene; a path does not. This matters because
reparenting is exactly what happens during UI iteration.

---

## 4. Scene file hygiene

| Rule | Reason |
|---|---|
| **Never reorder exported properties** in a `Resource` once merged | Reordering rewrites every `.tres` that uses it, producing enormous, unreviewable diffs |
| **Never reorder nodes** without a reason | Same, for `.tscn` |
| Save scenes before committing; never commit a scene with unsaved editor state | |
| Keep `.tscn` sub-resources inline only when they are genuinely single-use | Shared sub-resources belong in `.tres` |
| Do not commit `.tscn` files containing absolute paths from your machine | |

---

## 5. Instancing and pooling

| Rule | Reason |
|---|---|
| **Never instantiate during a match** what can be pre-allocated | Instantiating a `CharacterBody3D` with a `NavigationAgent3D` is a frame spike, and a frame spike in a game decided at 2.5 m is a lost kill |
| All 90 NPCs are allocated during `COUNTDOWN` and recycled | [`../20_tdd/08_crowd_system.md`](../20_tdd/08_crowd_system.md) §2 |
| Pooled objects are **hidden and skipped**, never `queue_free`d | |
| Corpses, projectiles and VFX are pooled | Each has a bounded maximum |

`test_no_midmatch_instantiate.gd` asserts no NPC is created or freed between match start and end.

---

## 6. Layers and masks

Declared once in `project.godot`, referenced by named constant, never by number.

| Layer | Name | Contains |
|---|---|---|
| 1 | `WORLD` | Static map geometry, climbable façades, vaultable furniture |
| 2 | `PAWN` | Player capsules |
| 3 | `NPC` | Crowd capsules |
| 4 | `TRIGGER` | Blend props, zone volumes, spawn markers |

**Traversal probes mask `WORLD` only.** This is a determinism requirement, not an optimisation:
static geometry is identical on every peer, while pawn and NPC positions are interpolated on
clients and authoritative on the server. A probe that could hit a moving body would resolve
differently on the two machines and produce a different traversal
([`../20_tdd/06_player_pawn.md`](../20_tdd/06_player_pawn.md) §1.2).

---

## 7. Merge policy for scenes

**A conflicted `.tscn` is re-authored in the editor, never hand-merged.**

`.gitattributes` leaves scenes as normal text so they can be reviewed, and this is a *process*
rule rather than a tooling one because no tooling solves it. A hand-merged scene that loads
successfully but has a duplicated sub-resource ID or a lost property is a defect that survives
review and surfaces days later.

### 7.1 Avoiding conflicts in the first place

| Practice | Effect |
|---|---|
| **Say before you edit a shared scene** (`client_root.tscn`, `map_vetraio.tscn`, `hud.tscn`) | The only reliable prevention |
| Keep branches ≤ 2 days (ADR-0009) | Conflict probability scales with branch lifetime |
| Split large scenes into sub-scenes | Two people editing two widget scenes never conflict |
| Prefer adding nodes in code where reasonable | A script merges; a scene does not |

### 7.2 If a conflict happens

1. `git checkout --theirs` (or `--ours`) — pick **one** side wholesale.
2. Re-apply the other side's change **in the editor**.
3. Save, and verify by loading the scene and running the relevant test.
4. **Never** hand-edit the conflict markers in a `.tscn`.

---

## 8. Scene inventory

The scenes that exist, and who owns them. Anything not listed needs a reason.

| Scene | Owner | Notes |
|---|---|---|
| `boot.tscn` | Tech | The `--server` branch. Rarely changes |
| `server_root.tscn` | Tech | Systems container; no presentation nodes |
| `client_root.tscn` | Tech | **High-traffic — announce before editing** |
| `pawn_server/local/remote.tscn` | Tech | Parity between the first two is tested |
| `npc_server.tscn` / `npc_view.tscn` | Tech | View must stay inert |
| `map_vetraio.tscn` | Level design | **Highest-traffic scene in the project** |
| `hud.tscn` + 7 widget scenes | UI | Split so widget work does not collide |
| `main_menu / lobby / results / options.tscn` | UI | |

---

## 9. Acceptance criteria

- [ ] No `GameSystem` exists as a scene.
- [ ] `pawn_server.tscn` and `pawn_local.tscn` have identical collision shape, layers and state-machine script.
- [ ] `npc_view.tscn` has no `NavigationAgent3D` and no brain.
- [ ] Every node accessed from script uses `%UniqueName` or `@export`, never a path.
- [ ] No collision layer is referenced by numeric literal.
- [ ] Traversal probe masks include only `WORLD`.
- [ ] No NPC is instantiated or freed mid-match.
- [ ] Every scene in `client_root.tscn` loads with no missing dependencies in a headless import.

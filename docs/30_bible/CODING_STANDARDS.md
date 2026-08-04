---
id: BIBLE-CODING-STANDARDS
title: Coding Standards — GDScript
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0001, ADR-0005, ADR-0008, TDD-01-ARCHITECTURE]
---

# Coding Standards — GDScript

> **Enforcement over convention.** Every rule here is either checked by `gdlint`, checked by a
> test in `test/arch/`, or explicitly marked as a judgement call. A style rule nobody checks is
> a style rule nobody follows.

---

## 1. Typing

**Everything is typed. No exceptions.**

```gdscript
# Correct
var suspicion: float = 0.0
var peers: Dictionary = {}
var states: Array[PawnState] = []
func integrate(state: SuspicionState, dt: float) -> float:

# Wrong
var suspicion = 0.0            # untyped
func integrate(state, dt):     # untyped params, no return type
```

| Rule | Enforced by |
|---|---|
| Every `var` has an explicit type or an inferred-typed initialiser (`:=`) | `test_typing_coverage.gd` |
| Every function parameter is typed | `gdlint` |
| Every function declares a return type, including `-> void` | `gdlint` |
| Typed arrays where the element type is known: `Array[ScoreEvent]` | Review |
| `StringName` (`&"..."`) for IDs, never `String` | `test_ids_are_stringname.gd` |

**Why `StringName` for IDs:** comparisons are pointer-equal and allocation-free. IDs are compared
on the hot path — every score append, every ability lookup, every state transition.

---

## 2. `class_name` policy

| Declare `class_name` | Do not |
|---|---|
| Anything instantiated from more than one file | One-off scene scripts |
| Every `Resource` subclass | Scripts attached to a single scene root and never referenced by type |
| Every base class | |
| Every Core type | |

Names are `PascalCase` and the file is the `snake_case` of the name — `SuspicionSystem` lives in
`suspicion_system.gd`. Checked by `test_file_naming.gd`.

---

## 3. Signals

**Signals are past-tense facts.** The bus reports what has happened, never what should happen.

```gdscript
# Correct
signal contract_assigned(reason: int)
signal suspicion_tier_changed(tier: int, active_sources: int)
signal prey_warning_triggered()

# Wrong
signal assign_contract(...)        # imperative — that is a function call
signal on_contract(...)            # "on_" is a handler prefix, not an event name
signal contract_changed_signal()   # "_signal" is noise
```

| Rule | Enforced by |
|---|---|
| Past tense, `snake_case`, no `on_` prefix, no `_signal` suffix | `test_signal_naming.gd` |
| Every parameter typed | `gdlint` |
| Every `EventBus` signal has a row in `SIGNAL_AND_EVENT_BUS.md` with matching arity | `test_eventbus_signals_documented.gd` |
| Handler methods are `_on_<emitter>_<signal>` | Convention, reviewed |

---

## 4. Privacy

`_` prefix for anything not part of a type's contract. This is a real constraint, not decoration:
a `_`-prefixed member may be changed without considering other files.

```gdscript
class_name ContractCycle
extends RefCounted

var _order: PackedInt32Array          ## private state
var _recent: Dictionary

func contract_of(peer: int) -> int:   ## public API
    ...

func _rebuild(rng: RandomNumberGenerator) -> void:   ## private helper
    ...
```

---

## 5. Node access

**Never `get_node("../..")`. Never a hardcoded absolute path.**

```gdscript
# Correct — declared dependency, visible in the inspector
@export var crowd_director: CrowdDirector

# Correct — own subtree, typed
@onready var _compass: CompassWidget = %CompassWidget

# Correct — injected explicitly (systems)
func setup(ctx: MatchContext) -> void:
    _crowd = ctx.crowd

# WRONG
var player = get_node("../../World/Pawns/Pawn_1")
var hud = get_tree().root.get_node("ClientRoot/Presentation/HUD")
```

| Context | Mechanism |
|---|---|
| Systems | Explicit injection via `MatchContext` — the dependency-injection seam |
| Widgets | A view model, assigned at construction (ADR-0006) |
| Own subtree | `%UniqueName` with a type annotation |
| Cross-layer | The event bus — never a direct reference |

`test_ui_no_gameplay_refs.gd` and `test_layer_dependencies.gd` enforce this.

---

## 6. Length limits

| Limit | Value | Enforced by |
|---|---|---|
| File | **400 lines** | `.gdlintrc` |
| Function | **40 lines** | `test_function_lengths.gd` |
| Line | 100 characters | `.gdlintrc` |
| Function parameters | 6 | `.gdlintrc` |
| Public methods per class | 20 | `.gdlintrc` |

**These are design signals, not style preferences.** A function reaching 40 lines is usually
doing two things; a file reaching 400 usually wants splitting. If a limit is genuinely wrong for
a case, that is an ADR, not a `# gdlint:ignore`.

---

## 7. Early returns

Guard clauses first, happy path unindented.

```gdscript
# Correct
func try_stun(ctx: MatchContext, stunner: int, target: int) -> bool:
    if ctx.suspicion.tier_of(target) < Tier.NOTICED:
        return false
    if ctx.cycle.contract_of(target) != stunner:
        return false
    if _distance(stunner, target) > Tuning.combat.stun_range:
        return false
    _apply_stun(ctx, stunner, target)
    return true

# Wrong — arrow code
func try_stun(...) -> bool:
    if tier_ok:
        if is_pursuer:
            if in_range:
                _apply_stun(...)
                return true
    return false
```

---

## 8. No magic numbers

```gdscript
# Correct
if speed > Tuning.suspicion.decay_speed_ceiling:
if ctx.state_timer_ticks >= Tuning.ticks(&"TUN-KILL-ANIM-DURATION"):

# Wrong
if speed > 2.2:
if ctx.state_timer_ticks >= 42:
```

**The only permitted bare literals are `0`, `1`, `-1`, array indices, and mathematical
identities.** Everything else is either a tunable (ADR-0005) or a named constant.

```gdscript
# Named constants are fine for non-gameplay values
const PHYSICS_PER_NET_TICK: int = 2
const CELL_SIZE: float = 6.0   ## == TUN-SUSPICION-OPEN-RADIUS; see TDD-08 §6
```

`test_no_gameplay_literals.gd` scans `scripts/systems/` and `scripts/pawn/`.

---

## 9. Docstrings

`##` comments, immediately above the declaration.

```gdscript
## Suspicion decayed per second at or below decay_speed_ceiling.
## Full 100 -> 0 in 12.5 s of civilian behaviour: long enough that a mistake has
## consequences, short enough that a match is not ruined by five bad seconds.
## TUN-SUSPICION-DECAY-BASE
@export_range(6.0, 12.0, 0.1) var decay_base: float = 8.0
```

| Required on | Content |
|---|---|
| Every `class_name` | What it is, and what it must never do |
| Every public function | What it does. Preconditions if any. **Never restate the signature** |
| Every `@export` in a `*Tuning` class | Rationale + the `TUN-` ID as the **last token** (the docs-sync check greps for it) |
| Every non-obvious branch | *Why*, never *what* |

```gdscript
# Useless — restates the code
## Returns the contract of the given peer.
func contract_of(peer: int) -> int:

# Useful — explains the consequence
## The successor in the cycle. Because the cycle is Hamiltonian, this is also
## the ONLY player who may kill `peer` — there is no kill-stealing.
func contract_of(peer: int) -> int:
```

---

## 10. Error handling

Two categories, two mechanisms. **Never mix them.**

| Category | Mechanism | Example |
|---|---|---|
| **Programmer error** — a broken invariant that indicates a bug | `assert()`. Compiled out of release | Illegal state transition; a null view model; a cycle with a fixed point |
| **Runtime condition** — something the world can legitimately do | `push_error()` + graceful degrade | Malformed packet; missing string key; a client with a stale tuning hash |

```gdscript
# Programmer error — this must never happen, and if it does we want the stack
assert(vm != null, "Widget requires a view model (ADR-0006)")

# Runtime condition — the world did something; carry on
if not TRANSITIONS[from].has(to):
    assert(false, "Illegal transition %s -> %s (TDD-06 §2.2)" % [from, to])
    push_error("Illegal transition %s -> %s" % [from, to])
    return false   # degrade: stay in the current state
```

**Never fail silently.** A rejected kill plays a whiff (`SFX-KILL-WHIFF`); a rejected ability
sends `NET-S2C-ABILITY-DENIED`; a refused blend gives distinct feedback. Silence is
indistinguishable from a bug, and players report it as one.

---

## 11. Determinism rules for `scripts/pawn/`

That code is replayed during prediction reconciliation, so it must be a pure function of
`(ctx, input, delta)`.

**Banned in `scripts/pawn/`:** `randf`, `randi`, `Time.*`, `get_node`, `get_tree`,
`Engine.get_*`, and every autoload except `Tuning`.

Enforced by `test_pawn_determinism_grep.gd`. This is the one rule where a violation produces a
bug that is genuinely hard to diagnose from a player report — it shows up as the game
occasionally disagreeing with itself under load.

---

## 12. Allocation on the hot path

`NpcBrain.step()` runs ~34 times per tick, and `PawnState.step()` twelve. Neither may allocate.

```gdscript
# WRONG — allocates every call
func step(...) -> StringName:
    var nearby := []                        # new Array
    var data := {"x": 1}                    # new Dictionary
    return "Idle"                           # new String

# Correct — reuse buffers, use StringName
var _nearby: PackedInt32Array = PackedInt32Array()   # member, sized once

func step(...) -> StringName:
    _nearby.clear()
    return &"Idle"                          # interned
```

`test_npc_no_alloc.gd` asserts zero allocations after warm-up.

---

## 13. Comments

| Write | Do not write |
|---|---|
| *Why* a non-obvious choice was made | *What* the code does |
| A reference to the governing doc section (`# see TDD-07 §2.1`) | Commented-out code — delete it; git remembers |
| A `TODO(US-####):` tied to a real story | A bare `TODO` with no owner |
| The consequence of getting it wrong | Decoration banners |

---

## 14. Formatting

`gdformat` decides. `gdformat --check` runs in CI; `gdformat` runs on a pre-commit hook.
**Formatting is never a review topic** and never appears in a diff alongside a behaviour change.

---

## 15. Enforcement summary

| Rule | Mechanism |
|---|---|
| Typing coverage | `test_typing_coverage.gd` |
| File / line / params / methods limits | `.gdlintrc` |
| Function length ≤ 40 | `test_function_lengths.gd` |
| Signal naming | `test_signal_naming.gd` |
| File ↔ `class_name` match | `test_file_naming.gd` |
| No gameplay literals | `test_no_gameplay_literals.gd` |
| No literal user-facing strings | `test_no_literal_strings.gd` |
| No `get_node` outside a widget's subtree | `test_ui_no_gameplay_refs.gd` |
| Layer dependency direction | `test_layer_dependencies.gd` |
| Core purity | `test_core_is_pure.gd` |
| Pawn determinism | `test_pawn_determinism_grep.gd` |
| `randf` confined to presentation | `test_randf_confined.gd` |
| No hot-path allocation | `test_npc_no_alloc.gd` |
| `StringName` for IDs | `test_ids_are_stringname.gd` |
| No `utils`/`helpers`/`misc` files | `test_no_utils_files.gd` |
| Formatting | `gdformat --check` |

**Sixteen mechanical checks.** Anything not on this list is a judgement call, and judgement calls
are settled by the reviewer, not by argument in the PR.

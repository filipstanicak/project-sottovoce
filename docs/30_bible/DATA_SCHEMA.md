---
id: BIBLE-DATA-SCHEMA
title: Data Schema — Resource Reference
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-05-DATA, TUN-INDEX, ADR-0005]
---

# Data Schema — Resource Reference

> **The rule:** no gameplay constant may appear as a literal in any script. Every one lives in a
> typed `Resource`, is documented in [`../50_tuning/TUNABLES.md`](../50_tuning/TUNABLES.md) with a
> `TUN-` ID, and is server-authoritative at runtime.
>
> This document is the **field-level reference**: every resource class, every field, its type,
> range and default. The rationale for each value lives in TUNABLES.md; the architecture lives
> in [`../20_tdd/05_data_architecture.md`](../20_tdd/05_data_architecture.md).

---

## 1. The three `@export` rules

Every exported field in a `*Tuning` class obeys all three:

1. An `@export_range` matching the **Range** column in TUNABLES.md.
2. A `##` docstring whose **last token is the `TUN-` ID** — this is what `tuning_docs_sync.gd`
   greps for.
3. A one-line rationale, so a developer reading the resource never has to open the document.

```gdscript
## Gained per second while sprinting. Noticed in 1.2 s, Exposed in 2.8 s —
## sprinting is a three-second budget, not a movement mode.
## TUN-SUSPICION-GAIN-SPRINT
@export_range(20.0, 32.0, 0.5) var gain_sprint: float = 25.0
```

**The field name is a mechanical transform of the ID:** `TUN-<DOMAIN>-<NAME>` →
`<Domain>Tuning.<name_lowercased_underscored>`. The leading domain segment is dropped when the
class owns that domain and kept when it does not, so `MovementTuning` holds both `stroll` (from
`TUN-SPEED-STROLL`) and `traverse_gap_max` (from `TUN-TRAVERSE-GAP-MAX`).

**Exceptions are enumerated, never improvised.** Four names deviate, each for a stated reason;
there are no others, and adding a fifth needs a line in this table:

| ID | Field | Why not the mechanical name |
|---|---|---|
| `TUN-SUSPICION-MAX` | `max_value` | A member named `max` shadows GDScript's built-in `max()` inside the class. |
| `TUN-SPEED-BLENDWALK` | `blend_walk` | Compound word; `blendwalk` is unreadable. |
| `TUN-PASV-COLDREAD-MULT` | `cold_read_mult` | Compound word. |
| `TUN-PASV-SECONDWIND-REDUCTION` | `second_wind_reduction` | Compound word. |

`AbilityData` adds two of its own, for the same reason of matching §4.1's written names:
`TUN-<ABIL>-SUSPICION` → `suspicion_cost`, `TUN-<ABIL>-STUNNABLE` → `stunnable_during`.

---

## 2. `TuningProfile` — the root

| Field | Type | Notes |
|---|---|---|
| `movement` | `MovementTuning` | §3.1 |
| `suspicion` | `SuspicionTuning` | §3.2 |
| `compass` | `CompassTuning` | §3.3 |
| `combat` | `CombatTuning` | §3.4 |
| `contract` | `ContractTuning` | §3.5 |
| `crowd` | `CrowdTuning` | §3.6 |
| `match_rules` | `MatchTuning` | §3.7 |
| `scoring` | `ScoringTuning` | §3.8 |
| `camera` | `CameraTuning` | §3.9 |
| `net` | `NetTuning` | §3.10 |
| `ui_audio` | `UiAudioTuning` | §3.11 |
| `ability` | `AbilityTuning` | §3.13 — the five ability-system settings that are not per-ability |
| `flags` | `FeatureFlags` | §3.12 |
| `abilities` | `Dictionary` | `StringName(ABIL-*) → AbilityData` |
| `passives` | `Dictionary` | `StringName(PASV-*) → PassiveData` |

```gdscript
func compute_hash() -> int          ## stable over VALUES only; excludes paths and metadata
func validate() -> Array[String]    ## ranges + the 20 cross-field invariants; empty == valid
func serialise() -> PackedByteArray
static func deserialise(b: PackedByteArray) -> TuningProfile
```

---

## 3. Sub-resources

Values, units and rationales are in TUNABLES.md at the section noted. Reproduced here as
**type + range + default** only, to keep one source of truth for the *numbers*.

### 3.1 `MovementTuning` — TUNABLES §2

| Field | Type | Range | Default |
|---|---|---|---|
| `blend_walk` | float | 1.2–1.6 | 1.4 |
| `stroll` | float | 1.8–2.6 | 2.2 |
| `jog` | float | 3.0–3.8 | 3.4 |
| `run` | float | 4.0–5.0 | 4.5 |
| `sprint` | float | 5.6–6.8 | 6.2 |
| `climb` | float | 2.4–3.2 | 2.8 |
| `accel` | float | 12–26 | 18.0 |
| `decel` | float | 16–34 | 24.0 |
| `turn_rate_ground` | float | 360–720 | 540.0 |
| `backpedal_mult` | float | 0.4–0.8 | 0.55 |
| `traverse_vault_max_height` | float | 0.9–1.3 | 1.1 |
| `traverse_mantle_max_height` | float | 2.0–2.6 | 2.3 |
| `traverse_climb_max_height` | float | 6–12 | 9.0 |
| `traverse_drop_safe_height` | float | 3–5 | 4.0 |
| `traverse_gap_max` | float | 2.5–4.0 | 3.2 |
| `traverse_magnet_window` | float | 0.15–0.40 | 0.25 |
| `traverse_magnet_radius` | float | 0.4–0.9 | 0.6 |
| `traverse_input_buffer` | float | 0.1–0.3 | 0.20 |
| `probe_length` | float | 0.7–1.2 | 0.9 |

### 3.2 `SuspicionTuning` — TUNABLES §3

| Field | Type | Range | Default |
|---|---|---|---|
| `max_value` | float | — | 100.0 |
| `decay_base` | float | 6–12 | 8.0 |
| `decay_speed_ceiling` | float | 1.0–4.0 | 2.2 |
| `decay_delay` | float | 0.3–1.2 | 0.6 |
| `gain_jog` | float | 2–7 | 4.0 |
| `gain_run` | float | 10–18 | 14.0 |
| `gain_sprint` | float | 20–32 | 25.0 |
| `gain_roof` | float | 14–24 | 18.0 |
| `gain_climb` | float | 8–16 | 12.0 |
| `gain_open` | float | 4–9 | 6.0 |
| `open_radius` | float | 4–9 | 6.0 |
| `gain_npc_bump` | float | 10–22 | 15.0 |
| `gain_npc_bump_cooldown` | float | 0.5–1.5 | 0.8 |
| `gain_loud_ability` | float | 30–50 | 40.0 |
| `gain_failed_kill` | float | 20–40 | 30.0 |
| `gain_witnessed_kill` | float | 15–35 | 25.0 |
| `tier_noticed` | float | 25–40 | 30.0 |
| `tier_exposed` | float | 60–80 | 70.0 |
| `hysteresis` | float | 3–10 | 5.0 |
| `blend_crush_time` | float | 0.8–2.0 | 1.2 |
| `blend_entry_time` | float | 0.2–0.6 | 0.35 |
| `blend_exit_time` | float | 0.2–0.5 | 0.30 |
| `blend_group_join_radius` | float | 2.0–3.5 | 2.5 |
| `blend_group_slot_tolerance` | float | 0.5–1.2 | 0.8 |
| `blend_pocket_min_npc` | int | 3–6 | 4 |
| `blend_pocket_radius` | float | 2.5–5.0 | 3.5 |
| `blend_prop_capacity` | int | 1–2 | 1 |
| `blend_prop_exit_vuln` | float | 0.3–0.8 | 0.5 |
| `blend_score_grace` | float | 0.5–1.5 | 1.0 |
| `stillness_mult` | float | 1.2–1.8 | 1.40 |
| `stillness_speed_ceiling` | float | 0.0–0.5 | 0.15 |

### 3.3 `CompassTuning` — TUNABLES §4

| Field | Type | Range | Default |
|---|---|---|---|
| `range_max` | float | 45–80 | 60.0 |
| `pulse_max` | float | 0.7–1.2 | 0.90 |
| `pulse_min` | float | 0.10–0.25 | 0.15 |
| `pulse_exp` | float | 1.6–3.0 | 2.2 |
| `cone_halfwidth` | float | 8–20 | 12.0 |
| `cone_wobble` | float | 0–8 | 4.0 |
| `cone_wobble_period` | float | 2–6 | 3.1 |
| `lock_cone` | float | 18–35 | 25.0 |
| `lock_range` | float | 15–28 | 20.0 |
| `lock_fill_time` | float | 1.0–2.5 | 1.6 |
| `lock_decay_rate` | float | 1.0–3.0 | 1.4 |
| `reveal_duration` | float | 1.0–2.5 | 1.5 |
| `reveal_cooldown` | float | 2–8 | 4.0 |
| `warn_radius` | float | 10–22 | 15.0 |
| `warn_min_tier` | float | — | 30.0 |
| `warn_duration` | float | 0.8–2.0 | 1.2 |
| `warn_cooldown` | float | 1.5–5.0 | 2.5 |
| `warn_gives_direction` | bool | — | **false** |
| `cold_read_mult` | float | 1.15–1.6 | 1.30 |

### 3.4 `CombatTuning` — TUNABLES §5–6

| Field | Type | Range | Default |
|---|---|---|---|
| `kill_range` | float | 2.0–3.2 | 2.5 |
| `kill_facing_cone` | float | 45–90 | 60.0 |
| `kill_anim_duration` | float | 1.2–1.8 | 1.4 |
| `kill_validation_grace` | float | 0.2–0.6 | 0.35 |
| `kill_contest_window` | float | 0.25–0.6 | 0.4 |
| `kill_contest_stagger` | float | 1.0–2.5 | 1.5 |
| `kill_corpse_spawn_delay` | float | — | 0.9 |
| `stun_range` | float | 2.5–4.0 | **3.0** |
| `stun_facing_cone` | float | 90–180 | 120.0 |
| `stun_min_tier` | float | — | 30.0 |
| `stun_freeze` | float | 3.0–6.0 | 4.0 |
| `stun_lockout` | float | 8–18 | 12.0 |
| `stun_anim_duration` | float | 0.5–1.0 | 0.7 |
| `stun_invalid_stagger` | float | 1.5–3.5 | 2.0 |
| `stun_invalid_suspicion` | float | 10–30 | 20.0 |
| `stun_cooldown` | float | 2–6 | 3.0 |
| `second_wind_reduction` | float | 2–6 | 4.0 |

### 3.5 `ContractTuning` — TUNABLES §7

| Field | Type | Range | Default |
|---|---|---|---|
| `reassign_delay` | float | 2–5 | 3.0 |
| `anti_repeat_depth` | int | 1–3 | 1 |
| `min_cycle_length` | int | — | 3 |
| `repair_debounce` | float | 0.1–0.5 | 0.25 |
| `respawn_delay` | float | 3–8 | 5.0 |
| `respawn_min_dist_from_killer` | float | 25–60 | 40.0 |
| `respawn_min_dist_from_any` | float | 8–20 | 12.0 |
| `respawn_invuln` | float | 0.5–2.0 | 1.0 |
| `spawn_point_count` | int | 6–8 | 6 |

### 3.6 `CrowdTuning` — TUNABLES §9

| Field | Type | Range | Default |
|---|---|---|---|
| `count_min` / `count_max` | int | — | 60 / 90 |
| `count_default_6p` / `_4p` | int | 66–90 / 60–78 | 78 / 66 |
| `clones_per_persona_min` / `_max` | int | — | 8 / 12 |
| `clone_local_min` | int | 1–4 | 2 |
| `director_interval` | float | 1–5 | 2.0 |
| `npc_speed_stroll` | float | — | **1.4** |
| `npc_speed_flee` | float | 4–6 | 5.0 |
| `group_size` / `group_count` | int | 3–6 / 3–6 | 4 / 4 |
| `group_spacing` | float | 1.0–2.0 | 1.3 |
| `startle_duration` | float | 3–6 | 4.0 |
| `startle_radius_violence` | float | 8–18 | 12.0 |
| `startle_radius_sprint` | float | 3–8 | 5.0 |
| `startle_propagation` | float | 0.0–0.7 | 0.4 |
| `gawk_duration` | float | 4–10 | 6.0 |
| `gawk_radius` | float | 6–15 | 10.0 |
| `gawk_max` | int | 4–10 | 6 |
| `corpse_lifetime` | float | 12–30 | 20.0 |
| `bump_push` | float | 0.8–2.0 | 1.2 |

### 3.7 `MatchTuning` — TUNABLES §10

| Field | Type | Range | Default |
|---|---|---|---|
| `lobby_min_players` / `_max_players` | int | — | 4 / 6 |
| `lobby_countdown` | float | 3–10 | 5.0 |
| `duration` | float | 420–600 | 480.0 |
| `finalphase_duration` | float | 20–60 | 30.0 |
| `finalphase_mult` | float | 1.5–3.0 | 2.0 |
| `finalphase_warning` | float | 3–10 | 5.0 |
| `results_duration` | float | 15–45 | 25.0 |
| `tick_rate` | int | — | 30 |

### 3.8 `ScoringTuning` — TUNABLES §11

| Field | Type | Range | Default |
|---|---|---|---|
| `contract` | int | — | **100** |
| `silent` | int | 75–150 | 100 |
| `patient` | int | 100–200 | 150 |
| `patient_window` | float | 8–15 | 10.0 |
| `masked` | int | 100–200 | 150 |
| `focus` | int | 75–150 | 100 |
| `focus_window` | float | 4–10 | 6.0 |
| `focus_break_grace` | float | 0.2–0.8 | 0.4 |
| `fromabove` | int | 75–150 | 100 |
| `fromabove_height` | float | 2.5–4.5 | 3.0 |
| `blended` | int | 150–250 | **200** |
| `poisoned` | int | 50–125 | 75 |
| `longhunt_1` / `_2` | int | 25–100 / 100–200 | 50 / 150 |
| `longhunt_t1` / `_t2` | float | 15–30 / 35–70 | 20.0 / 45.0 |
| `vendetta` | int | 75–150 | 100 |
| `variety_per_type` | int | 25–75 | 50 |
| `reckless` | int | −100–−25 | **−50** |
| `stun` | int | 75–150 | 100 |

### 3.9 `CameraTuning` — TUNABLES §12

`fov_blend` 55 · `fov_stroll` 60 · `fov_jog` 65 · `fov_run` 69 · `fov_sprint` 72 ·
`fov_blend_rate` 90 · `arm_length` 2.6 · `arm_height` 1.55 · `shoulder_offset` 0.45 ·
`shoulder_swap_time` 0.25 · `occlusion_pull_rate` 12.0 · `occlusion_restore_rate` 4.0 ·
`crowdscan_speed` 0.45 · `crowdscan_fov` 48.

### 3.10 `NetTuning` — TUNABLES §13

`server_tick_hz` 30 · `client_input_rate` 60 · `snapshot_rate` 30 · `interp_buffer_ms` 100 ·
`lagcomp_min_ms` 100 · `lagcomp_max_ms` 200 · `lagcomp_history_ms` 500 ·
`reconcile_threshold` 0.10 · `reconcile_smooth_time` 0.12 · `input_buffer_size` 32 ·
`bandwidth_budget_down` 96 · `bandwidth_budget_up` 16 · `timeout` 10.0 · `quant_pos` 0.01 ·
`quant_yaw` 1.0 · `npc_cull_radius` 70.0.

### 3.11 `UiAudioTuning` — TUNABLES §15

`readability_target` 0.5 · `scorefeed_duration` 4.0 · `scorefeed_max_lines` 4 ·
`scorefeed_stagger` 0.12 · `tier_transition_time` 0.25 · `damage_vignette_time` 0.8 ·
`compass_duck` −6.0 · `sting_duck` −12.0 · `occlusion_lowpass` 900 ·
`footstep_radius_blend` 4.0 · `footstep_radius_sprint` 18.0.

### 3.13 `AbilityTuning` — TUNABLES §8.1

The five ability-system settings that belong to no single ability: `slots_active`,
`slots_passive`, `lock_at_match_start`, `global_cooldown`, `input_buffer`. Added because §8's
globals had no home in the original §2 field list, and a documented `TUN-` value that lives
nowhere in the data breaks the "every number is a tunable" rule.

### 3.12 `FeatureFlags`

```gdscript
class_name FeatureFlags
extends Resource

## Enable ABIL-SECONDFACE. Off until US-0051 completes. REMOVE THIS FLAG AT M5 EXIT.
@export var enable_second_face: bool = false
```

**Every flag's docstring names the story that removes it.** A flag with no removal story is
technical debt with a nice name, and the Definition of Done checks for it.

---

## 4. Content resources

### 4.1 `AbilityData`

| Field | Type | Notes |
|---|---|---|
| `id` | `StringName` | `ABIL-*`, immutable |
| `display_key` | `StringName` | String-table key — never a literal |
| `cast_time` / `duration` / `cooldown` | float | Authored in seconds; converted to ticks at load |
| `suspicion_cost` | float | |
| `forces_exposed` | bool | Whisperbolt only |
| `exposed_tail` | float | |
| `effect_script` | `Script` | `extends AbilityEffect`. **The only per-ability code** |
| `range_min` / `range_max` / `radius` | float | |
| `tell_sfx` | `StringName` | `SFX-*` |
| `tell_audio_radius` | float | **Environmental/audio tell channel** |
| `tell_vfx` | `PackedScene` | |
| `startle_radius` | float | **Environmental tell channel** |
| `stunnable_during` | bool | Lunge, Whisperbolt wind-up |
| `breaks_on_sprint` / `breaks_on_damage` | bool | Second Face |

> **`test_ability_has_tell.gd` asserts ≥ 2 tell channels are filled, with ≥ 1 of
> `tell_audio_radius > 0` or `startle_radius > 0`.** The legibility law is enforced by the
> schema, not by review.

### 4.1a `PassiveData`

| Field | Type | Notes |
|---|---|---|
| `id` | `StringName` | `PASV-*`, immutable |
| `display_key` | `StringName` | String-table key |
| `effect_script` | `Script` | `extends PassiveEffect` |

**Deliberately holds no numbers.** A passive modifies a domain, so its magnitude lives with that
domain: `PASV-STILLNESS` → `SuspicionTuning.stillness_mult`, `PASV-COLDREAD` →
`CompassTuning.cold_read_mult`, `PASV-SECONDWIND` → `CombatTuning.second_wind_reduction`. A second
copy here would mean two places to change one number.

### 4.2 `PersonaData`

| Field | Type | Notes |
|---|---|---|
| `id` | `StringName` | `PERSONA-*` |
| `display_key` | `StringName` | |
| `silhouette` | enum | `LOW_BROAD` · `FLOOR_TRIANGLE` · `TALL_THIN` · `ROUND_MID`. **The four MVP personas must be mutually distinct** |
| `mesh` | `PackedScene` | |
| `animation_library` | `AnimationLibrary` | |
| `identity_hue` | `Color` | Reserved by the colour-language law |
| `anonymous_clip_names` | `PackedStringArray` | **The clone-parity set.** Every entry must exist in the clone's library |

### 4.3 `MapData`

| Field | Type | Notes |
|---|---|---|
| `id` | `StringName` | `MAP-*` |
| `playable_bounds` | `AABB` | |
| `soft_bound_4p` | `AABB` | Inner 90 × 90 m |
| `spawn_points` | `Array[SpawnPoint]` | 6 |
| `idle_anchors` | `Array[IdleAnchor]` | position + archetype filter + prop type |
| `circuits` | `Array[CircuitData]` | 4 |
| `blend_props` | `Array[BlendProp]` | 5 concealment + ~12 static |
| `zones` | `Array[ZoneVolume]` | density band + audio zone + telemetry name |
| `theatre_spaces` | `Array[AABB]` | ≥ 2 |

**`MapData` is authoring data, deliberately separate from geometry, so the art pass cannot move
it** ([`../10_gdd/05_level_design.md`](../10_gdd/05_level_design.md) §7.3).

---

## 5. `.tres` example

```
[gd_resource type="Resource" script_class="SuspicionTuning" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/core/tuning/suspicion_tuning.gd" id="1"]

[resource]
script = ExtResource("1")
decay_base = 8.0
decay_speed_ceiling = 2.2
decay_delay = 0.6
gain_jog = 4.0
gain_run = 14.0
gain_sprint = 25.0
gain_roof = 18.0
gain_climb = 12.0
gain_open = 6.0
open_radius = 6.0
tier_noticed = 30.0
tier_exposed = 70.0
hysteresis = 5.0
```

**Never reorder exported properties in a resource class once merged** — reordering rewrites every
`.tres` that uses it, producing enormous unreviewable diffs.

---

## 6. Cross-field invariants

Twenty invariants beyond per-field ranges, asserted at load by `validate()` and in
`test_tuning_ranges.gd`. The full list is TUNABLES §17. The five that matter most:

| # | Invariant | Why |
|---|---|---|
| 1 | `movement.blend_walk == crowd.npc_speed_stroll` | A player at blend-walk must be indistinguishable from an NPC by motion. **The most important invariant in the file** |
| 3 | `suspicion.decay_speed_ceiling == movement.stroll` | The decay cliff sits exactly at the top civilian speed |
| 6 | `combat.stun_range > combat.kill_range` | The prey's reach must exceed the hunter's |
| 8 | `compass.warn_min_tier == combat.stun_min_tier` | "I was warned" and "I can stun" are the same condition — two thresholds would be unlearnable |
| 18 | `scoring.blended > scoring.patient > scoring.silent` | The bonus hierarchy encodes the design thesis. If a tuning change inverts it, the change is wrong |

---

## 7. Acceptance criteria

- [ ] Every `TUN-` ID in TUNABLES.md maps to exactly one `@export`, and vice versa (`test_tuning_docs_sync.gd`).
- [ ] Every `@export_range` matches TUNABLES.md's Range column.
- [ ] Every `*Tuning` `@export` docstring ends with its `TUN-` ID.
- [ ] `validate()` implements all 20 invariants.
- [ ] `compute_hash()` is stable across files with identical values.
- [ ] `deserialise(serialise(p))` round-trips field-for-field.
- [ ] Every `AbilityData` fills ≥ 2 tell channels with ≥ 1 environmental/audio.
- [ ] The four `PersonaData` have four distinct `silhouette` values.
- [ ] Every `FeatureFlags` field names its removal story.
- [ ] Every `display_key` resolves in `data/strings/en.csv`.

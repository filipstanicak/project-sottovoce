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

**Every table below is the resource.** Field, type, `@export_range` band and default are read off
`scripts/core/tuning/<resource>.gd`, the generated script, and `test_data_schema_mirrors_tuning.gd`
holds each table to it, so a tunable added, renamed, re-typed or re-priced turns that test red
until this page follows. *Until 2026-09-29 these were written by hand at M0 and never re-read; each
block says what it used to get wrong.*

### 3.1 `MovementTuning` — TUNABLES §2

*Regenerated 2026-09-29. The previous block left out `run_resolve`, `stick_deadzone`, `stick_blendwalk_max`, `trigger_run`, `vault_duration`, `mantle_duration`, `hop_standing`, `hop_committed`, `drop_min_height`, `drop_stagger`, `probe_count`, `probe_height_chest`, `probe_height_waist`, `probe_height_foot`, `gapjump_launch`, `gap_align_arc`, `gap_probe_ahead`, `gap_probe_depth`, `gap_probe_step`, `input_to_anim_max`, `max_commit`.*

| Field | Type | Range | Default |
|---|---|---|---|
| `blend_walk` | float | 1.2–1.6 | 1.4 |
| `stroll` | float | 1.8–2.6 | 2.2 |
| `run` | float | 4–5 | 4.5 |
| `sprint` | float | 5.6–6.8 | 6.2 |
| `climb` | float | 2.4–3.2 | 2.8 |
| `accel` | float | 12–26 | 18 |
| `decel` | float | 16–34 | 24 |
| `turn_rate_ground` | float | 360–720 | 540 |
| `run_resolve` | float | 0.08–0.35 | 0.15 |
| `stick_deadzone` | float | 0.05–0.25 | 0.15 |
| `stick_blendwalk_max` | float | 0.2–0.45 | 0.3 |
| `trigger_run` | float | 0.5–0.95 | 0.75 |
| `backpedal_mult` | float | 0.4–0.8 | 0.55 |
| `traverse_vault_max_height` | float | 0.9–1.3 | 1.1 |
| `vault_duration` | float | 0.4–0.7 | 0.55 |
| `traverse_mantle_max_height` | float | 2–2.6 | 2.3 |
| `mantle_duration` | float | 0.8–1.2 | 0.95 |
| `traverse_climb_max_height` | float | 6–12 | 9 |
| `traverse_drop_safe_height` | float | 3–5 | 4 |
| `hop_standing` | float | 1.8–3.4 | 2.6 |
| `hop_committed` | float | 3.2–5.4 | 4.2 |
| `drop_min_height` | float | 0.6–1.6 | 1.1 |
| `drop_stagger` | float | 0.5–1.2 | 0.8 |
| `traverse_gap_max` | float | 2.5–4 | 3.2 |
| `traverse_magnet_window` | float | 0.15–0.4 | 0.25 |
| `traverse_magnet_radius` | float | 0.4–0.9 | 0.6 |
| `probe_count` | int | — | 3 |
| `probe_height_chest` | float | — | 1.35 |
| `probe_height_waist` | float | — | 0.85 |
| `probe_height_foot` | float | — | 0.25 |
| `probe_length` | float | 0.7–1.2 | 0.9 |
| `traverse_input_buffer` | float | 0.1–0.3 | 0.2 |
| `gapjump_launch` | float | 3–5 | 3.9 |
| `gap_align_arc` | float | 10–30 | 20 |
| `gap_probe_ahead` | float | 0.4–0.9 | 0.6 |
| `gap_probe_depth` | float | 9–14 | 10 |
| `gap_probe_step` | float | 0.2–0.8 | 0.4 |
| `input_to_anim_max` | float | 50–100 | 80 |
| `max_commit` | float | — | 1.4 |

### 3.2 `SuspicionTuning` — TUNABLES §3

*Regenerated 2026-09-29. The previous block named `gain_jog` (no such field); left out `min`, `roof_height`, `break_on_damage`, `break_on_speed`.*

| Field | Type | Range | Default |
|---|---|---|---|
| `max_value` | float | — | 100 |
| `min` | float | — | 0 |
| `decay_base` | float | 6–12 | 8 |
| `decay_speed_ceiling` | float | — | 2.2 |
| `decay_delay` | float | 0.3–1.2 | 0.6 |
| `gain_sprint` | float | 20–32 | 25 |
| `gain_run` | float | 10–18 | 14 |
| `roof_height` | float | 4–8 | 6 |
| `gain_roof` | float | 14–24 | 18 |
| `gain_climb` | float | 8–16 | 12 |
| `gain_open` | float | 0–9 | 0 |
| `open_radius` | float | 4–9 | 6 |
| `gain_npc_bump` | float | 10–22 | 15 |
| `gain_npc_bump_cooldown` | float | 0.5–1.5 | 0.8 |
| `gain_loud_ability` | float | 30–50 | 40 |
| `gain_failed_kill` | float | 20–40 | 30 |
| `gain_witnessed_kill` | float | 15–35 | 25 |
| `tier_noticed` | float | 25–40 | 30 |
| `tier_exposed` | float | 60–80 | 70 |
| `hysteresis` | float | 3–10 | 5 |
| `blend_crush_time` | float | 0.8–2 | 1.2 |
| `blend_entry_time` | float | 0.2–0.6 | 0.35 |
| `blend_exit_time` | float | 0.2–0.5 | 0.3 |
| `blend_group_join_radius` | float | 2–3.5 | 2.5 |
| `blend_group_slot_tolerance` | float | 0.5–1.2 | 0.8 |
| `blend_pocket_min_npc` | int | 3–6 | 4 |
| `blend_pocket_radius` | float | 2.5–5 | 3.5 |
| `break_on_damage` | bool | — | true |
| `break_on_speed` | float | — | 2.2 |
| `blend_prop_capacity` | int | 1–2 | 1 |
| `blend_prop_exit_vuln` | float | 0.3–0.8 | 0.5 |
| `blend_score_grace` | float | 0.5–1.5 | 1 |
| `stillness_mult` | float | 1.2–1.8 | 1.4 |
| `stillness_speed_ceiling` | float | 0–0.5 | 0.15 |

### 3.3 `CompassTuning` — TUNABLES §4

*Regenerated 2026-09-29. The previous block left out `cone_full_radius`, `update_rate`, `lock_requires_los`; gave `warn_gives_direction` **false** → true.*

| Field | Type | Range | Default |
|---|---|---|---|
| `range_max` | float | 45–80 | 60 |
| `pulse_max` | float | 0.7–1.2 | 0.9 |
| `pulse_min` | float | 0.1–0.25 | 0.15 |
| `pulse_exp` | float | 1.6–3 | 2.2 |
| `cone_halfwidth` | float | 8–20 | 12 |
| `cone_full_radius` | float | 6–24 | 20 |
| `cone_wobble` | float | 0–8 | 4 |
| `cone_wobble_period` | float | 2–6 | 3.1 |
| `update_rate` | float | — | 30 |
| `lock_cone` | float | 18–35 | 25 |
| `lock_range` | float | 15–28 | 20 |
| `lock_fill_time` | float | 1–2.5 | 1.6 |
| `lock_decay_rate` | float | 1–3 | 1.4 |
| `lock_requires_los` | bool | — | true |
| `reveal_duration` | float | 1–2.5 | 1.5 |
| `reveal_cooldown` | float | 2–8 | 4 |
| `warn_radius` | float | 10–22 | 15 |
| `warn_min_tier` | float | — | 30 |
| `warn_duration` | float | 0.8–2 | 1.2 |
| `warn_cooldown` | float | 1.5–5 | 2.5 |
| `warn_gives_direction` | bool | — | true |
| `cold_read_mult` | float | 1.15–1.6 | 1.3 |

### 3.4 `CombatTuning` — TUNABLES §5–6

*Regenerated 2026-09-29. The previous block left out `anim_cancel_window`, `invalid_target_penalty`, `forces_exposed`, `score`, `vs_lunge_window`.*

| Field | Type | Range | Default |
|---|---|---|---|
| `kill_range` | float | 2–3.2 | 2.5 |
| `kill_facing_cone` | float | 45–90 | 60 |
| `kill_anim_duration` | float | 1.2–1.8 | 1.4 |
| `anim_cancel_window` | float | — | 0 |
| `kill_validation_grace` | float | 0.2–0.6 | 0.35 |
| `kill_contest_window` | float | 0.25–0.6 | 0.4 |
| `kill_contest_stagger` | float | 1–2.5 | 1.5 |
| `invalid_target_penalty` | bool | — | true |
| `kill_corpse_spawn_delay` | float | — | 0.9 |
| `stun_range` | float | 2.5–4 | 3 |
| `stun_facing_cone` | float | 90–180 | 120 |
| `stun_min_tier` | float | — | 30 |
| `stun_freeze` | float | 3–6 | 4 |
| `stun_lockout` | float | 8–18 | 12 |
| `forces_exposed` | bool | — | true |
| `score` | float | 75–250 | 200 |
| `stun_anim_duration` | float | 0.5–1 | 0.7 |
| `stun_invalid_stagger` | float | 1.5–3.5 | 2 |
| `stun_invalid_suspicion` | float | 10–30 | 20 |
| `stun_cooldown` | float | 2–6 | 3 |
| `vs_lunge_window` | bool | — | true |
| `second_wind_reduction` | float | 2–6 | 4 |

### 3.5 `ContractTuning` — TUNABLES §7

*Regenerated 2026-09-29. The previous block named `respawn_min_dist_from_any` (no such field); left out `min_dist_from_any_player`, `suspicion`, `pursuit_duration`, `pursuit_sight_range`, `pursuit_sight_cone`, `pursuit_closecall_radius`.*

| Field | Type | Range | Default |
|---|---|---|---|
| `reassign_delay` | float | 2–5 | 3 |
| `anti_repeat_depth` | int | 1–3 | 1 |
| `min_cycle_length` | int | — | 3 |
| `repair_debounce` | float | 0.1–0.5 | 0.25 |
| `respawn_delay` | float | 3–8 | 5 |
| `respawn_min_dist_from_killer` | float | 25–60 | 40 |
| `min_dist_from_any_player` | float | 8–20 | 12 |
| `respawn_invuln` | float | 0.5–2 | 1 |
| `suspicion` | float | — | 0 |
| `spawn_point_count` | int | 6–8 | 6 |
| `pursuit_duration` | float | 8–16 | 10.72 |
| `pursuit_sight_range` | float | 16–40 | 25 |
| `pursuit_sight_cone` | float | 60–120 | 90 |
| `pursuit_closecall_radius` | float | 3–8 | 5 |

### 3.6 `CrowdTuning` — TUNABLES §9

*Regenerated 2026-09-29. The previous block left out `count_max`, `count_default_4p`, `count_default_5p`, `clones_per_persona_max`, `clone_local_radius`, `group_count`, `idle_duration_min`, `idle_duration_max`, `idle_group_size_min`, `idle_group_size_max`, `startle_sprint_interval`, `fade_time`, `anchor_arrive_radius`.*

| Field | Type | Range | Default |
|---|---|---|---|
| `count_min` | int | — | 60 |
| `count_max` | int | — | 90 |
| `count_default_6p` | int | 66–90 | 78 |
| `count_default_4p` | int | 60–78 | 66 |
| `count_default_5p` | int | 63–84 | 72 |
| `clones_per_persona_min` | int | — | 8 |
| `clones_per_persona_max` | int | — | 12 |
| `clone_local_min` | int | 1–4 | 2 |
| `clone_local_radius` | float | 15–40 | 25 |
| `director_interval` | float | 1–5 | 2 |
| `npc_speed_stroll` | float | — | 1.4 |
| `npc_speed_flee` | float | 4–6 | 5 |
| `group_size` | int | 3–6 | 4 |
| `group_count` | int | 3–6 | 4 |
| `group_spacing` | float | 1–2 | 1.3 |
| `idle_duration_min` | float | 5–15 | 8 |
| `idle_duration_max` | float | 15–40 | 25 |
| `idle_group_size_min` | int | — | 2 |
| `idle_group_size_max` | int | 4–6 | 4 |
| `startle_duration` | float | 3–6 | 4 |
| `startle_radius_violence` | float | 8–18 | 12 |
| `startle_radius_sprint` | float | 3–8 | 5 |
| `startle_sprint_interval` | float | 0.5–2 | 1 |
| `startle_propagation` | float | 0–0.7 | 0.4 |
| `gawk_duration` | float | 4–10 | 6 |
| `gawk_radius` | float | 6–15 | 10 |
| `gawk_max` | int | 4–10 | 6 |
| `corpse_lifetime` | float | 12–30 | 20 |
| `fade_time` | float | — | 1.5 |
| `bump_push` | float | 0.8–2 | 1.2 |
| `anchor_arrive_radius` | float | 0.6–2.5 | 1.2 |

### 3.7 `MatchTuning` — TUNABLES §10

*Regenerated 2026-09-29. The previous block named `lobby_min_players` (no such field); left out `min_players`, `max_players`.*

| Field | Type | Range | Default |
|---|---|---|---|
| `min_players` | int | — | 4 |
| `max_players` | int | — | 6 |
| `lobby_countdown` | float | 3–10 | 5 |
| `duration` | float | 420–600 | 480 |
| `finalphase_duration` | float | 20–60 | 30 |
| `finalphase_mult` | float | 1.5–3 | 2 |
| `finalphase_warning` | float | 3–10 | 5 |
| `results_duration` | float | 15–45 | 25 |
| `tick_rate` | float | — | 30 |

### 3.8 `ScoringTuning` — TUNABLES §11

*Regenerated 2026-09-29, first of the blocks, during the review of #238. The M0 block typed every
points field `int`, carried five pre-ADR-0013 prices (silent 100, patient 150, focus 100, stun 100,
reckless −50), called `variety` `variety_per_type`, and left out `patient_speed`, `halfseen`,
`escape`, `closecall`, `stun_invalid` and `death_penalty`.*

| Field | Type | Range | Default |
|---|---|---|---|
| `contract` | float | — | 100 |
| `silent` | float | 150–250 | 200 |
| `patient` | float | 75–150 | 100 |
| `patient_window` | float | 8–15 | 10 |
| `patient_speed` | float | 2.6–4.4 | 3.4 |
| `halfseen` | float | 25–100 | 50 |
| `masked` | float | 100–200 | 150 |
| `focus` | float | 100–200 | 150 |
| `focus_window` | float | 4–10 | 6 |
| `focus_break_grace` | float | 0.2–0.8 | 0.4 |
| `fromabove` | float | 75–150 | 100 |
| `fromabove_height` | float | 2.5–4.5 | 3 |
| `blended` | float | 150–250 | 200 |
| `poisoned` | float | 50–125 | 75 |
| `longhunt_1` | float | 25–100 | 50 |
| `longhunt_2` | float | 100–200 | 150 |
| `longhunt_t1` | float | 15–30 | 20 |
| `longhunt_t2` | float | 35–70 | 45 |
| `vendetta` | float | 75–150 | 100 |
| `variety` | float | 25–75 | 50 |
| `reckless` | float | −100–0 | 0 |
| `stun` | float | 75–250 | 200 |
| `escape` | float | 75–150 | 100 |
| `closecall` | float | 25–100 | 50 |
| `stun_invalid` | float | — | 0 |
| `death_penalty` | float | — | 0 |

### 3.9 `CameraTuning` — TUNABLES §12

*Regenerated 2026-09-29. The previous block named `fov_jog` (no such field); left out `fov_climb`, `fov_motion_reduced`, `occlusion_margin`.*

| Field | Type | Range | Default |
|---|---|---|---|
| `fov_blend` | float | 50–60 | 55 |
| `fov_stroll` | float | 55–65 | 60 |
| `fov_run` | float | 64–74 | 69 |
| `fov_climb` | float | 55–70 | 62 |
| `fov_sprint` | float | 68–80 | 72 |
| `fov_blend_rate` | float | 60–140 | 90 |
| `fov_motion_reduced` | float | 55–70 | 62 |
| `arm_length` | float | 2.2–3.2 | 2.6 |
| `arm_height` | float | 1.4–1.8 | 1.55 |
| `occlusion_margin` | float | 0.1–0.5 | 0.2 |
| `occlusion_pull_rate` | float | 8–20 | 12 |
| `occlusion_restore_rate` | float | 2–8 | 4 |
| `crowdscan_speed` | float | 0.3–0.7 | 0.45 |
| `crowdscan_fov` | float | 42–54 | 48 |

### 3.10 `NetTuning` — TUNABLES §13

*Regenerated 2026-09-29. The previous block named `server_tick_hz`, `interp_buffer_ms`, `lagcomp_min_ms`, `lagcomp_max_ms`, `lagcomp_history_ms` (no such field); left out `server_tick`, `interp_buffer`, `lagcomp_min`, `lagcomp_max`, `lagcomp_history`, `npc_rate_lod_radius`, `npc_rate_lod_hz`.*

| Field | Type | Range | Default |
|---|---|---|---|
| `server_tick` | float | — | 30 |
| `client_input_rate` | float | — | 60 |
| `snapshot_rate` | float | 15–30 | 30 |
| `interp_buffer` | float | 80–150 | 100 |
| `lagcomp_min` | float | — | 100 |
| `lagcomp_max` | float | 150–250 | 200 |
| `lagcomp_history` | float | 300–1000 | 500 |
| `reconcile_threshold` | float | 0.05–0.25 | 0.1 |
| `reconcile_smooth_time` | float | 0.08–0.25 | 0.12 |
| `input_buffer_size` | int | 16–64 | 32 |
| `bandwidth_budget_down` | float | 64–160 | 96 |
| `bandwidth_budget_up` | float | 8–32 | 16 |
| `timeout` | float | 5–20 | 10 |
| `quant_pos` | float | — | 0.01 |
| `quant_yaw` | float | — | 1 |
| `npc_cull_radius` | float | 50–90 | 70 |
| `npc_rate_lod_radius` | float | 25–70 | 45 |
| `npc_rate_lod_hz` | float | 5–30 | 10 |

### 3.11 `UiAudioTuning` — TUNABLES §15

*Regenerated 2026-09-29; the previous block already agreed with the resource.*

| Field | Type | Range | Default |
|---|---|---|---|
| `readability_target` | float | — | 0.5 |
| `scorefeed_duration` | float | 3–6 | 4 |
| `scorefeed_max_lines` | int | 3–6 | 4 |
| `scorefeed_stagger` | float | 0.08–0.25 | 0.12 |
| `tier_transition_time` | float | 0.15–0.4 | 0.25 |
| `damage_vignette_time` | float | — | 0.8 |
| `compass_duck` | float | — | −6 |
| `sting_duck` | float | — | −12 |
| `occlusion_lowpass` | float | 600–1600 | 900 |
| `footstep_radius_blend` | float | 3–6 | 4 |
| `footstep_radius_sprint` | float | 12–26 | 18 |

### 3.13 `AbilityTuning` — TUNABLES §8.1

*Regenerated 2026-09-29; the previous block already agreed with the resource.*

| Field | Type | Range | Default |
|---|---|---|---|
| `slots_active` | int | — | 2 |
| `slots_passive` | int | — | 1 |
| `lock_at_match_start` | bool | — | true |
| `global_cooldown` | float | 0.3–1 | 0.5 |
| `input_buffer` | float | 0.1–0.3 | 0.2 |

The ability-system settings that belong to no single ability. Added because §8's globals had no
home in the original §2 field list, and a documented `TUN-` value that lives nowhere in the data
breaks the "every number is a tunable" rule. The per-ability fields are `AbilityData`'s, one
resource per ability (§4).

### 3.12 `FeatureFlags`

*Regenerated 2026-09-29; the previous block already agreed with the resource.*

| Field | Type | Range | Default |
|---|---|---|---|
| `enable_second_face` | bool | — | false |

**Every flag's docstring names the story that removes it.** A flag with no removal story is
technical debt with a nice name, and the Definition of Done checks for it.

### 3.14 `PerfTuning` — TUNABLES §14

*This resource had no section here at all until 2026-09-29, although `TuningProfile` carries it as
`perf` beside the other thirteen.*

| Field | Type | Range | Default |
|---|---|---|---|
| `frame_budget` | float | — | 16.6 |
| `crowd_budget` | float | — | 2 |
| `net_budget` | float | — | 1.5 |
| `gameplay_budget` | float | — | 2 |
| `ui_budget` | float | — | 1 |
| `render_budget` | float | — | 9 |
| `server_tick_budget` | float | — | 8 |
| `crowd_lod_near` | float | 15–30 | 20 |
| `crowd_lod_mid` | float | 30–60 | 45 |
| `crowd_lod_far` | float | — | 70 |
| `crowd_repath_per_tick` | int | 1–10 | 3 |

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
| `effect_script` | `Script` | `extends AbilityEffect`. **The only per-ability code.** Set for `ABIL-CINDERFALL` (US-0067) and `ABIL-LUNGE` (US-0070); null for Second Face until US-0069, and for Whisperbolt, deferred. *Was: "null for the other three until US-0069/0070" — stale since US-0070.* **Stripped from `TuningProfile.serialise`** — effects are server-only and `scripts/systems/` is excluded from the client export, so a client is never handed the code by whatever it connected to. `tell_vfx` is stripped for the same reason. Neither is in `compute_hash`, so this cannot cause a handshake refusal |
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

Built in US-0046; `data/personas/*.tres`.

| Field | Type | Notes |
|---|---|---|
| `id` | `StringName` | `PERSONA-*` |
| `display_key` | `StringName` | |
| `silhouette` | enum | `LOW_BROAD` · `FLOOR_TRIANGLE` · `TALL_THIN` · `ROUND_MID`. **The four MVP personas must be mutually distinct** |
| `stand_height` | `float` | ART_BIBLE §6.1's drawn height. **Added in US-0046, not in the original table.** Deliberately *not* the collider: every persona shares one 1.8 m capsule so no clone is findable by walking into it, and these differ so none is findable by looking — the same anonymity rule from opposite ends |
| `width_scale` | `float` | Horizontal scale of the drawn capsule. Vetraio's ×1.4 and Lucerna's ×0.8 *are* their silhouette claim. Added in US-0046 |
| `mesh` | `PackedScene` | **Null on all four, and expected to stay so.** IP_GUARDRAILS §4 forbids a downloaded model entering this repository, so `PersonaBody` builds §6.1's constructions from primitives at runtime instead |
| `animation_library` | `AnimationLibrary` | **Null on all four.** There are no animation clips in this project on either rig, which is what leaves parity layer 2's library half reporting rather than asserting |
| `identity_hue` | `Color` | Reserved by the colour-language law. Asserted mutually distinct |
| `anonymous_clip_names` | `PackedStringArray` | **The clone-parity set.** Every entry must exist in the clone's library. The canonical fourteen live as `PersonaData.PARITY_SET` — one `const`, not four copies, because ANIMATION_SPEC §7.1's table has a tick in every cell and four copies is four places to drift invisibly |

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
gain_open = 0.0
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
- [x] The four `PersonaData` have four distinct `silhouette` values. Asserted by `test_clone_animation_parity.gd`, US-0046, along with four distinct identity hues.
- [ ] Every `FeatureFlags` field names its removal story.
- [ ] Every `display_key` resolves in `data/strings/en.csv`.

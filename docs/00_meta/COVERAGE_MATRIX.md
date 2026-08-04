---
id: DOC-COVERAGE-MATRIX
title: Coverage Matrix
version: 0.1.0
status: draft
owner: Documentation Architect
last_updated: 2026-08-03
depends_on: [DOC-GLOSSARY, BACKLOG-ROADMAP, BIBLE-TEST-PLAN]
---

# Coverage Matrix

> **Every `SYS-` ID mapped to its design chapter, its technical chapter, its stories and its
> tests. Any row with a gap is a documentation bug**, not a note for later — a system with no
> TDD chapter cannot be implemented consistently, and one with no test cannot be verified.
>
> This document is regenerable. `tools/coverage_check.gd` reproduces it from the corpus and
> fails CI on any gap in a required column.

---

## 1. The matrix

**34 systems.** Columns marked `—` are justified in §2; every other cell is populated.

| # | `SYS-` ID | GDD | TDD | Bible | Stories | Key tests |
|---|---|---|---|---|---|---|
| 1 | `SYS-TUNING` | — ⁽ᵃ⁾ | 05 §3–4 | DATA_SCHEMA | US-0007, US-0008 | `test_tuning_ranges`, `test_tuning_docs_sync`, `test_tuning_reload_rejects_invalid` |
| 2 | `SYS-EVENTBUS` | — ⁽ᵃ⁾ | 01 §2, 11 §1 | SIGNAL_AND_EVENT_BUS | US-0009 | `test_eventbus_is_stateless`, `test_eventbus_signals_documented` |
| 3 | `SYS-PROFILE` | — ⁽ᵃ⁾ | 05 §4.3 | — ⁽ᵇ⁾ | US-0089 | `test_profile_store_is_noop` |
| 4 | `SYS-MAP` | 05 | 05 §3.5 | ART_BIBLE §7 | US-0012 | `test_map_metrics`, `test_map_dead_ends`, `test_navmesh_coverage` |
| 5 | `SYS-PAWN` | 02 §2–3 | 06 | ANIMATION_SPEC | US-0013–0015, US-0028, US-0032 | `test_pawn_transitions`, `test_pawn_determinism`, `test_slow_always_available` |
| 6 | `SYS-INPUT` | 02 §1 | 06 §3 | — ⁽ᵇ⁾ | US-0016, US-0084 | `test_cli_args`, `test_pawn_determinism_grep` |
| 7 | `SYS-TRAVERSAL` | 02 §7 | 06 §4 | ANIMATION_SPEC §3.2 | US-0017–0020 | `test_traversal_resolution`, `test_traversal_forgiveness`, `test_probes_mask_world_only` |
| 8 | `SYS-CAMERA` | 02 §4 | 01 §3.2 | UI_UX_SPEC | US-0021–0024, US-0084 | `test_camera_fov_ladder`, `test_feel_latency` |
| 9 | `SYS-NET-REPLICATION` | — ⁽ᵃ⁾ | 04 §2–3, §5 | NETWORK_PROTOCOL | US-0025, US-0026, US-0029–0031, US-0037 | `test_no_client_authority`, `test_snapshot_size`, `test_crowd_bandwidth` |
| 10 | `SYS-NET-PREDICTION` | — ⁽ᵃ⁾ | 04 §4 | NETWORK_PROTOCOL | US-0032–0034, US-0038 | `test_prediction_reconciliation`, `test_reconcile_snaps_sim_blends_visual` |
| 11 | `SYS-NET-LAGCOMP` | 03 §10 | 04 §8 | NETWORK_PROTOCOL §7 | US-0035, US-0060 | `test_lagcomp_rewind`, `test_lagcomp_no_exploit`, `test_no_client_time_in_kill` |
| 12 | `SYS-CROWD` | 03 §5–6 | 08 | ANIMATION_SPEC §7 | US-0039, US-0041–0047 | `test_crowd_perf`, `test_clone_local_min`, `test_spatial_hash_correctness` |
| 13 | `SYS-NPC-AI` | 03 §6 | 08 §3 | — ⁽ᵇ⁾ | US-0040, US-0044 | `test_npc_transition_table`, `test_npc_no_alloc`, `test_startle_propagation` |
| 14 | `SYS-CORPSE` | 03 §6.4 | 08 §3.3 | — ⁽ᵇ⁾ | US-0044 | `test_gawk_pocket_preservation`, `test_gawk_corpse_phases` |
| 15 | `SYS-CONTRACT` | 03 §7 | 10 §5 | — ⁽ᵇ⁾ | US-0049, US-0050 | `test_contract_cycle_fuzz`, `test_contract_never_self`, `test_contract_repair_same_tick` |
| 16 | `SYS-SUSPICION` | 03 §3 | 07 §2 | — ⁽ᵇ⁾ | US-0051, US-0052 | `test_suspicion_math`, `test_suspicion_tapsprint`, `test_suspicion_hysteresis` |
| 17 | `SYS-BLEND` | 03 §4 | 07 §3 | — ⁽ᵇ⁾ | US-0053, US-0054 | `test_blend_revalidated`, `test_blend_grace`, `test_blend_prop_capacity` |
| 18 | `SYS-DETECTION` | 03 §2, §9 | 07 §4 | — ⁽ᵇ⁾ | US-0055, US-0056, US-0059 | `test_render_state_per_observer`, `test_los_ignores_npcs`, `test_warning_tier_gate` |
| 19 | `SYS-COMPASS` | 03 §8 | 07 §4.5, 11 §2.2 | UI_UX_SPEC §3 | US-0057, US-0058, US-0072 | `test_compass_curve`, `test_compass_vm`, `test_lock_through_crowd` |
| 20 | `SYS-KILL` | 03 §10 | 10 §3 | — ⁽ᵇ⁾ | US-0060 | `test_kill_contract_only`, `test_kill_contest`, `test_kill_facing_cone` |
| 21 | `SYS-STUN` | 03 §10 | 10 §4 | — ⁽ᵇ⁾ | US-0061 | `test_stun_range_exceeds_kill`, `test_stun_tier_gate`, `test_stun_invalid` |
| 22 | `SYS-SPAWN` | 05 §2.7 | 10 §6 | — ⁽ᵇ⁾ | US-0062 | `test_spawn_constraints`, `test_spawn_anticamp` |
| 23 | `SYS-SCORE` | 07 §3 | 10 §1–2 | — ⁽ᵇ⁾ | US-0064, US-0065 | `test_score_fold`, `test_score_no_direct_mutation`, `test_multiplier_frozen` |
| 24 | `SYS-ABILITY` | 04 | 09 | DATA_SCHEMA §4.1 | US-0066–0070 | `test_ability_validation`, `test_ability_has_tell`, `test_cinderfall_self_block` |
| 25 | `SYS-LOADOUT` | 04 §5 | 09 §7 | — ⁽ᵇ⁾ | US-0071, US-0078 | `test_loadout_lock`, `test_secondwind_freeze_unchanged` |
| 26 | `SYS-HUD` | 06 §2 | 11 §3 | UI_UX_SPEC | US-0072, US-0073, US-0085 | `test_crosshair_truth`, `test_tier_monochrome`, `test_hud_readability` |
| 27 | `SYS-SCOREFEED` | 06 §3 | 11 §2.3 | UI_UX_SPEC §5 | US-0074 | `test_scorefeed_stagger`, `test_scorefeed_cap` |
| 28 | `SYS-AUDIO` | 06 §5–6 | 11 §4 | AUDIO_BIBLE | US-0075, US-0083 | `test_prey_sting_nonpositional`, `test_footstep_parity` |
| 29 | `SYS-MUSIC` | 06 §7 | 11 §4 | AUDIO_BIBLE §10 | US-0076 | Source scan: no other-player reference in the music controller |
| 30 | `SYS-RESULTS` | 06 §3.4 | 10 §7, 11 §5 | — ⁽ᵇ⁾ | US-0077 | `test_results_matches_scoreboard` |
| 31 | `SYS-LOBBY` | 06 §4 | 11 §5 | UI_UX_SPEC §10 | US-0078 | Loadouts absent from `NET-S2C-LOBBY-STATE` |
| 32 | `SYS-MATCH` | 07 §1 | 10 §6 | — ⁽ᵇ⁾ | US-0079 | `test_finalphase_boundary` |
| 33 | `SYS-TELEMETRY` | 07 §8 | 12 §9 | — ⁽ᵇ⁾ | US-0080, US-0086 | `test_refold_historical` |
| 34 | `SYS-DEBUG` | — ⁽ᵃ⁾ | 12 §5 | — ⁽ᵇ⁾ | US-0081 | `test_debug_stripped` |

**Legend**
⁽ᵃ⁾ No GDD chapter — the system is purely technical and has no player-facing design surface (§2.1).
⁽ᵇ⁾ No dedicated Bible document — the Bible covers cross-cutting concerns, not per-system specs (§2.2).

---

## 2. Justified gaps

A `—` is only acceptable with a reason. These are the reasons.

### 2.1 Systems with no GDD chapter

| System | Why |
|---|---|
| `SYS-TUNING` | Infrastructure. Its *values* are the whole of TUNABLES.md; the loading mechanism has no player-facing surface |
| `SYS-EVENTBUS` | Pure plumbing between layers |
| `SYS-PROFILE` | A stubbed seam with no MVP behaviour. Its one player-visible consequence — rebinds not persisting — is stated in GDD-02 §1.4 |
| `SYS-NET-REPLICATION`, `SYS-NET-PREDICTION` | Netcode has no design surface *by intent*. Where it does — lag compensation's "killed behind cover" — that system (`SYS-NET-LAGCOMP`) **does** have a GDD reference |
| `SYS-DEBUG` | Stripped from release; players never see it |

### 2.2 Systems with no Bible document

The Bible covers **cross-cutting concerns** — naming, coding standards, data schemas, protocols,
animation, art, audio, UI, testing, performance, risk. It is deliberately not a per-system
reference; that is the TDD's job. A system appears in the Bible only where it has a cross-cutting
artefact (a schema, a protocol table, a parity constraint).

### 2.3 What has no justified gap

**Every system has at least one TDD chapter, at least one story, and at least one test.** Those
three columns have no `—` anywhere, and CI enforces it.

---

## 3. Coverage by milestone

| Milestone | Systems first implemented | Count |
|---|---|---|
| **M0** | `SYS-TUNING`, `SYS-EVENTBUS`, `SYS-PROFILE`, `SYS-MAP` | 4 |
| **M1** | `SYS-PAWN`, `SYS-INPUT`, `SYS-TRAVERSAL`, `SYS-CAMERA` | 4 |
| **M2** | `SYS-NET-REPLICATION`, `SYS-NET-PREDICTION`, `SYS-NET-LAGCOMP` | 3 |
| **M3** | `SYS-CROWD`, `SYS-NPC-AI`, `SYS-CORPSE` | 3 |
| **M4** | `SYS-CONTRACT`, `SYS-SUSPICION`, `SYS-BLEND`, `SYS-DETECTION`, `SYS-COMPASS`, `SYS-KILL`, `SYS-STUN`, `SYS-SPAWN` | **8** |
| **M5** | `SYS-SCORE`, `SYS-ABILITY`, `SYS-LOADOUT`, `SYS-HUD`, `SYS-SCOREFEED`, `SYS-AUDIO`, `SYS-MUSIC`, `SYS-RESULTS` | 8 |
| **M6** | `SYS-LOBBY`, `SYS-MATCH`, `SYS-TELEMETRY`, `SYS-DEBUG` | 4 |

**M4 carries eight systems — the largest single milestone**, and correctly so: it is the point at
which the game exists. Everything before it is scaffolding for that question.

---

## 4. Design-law coverage

The six design laws are not systems, but each must be *enforced* somewhere. An unenforced law is
a slogan.

| Law | Enforced by | Test |
|---|---|---|
| **1. Speed is spent anonymity** | The suspicion ladder; decay only at or below stroll | `test_suspicion_math`, `test_suspicion_tapsprint` |
| **2. The crowd is a mechanic** | Blend validity, open-ground suspicion, startle, gawk, LOS all query the live crowd | `test_blend_revalidated`, `test_startle_propagation` |
| **3. Every ability has a tell** | **The `AbilityData` schema** — two channels, ≥ 1 environmental or audio | `test_ability_has_tell` |
| **4. Patience is the strongest strategy** | The bonus hierarchy, asserted as a tuning invariant | `test_tuning_ranges` §17.18, `test_score_fold` |
| **5. The prey must have teeth** | Stun range exceeds kill range, asserted as an invariant | `test_stun_range_exceeds_kill`, `test_stun_tier_gate` |
| **6. Uncertainty is authored** | Deterministic compass wobble, hysteresis, published pulse curve | `test_compass_curve`, `test_suspicion_hysteresis`, `test_compass_no_wobble_clientside` |

**Law 3 is enforced by a data schema rather than by review**, which is the strongest form
available: an ability that fails it cannot load.

---

## 5. Permanent-absence coverage

Things the design forbids need enforcement too, or they reappear.

| Forbidden | Enforced by |
|---|---|
| Minimap | No positional data in any payload beyond bearing + distance bucket (`test_payload_omissions`) |
| Global kill feed | `NET-S2C-KILL-RESULT` sent only to killer and victim |
| Nameplates | No identity field in `remote_pawns[]` |
| Hit-direction indicator | `NET-S2C-PREY-WARNING` has exactly one field; the signal has zero parameters (`test_warning_payload_empty`, `test_prey_warning_signal_arity`) |
| Kill-cam | No positional or temporal data in `NET-S2C-KILL-RESULT` beyond killer, victim, tick |
| Cosmetics | No per-instance variation on clones (`test_clone_animation_parity`) |
| Contract's persona before a lock | Not in any payload (`test_payload_omissions`) |
| A ninth autoload | `test_autoload_inventory` |
| Franchise terminology | `ip-guard` CI job, hard failure |

---

## 6. Known open items

Not gaps — items deliberately open, tracked to a milestone.

| Item | Status | Due |
|---|---|---|
| `SCORE-POISONED` implemented but dormant — no MVP ability triggers it | By design (ASM-0016) | Post-M6 |
| `SCORE-VARIETY` behaves as a flat uplift at ~1 kill per life | Measured finding; one-line fix identified, gated on telemetry | M5 |
| Upstream bandwidth misses budget by ~2 kbit/s | Test written to fail until coalescing lands | M2 |
| Crowd budget margin is 0.10 ms | Fallback ladder documented | M3 |
| Balance model predicts ~90 % patient win rate vs a ~60 % target | Deliberately not pre-tuned; lever list ordered | M6 |
| Player positions replicated without LOS culling | Accepted; rejection reasoned | Post-M6 |
| `ANIM-BLENDWALK-LOOP`'s 1.15 s stride cycle is gameplay-critical but lives in an animation | Flagged; may warrant promotion to a tunable | M3 |

---

## 7. Regeneration and enforcement

```gdscript
## tools/coverage_check.gd — regenerates §1 from the corpus and fails on a gap.
##
## For each SYS- ID found anywhere in docs/ or scripts/:
##   1. Find its GDD chapter      (grep 10_gdd/)
##   2. Find its TDD chapter      (grep 20_tdd/ "Implements:" lines)
##   3. Find its stories          (grep 40_backlog/stories/ "Systems" rows)
##   4. Find its tests            (grep test/ and TDD "Test hooks" tables)
##   5. FAIL if TDD, stories or tests is empty
##   6. FAIL if the GDD column is empty AND the ID is not in the §2.1 justified list
```

| Rule | |
|---|---|
| Run at every milestone exit | A DoD milestone item |
| A new `SYS-` ID must appear here in the same commit | A DoD item |
| The TDD, stories and tests columns may **never** be empty | CI failure |
| A GDD gap requires a §2.1 entry | CI failure otherwise |

---

## 8. Acceptance criteria

- [ ] Every `SYS-` ID in the corpus appears in §1.
- [ ] No row has an empty TDD, Stories or Tests column.
- [ ] Every `—` in the GDD column has a justification in §2.1.
- [ ] Every design law in §4 has a named enforcing test.
- [ ] Every permanent absence in §5 has a named enforcement mechanism.
- [ ] `tools/coverage_check.gd` regenerates §1 and passes.
- [ ] The matrix is updated in the same commit as any new `SYS-` ID.

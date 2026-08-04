---
id: US-0007
title: TuningProfile and all sub-resources
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-04
depends_on: [ADR-0005, TDD-05-DATA, BIBLE-DATA-SCHEMA, TUN-INDEX]
---

# US-0007 — TuningProfile and all sub-resources

| | |
|---|---|
| **Milestone** | M0 |
| **Epic** | `EPIC-DATA` |
| **Systems** | `SYS-TUNING` |
| **Estimate** | **L** |
| **Depends on** | US-0006 |

## Description

Every Tuning resource class and every .tres in `data/tuning/default/` — all 269 values from
TUNABLES.md, with ranges, docstrings and rationales.

Large and unglamorous, and it lands at M0 because retrofitting 269 constants across 40 files is
a multi-day refactor with a long tail of misses.

## Acceptance criteria

- [x] All 11 Tuning classes plus FeatureFlags, AbilityData and PassiveData exist. *(Plus `PerfTuning` and `AbilityTuning`, added because TUNABLES §14 and §8.1 belonged to no class.)*
- [x] Every field name is the mechanical transform of its TUN- ID.
- [x] Every export has an export_range matching the documented Range column.
- [x] Every export docstring ends with its TUN- ID as the last token.
- [x] Every export docstring carries the one-line rationale from TUNABLES.md.
- [x] `data/tuning/default/*.tres` populated with every default, including `abilities/` and `passives/`.
- [x] `validate()` implements all 20 cross-field invariants from TUNABLES §17 — all 20 now assert against real data.
- [x] `compute_hash()` is stable across files with identical values.
- [x] serialise/deserialise round-trip field-for-field.

## Test notes

`test_tuning_ranges.gd` asserts every field in range plus all 20 invariants.
`test_tuning_serialise_roundtrip.gd`. `test_tuning_hash_stable.gd`.

## Notes

Never reorder exported properties once merged — it rewrites every .tres and produces
unreviewable diffs.

> **Done 2026-08-04.** 264 of 269 tunables are live across 14 sub-resources; the other
> five are `AbilityData` fields carried per-ability in
> `data/tuning/default/abilities/*.tres`. All 20 cross-field invariants assert against
> real data — 11 and 12 were reported as *"cannot check"* until `AbilityData` existed
> and are now live, which is what `test_tuning_ranges` was written to force.
>
> Two classes were added beyond the story's list, both because a documented `TUN-`
> value had no home: `PerfTuning` (§14, needed by invariant 20) and `AbilityTuning`
> (§8.1's five globals).
>
> Four tunables were added: `TUN-<ABILITY>-TELL-AUDIO-RADIUS` for each ability. Three
> were promoted from bare prose numbers in `10_gdd/04_abilities.md`, which TUNABLES
> §1.1 forbids; Whisperbolt's had no number anywhere and was set to 30 m with the
> owner. Without them design law 3 was unenforceable for Second Face and Whisperbolt,
> which have no startle radius — `test_ability_has_tell.gd` now asserts it.
>
> One row is deliberately not a field: `TUN-SUSPICION-GAIN-WHISPERBOLT-WINDUP`
> documents the *absence* of a gain, with value, unit and range all em dashes.

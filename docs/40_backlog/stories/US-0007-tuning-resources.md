---
id: US-0007
title: TuningProfile and all sub-resources
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
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

Every Tuning resource class and every .tres in `data/tuning/default/` — all ~180 values from
TUNABLES.md, with ranges, docstrings and rationales.

Large and unglamorous, and it lands at M0 because retrofitting ~180 constants across 40 files is
a multi-day refactor with a long tail of misses.

## Acceptance criteria

- [ ] All 11 Tuning classes plus FeatureFlags, AbilityData and PassiveData exist.
- [ ] Every field name is the mechanical transform of its TUN- ID.
- [ ] Every export has an export_range matching the documented Range column.
- [ ] Every export docstring ends with its TUN- ID as the last token.
- [ ] Every export docstring carries the one-line rationale from TUNABLES.md.
- [ ] `data/tuning/default/*.tres` populated with every default.
- [ ] `validate()` implements all 20 cross-field invariants from TUNABLES section 17.
- [ ] `compute_hash()` is stable across files with identical values.
- [ ] serialise/deserialise round-trip field-for-field.

## Test notes

`test_tuning_ranges.gd` asserts every field in range plus all 20 invariants.
`test_tuning_serialise_roundtrip.gd`. `test_tuning_hash_stable.gd`.

## Notes

Never reorder exported properties once merged — it rewrites every .tres and produces
unreviewable diffs.

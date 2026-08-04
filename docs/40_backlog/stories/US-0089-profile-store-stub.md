---
id: US-0089
title: IProfileStore stub
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-05-DATA, DOC-SCOPE-FENCE]
---

# US-0089 — IProfileStore stub

| | |
|---|---|
| **Milestone** | M0 |
| **Epic** | `EPIC-DATA` |
| **Systems** | `SYS-PROFILE` |
| **Estimate** | S |
| **Depends on** | US-0010 |

## Description

The persistence seam, stubbed. There is no persistence in MVP — no accounts, no progression, no
saved settings — but the interface exists so that adding a real store later is a single class
rather than a hunt through call sites.

Implemented as a NO-OP that returns defaults and discards writes, exposing **the full method set
a real store would need** rather than a minimal stub (ASM-0026).

## Acceptance criteria

- [ ] `IProfileStore` declares the full eventual surface: input bindings, audio bus levels, accessibility settings, persona and loadout preference.
- [ ] `MemoryProfileStore` implements it, returning defaults and discarding writes.
- [ ] NO file I/O and NO network — a stub that touches disk is not a stub.
- [ ] Call sites are written as if persistence were real, so swapping the implementation changes one line.
- [ ] Rebinds and options apply for the session and are documented as not persisting.
- [ ] Nothing in `scripts/systems/` depends on it — it is a presentation and settings concern.

## Test notes

`test_profile_store_is_noop.gd` asserts a write followed by a read returns the default, and that
no file handle is opened.

## Notes

A no-op implementing the full surface is more useful than a minimal one, because it forces the
call sites to be written correctly now.

Rebinds not persisting across sessions is a known, accepted MVP limitation, and the first thing a
real profile store fixes. It is stated in GDD-02 §1.4 so playtesters are not surprised by it.

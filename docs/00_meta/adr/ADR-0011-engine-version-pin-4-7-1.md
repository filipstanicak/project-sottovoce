---
id: ADR-0011
title: Engine version pin — Godot 4.7.1 stable
version: 1.0.0
status: accepted
owner: Technical Director
last_updated: 2026-08-04
depends_on: [ADR-0001]
supersedes: ADR-0001
---

# ADR-0011 — Engine version pin: Godot 4.7.1 stable

## Context

[ADR-0001](ADR-0001-engine-and-language.md) selected **Godot 4.5 stable** with GDScript, and
established that the version is pinned in `.godot-version` so that *"engine upgrades become a
deliberate, tested operation with an ADR, not background drift."*

At the start of M0 the available engine is **`4.7.1.stable.official.a13da4feb`**. Godot 4.5 was
the current stable release when ADR-0001 was written; 4.7.1 is now.

This ADR exists because ADR-0001's own rule forbids absorbing the change silently. **Pinning a
different version than the one an accepted ADR specifies is exactly the drift that rule
prohibits** — even when the new version is obviously better.

Nothing else in ADR-0001 changes. The language decision (GDScript for gameplay, C# only for a
profiled hotspot with an ADR), the renderer (Forward+), and the rejection of Unity, Unreal and a
custom engine all stand unaltered and are restated in §3 so this document is self-contained.

## Options considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Pin 4.7.1 stable, supersede ADR-0001** | Uses what is installed. Two minor releases of fixes ahead, including in the high-level multiplayer API and navigation — our two highest-risk areas (`RISK-NETCODE`, `RISK-CROWD-PERF`). Longer support runway before the next forced upgrade. | ~15 documentation references to update. The multiplayer API changed between 4.5 and 4.7, so TDD-04's assumptions need verifying rather than assuming. | **Chosen** |
| Install 4.5 stable to match the corpus | Zero documentation churn. The corpus's netcode and crowd chapters were written against 4.5 API surface. | Deliberately adopting a two-versions-old engine at the *start* of a project, for documentation convenience. Forgoes fixes in precisely the subsystems we have flagged as highest risk. A future upgrade would cost this same ADR plus a migration. | Rejected |
| Pin 4.7.1 but edit ADR-0001 in place | No new document. | **Violates the immutability rule** in [`../DECISION_LOG.md`](../DECISION_LOG.md) §2.1 and [`../../30_bible/NAMING_AND_IDS.md`](../../30_bible/NAMING_AND_IDS.md) §2. A superseded ADR is kept forever so the reasoning at the time stays legible. | Rejected |

## Decision

**Pin `4.7.1.stable.official.a13da4feb` in `.godot-version`.** CI installs exactly this build.

ADR-0001 is marked `superseded` and retained. Its language, renderer and
alternatives-considered reasoning are carried forward unchanged in §3 below.

## Consequences

### Positive
- The engine matches what is installed, so no one develops against a version CI does not use.
- Fixes in the high-level multiplayer API and `NavigationAgent3D` land in the two subsystems
  carrying our highest-probability risks.
- The version pin is recorded through the process the corpus specifies, which is a working
  demonstration that the process is usable rather than decorative.

### Negative — stated honestly
- **TDD chapter 4's multiplayer assumptions were written against 4.5.** Godot changed parts of
  the high-level multiplayer API across 4.6 and 4.7. TDD-04 deliberately specifies a
  conservative subset, so it is expected to survive — but *expected* is not *verified*, and
  this must be checked against 4.7 documentation during M2 rather than assumed. Recorded as a
  compliance item below.
- `NavigationAgent3D` behaviour may differ from what TDD-08 assumes. First measurable at M3.
- ~15 documentation references require updating. Mechanical, done in the same commit as this ADR.
- Godot 4.7 is newer and therefore less battle-tested than 4.5 in community usage. Accepted:
  the subsystems we depend on most are the ones that received the most fixes.

### Neutral / follow-on
- `gdtoolkit` is at 4.5.0. **This is a coincidence of version numbering, not a dependency** —
  gdtoolkit's version does not track the engine's. It is verified working against 4.7.1 output
  and requires no change.
- The next engine upgrade requires another ADR superseding this one.

## Restated from ADR-0001, unchanged

- **Language:** GDScript for all gameplay. C# only for a *profiled* hotspot, with its own ADR.
  The default answer to "should this be C#?" remains **no**.
- **Renderer:** Forward+.
- **Typed GDScript everywhere**, enforced by `test_typing_coverage.gd`.
- **The crowd budget is addressed architecturally**, not by language choice: LOD by distance,
  update-rate reduction, flat state machines, server-side simulation. If 90 NPCs cannot hit
  2.0 ms after those measures, re-examine the measures before the language.
- Unity, Unreal, a custom engine and C#-first were considered and rejected; the reasoning in
  ADR-0001 §Options stands.

## Compliance

- [ ] `.godot-version` contains `4.7.1.stable.official.a13da4feb`.
- [ ] CI installs exactly that build; `test_import_time.gd` runs against it.
- [ ] No documentation references Godot 4.5 as the target engine.
- [ ] ADR-0001 is marked `superseded` and links here.
- [ ] **TDD-04 §3 and §6 verified against Godot 4.7 multiplayer API documentation before M2 exit.**
- [ ] **TDD-08 §7 navmesh and agent assumptions verified against 4.7 before M3 exit.**
- [ ] `project.godot` sets `rendering/renderer/rendering_method = "forward_plus"`.
- [ ] No `.cs` file exists without an ADR naming the profiled hotspot.

## Revisit trigger

Reopen if either:

1. A 4.7 API change makes the conservative multiplayer subset in TDD-04 unworkable, in which
   case the choice is between adapting the netcode design and pinning back to 4.6; or
2. `test_crowd_perf.gd` fails at M3 by a margin the fallback ladder cannot close, which would
   reopen ADR-0001's language decision rather than this version pin.

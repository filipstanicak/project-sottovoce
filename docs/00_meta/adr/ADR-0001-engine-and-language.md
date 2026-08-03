---
id: ADR-0001
title: Engine and language selection
version: 1.0.0
status: accepted
owner: Technical Director
last_updated: 2026-08-03
depends_on: [DOC-SCOPE-FENCE]
supersedes: none
---

# ADR-0001 — Engine and language selection

## Context

Project Sottovoce is a 4–6 player, server-authoritative, networked 3D game with a crowd of
60–90 animated NPCs, built by a small indie team with no dedicated engine programmer. The
binding constraints are:

- **Team size.** Nobody can be spared to maintain engine-level infrastructure.
- **Crowd cost.** 90 animated agents at ≤ 2.0 ms/frame (`TUN-PERF-CROWD-BUDGET`) is the
  single hardest technical requirement in the project.
- **Netcode.** Server-authoritative with client prediction and lag compensation. This is
  the second hardest.
- **Iteration speed.** The design thesis (restraint, patience, the feel of a crowd) can
  only be validated by playing it. Anything that lengthens the edit→playtest loop is a
  direct cost to design quality.
- **Scope fence.** No console ports, no mobile, desktop Windows + Linux only.

The interesting tension: GDScript is fast to iterate in and slow to execute; the crowd
budget is the one place where execution speed might genuinely bind. An engine choice that
optimises for the crowd at the cost of iteration speed would be optimising the wrong thing —
but only if the crowd budget is actually reachable in GDScript, which is not obvious.

## Options considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Godot 4.5, GDScript-first** | Fastest iteration loop in the category; built-in high-level multiplayer API and `ENetMultiplayerPeer`; headless export is a first-class target; scene/resource model maps cleanly onto the data-driven design this project needs; small binary; no licence cost or revenue share. | GDScript is ~10–40× slower than C++ on tight numeric loops; the crowd budget may require mitigation; smaller ecosystem of networking examples than Unity/Unreal. | **Chosen** |
| Godot 4.5, C#-first | 3–10× faster than GDScript on hot paths; static typing catches more at compile time. | Slower iteration (build step on every change); Godot's C# tooling is less mature than its GDScript tooling; export complexity increases; no benefit until a hotspot is *proven*. | Rejected as a default; permitted per-hotspot |
| Unity 6 | Large ecosystem; DOTS/ECS would trivially handle 90 NPCs; mature netcode packages (NGO, Fish-Net). | Licensing history creates business risk for a small team; DOTS is a second programming model to learn; heavier editor; the crowd advantage is only realised if the whole project adopts ECS, which is a large architectural commitment for one subsystem. | Rejected |
| Unreal 5 | Best-in-class networking out of the box (replication, prediction); crowds via Mass Entity. | Overwhelming for a 4-person team; C++ iteration loop is slow; Blueprint/C++ split adds process overhead; engine size and build times are a daily tax; 5 % revenue share. | Rejected |
| Custom / bevy / raylib | Full control. | Everything the engines give free would have to be built. Disqualifying at this team size. | Rejected |

## Decision

**Use Godot 4.5 stable with the Forward+ renderer. Write all gameplay in GDScript.**

Introduce C# only for a specific, profiled hotspot, and only with a follow-on ADR that
records the measurement that justified it. The default answer to "should this be C#?" is
**no**.

The crowd budget is addressed *architecturally* rather than by language choice: LOD by
distance (`TUN-PERF-CROWD-LOD-NEAR/MID/FAR`), update-rate reduction, flat state machines
rather than per-agent trees (ADR-0003), and server-side simulation with the client doing
interpolation only (ADR-0007). If 90 NPCs in GDScript cannot hit 2.0 ms after those
measures, the correct response is to re-examine the measures before re-examining the
language.

## Consequences

### Positive
- Edit-and-run iteration in under a second. For a game whose quality is dominated by feel,
  this is worth more than any constant-factor runtime win.
- `ENetMultiplayerPeer` and the high-level multiplayer API give us peer management,
  reliability classes and RPC plumbing without writing a transport.
- Headless server export is a supported target, not a workaround.
- The `Resource`/`.tres` model directly supports ADR-0005's no-hardcoded-constants rule.
- Typed GDScript (`var x: float`) recovers a meaningful part of the performance gap and all
  of the readability benefit. Mandated in
  [`../../30_bible/CODING_STANDARDS.md`](../../30_bible/CODING_STANDARDS.md).

### Negative — stated honestly
- **The crowd budget is a real risk, not a solved problem.** It is tracked as
  `RISK-CROWD-PERF` with a probability of *medium*. If it fails, the fallback ladder is:
  (1) reduce `TUN-CROWD-COUNT-MAX`, (2) coarsen LOD tiers, (3) move the NPC steering
  update to C#. Reducing crowd count is the *worst* option because crowd density is the
  game's substrate — it is listed first only because it is the fastest lever to test with.
- GDScript's lack of compile-time checking means whole classes of error surface at runtime.
  Mitigated by mandatory typing, `gdlint` in CI, and a real unit-test suite.
- Fewer worked examples of server-authoritative prediction in Godot than in Unity/Unreal.
  We will be reading engine source. Budget for it.
- Godot 4.5's multiplayer API has rough edges around authority transfer and scene
  replication. TDD chapter 4 specifies a deliberately conservative subset.

### Neutral / follow-on
- Pin the exact Godot version in `.godot-version` and in CI. Engine upgrades become a
  deliberate, tested operation with an ADR, not a background drift.
- Export templates for the pinned version are cached in CI.

## Compliance

A reviewer can check this ADR mechanically:

- [ ] `.godot-version` exists and matches the version CI installs.
- [ ] No `.cs` file exists without a corresponding ADR naming the profiled hotspot.
- [ ] `project.godot` sets `rendering/renderer/rendering_method = "forward_plus"`.
- [ ] `gdlint` passes with the project's rule set, including the type-annotation rule.
- [ ] No `csproj`/`sln` in the repository root.

## Revisit trigger

Reopen this ADR if **either**:

1. After implementing all four architectural mitigations, 90 NPCs on the reference machine
   exceed `TUN-PERF-CROWD-BUDGET` (2.0 ms) by more than 50 %; or
2. A Godot release introduces a breaking change to the high-level multiplayer API that
   would cost more to absorb than the netcode is worth.

---
id: US-0039
title: NPC pool and seeded roster
version: 1.1.0
status: done
owner: Technical Director
last_updated: 2026-08-16
depends_on: [ADR-0007, TDD-08-CROWD]
---

# US-0039 — NPC pool and seeded roster

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-CROWD-CORE` |
| **Systems** | `SYS-CROWD` |
| **Estimate** | M |
| **Depends on** | US-0038 |

## Description

Pre-allocate 90 NPCs during countdown and assign personas deterministically from the match seed.

## The failure this story exists to prevent is silent

A roster that differed between peers would not error, crash, or desync the simulation. NPC
identity is **visual and derived**, so two clients would simply be looking at different cities.
The symptom is a player saying *"I saw a Lucerna by the furnace"* and being wrong — which reads as
a lying teammate rather than a bug, and takes the social layer with it (GDD-03 §6.3 rule 4).

So the derivation is **pure and in Core**, and parity is asserted directly rather than by standing
three peers up — which is also the only way to ask it across many seeds at once.

## Acceptance criteria

> **All six, as of US-0040.** The first was unticked at the M3-start checkpoint because the pool
> was in no scene; US-0040 wired it, and the allocation was then **verified by running the actual
> server** rather than by a test.

- [x] **All 90 allocated before the first PLAYING tick, sized to the maximum regardless of player
      count.** Ninety real `CharacterBody3D` nodes from `npc_server.tscn` — not array slots,
      because the cost this story moves off the hot path is the **body**, and a pool that sized an
      array would satisfy the criterion's words while missing its point. `body_count()` reads the
      node list so a test can tell the difference.

      **Wired into `server_root.tscn` by US-0040, and verified by running the server**, not by a
      test — which is the only way this criterion could honestly be ticked:

      ```
      [info] [boot] seed 424242 (deterministic)
      [info] [crowd] match seed 424242
      [info] [crowd] NpcPool: 90 bodies allocated
      ```

      It was ticked in this story's own PR on the strength of the tests alone, and **unticked at
      the next checkpoint** because `server_root.tscn` held no pool. A criterion can be true of a
      class and false of the game; before ticking "X happens", check that something in a shipping
      scene calls X.
- [x] **No NPC is instantiated or freed between match start and end.** Asserted by **counting
      nodes** across three `activate()` calls at different crowd sizes, rather than by reading the
      source: the failure is a body appearing at runtime however it got there. `activate()` also
      refuses a count above the allocation rather than growing to fit — growing *is* the spike.
- [x] **Inactive NPCs are hidden and skipped, never freed.** `PROCESS_MODE_DISABLED` and
      `visible = false`; the node, body and collider all survive. Processing is disabled as well
      as visibility, because an inactive NPC that still collided would be an invisible wall in
      the middle of the district.
- [x] **Persona assignment derives from match seed plus index, identically on every peer.**
      `CrowdRoster.derive()` is pure and seeded. Adjacent seeds share **5 of 78 slots**, because
      the seed is mixed rather than used raw — sequential match seeds are the ordinary case, and
      if they differed in one draw every match in a session would look like the last one.
- [x] **Clone quota respected: 8 to 12 per persona, remainder filler archetypes.** And it lands
      on TUNABLES' own three defaults — see below.
- [x] **Three peers derive identical rosters from one seed.** Asserted on the pure derivation and
      again through two live pools, because a pool that shuffled *after* deriving would break
      parity while the pure test stayed green.

## The clone quota derives from existing tunables rather than a new ratio

TUNABLES gives three crowd defaults — 66, 72 and 78 for 4, 5 and 6 players — decomposed as 40, 44
and 48 clones plus filler: **10, 11 and 12 per persona.** But it calls those numbers *"chosen"*
while BALANCE_MODEL calls them *"derived: (count − filler) / 4"*, which is circular. Neither gives
a rule.

The rule used is the one TUNABLES states **in prose**: *"fewer players need fewer clones for the
same per-player anonymity"*. Each seat below a full lobby costs one clone per persona:

```
clones_per_persona = clamp(CLONES_PER_PERSONA_MAX - (MAX_PLAYERS - players), MIN, MAX)
```

It reproduces **all three documented numbers exactly** — 12, 11, 10 — from
`TUN-CROWD-CLONES-PER-PERSONA-MAX` and `TUN-LOBBY-MAX-PLAYERS`, both of which already exist. **No
new constant was introduced**, which matters because a ratio invented here would have been a
gameplay number without a `TUN-` ID (CLAUDE.md never-do #1).

The clamp is not decoration. GDD-03 §6.3 rule 3 is a release blocker in **both** directions: below
8, a persona's clones can be locally depleted and the player wearing it becomes unique; above 12
the crowd reads as a police lineup of repeats rather than a city.

## Why the roster is derived whole rather than per index

TDD-08 §2 sketches `persona_for(index, seed, in_use)`. The quota it has to satisfy — 8 to 12
clones *per persona* — is a property of the **whole list**, and a per-index function could only
honour it by deriving the whole list on every call. The signature moved; the guarantee did not.

**Clones are placed before any filler**, because rule 5 is a release blocker: a player whose
persona has no clones is a marked man. Filler takes the remainder.

**The list is then shuffled by the seed**, and that is not cosmetic. The pool hands index 0 the
first spawn point, so an unshuffled roster would put every clone in one quarter of the district
and every filler in another — visible at a glance, and it would make the clone quota locally
meaningless everywhere else. Measured: 24 of 48 clones fall in the first half.

`Array.shuffle()` is **not** used — it draws from the global RNG, which CLAUDE.md rule 8 bans
outside `scripts/presentation/` and which is non-deterministic, the one thing this file exists to
avoid. Fisher–Yates against the seeded generator instead.

## What `npc_server.tscn` deliberately does not have

Each omission is a story, not an oversight:

| Missing | Whose |
|---|---|
| `NavigationAgent3D` | **US-0041**, with the navmesh and steering — the navmesh half landed there; the agent comes with the steering half |
| `NpcBrain` (the five-state HFSM) | **US-0040** |
| Any mesh at all | US-0046 — and it must be the **persona's own** mesh, because a clone with an "NPC variant" material is a discriminator (GDD-03 §6.3 rule 1) |

**The capsule matches the pawn's on purpose.** A clone whose collider differed from a player's
would be findable by walking into it — exactly the silent discriminator `RISK-ANONYMITY-LEAK`
names.

## Test notes

| Test | Asserts |
|---|---|
| `test_crowd_roster.gd` | The quota hits TUNABLES' 10/11/12; it never leaves the 8–12 range for any lobby size; three derivations agree; **a different seed differs**; adjacent seeds are not nearly identical; every in-use persona gets its full quota; the remainder is filler; clones are **not clustered**; the roster is exactly the length asked for; no uninvited persona appears; **the fingerprint discriminates** |
| `test_npc_pool.gd` | Ninety **real bodies**, not slots; sized to the max regardless of active count; `activate()` allocates nothing; `deactivate_all()` frees nothing; inactive NPCs are hidden **and** disabled; `preallocate()` twice does not reallocate; it **refuses to grow**; the roster reaches the pool; two pools on one seed agree; a position reaches the body |

`test_clone_roster_parity.gd` and `test_no_midmatch_instantiate.gd` are named in the original test
notes and are **not** written under those names — both properties are asserted, in the two files
above, against live objects rather than by scanning source. Recorded rather than left looking
missing.

## Notes

Instantiating a CharacterBody3D with a NavigationAgent3D mid-match is a frame spike, and a frame
spike in a game decided at 2.5 m is a lost kill.

Appearance is derived rather than replicated so every peer agrees without spending bandwidth —
if two players saw different clone distributions, "I saw a Lucerna by the furnace" becomes a lie.

**Nothing places, steers or animates these NPCs yet.** They are allocated, identified and parked
at the origin. **There is no spawn-distribution story in M3 at all** — US-0040 is the brain,
US-0041 the navmesh and steering, US-0042 the spatial hash. **Placement landed in US-0041**,
because a position that is not on the navmesh is a position an agent cannot leave. The crowd does
not appear in a snapshot yet either, so US-0030's culling criteria and US-0031's rate-LOD
criterion stay unticked — they need NPCs *on the wire*, which is US-0040 at the earliest.

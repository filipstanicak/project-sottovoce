---
id: ADR-0026
title: The art pass is procedural, and it starts before the playtest
version: 1.0.0
status: accepted
owner: Lead Game Designer
last_updated: 2026-11-16
depends_on: [BIBLE-ART, DOC-IP-GUARDRAILS, GDD-05-LEVEL, US-0098]
supersedes: none
---

# ADR-0026 — The art pass is procedural, and it starts before the playtest

- **Status:** accepted. The first part is built by US-0108 (the district); figures, sound and
  the interface follow as their own stories.
- **Date:** 2026-11-16
- **Deciders:** owner. Owner decision 18, in the owner's words: *"Ich möchte, dass du das Spiel
  soweit fertig machst wie es geht. Ich möchte, dass es wirklich wie ein AAA-Spiel aussieht.
  Komplett fertig poliert, und zwar jeder einzelne Aspekt des Spieles."*
- **Amends:** GDD-05 §7.2 (the gate at stage 6), ART_BIBLE §6 and §7, IP_GUARDRAILS §4 rule 7
  (this is the record that rule asks for).
- **Related:** US-0098 (the first human playtest, which the gate waited for and which has not
  run), ADR-0016 (the last time a gate was split rather than waited on).

## Context

**Two rules stood between the build and looking like a game, and the owner has now asked for
both to be crossed.**

GDD-05 §7.2 says *no art work begins until the greybox map has been playtested and the loop is
fun on it*, and calls that *the single most important rule in the pipeline*. Its reason is
sound: art is the most expensive and least reversible work in a project, and a map's quality is
density, sightlines and metrics, none of which art changes. The playtest it waits for is
US-0098, which needs three to five people at once and has not happened in the four months the
build has been playable.

IP_GUARDRAILS §4 and ART_BIBLE §6 say placeholder art is *primitives or procedural* and that no
downloaded model may enter the repository, and §4 rule 7 says *no AI-generated assets in
shipping builds without an ADR recording the tool, the prompt, and the licence position of its
output*.

**The constraint that makes the easy answers wrong** is that both rules protect something real.
Buying or downloading a kit of buildings and characters is the fast way to a finished look and
is exactly what the asset rules exist to stop: each file is a licence question, and a mismatched
kit is how a game ends up looking like somebody else's. Waiting for the playtest keeps the gate
and leaves the owner looking at capsules on grey boxes for as long as five friends cannot be
found for one evening.

**What changed the arithmetic of §7.2 is how the art is made.** The gate prices art as
expensive and irreversible because a modelled district has to be re-modelled when a wall moves.
A district that is *derived* does not: if the dressing reads the generated map and builds
itself on whatever is there, a wall the playtest moves takes its windows with it.

## Options considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **A. Hold the gate; no art until US-0098 has run** | The pipeline as written; no art spent on a map that may change | The owner has asked for the opposite; the wait has no end date; the first external impression of the game stays a greybox | Rejected by the owner's decision |
| **B. A licensed or CC0 asset kit** | The fastest route to a conventional look; real character models and clips | Every file is a licence row and an IP question; a kit's style is its author's, not ours; a kit building has its own dimensions, so §7.1's invariants have to be re-proven on it; nothing in it knows the four silhouettes | Not now. Open for animation clips and sound, where code cannot go as far |
| **C. Procedural, in code, on top of the greybox** | Nothing to licence and nothing downloaded; the generated map, its colliders and its navmesh stay byte-identical; a map change re-dresses itself; one palette, checked against the reserved hues | A ceiling: a shader and a box are not a sculpted model, and "AAA" in the literal sense is out of its reach; build cost lands on the client at load | **Chosen** |
| **D. Commissioned art** | The only route to the literal request | Money, weeks, an artist and a brief the project does not have | Out of scope; the revisit trigger below names when it comes back |

## Decision

**Start the art pass now, and make all of it procedural.** Every visible thing the art pass adds
is code in this repository — shaders under `assets/procedural/`, geometry built when a client
loads a map — and none of it is a downloaded or imported file. The generated map scenes are not
touched: the dressing reads them and builds on them, and ART_BIBLE §7.1's invariants are held by
never adding a collider and never moving a box. The district is read as what its own schematic
suggests — a glassmakers' quarter on an island in a lagoon — so its drops become canals.

**This ADR is the record IP_GUARDRAILS §4 rule 7 asks for.** The generators are written by an AI
coding agent (Claude, by Anthropic) working in this repository at the owner's direction, from
the owner's request quoted above and the art bible. What it produces is source code — GDScript
and shader text — which is reviewed, tested and owned exactly as the rest of the codebase is. No
image, mesh, sound or animation file made by a generative model is imported; if one ever is, it
needs its own row and its own ADR.

## Consequences

### Positive

- The game stops looking like a greybox without one licence row being written.
- **The gate's worry does not materialise for this kind of art**: the dressing is derived from
  the scene, so a wall moved after US-0098 is dressed where it lands, at no cost.
- The server never loads a line of it; the collision scene, the navmesh and every map metric are
  byte-identical to the day before.
- The art bible's rules get their first enforcement, because there is finally art to hold to
  them: the reserved hues (§3), the quiet band at eye height (§4.1) and the clean roof line (§4).
- The climbing language survives the loss of `MAT-CLIMB`'s blue: a facade of coursed stone can
  be climbed, a plastered one cannot.

### Negative — stated honestly; an ADR with no downsides is an ADR that has not been thought about

- **It is not the literal request.** Procedural art built by one agent reaches *a coherent,
  stylised, finished-looking district*. It does not reach the fidelity "AAA" names — sculpted
  characters, captured animation, recorded sound. Saying otherwise would be the claimed-number
  failure this project keeps finding.
- **GDD-05 §7.2's gate is crossed, not met.** The map has still never been played by several
  humans. If US-0098 finds the loop is not fun on this map, the art did not change that and may
  make the finding harder to hear, because a place that looks finished reads as a place that is.
- **Decoration has no collision.** A post, a boat or an awning a pawn can walk through is a
  small lie; each is placed where a pawn cannot reach or above head height, and the rule is
  only as good as the tests that hold it.
- The build cost moved to the client's load: tens of thousands of triangles assembled in
  GDScript on every map load.
- A look built from noise functions is tuned by eye, and the eye that tuned it is the agent's,
  looking at screenshots. The owner's is the one that counts.

### Neutral / follow-on work required

- Figures and their animation, sound, and the interface are separate stories under this ADR.
- ART_BIBLE §6.2's greybox materials remain what the *generated scene* is painted in: they are
  now the vocabulary the dressing reads, not what a player sees.
- Animation clips and recorded sound are where option B may still be the right answer; that is
  an owner decision when those stories reach it.

## Compliance

- `test_the_dressing_changes_no_geometry.gd`: no solid moved, resized, added or removed on
  either map; the dressing holds no collider, shape, navigation region or obstacle.
- `test_the_dressing_keeps_the_rules_of_the_place.gd`: no surface colour within 18° of a
  persona's hue unless clearly greyer; no glass, cloth, iron or roof tile between 1.4 m and
  1.9 m; nothing above a roof a pawn can stand on.
- `test_no_colour_literals.gd` scans `scripts/presentation/world/`; only `WorldPalette` names a
  colour.
- `.ci/check_asset_inventory.sh`: everything the art pass adds lives under `assets/procedural/`,
  the licence-exempt path for work authored in the repository.
- `test_server_root_has_no_presentation.gd` and the server export filter keep it off the server.

## Revisit trigger

- **US-0098 runs and changes the map**: confirm the dressing followed, and re-run the look probe.
- **The owner wants more than procedural reaches** — modelled characters, captured animation,
  recorded sound: that is option B or D, with licence rows, and a new ADR.
- **The client's frame time leaves `TUN-PERF-RENDER-BUDGET`** on the reference machine: the look
  gets quality levels before it gets cut.

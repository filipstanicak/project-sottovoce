---
id: US-0108
title: The district is dressed
version: 0.1.0
status: in-progress
owner: Lead Game Designer
last_updated: 2026-11-16
depends_on: [BIBLE-ART, GDD-05-LEVEL, ADR-0026, US-0107]
---

# US-0108 — The district is dressed

| | |
|---|---|
| **Milestone** | M6 |
| **Epic** | `EPIC-BOOT` |
| **Systems** | `SYS-MAP` (the client's picture of it; nothing a server runs) |
| **Estimate** | L — one PR |
| **Depends on** | ADR-0026 (the art pass is procedural and starts now) |

## Description

**The owner, 2026-11-16:** *make the game as finished as it can be; it should really look like a
AAA game, every single aspect polished.* Until then a client drew what the map generator wrote:
grey slabs, blue and yellow boxes, a flat sky, one light. ADR-0026 records the decision to begin
the art pass before the playtest GDD-05 §7.2 waits for, and to do all of it procedurally.

**This story is the district.** When a client loads a map, `DistrictDressing` reads the
generated scene and builds on it: the greybox solids are repainted, and everything a place has
that a box does not is added round them. The map scene, its colliders and its navmesh are not
touched, so the district plays exactly as it did.

**What it reads the district as:** a glassmakers' quarter on an island in a lagoon. The drops
between the piazza and the Loggia and along the Fondaco are canals, the ground is quays, the
narrow floors over a drop are bridges, and other islands stand across the water.

Figures, animation, sound and the interface are not in this story.

## Acceptance criteria

- [x] **A low afternoon sun, a sky with clouds, haze and soft shadows** (`WorldLook`), built in
      code from `WorldPalette` and replacing the greybox's one key light.
- [x] **Every greybox solid is repainted**: plaster in the building's own colour, coursed stone
      on every climbable facade, paving on the squares, setts in the streets, boards on the
      balcony, timber stalls, stone parapets and benches.
      `test_every_greybox_material_is_replaced`.
- [x] **The climbing language survives**: a facade of coursed stone can be climbed, a plastered
      one cannot, exactly where `MAT-CLIMB` was (`test_facade_dresser.gd`).
- [x] **Water lies in every canal and round the island**, with quays reaching below it, an arch
      under each of the three bridges, mooring poles and boats.
- [x] **A facade has what a facade has**: a plinth, a string course at the balcony line, a tiled
      eave, shuttered windows above 3.5 m with one in six lit, a door every third bay under an
      awning or a sign, lanterns on brackets, and a roofed bell tower.
- [x] **The market looks like one**: posts and a striped awning over every stall, wares on the
      counter.
- [x] **Islands stand across the lagoon**, the same ones on every screen.
- [x] **Art changed no geometry** (ART_BIBLE §7.1): no solid moved, resized, added or removed on
      either map, and the dressing holds no collider.
      `test_the_dressing_changes_no_geometry.gd`.
- [x] **The reserved hues stay reserved** (ART_BIBLE §3): no surface colour within 18° of a
      persona's hue unless it is clearly greyer. The first run found the canal in the Vetraio's
      own teal.
- [x] **Eye height stays quiet** (ART_BIBLE §4.1) for everything with a glint, a stripe or a
      light in it: no glass, cloth, iron or roof tile between 1.4 m and 1.9 m.
- [x] **A roof a pawn can stand on is still a clean line**: nothing is built above it. Only the
      bell tower, 22 m up, has a roof with a shape.
- [x] **The same district on every screen**: nothing in it is random
      (`test_the_same_district_is_built_every_time`).
- [x] **Inside the art bible's triangle budget** (§5): 58 550 triangles for the district and its
      backdrop, against 3 000 a building and 800 a prop.
- [x] **Measured, not assumed**: from the piazza at 1080p on the development machine (RTX 3080),
      with a crowd of 34 and the HUD hidden, a frame costs 1.97 ms with everything on and
      1.13 ms with all of it off (`tools/look_probe.tscn -- --bench`). The reference machine of
      `TUN-PERF-RENDER-BUDGET` has not been measured.
- [x] **The blend net reads on the finished ground** (US-0107's open criterion): the ground is a
      light grey no lighter than the net can stand on, and the net's line and seam were
      strengthened for it. Judged in `tools/blend_cue_probe.tscn`.
- [x] **A client with no screen dresses nothing.** A bot is a headless client; so is every test
      that boots one. Dressing them cost the integration suite 37 s (192 s to 229 s), so
      `DistrictDressing.is_wanted()` asks for a display, and
      `test_the_client_dresses_its_district.gd` forces the real boot path through it.
- [ ] **The owner looks at it** and says whether this is the direction.
- [ ] **The doors.** A door every third bay stands in the 1.4–1.9 m band. They are dark and
      flat, and §4.1 allows *sparse decoration*; whether they cost identification accuracy needs
      human eyes on a crowd in front of one.
- [ ] **Frame time on the reference machine**, and quality levels if it needs them.

## Open

- **Decoration has no collision.** Posts stand on the parapet line, outside the ground a pawn
  reaches; awnings, signs and eaves hang above head height; boats lie in the water. A Lucerna's
  pole, 2.79 m, passes through an awning at 2.4 m.
- **A pawn that leaves a quay still falls through the water.** The water is a picture of the
  drop, not a floor in it; what happens to a pawn that goes in is a rule the game does not have.
- **The sandbox** is dressed by the same code and has been looked at by no one.

## Files

| File | What |
|---|---|
| `scripts/presentation/world/district_dressing.gd` | The art pass's entry: survey, repaint, build |
| `scripts/presentation/world/dressing_survey.gd` | What the greybox is made of, read back from the scene |
| `scripts/presentation/world/world_palette.gd` | Every colour the district is built in |
| `scripts/presentation/world/world_materials.gd` | Ten materials from that palette |
| `scripts/presentation/world/mesh_batch.gd` | Thousands of parts, one mesh a material |
| `scripts/presentation/world/world_look.gd` | The sun, the sky, the air |
| `scripts/presentation/world/ground_dresser.gd` | Paving, quays, bridges, the balcony's timbers, the water |
| `scripts/presentation/world/facade_dresser.gd`, `facade_trimmings.gd` | What makes a box a building |
| `scripts/presentation/world/prop_dresser.gd`, `waterside_dresser.gd` | Stalls, benches, hiding places; moorings and boats |
| `scripts/presentation/world/backdrop_dresser.gd` | The islands across the water |
| `assets/procedural/shaders/world_*.gdshader` | Surface, ground, water, sky; no texture file |
| `tools/look_probe.tscn` | Photograph the district from ten places; `--bench` prices each effect |
| `test/unit/presentation/world/` | Seven scripts: the batch, the survey, the look, and the rules above |
| `test/integration/test_the_client_dresses_its_district.gd` | `client_root.tscn` dresses the map it loaded, and only with a screen |

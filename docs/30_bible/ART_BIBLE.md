---
id: BIBLE-ART
title: Art Bible
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-03-SOCIAL-STEALTH, GDD-05-LEVEL, DOC-IP-GUARDRAILS, BIBLE-ANIMATION-SPEC]
---

# Art Bible

> **Context restated.** Project Sottovoce is a social-stealth game whose core promise is that a
> player is indistinguishable from the 8–12 **clones** of their persona in a crowd of 60–90.
> Players identify each other by **shape and behaviour**, never by a rendered marker. There are
> no nameplates, no minimap, and the only through-geometry effect in the game is the Exposed
> outline — which is a punishment.
>
> **The art's job is therefore unusual: it must make four characters instantly distinguishable
> from *each other* and completely indistinguishable from *their own copies*.**

---

## 1. Silhouette-first persona design

> **Every persona must be identifiable from its silhouette alone, in solid black, at 40 m, in
> motion, partially occluded by a crowd.**

Identification at that distance is a **shape** problem, not a costume problem. Texture, colour
and detail are invisible at 40 m; outline is not.

### 1.1 The four silhouettes

Chosen for orthogonality on two axes (height, width) plus one distinguishing appendage
(ASM-0003). Fiction was chosen *afterwards* to justify the shapes.

| Persona | Silhouette class | Height | Width | Distinguishing feature |
|---|---|---|---|---|
| **Vetraio** (Glasswright) | `LOW_BROAD` | 1.68 m | Widest at shoulder | Leather apron, goggles on brow — mass concentrated high |
| **Cantatrice** (Street Singer) | `FLOOR_TRIANGLE` | 1.72 m | Widest at floor | Bell skirt, tall coiled headdress — a triangle standing on its base |
| **Lucerna** (Lamp-Tender) | `TALL_THIN` | 1.89 m | Narrowest | Hooded cloak + **long wick-pole breaking the head line** |
| **Pesatore** (Weighmaster) | `ROUND_MID` | 1.75 m | Even, rounded | Flat cap, ledger box under one arm — a rounded rectangle |

```
     LOW_BROAD      FLOOR_TRIANGLE     TALL_THIN        ROUND_MID
                                          |
       ___             ___                O                ___
      /   \             O                /|\              (   )
     |=====|           /|\              / | \             |   |
     |     |          / | \            |  |  |            |[ ]|
      |   |          /  |  \           |  |  |            |   |
      |   |         /___|___\          |  |  |            |   |
      ‾‾ ‾‾        /_________\          ‾‾ ‾‾              ‾‾ ‾‾
     wide top      wide bottom       pole line          even mass
```

**The `TALL_THIN` pole line is the single most readable feature in the cast**, because a vertical
element above the head survives crowd occlusion better than anything at torso height. It is
deliberately given to the tallest persona so the two cues reinforce.

### 1.2 The silhouette test

Run at every art milestone, and it is a **gate**, not a review note:

1. Render all four personas in solid black on white, at 40 m equivalent scale.
2. Render each in three poses: idle, mid-blend-walk-stride, turning.
3. Occlude the lower 40 % with a crowd silhouette band.
4. Show to five people who have not seen the game. **All four must be distinguished with ≥ 90 %
   accuracy.**

`test_persona_silhouettes_distinct.gd` asserts the four `PersonaData.silhouette` enum values
differ; the perceptual half needs humans.

### 1.3 The scale anchor

`ARCH-CHILD` exists specifically as a **negative silhouette**: unmistakably non-player scale, so
the eye is trained to size-check before shape-check. This is why five filler archetypes exist
rather than three — the crowd needs shapes that are *definitively not a player*.

---

## 2. Clone identity — the rule that overrides everything

> **A clone is visually identical to a player of that persona. Not similar. Identical.**

| Rule | Consequence of breaking it |
|---|---|
| Same mesh, materials, shader, animation set | Players learn the difference within one session; anonymity is dead |
| **No per-instance variation on clones** — no colour tint, no accessory shuffle, no scale jitter | Any variation the player cannot also have is a discriminator |
| No reduced-bone rig within `TUN-COMPASS-RANGE-MAX` 60 m | Gait differences are visible in peripheral vision |
| Clone appearance is derived from `match_seed`, identical on every peer (ASM-0025) | "I saw a Lucerna by the furnace" becomes a lie; the social layer breaks |

### 2.1 Why cosmetics are design-blocked, not deferred

The instinct is to add per-instance variety so the crowd looks less like a lineup. **That
instinct is the exact failure mode**, and it is why cosmetics are blocked in
[`../00_meta/SCOPE_FENCE.md`](../00_meta/SCOPE_FENCE.md) OUT #3 pending a *design* answer rather
than art time.

The unblocking design is **crowd-wide propagation**: a cosmetic you equip also appears on your
clones. Genuinely interesting, entirely unbuilt.

Crowd variety in MVP comes from the **five filler archetypes** instead — they can vary freely,
because no player can be one.

---

## 3. The colour-language law

> **Colour carries exactly three meanings in this game. Nothing decorative may use those hues.**

| Meaning | Hues | Used by |
|---|---|---|
| **Persona identity** | Four reserved hues, one per persona | Exposed outline, Noticed tint, contract portrait |
| **Suspicion tint** | Saturation and rim intensity on the identity hue | Render state |
| **Ability tells** | Cinderfall orange, Whisperbolt steel-white, Second Face violet shimmer | VFX only |

Everything else — architecture, props, NPC clothing, terrain, UI chrome — lives in a
**desaturated warm-neutral range**: stone, plaster, terracotta, weathered timber, dull brass.

### 3.1 Why this is severe

The Noticed tint is a **12 % desaturation shift plus a low-intensity rim light**, tuned to be
visible *only against its own crowd*. If a market awning uses the Vetraio identity hue at similar
saturation, the tint becomes unreadable in that market — a gameplay dead zone created by set
dressing, invisible to whoever placed the awning.

`test_no_reserved_hues_in_environment.gd` samples environment albedo textures and fails on any
pixel cluster within a tolerance of a reserved hue above a saturation threshold.

### 3.2 The reserved palette

| Reserved for | Hue | Notes |
|---|---|---|
| `PERSONA-VETRAIO` | Amber | |
| `PERSONA-CANTATRICE` | Rose | |
| `PERSONA-LUCERNA` | Cyan | |
| `PERSONA-PESATORE` | Jade | |
| Ability — Cinderfall | Hot orange | The only fire-bright value in the game |
| Ability — Whisperbolt | Steel white | |
| Ability — Second Face | Violet | |
| Danger / Exposed vignette | Deep red | Screen-edge only, never in world |

Exact values live in `Palette` ([`UI_UX_SPEC.md`](UI_UX_SPEC.md) §7) with colourblind variants.
**No widget or material names a colour literal.**

---

## 4. Environment art direction

Renaissance-Italian glassmakers' quarter. The direction serves legibility first.

| Principle | Application |
|---|---|
| **Value over hue** | Readability comes from light/dark contrast, not colour contrast, so the reserved hues stay unique |
| **Horizontal banding** | Buildings read as clear strata (street / balcony / roof), so the vertical layer a player occupies is instantly legible |
| **Silhouette-clean architecture** | No busy rooflines. A player on a roof must be a clear shape against sky |
| **Warm interiors, cool exteriors** | Furnaces glow; streets are cool. Gives depth cueing without saturated colour |
| **Sparse decoration at eye height** | 1.4–1.9 m is where players read other players. Keep it clean |
| **Density reads as density** | A dense zone should *look* dense from 30 m, so players can route toward safety without checking a HUD |

### 4.1 The eye-height rule

Between **1.4 m and 1.9 m**, environment art is deliberately quiet: no high-frequency patterns,
no strong value contrast, no reserved hues. That band is where the game is played, and clutter
there costs identification accuracy directly.

Furniture below 0.9 m (vaultable) and detail above 2.3 m (out of the reading band) can be as rich
as the budget allows.

---

## 5. Budgets

Reference machine: 1080p/60, `TUN-PERF-RENDER-BUDGET` 9.0 ms.

| Asset | Tris | Textures | Notes |
|---|---|---|---|
| Persona (player + clone, same mesh) | ≤ 8 000 | 1× 1024² albedo + ORM | **90 on screen at once** — this is the binding constraint |
| Filler archetype | ≤ 6 000 | shared 1024² atlas | |
| Building module | ≤ 3 000 | shared 2048² atlas | |
| Prop (stall, bench, cart) | ≤ 800 | shared atlas | |
| Blend prop (hay cart, well, wardrobe) | ≤ 1 500 | own 512² | 5 on the map; must read as interactable |
| VFX (Cinderfall cloud) | — | 512² flipbook | |

### 5.1 The crowd is the budget

90 characters × 8 000 tris = **720 000 tris of characters alone**. That is the whole reason for:

- LOD meshes at 100 % / 50 % / 20 % triangle counts by
  `TUN-PERF-CROWD-LOD-NEAR/MID/FAR`
- A shared material per persona so the crowd batches
- **No per-instance material variation** — which the clone rule already requires, so the
  performance constraint and the design constraint agree

> **LOD may reduce fidelity. It may never change silhouette or gait inside
> `TUN-COMPASS-RANGE-MAX` 60 m**, because that is the distance at which players are trying to
> distinguish clones from humans. `test_anim_lod_silhouette.gd` compares rendered silhouettes at
> each band boundary.

---

## 6. Placeholder art standards

Per [`../00_meta/IP_GUARDRAILS.md`](../00_meta/IP_GUARDRAILS.md) §4 and ASM-0029: **primitives
and procedural only**. No downloaded models, ever — not for reference, not in a scratch folder,
not on a branch.

### 6.1 Greybox personas

Silhouette differentiation achieved with **scale and attached primitives**, which is sufficient
to playtest the entire anonymity system:

| Persona | Greybox construction |
|---|---|
| Vetraio | Capsule, 1.68 m, ×1.4 shoulder scale, box on chest |
| Cantatrice | Capsule + cone skirt, 1.72 m, sphere on head |
| Lucerna | Capsule, 1.89 m, ×0.8 width, **cylinder pole 0.9 m above head** |
| Pesatore | Capsule, 1.75 m, uniform, box under arm |

> **NONE OF THE FOUR IS BUILT YET, AND THE M1 PLACEHOLDER IS NOT ONE OF THEM.**
> `GreyboxBody` (US-0091) draws a deliberately generic figure — a capsule the size of the
> collider, a head and a chest marker so facing can be read. It makes no silhouette claim,
> because each row below *is* a claim that has to survive §1.2 at 40 m in solid black, and
> asserting one untested would quietly start `PERSONA-*` work that belongs to US-0039 along with
> its clone-parity rules.

**These four greybox shapes pass the §1.2 silhouette test.** That is the point: if the greybox
fails it, no amount of art will fix it, and if it passes, art is polish rather than rescue.

### 6.2 Greybox material set

| Material | Colour role | Applied to |
|---|---|---|
| `MAT-GREY-FLOOR` | Neutral mid-grey | Walkable street |
| `MAT-GREY-WALL` | Lighter grey | Non-climbable walls |
| `MAT-CLIMB` | **Desaturated blue** | Every climbable façade |
| `MAT-VAULT` | **Desaturated yellow** | Every 0.9 m vaultable surface |
| `MAT-BLEND` | **Desaturated green** | Blend props and pocket markers |
| `MAT-GREY-PAWN` | Desaturated plaster | The placeholder body, and one value off `MAT-GREY-WALL` so a pawn against a façade is still a separate shape |
| `MAT-VOID` | Magenta | Out of bounds / error — **must never appear in a playtest build** |

Greybox uses **desaturated** hues deliberately, avoiding the saturated identity hues reserved by
§3.

---

## 7. The art pass

Gated by [`../10_gdd/05_level_design.md`](../10_gdd/05_level_design.md) §7.2: **no art work
begins until the greybox map has been playtested and the loop is fun on it.** Art is the most
expensive and least reversible work in the project, and a map's quality here is a function of
density, sightlines and metrics — none of which art changes.

### 7.1 What art may not change

| Invariant | Verified by |
|---|---|
| Every traversable surface height | `test_map_metrics.gd` re-run on art geometry |
| Every navmesh boundary | Navmesh diff against the greybox bake |
| Idle anchor and circuit waypoint positions | They are **data** in `MapData` — art cannot move them |
| Named sightlines, ± 2 m | `test_map_sightlines.gd` |
| Dead-end lengths, alley widths | `test_map_dead_ends.gd`, `test_map_widths.gd` |

**Decorative geometry may not create new cover.** Every art prop is either inside the
navmesh-excluded volume, below 0.9 m (vaultable, therefore not cover), or signed off as a metrics
change with the tests re-run.

---

## 8. IP constraints

Restated because they bind art harder than any other discipline.

| Rule | |
|---|---|
| **No asset from a commercial game.** Ever, anywhere, for any reason | [`../00_meta/IP_GUARDRAILS.md`](../00_meta/IP_GUARDRAILS.md) §4.3 |
| Third-party assets **CC0 or equivalent**, recorded in `ASSET_LICENSES.md` **in the same commit** | §4.2 |
| Reference photography is research; **importing it makes it an asset** needing a row | §4.4 |
| Fonts are assets | §4.5 |
| No AI-generated assets in shipping builds without an ADR | §4.7 |

### 8.1 The homage boundary, for art specifically

| Case | Verdict |
|---|---|
| Renaissance Italian architecture, period-accurate | ✅ Nobody owns a historical period |
| A hooded figure in period dress | ✅ Functional: hoods make silhouettes readable at 40 m |
| **A hooded figure in a white robe with a red sash and a beaked hood** | ❌ That is a specific character design |
| An amber-lit furnace interior | ✅ |
| A UI that fades to a grid-white loading screen with glitch text | ❌ Trade dress |

**The review question, before any commit that adds a visible asset:**

> ### Ask the review question in
> ### [`../00_meta/IP_GUARDRAILS.md`](../00_meta/IP_GUARDRAILS.md) §5.

If the answer is *yes*, *maybe*, or *I'd have to think about it* — rework it and ask again.

---

## 9. Acceptance criteria

- [ ] All four personas pass the §1.2 silhouette test with ≥ 90 % accuracy from five naive viewers.
- [ ] The four `PersonaData.silhouette` values are mutually distinct.
- [ ] Clone and player meshes, materials and animation sets are byte-identical references.
- [ ] No per-instance variation exists on any clone.
- [ ] No environment texture uses a reserved hue above the saturation threshold.
- [ ] No material or widget names a colour literal; all come from `Palette`.
- [ ] Environment art in the 1.4–1.9 m band meets the §4.1 quiet rule.
- [ ] Persona meshes ≤ 8 000 tris with three LOD levels.
- [ ] LOD silhouettes match across band boundaries inside 60 m.
- [ ] `MAT-VOID` appears nowhere in a playtest build.
- [ ] Every third-party asset has an `ASSET_LICENSES.md` row.
- [ ] Art-pass invariants (§7.1) all re-verified on art geometry.

---

## 10. Open questions

| # | Question | Position | Needed by |
|---|---|---|---|
| 1 | Four personas may be too few for crowd variety — 48 of 78 NPCs are clones, so the district is 62 % four repeated shapes. | Filler archetypes carry the variety. If it still reads as a lineup, raise filler and lower clones toward the **8 floor — never below it** ([`../10_gdd/03_social_stealth.md`](../10_gdd/03_social_stealth.md) §13 failure mode 6) | M3 |
| 2 | Is the Noticed tint (12 % desaturation + rim) findable at all in a dense market, or invisible? The gap between "requires comparison" and "imperceptible" is about 5 %. | Needs perceptual testing with real crowds, not a colour picker. First measurable at M3 | M3 |
| 3 | Should personas have distinct *gaits* as well as silhouettes? It would help identification at range — but gait must then be identical between player and clone, adding four more parity clips. | Not for MVP. Revisit if the silhouette test underperforms at 40 m | M4 |
| 4 | The eye-height quiet rule (§4.1) may make the district feel sterile at street level, which is where players spend all their time. | Genuine tension between legibility and atmosphere. Resolve visually at the first art pass; legibility wins if they conflict | M6 |

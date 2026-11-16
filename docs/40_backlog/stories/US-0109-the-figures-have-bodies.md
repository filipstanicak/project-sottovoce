---
id: US-0109
title: The figures have bodies, and move
version: 0.1.0
status: in-progress
owner: Lead Game Designer
last_updated: 2026-11-16
depends_on: [BIBLE-ART, BIBLE-ANIMATION-SPEC, ADR-0026, US-0046, US-0108]
---

# US-0109 — The figures have bodies, and move

| | |
|---|---|
| **Milestone** | M6 |
| **Epic** | `EPIC-ANONYMITY` |
| **Systems** | `SYS-CROWD`, `SYS-PAWN` (the client's picture of both; nothing a server runs) |
| **Estimate** | L — one PR |
| **Depends on** | US-0108 (the district they stand in), ADR-0026 |

## Description

**Until 2026-11-16 every figure in the district was a capsule with a box on it, and it glided.**
ROADMAP §8.3 row 7 priced animation at five to eight pull requests and waited on licensed clips;
ADR-0026 decided the art pass is procedural, so this is that row done the other way.

**One skeleton, for everybody.** The local player, every other player and every civilian is a
`PersonaBody`: a `FigureRig` of pelvis, trunk, head and two-boned limbs, in a `FigureShape`'s
proportions, dressed by what makes its persona's silhouette — the Vetraio's yoke and apron, the
Cantatrice's bell skirt and coiled hair, the Lucerna's hood and pole, the Pesatore's round middle,
cap and ledger. The five filler archetypes, undressed until now, are trades no player can be: a
child, a fishwife, a mendicant, a porter and a water-carrier.

**And one way of moving.** `FigureAnimator` reads a pose from three things: how the body moved
since the last frame, where it is standing, and what it is doing. **None of the three says whether
a player is behind the figure**, which is the whole of clone parity here (ANIMATION_SPEC §1, §12):
there is no second rig or clip library for the first to drift from.

## Acceptance criteria

- [x] **Every figure is a jointed body**: trunk, head, two arms and two legs of two bones, the
      same fourteen joints whatever it wears (`test_every_figure_has_the_same_skeleton`).
- [x] **The four silhouettes keep the art bible's claims** (§1.1): the heights and widths are read
      from `data/personas/*.tres`, the Vetraio is the broadest at the shoulder, the Cantatrice the
      widest at the floor, the Lucerna the tallest, and **only the Lucerna's pole breaks a head
      line** (`test_persona_silhouettes.gd`, `test_figure_shape.gd`).
- [x] **The five fillers have shapes of their own**, in homespun no persona could be taken for, and
      the child is shorter than anything a player can be (§1.3).
- [x] **A figure walks when its body moves and stands when it does not**, at the spec's stride:
      1.15 s a cycle at blend-walk, 0.78 s at stroll, 0.54 s at run, 0.44 s at sprint, never
      snapping between (`test_figure_motion.gd`). The stride follows the ground covered, and runs
      backwards for a figure walking backwards.
- [x] **A figure that stops on a bench seat sits, and one that stops at a counter leans**, facing
      the bench or the counter — decided by the place, never by who is standing there, because a
      client is not told another player's blend (`FigurePlaces`, `test_figure_places.gd`).
- [x] **A clone and a player moved alike are posed alike**: one built as another player's pawn is
      and one as `NpcView` builds a civilian, walked down the same street and sat on the same
      seat, joint for joint, for all four personas
      (`test_the_clone_moves_as_the_player_does.gd`). And nothing that poses a figure names a
      player, a slot, a persona or a view.
- [x] **No state reachable while Anonymous is shown as an act.** Climbing, vaulting, the kill, the
      stun, being stunned, staggered, choking, dead and lunging are told to a figure by
      `FigureDirector`; idle, blend-walk, stroll and blending are not, and every pawn state is one
      or the other (`test_figure_director.gd`). Another player's state has been on the wire since
      US-0029 and is read for the first time here.
- [x] **A civilian flinches when startled and stares when it gawks**; its brain's state was on the
      wire and unread too.
- [x] **Still no per-instance variation**: the seven files that build and move a figure are under
      `test_no_clone_variation.gd`. Each figure's offset into the idle is the next step of one
      sequence, player or civilian, and the sequence is not random.
- [x] **Ninety figures are a few dozen shapes to the renderer**: one mesh a shape and one material
      a colour, shared by every figure (`FigureParts`); greying one for the blend net hands it
      another paint rather than tinting the shared one.
- [x] **Inside the art bible's budget** (§5): 3 444 to 4 188 triangles a figure, against 8 000.
- [x] **A client with no screen animates nobody** (`DisplayGate`): a bot's figures are built and
      stand still.
- [x] **Measured in a real session**: a server, three bots and this client, 57 civilians and three
      players in view, the district dressed — 2.30 ms a frame and 1.61 ms a physics tick, at
      1080p on the development machine (`tools/session_probe.tscn`). The reference machine of
      `TUN-PERF-RENDER-BUDGET` has not been measured.
- [ ] **The owner looks at them**, walking, sitting and in a crowd.
- [ ] **A human reads the four personas apart at 40 m** (ART_BIBLE §1.2's gate, five naive
      viewers). The machine half is `test_persona_silhouettes.gd`.
- [ ] **A figure standing on a seat without having blended also sits**, on every screen. The rule
      is what keeps a player indistinguishable; whether it reads as odd needs play.
- [ ] **Animation LOD** (US-0045): every figure is posed every tick at every distance.

## Open

- **Poses, not performances.** No turn-in-place, no start and stop steps, no whiff, no persona
  gesture (`ANIM-IDLE-VAR-C`), no root motion. A traversal is a held shape.
- **A seated figure faces its bench, not its pawn's yaw.** The pawn's facing is what a kill cone
  reads; the picture of a seated player says nothing of it.
- **Corpses.** A dead player's figure lies where it fell until its pawn moves. A civilian's
  corpse is not a figure at all yet.
- **The figure's colours are flat**, and the personas' hues are the data's own, authored for
  capsules.

## Files

| File | What |
|---|---|
| `scripts/presentation/pawn_visuals/persona_body.gd` | Every figure: builds, dresses, greys, moves |
| `…/figure_shape.gd` | Ten shapes; the personas' numbers come from `data/personas/` |
| `…/figure_rig.gd`, `figure_pose.gd` | The skeleton, and where every joint is |
| `…/figure_tailor.gd`, `figure_garments.gd`, `figure_trades.gd`, `figure_parts.gd` | The body, the personas' pieces, the fillers', and the shared meshes and paints |
| `…/figure_motion.gd`, `figure_acts.gd`, `figure_animator.gd` | Gait, idle, sitting, leaning; the acts; one figure's motion frame to frame |
| `…/figure_places.gd`, `figure_director.gd` | Where figures sit and lean; what the players' pawns are doing |
| `scripts/presentation/display_gate.gd` | Whether this process has a screen |
| `tools/figure_probe.tscn`, `tools/session_probe.tscn` | Every shape, gait, act and place; a real session photographed and priced |
| `test/unit/presentation/pawn_visuals/` | Eight scripts new or rewritten for the jointed body |

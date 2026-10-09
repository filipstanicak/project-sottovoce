---
id: US-0107
title: The net under every group and bench, and the grey over one's own
version: 0.1.0
status: in-progress
owner: Lead Game Designer
last_updated: 2026-10-06
depends_on: [GDD-03-SOCIAL-STEALTH, US-0053, US-0054, US-0103]
---

# US-0107 — The net under every group and bench, and the grey over one's own

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-SUSPICION` |
| **Systems** | `SYS-BLEND`, `SYS-CROWD`, `SYS-NET-*` |
| **Estimate** | M — one PR |
| **Depends on** | US-0103 (the crowd that sits, leans and gathers) |

## Description

**Reported from the controls on 2026-10-06**, after US-0103: *the crowd feels right, but I would
like visual cues for the bench, the counters and the circles.* The server knew where a player
could blend and whether they were, and no client drew either: the blend worked and nothing said
so.

**The owner's reading of the reference, from playing it:** a faint white honeycomb lies on the
ground under every group a player can blend with and under every bench, **all the time**; and
while blended, the player's own figure and the civilians forming the group with them are
**slightly greyed — on that player's screen alone**, so they know which civilians the blend rests
on. One frame of the reference match the owner keeps confirms the net under a walking group; the
grey was not checkable from it, because that player never blends.

## Acceptance criteria

- [x] **A net lies under every bench seat and every stall counter**, from the first frame, on
      every screen — drawn from `MapData.static_props`, so the sandbox's props get one too.
- [x] **A net lies under every walking group, and wherever standing civilians guarantee a
      pocket**, and moves with them. The server says on `NET-S2C-CROWD-GROUPS`
      (`PROTOCOL_VERSION` 8) what each civilian is, **from civilians alone**, so no net ever
      appears, moves or vanishes because a player joined: a walking group's tag is its NPC
      occupants and the player's slot is never an NPC's. **A standing net is a promise kept at
      every point of it**: the client draws the widest discs in which
      `TUN-BLEND-POCKET-MIN-NPC` standing civilians are within `TUN-BLEND-POCKET-RADIUS` of every
      point, centred on a standing civilian or on the centre of its four nearest
      (`BlendCueRules._pocket_nets`). The second version drew a net per knot and three of four
      nets round one granted pocket lay where the server refused it; the third split the standing
      at 1.75 m first and lost a full circle standing 2.8 m apart (reviews of #252);
      `test_the_net_keeps_its_promise.gd` now asks the real `BlendSystem.request` at the centre
      and rim of every net drawn. **Stricter than the pocket on purpose**: walkers are never
      counted, because a net under people walking away promises a blend that leaves.
- [x] **A blended player sees themselves and their group slightly greyed, and nobody else
      does.** A walking group greys its members; a pocket the standing civilians within the
      pocket radius; a bench the others sitting on it; a counter only the player; a hiding spot
      nothing, because the player is not drawn there. `BlendCueRules`, `PersonaBody.set_greyed`.
      **By membership, never by distance** (review of #252): the first version tagged only the
      civilians that could each anchor a pocket and found sitters by a 0.5 m radius, so a pocket
      the server granted greyed one of its four, and a passer-by at a counter was greyed as a
      sitter. The server now says what each civilian is — standing, in which walking group,
      holding which seat — and `test_crowd_groups.gd` checks the grey against the server's own
      tags.
- [x] **The grey keeps the persona readable** — half way to grey, not all the way: judged in
      `tools/blend_cue_probe.tscn`, where 70 % had washed the Lucerna's yellow out.
- [x] **A walking group walks the player** (the owner, 2026-10-09: *I do not walk myself, I walk
      along automatically until I walk out of the group*; a player guide says the persona is
      *"taken over by the AI"*). While blended in a group and hands off, the client writes the
      commands toward the slot (`GroupFollow`, `GroupFollowSteer`), marked `InputBits.FOLLOW`, so
      the pawn faces its travel and never backpedals; the camera stays the player's. Touching the
      stick hands control back, and an action is aimed where the player looks. `blend_slot` rides
      the own block, `PROTOCOL_VERSION` 9. **The server honours `FOLLOW` only for a player it has in
      a walking group with no action pressed** (`PawnHost.screen_follow`), and the client ignores
      snapshots older than its newest (review of #253). The steering's gain, deadband and headroom
      are `TUN-BLEND-FOLLOW-*`. Measured through the real state machine, camera looking
      back, a corner turned: at most 0.08 m from the slot (tolerance 0.8), at most 1.52 m/s (break
      2.2), facing exact; without `FOLLOW` the same steering falls 1.67 m behind.
- [x] **The street is grey in a debug build.** It was drawn white, and the net on it could not be
      seen: the debug district map set every street floor's material to `null` when hidden, on a
      docstring's word that the floors had none, and it starts hidden — so every `play.bat` session
      since US-0041 drew the streets in Godot's default white. It now puts the floor's own
      `MAT-GREY-FLOOR` back. A red floor drawing white is how it was found.
- [ ] **The net reads on the finished district's ground.** Judged on the greybox only, whose
      sunlit floor is near-white: a white line alone vanished there, so each line carries a faint
      dark seam. Blocked: no art.
- [ ] **Felt from the controls**: the owner finds a bench, a counter, a walking group and a
      circle by the net, and reads their own group by the grey.

## Open

- **Hiding spots.** Whether the reference draws the net under a hay cart as well is not
  sourced. They get none; the prop itself is the mark.
- **The grey is the one per-instance difference a body carries**, and GDD-03 §6.3 rule 6 still
  holds: it is drawn on the blender's screen alone, over figures they already know they stand
  with.

## Files

| File | What |
|---|---|
| `scripts/core/blend/blend_group_tag.gd` | The tag values, which are the wire |
| `scripts/core/blend/blend_cue_rules.gd` | Who is greyed; where each group's net lies. Pure |
| `scripts/systems/crowd/crowd_groups.gd` | The server's tags, from civilians alone |
| `scripts/server/crowd_group_announcer.gd` | The whole table to a newcomer, then the changes |
| `scripts/net/crowd_group_wire.gd` | `NET-S2C-CROWD-GROUPS` |
| `scripts/presentation/vfx/blend_cues.gd` | The net and the grey |
| `tools/blend_cue_probe.tscn` | Look at both, windowed |
| `test/unit/systems/blend/test_the_net_keeps_its_promise.gd` | Every standing net drawn from the server's tags, asked at its centre and rim through `BlendSystem.request` |
| `test/unit/systems/crowd/test_crowd_groups.gd`, `test/unit/server/test_crowd_group_announcer.gd`, `test/unit/core/blend/test_blend_cue_rules.gd`, `test/unit/presentation/vfx/test_blend_cues.gd` | The rule, the wire's recipients, the selection, the drawing |

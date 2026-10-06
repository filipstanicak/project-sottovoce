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
- [x] **A net lies under every walking group and every knot of standing civilians a pocket
      can be taken in**, and moves with them. The server names them on `NET-S2C-CROWD-GROUPS`
      (`PROTOCOL_VERSION` 8) **from civilians alone**, so no net ever appears, moves or vanishes
      because a player joined: a walking group's tag is its NPC occupants and the player's slot
      is never an NPC's; a standing knot counts standing civilians, at least
      `TUN-BLEND-POCKET-MIN-NPC` within `TUN-BLEND-POCKET-RADIUS`. **Stricter than the pocket on
      purpose**: a pocket the server grants from passers-by gets no net, because a net under
      people walking away promises a blend that leaves.
- [x] **A blended player sees themselves and their group slightly greyed, and nobody else
      does.** A walking group greys its members; a pocket the standing civilians within the
      pocket radius; a bench the others sitting on it; a counter only the player; a hiding spot
      nothing, because the player is not drawn there. `BlendCueRules`, `PersonaBody.set_greyed`.
      **By membership, never by distance** (review of #252): the first version tagged only the
      civilians that could each anchor a pocket and found sitters by a 0.5 m radius, so a pocket
      the server granted greyed one of its four, and a passer-by at a counter was greyed as a
      sitter. The server now says what each civilian is — in a knot, standing alone, holding
      which seat — and `test_crowd_groups.gd` checks the grey against the server's own tags.
- [x] **The grey keeps the persona readable** — half way to grey, not all the way: judged in
      `tools/blend_cue_probe.tscn`, where 70 % had washed the Lucerna's yellow out.
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
| `test/unit/systems/crowd/test_crowd_groups.gd`, `test/unit/server/test_crowd_group_announcer.gd`, `test/unit/core/blend/test_blend_cue_rules.gd`, `test/unit/presentation/vfx/test_blend_cues.gd` | The rule, the wire's recipients, the selection, the drawing |

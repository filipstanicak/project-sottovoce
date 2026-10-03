---
id: ADR-0025
title: The hunter picks the figure
version: 1.0.0
status: accepted
owner: Lead Game Designer
last_updated: 2026-10-02
depends_on: [ADR-0010, ADR-0013, ADR-0015, ADR-0021, GDD-03-SOCIAL-STEALTH, US-0103]
supersedes: none
---

# ADR-0025 — The hunter picks the figure

- **Status:** accepted. **Nothing is built here**; the build is US-0106, scheduled after US-0103.
- **Date:** 2026-10-02
- **Deciders:** owner. Owner decision 14, raised 2026-09-24 by the fidelity comparison and
  explained on 2026-10-02; the owner answered *"ja, wie im Original"*, to be built after the
  crowd learns to sit and gather — and made the scope explicit the same day: *"mache es genau
  so wie im Original"*. **Exactly as the reference, with no divergence of ours.**
- **Amends, once built:** GDD-03 §8 (the lock's reveal) and §10 (kill targeting); ADR-0013's kill
  rules; ADR-0015 (sight as a target filter); ADR-0010 (what the lag-compensation ring records);
  ADR-0021 (the portrait latch's meaning); UI_UX_SPEC's crosshair; NETWORK_PROTOCOL; US-0105's
  civilian line.
- **Related:** ADR-0021 (the face from assignment), ADR-0022 (the stun hint that names nobody,
  the same shape this needs for the kill ring), owner decision 15 (pursuer count).

## Context

**The game asks one question at the decisive moment — *which of these identical figures is the
human?* — and today the server answers it for the hunter twice.**

1. **The kill button chooses.** `KillRules.resolve` takes the **nearest player** in reach and
   cone. An NPC is never a candidate, so pressing kill into a group of clones lands on the
   contract whenever the contract is the nearest player. The hunter does not have to know which
   figure it is.
2. **The lock confirms.** Holding the contract in view for `TUN-COMPASS-LOCK-FILL-TIME` 1.6 s
   within `TUN-COMPASS-LOCK-RANGE` 20 m outlines **the true body** for
   `TUN-COMPASS-REVEAL-DURATION` 1.5 s.

That was defensible while the persona was hidden (ASM-0030). Since ADR-0021 the hunter knows the
persona from assignment, and since US-0101 the district is dressed, so *which persona* is read at
a glance and *which of the twelve* is the whole game — answered on the last metres by the server.
Design law 4 (patience must win) and law 6 (authored uncertainty) both lose there.

**The reference does the opposite.** Its sources are in the chat log of 2026-10-02, never here
(never-do #5):

- **the kill strikes the figure the hunter chose**, civilian or not, and **a civilian killed
  instead costs the contract and gives the killer away**: the contract mode's own sources say it
  breaks the contract and reveals the killer's position to the others (the review of #249 found
  this in the reference's multiplayer guide; a second source says the killer becomes easier to
  spot). Its free-for-all training mode adds that a civilian kill scores nothing;
- **the lock is a targeting act**: one locks onto a figure one is already sure of, and the kill
  goes to the locked figure until the lock is released. It confirms nothing. (Its co-op mode also
  focuses stun attempts on a locked pursuer; whether the contract mode does is item F below);
- **the help is the compass**, which glows while the contract is in sight — described there as
  the way to find the individual *instead of attacking a random persona*. Ours already glows
  (US-0105);
- **the prey is paid when the pursuer kills a clone of the prey's persona nearby**, and is told
  *"your pursuer killed a civilian"*.

## Decision

**The rule is the reference's, whole.** Where a detail of it is not yet sourced, US-0106 sources
it before building that part, and **nothing is filled in with a rule of ours**.

1. **The kill goes to the figure the hunter has selected**, as the reference selects it — by the
   lock where there is one, otherwise by its own targeting. Player or civilian alike.
2. **Civilians are killable.** A civilian killed instead **costs the hunter the contract and
   reveals the killer's position to the other players**, as the reference's contract mode does;
   how the reveal is shown is item A. The prey whose persona the civilian wore, if near, is paid
   the reference's bonus (+100) and told *your pursuer killed a civilian*.
3. **The lock is the reference's lock**: a targeting act with its own input — a quick press snaps
   to a running figure, holding and releasing picks one precisely — and **the kill goes to the
   locked figure** until it is released. Which other actions it governs is item F; until that is
   sourced, the stun keeps its own target. **It confirms nothing**: the 1.5 s outline of the true
   body goes. `SCORE-FOCUS` keeps the reference's meaning, a charged lock on the contract.
4. **The kill ring names nobody.** It lights when a selected figure is in reach, whoever it is —
   the shape ADR-0022 A gave the stun hint, for the same reason.
5. **The dash resolves as the reference's does** against everybody it meets, civilians included
   (ADR-0018 already recorded that the reference's version knocks civilians aside and ours passes
   through them untouched).
6. **Validation stays the server's.** The client sends *which figure it selected*; the server
   rewinds and judges reach, cone, sight and the rest as today. A selection is not a claim of an
   outcome, so never-do #2 holds — US-0106 states why in its wire row.

## What does not change

The kill's reach, cone and grace; the stun and its rules (the target is still your own pursuer);
the contested kill; the stealth ladder; the Compass's bearing, distance and glow.

## To source before building (not open for our own choice)

- **A. How the killer's position is revealed** after a civilian kill in the contract mode — the
  consequence is sourced (the review of #249); its representation and duration are not.
- **B. The radius** within which the prey is paid for a clone of theirs being killed.
- **C. How the reference targets without a lock**, exactly: which figure the kill prompt goes to.
- **D. What the dash does to a civilian it meets**: knocked down, or killed, and with what cost.
- **E. Whether a lock is visible to the locked figure** in the contract mode (the free-for-all
  mode lights a locked player up; the contract mode's sources do not say).
- **F. Which actions the lock governs** besides the kill — in particular whether a stun goes to a
  locked pursuer, as the co-op mode's sources say.
- **G. What a civilian kill scores** in the contract mode. *Nothing* is sourced only for the
  free-for-all mode.
- **H. How the crowd reacts to a civilian killed** — whether the reference's civilians gather,
  flee or ignore it. Our corpse, gawk and startle exist for players' kills; they apply to a
  civilian only as far as this answer says, because they change what the crowd tells a player.

Each answer is written into US-0106 with its source before the part that depends on it is built.

## What this costs, said plainly

| Area | Change |
|---|---|
| Kill targeting | A selected figure on the wire, `PROTOCOL_VERSION` 8; `KillRules` takes it instead of choosing |
| Civilians | A killable NPC, contract loss, the killer's position revealed, the prey's bonus and notice; the crowd's reaction per item H (our corpse, gawk and startle are built and used only as far as H says) |
| Lag compensation | NPCs recorded in the ring, which ADR-0010 wanted and US-0035/US-0060 left out for want of a reader; roughly 28 KB → 130 KB |
| Lock | Becomes the reference's selection, with its quick-press and hold-and-release input; the reveal and its cooldown go; the portrait latch narrows again |
| Crosshair | `kill_ready` lit for any selected figure in reach — never *is it the contract* |
| The dash | Meets civilians as the reference's does, instead of passing through them |
| Tests | The kill suites assume the nearest-player rule throughout |

**About one ADR and five to eight PRs.** The risk is real: hunting becomes much harder for new
players, and while figures have no animation a human can be told from a clone almost only by
behaviour. That is the reference's game, and the reason it waits for US-0103 — a crowd that sits
and gathers gives the read something to work with.

## Consequences

- Owner decision 14 is **settled**.
- US-0105's *"your pursuer killed a civilian"* line is unblocked by decision and blocked by
  US-0106's build.
- US-0035's and US-0060's NPC-rewind criteria gain a reader.

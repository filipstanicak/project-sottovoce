---
id: DOC-GLOSSARY
title: Glossary — Canonical Terminology
version: 0.1.0
status: draft
owner: Documentation Architect
last_updated: 2026-08-03
depends_on: []
---

# Glossary — Canonical Terminology

This document is written before all others and depends on nothing. Every other document in
this corpus uses these terms with exactly these meanings. If you need a word that is not
here, add it here first.

**Rule:** a term defined in this glossary is never redefined elsewhere, and never used in a
looser sense. If a document needs a narrower concept, it coins a new term here.

**Naming rule:** every in-fiction name in this project is original. See
[`IP_GUARDRAILS.md`](IP_GUARDRAILS.md). Where a term has an in-fiction name and a
functional description, the **original name is listed first** and the functional
description follows.

---

## A

### Anonymity
The state of being visually indistinguishable, to another player, from an AI civilian. It
is not a binary: it is the observable consequence of being in the **Anonymous** suspicion
tier while your persona has living **doppelgängers** nearby. Anonymity is the resource the
entire game economy is denominated in. Speed spends it; patience refunds it.

### Anonymous (tier)
The lowest **suspicion tier**: `suspicion < TUN-SUSPICION-TIER-NOTICED`. While Anonymous
you render to every other player exactly as an NPC of your persona does — no tint, no
outline, no compass silhouette. See [`../10_gdd/03_social_stealth.md`](../10_gdd/03_social_stealth.md) §2.

### Ability
A player-activated verb on a cooldown, defined by an `AbilityData` resource and identified
by an `ABIL-` ID. MVP set: **Cinderfall**, **Whisperbolt**, **Second Face**, **Lunge**.
Every ability must have a **tell**. See [`../10_gdd/04_abilities.md`](../10_gdd/04_abilities.md).

### ADR (Architecture Decision Record)
A numbered, immutable document in `docs/00_meta/adr/` recording one decision: its context,
the options considered, the decision, and its consequences. Required whenever a decision
constrains future work or adds something outside the **scope fence**. Indexed in
[`DECISION_LOG.md`](DECISION_LOG.md).

### Archetype (NPC)
A non-playable civilian behaviour-and-appearance template. Distinct from a **persona**: no
player can ever look like an archetype. Archetypes are **filler** crowd. See **filler**.

---

## B

### Blend action
A discrete, positional action that crushes **suspicion** to zero over
`TUN-BLEND-CRUSH-TIME`. MVP blend actions: joining a **walking group**, sitting on a bench,
entering a concealment prop (hay cart, well, wardrobe), and standing still inside a market
**crowd pocket**. Blend actions are the game's primary defensive verb.

### Blend-walk
The slowest locomotion state (`TUN-SPEED-BLENDWALK`). Matches NPC stroll speed exactly.
Generates no suspicion. The default state a competent player spends most of a match in.

### Blended (state)
The pawn state entered while a **blend action** is active. The player is stationary or
group-locked, suspicion is being crushed, and the **Blended** score bonus is armed.

### Bonus
A named, scoring modifier applied to a **kill**, identified by a `SCORE-` ID. Bonuses stack.
The full table is in [`../10_gdd/07_balance.md`](../10_gdd/07_balance.md) §3. Bonuses are the
game's teaching mechanism: they name good play out loud in the **score feed** at the moment
it happens.

---

## C

### Cantatrice
**PERSONA-CANTATRICE.** The Street Singer. One of the four MVP **personas**. Silhouette: a
wide bell skirt and a tall coiled headdress — the widest-at-the-floor silhouette in the
cast. See [`../30_bible/ART_BIBLE.md`](../30_bible/ART_BIBLE.md).

### Cinderfall
**ABIL-CINDERFALL.** The area-denial ability. Throws a fired ash-pot that blocks line of
sight and forbids kill initiation inside its radius. Loud: costs
`TUN-SUSPICION-GAIN-LOUD-ABILITY`. Exists to give a punished attacker exactly one escape.

### Clone
An NPC instance that uses a **persona**'s mesh, materials and animation set — visually
identical to a player using that persona. Each persona has
`TUN-CROWD-CLONES-PER-PERSONA-MIN`–`MAX` clones alive at any time. Clones are the substrate
of **anonymity**; without them the game does not exist.

### Clone parity
The hard constraint that a **clone** must be able to perform every animation a player
performs in an anonymous state. Any animation a player has that its clones do not is an
**anonymity leak** and is a bug. Enforced by a table in
[`../30_bible/ANIMATION_SPEC.md`](../30_bible/ANIMATION_SPEC.md) and an automated test.

### Cold Read
**PASV-COLDREAD.** A passive: the **Compass** lock arc fills 30 % faster.

### Compass
**SYS-COMPASS.** The game's central instrument. A radial HUD element indicating the
*direction* and *proximity* of your **contract**, never its exact position. It gives a
direction cone and a distance-mapped **pulse**. It also flashes red and stings when your
**pursuer** is detected as suspicious near you — the prey's only warning. Full specification
in [`../10_gdd/03_social_stealth.md`](../10_gdd/03_social_stealth.md) §8 and
[`../30_bible/UI_UX_SPEC.md`](../30_bible/UI_UX_SPEC.md) §5.

### Contest window
`TUN-KILL-CONTEST-WINDOW`. If two players initiate a **kill** on the same victim within this
window, the earlier *server* timestamp wins; the loser is **staggered**.

### Contract
The single other player you are assigned to kill. You hold exactly one contract at a time,
and exactly one other player holds a contract on you. See **contract cycle**.

### Contract cycle
**SYS-CONTRACT.** The directed graph of contracts across all living players. It is
maintained as a single **Hamiltonian cycle**: every living player has exactly one outgoing
contract and one incoming contract, and the graph is one cycle rather than several disjoint
ones. The server maintains and repairs it on kill, disconnect and join. Algorithm and
validity proof in [`../10_gdd/03_social_stealth.md`](../10_gdd/03_social_stealth.md) §7.

### Contract lockout
A period after a successful **stun** during which the stunned hunter cannot re-initiate a
kill on the player who stunned them. Duration `TUN-STUN-LOCKOUT`.

### Corpse
The body left by a **kill**, persisting for `TUN-CORPSE-LIFETIME`. Corpses attract **Gawk**
crowds. A corpse is a deliberate information object, not a decoration.

### Crowd pocket
A level-design module: a bounded volume of standing NPCs dense enough that a stationary
player inside it is unreadable. The standard module's dimensions and NPC count are specified
in [`../10_gdd/05_level_design.md`](../10_gdd/05_level_design.md) §4.

---

## D

### Doppelgänger
Synonym for **clone**. Prefer "clone" in technical documents; "doppelgänger" is acceptable
in the vision chapter only.

### Detection
**SYS-DETECTION.** The server-side resolution of who can see whom, at what fidelity. Detection
consumes **suspicion** tier, distance, line of sight and facing, and produces the
per-observer render state of every player. Never client-authoritative.

---

## E

### Event bus
**SYS-EVENTBUS.** A single autoload through which systems announce facts to the presentation
layer. One-way: systems emit, presentation listens. A widget never reads a gameplay node.
Catalogue in [`../30_bible/SIGNAL_AND_EVENT_BUS.md`](../30_bible/SIGNAL_AND_EVENT_BUS.md).

### Exposed (tier)
The highest **suspicion tier**: `suspicion >= TUN-SUSPICION-TIER-EXPOSED`. You render with a
hard silhouette to your **pursuer**, their **Compass** locks on you freely, and — critically
— *your own prey is warned about you*. Exposed is a punishment state, not a stealth state.

---

## F

### Filler
An NPC using a non-playable **archetype**. Filler NPCs make the crowd feel like a city
rather than a police lineup of four repeated silhouettes. No player can be mistaken for
filler, and filler cannot be mistaken for a player.

### Final Contract
The last `TUN-MATCH-FINALPHASE` seconds of a match, during which all score is multiplied by
`TUN-MATCH-FINALPHASE-MULT`. It exists so that a trailing player has a live comeback path
and the match has an ending rather than a stop.

---

## G

### Gawk
An NPC behaviour: civilians within radius of a fresh **corpse** crowd around it for
`TUN-CROWD-GAWK-DURATION`. A free, diegetic "someone died here" signal readable from
distance by any player.

---

## H

### Hamiltonian cycle
A cycle in a directed graph that visits every node exactly once and returns to its start.
The **contract cycle** is maintained as one. This guarantees (a) nobody is assigned
themselves, (b) nobody is hunted by two people, (c) nobody is unhunted, and (d) the hunt
graph has no isolated pairs trading kills. See the proof in
[`../10_gdd/03_social_stealth.md`](../10_gdd/03_social_stealth.md) §7.4.

### Hunter
The role you occupy with respect to your **contract**. Every player is always simultaneously
a hunter and **prey**.

### Hysteresis
The deliberate gap between the suspicion value that raises you into a tier and the value that
drops you back out (`TUN-SUSPICION-HYSTERESIS`). Prevents visual tier flicker at threshold
boundaries, which would be both ugly and an unreliable information channel.

---

## I

### Information channel
Any mechanism by which one player learns something about another: **Compass** pulse,
silhouette tint, NPC **Startle**, corpse **Gawk**, ability **tell**, footstep audio, HUD
sting. The complete table — channel, receiver, latency, reliability — is the master system
diagram of this game. See [`../10_gdd/03_social_stealth.md`](../10_gdd/03_social_stealth.md) §11.

### Initiate (a kill)
Pressing the kill input while the validity conditions hold. Initiation begins the
`TUN-KILL-ANIM-DURATION` committed animation. The moment of initiation — not the moment of
death — is what bonus conditions are evaluated against.

---

## K

### Kill
**SYS-KILL.** The act of eliminating your **contract**. Requires range
`TUN-KILL-RANGE`, facing within `TUN-KILL-FACING-CONE`, and the kill input. Plays a committed
animation during which the killer is fully visible and vulnerable.

---

## L

### Legibility
Design pillar: the player must be able to *read* what happened and why. Every ability has a
**tell**; every score bonus is named at the moment it is earned; every death has a visible
cause. A social-stealth game where players cannot reconstruct events is a slot machine.

### Lock (compass)
The **Compass** fills a lock arc while your **contract** is inside `TUN-COMPASS-LOCK-CONE` of
your facing, within `TUN-COMPASS-LOCK-RANGE`, with line of sight. A completed lock reveals a
soft silhouette highlight for `TUN-COMPASS-REVEAL-DURATION`.

### Loadout
The pre-match-locked selection of two **abilities** and one **passive**. Locked at match
start so that reading an opponent's kit is a durable skill rather than a moving target.

### Lucerna
**PERSONA-LUCERNA.** The Lamp-Tender. One of four MVP **personas**. Silhouette: a tall hooded
cloak with a long wick-pole — the tallest, thinnest silhouette, with a distinctive line
above the head.

### Lunge
**ABIL-LUNGE.** A 6 m committed dash that ends in a kill. Loud, stunnable throughout, high
suspicion cost. Exists as the "I have been made, commit now" button.

---

## M

### Masked
**SCORE-MASKED.** A bonus: the kill happened while a disguise ability (**Second Face**) was
active.

### Match
One 8-minute round: lobby → countdown → play → **Final Contract** → results. Free-for-all.
Score, not kills, decides the winner.

---

## N

### Noticed (tier)
The middle **suspicion tier**:
`TUN-SUSPICION-TIER-NOTICED <= suspicion < TUN-SUSPICION-TIER-EXPOSED`. Your silhouette
faintly tints *for the player who holds you as a contract only*. Not a global broadcast.

---

## P

### Passive
A permanently-active loadout slot with no input. MVP set: **Stillness**, **Cold Read**,
**Second Wind**. One equipped.

### Patient
**SCORE-PATIENT.** A bonus: you never exceeded `TUN-SCORE-PATIENT-SPEED` (3.4 m/s) in the 10 s before the kill. That was the Jog rung's speed until the rung was deprecated on 2026-08-12; the threshold outlived the state. The
single most important bonus in the game — it is the thesis, priced.

### Persona
One of the four playable character templates. MVP: **Vetraio**, **Cantatrice**, **Lucerna**,
**Pesatore**. Each persona has `TUN-CROWD-CLONES-PER-PERSONA-MIN`–`MAX` **clones** in the
crowd. A persona must be identifiable from its silhouette alone at 40 m.

### Pesatore
**PERSONA-PESATORE.** The Weighmaster. One of four MVP **personas**. Silhouette: a rounded
robe, flat cap, and a ledger box carried under one arm — the rounded mid-height silhouette.

### Prey
The role you occupy with respect to your **pursuer**. You do not know who your pursuer is.

### Pulse
The **Compass**'s rhythmic beat, whose *cadence* encodes distance to your **contract**:
`TUN-COMPASS-PULSE-MAX` at maximum range down to `TUN-COMPASS-PULSE-MIN` at zero. The curve
is ease-in, not linear — the last 15 m must feel categorically different from 40 m.

### Pursuer
The player who holds you as their **contract**. Unknown to you unless they become
**Exposed** near you, at which point your Compass warns you.

---

## R

### Reckless
**SCORE-RECKLESS.** The only score *penalty*: killing while **Exposed**. Exists so that a
successful sprint-kill is still a bad trade.

### Rione Vetraio
**MAP-VETRAIO.** The Glassmakers' Quarter — the single MVP map, a district of the fictional
city of **Vessalia**. ~120 × 120 m playable, three vertical strata.

---

## S

### Score event
**SCORE-EVENT.** An immutable record appended to the server's event log whenever anything
scoreable happens. The scoreboard is a fold over this log. This makes scoring unit-testable
and the results screen a pure function of the log. See
[`../20_tdd/10_scoring_and_match_state.md`](../20_tdd/10_scoring_and_match_state.md).

### Score feed
The scrolling HUD list of score events. It is the game's teacher: it names good play at the
instant it occurs, in the player's peripheral vision.

### Second Face
**ABIL-SECONDFACE.** The disguise ability: adopt another persona's appearance for a duration.
Broken by sprinting or being hit. Exists to reward reading the crowd.

### Second Wind
**PASV-SECONDWIND.** A passive: **contract lockout** after being stunned is reduced by 4 s.

### Silent
**SCORE-SILENT.** A bonus: suspicion was in the **Anonymous** tier at the moment of kill
initiation.

### Stagger
A brief loss of control that is *not* a **stun**: no score is awarded to anyone, no lockout
applies. Used for losing a **contest window** and for **stun** misuse.

### Startle
An NPC behaviour: civilians near violence or a sprinting player flee for
`TUN-CROWD-STARTLE-DURATION`. A startle wave is a visible, directional, second-hand signal
that a player moved badly somewhere nearby.

### Stillness
**PASV-STILLNESS.** A passive: suspicion decays 40 % faster while stationary.

### Stun
**SYS-STUN.** The prey's counterplay. If your **pursuer** is **Noticed** or **Exposed** and
within `TUN-STUN-RANGE`, you may stun them: `TUN-STUN-SCORE` points to you, `TUN-STUN-FREEZE`
of frozen helplessness for them, a `TUN-STUN-LOCKOUT` **contract lockout**, and they are
forced to **Exposed**. Stun is the mechanic that makes recklessness fatal and must never be
tuned below "hard-counters a sprinting attacker".

### Stun spam
The degenerate strategy of stunning strangers on the chance one of them is your pursuer.
Punished: stunning a non-pursuer awards 0 points and self-**staggers** you for
`TUN-STUN-INVALID-STAGGER`.

### Suspicion
**SYS-SUSPICION.** A hidden per-player scalar in [0, 100] measuring how unlike an NPC you
currently look. Decays at `TUN-SUSPICION-DECAY-BASE` while walking or idle. Drives the three
**suspicion tiers**. The full source/decay table is in
[`../10_gdd/03_social_stealth.md`](../10_gdd/03_social_stealth.md) §3.

### Suspicion tier
One of **Anonymous**, **Noticed**, **Exposed**. Tiers, not the raw value, are what other
players perceive. Tier transitions apply **hysteresis**.

---

## T

### Tell
The mandatory, perceivable signal that an ability is being used, perceivable *by the victim*
in time to react. The **legibility law**: no ability ships without a tell. A tell has a
visual component, an audio component, or both, specified per ability in
[`../10_gdd/04_abilities.md`](../10_gdd/04_abilities.md).

### Theatre space
A level-design construct: an area where a chase between two players is visible to a third.
Theatre spaces are how players learn the game by watching, and how a match generates shared
stories. At least two are required per map.

### Tunable
A named gameplay constant with a `TUN-` ID, a value, a unit, a legal range and a one-line
rationale, defined exactly once in [`../50_tuning/TUNABLES.md`](../50_tuning/TUNABLES.md) and
stored at runtime in a `TuningProfile` resource. **No gameplay constant is ever written as a
literal in a script.**

---

## V

### Vessalia
The fictional Renaissance-Italian city in which the game is set. Original name. The MVP map
is one of its districts, **Rione Vetraio**.

### Vetraio
**PERSONA-VETRAIO.** The Glasswright. One of four MVP **personas**. Silhouette: squat and
broad-shouldered, leather apron, goggles pushed up on the brow — the low, wide silhouette.

---

## W

### Walking group
Four NPCs moving in loose formation along a circuit. A player may join one as a **blend
action**, matching its pace and formation slot. Walking groups are mobile cover — the only
way to travel across the map while gaining anonymity rather than spending it.

### Whisperbolt
**ABIL-WHISPERBOLT.** The thrown-blade ability: a ranged kill at 3–12 m requiring a 1.0 s
wind-up during which the thrower is forced **Exposed**. Exists to punish rooftop campers.

---

## Appendix A — ID namespaces at a glance

Full grammar, regexes and immutability rules are in
[`../30_bible/NAMING_AND_IDS.md`](../30_bible/NAMING_AND_IDS.md).

| Prefix | Namespace | Example |
|---|---|---|
| `SYS-` | Gameplay system | `SYS-COMPASS`, `SYS-PROFILE` |
| `TUN-` | Tunable constant | `TUN-SUSPICION-DECAY-BASE` |
| `SCORE-` | Score event type | `SCORE-BLENDED` |
| `ABIL-` | Ability | `ABIL-CINDERFALL` |
| `PASV-` | Passive | `PASV-STILLNESS` |
| `PERSONA-` | Playable persona | `PERSONA-VETRAIO` |
| `ARCH-` | NPC filler archetype | `ARCH-PORTER` |
| `MAP-` | Map | `MAP-VETRAIO` |
| `NET-` | Network message | `NET-C2S-INPUT` |
| `SFX-` / `MUS-` | Audio event | `SFX-STUN-SUCCESS` |
| `ANIM-` | Animation clip | `ANIM-BLENDWALK-LOOP` |
| `EVT-` | Event-bus signal | `EVT-SUSPICION-TIER-CHANGED` |
| `US-` | User story | `US-0042` |
| `ADR-` | Decision record | `ADR-0003` |
| `RISK-` | Risk register entry | `RISK-CROWD-PERF` |
| `ASM-` | Logged assumption | `ASM-0007` |

---

## Appendix B — Terms deliberately *not* used

These words are banned or discouraged, with the required replacement.

| Do not write | Write instead | Why |
|---|---|---|
| Any term from the banned list in [`IP_GUARDRAILS.md`](IP_GUARDRAILS.md) | The original name | Legal. Non-negotiable. |
| "smoke bomb" | **Cinderfall** | Functional-original naming rule. |
| "throwing knife" | **Whisperbolt** | Same. |
| "disguise" (as a proper noun) | **Second Face** | Same. "disguise" as a common noun is fine. |
| "detection meter", "awareness" | **suspicion** | One name per concept. |
| "target" (as a game term) | **contract** | "target" is overloaded with aiming. |
| "stealth kill" | **Silent kill**, or cite `SCORE-SILENT` | Bonuses are named things. |
| "immersive", "AAA", "revolutionary" | *(delete the sentence)* | It does not change an implementation decision. |

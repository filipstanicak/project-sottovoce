---
id: BIBLE-RISK-REGISTER
title: Risk Register
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0001, ADR-0002, ADR-0007, BIBLE-PERF-BUDGET, BIBLE-DOD, GDD-08-FUTURE]
---

# Risk Register

> **Scoring.** Probability and impact are Low / Medium / High. **Exposure** = the product, and it
> orders the register. Every risk has a named **trigger** (the observable that says it is
> happening), a **mitigation** (what is already in place), and a **response** (what to do when it
> fires). A risk with no trigger is a worry, not a risk.

---

## 1. Summary

| ID | Risk | Prob | Impact | Exposure | First measurable |
|---|---|---|---|---|---|
| `RISK-POPULATION` | Nobody can assemble a lobby | **High** | **High** | **Critical** | M6 |
| `RISK-CROWD-PERF` | 90 NPCs do not fit 2.0 ms | **Medium** | **High** | **High** | M3 — **re-scored at the gate: the SERVER half is measured and comfortable; the CLIENT half, which is where the 0.10 ms margin lives, has never been measured and cannot be** |
| `RISK-NETCODE` | Prediction/reconciliation instability | Medium | Medium | Medium | M2 — **re-scored down at the gate** |
| `RISK-AGENT-DRIFT` | Docs and code diverge | **High** | Medium | **High** | Continuous |
| `RISK-NOT-FUN-SOLO` | The loop needs 6 humans to be fun | Medium | **High** | **High** | M4 |
| `RISK-ANIM-SCOPE` | Clone parity doubles animation cost | **High** | Medium | **High** | M3 — **re-scored UP at the gate: zero clips exist on either rig, and three stories are blocked behind that** |
| `RISK-BALANCE-UNFALSIFIABLE` | Too few playtests to settle the model | **High** | Low | Medium | M6 |
| `RISK-ART-SCOPE` | Art exceeds a small team's capacity | Medium | Medium | Medium | M6 |
| `RISK-ANONYMITY-LEAK` | A silent discriminator ships | **Medium** | **High** | **High** | M3 — **re-scored UP at the gate: a live instance is in the map data, not hypothetical** |
| `RISK-BANDWIDTH` | Upstream/downstream budgets missed | **High** | **Medium** | **High** | M3 — **re-scored UP again at the M3 gate: DOWNSTREAM is 112 %, measured. Upstream is 145 %** |
| `RISK-IP` | A franchise term or asset reaches a public build | Low | **High** | Medium | Continuous |
| `RISK-SCOPE-CREEP` | The fence erodes | Medium | Medium | Medium | Continuous |

---

## 2. `RISK-POPULATION` — nobody can assemble a lobby

| | |
|---|---|
| **Probability** | High |
| **Impact** | High — the game is unplayable, regardless of quality |
| **Exposure** | **Critical. The project's defining risk.** |

**Why.** Social stealth needs 4–6 simultaneous humans; there is no single-player mode and no
asynchronous version. Historically the genre has succeeded **only** when attached to a large
product that supplied population for free, and died every time that product's population moved
on. We have no such product. Cold-start failure is self-accelerating: a player who queues and
finds nobody does not queue again.

**Trigger.** `TEL-LOBBY-FILL-TIME` median > 10 minutes, or lobbies routinely abandoned.

**Mitigations already in the design** — these are in the MVP *because* of this risk, not
incidentally:

| Mitigation | |
|---|---|
| 4 players is a **supported configuration**, not a degraded one | Crowd, compass range and map area all scale. Four humans is a far easier ask than six |
| Direct IP before matchmaking | Matchmaking is a multiplier on an existing population; applied to zero it yields zero, and it fails *silently* |
| 8-minute matches | A filled lobby is worth assembling; a bad match is cheap |
| No accounts, no progression | Zero re-entry friction after six months away |

**Response, in cost order:** private lobby codes (cheapest, highest ratio) → make 4-player
genuinely good → a practice district so an unfillable lobby is not a closed game → scheduled
community sessions → bots → matchmaking last.

**The honest position:** this may be fatal for a standalone game in this genre, and
[`../10_gdd/08_liveops_and_future.md`](../10_gdd/08_liveops_and_future.md) §4.7 treats the metric
as a genuine decision point rather than a formality.

---

## 3. `RISK-CROWD-PERF` — 90 NPCs do not fit 2.0 ms

| | |
|---|---|
| **Probability** | Medium — unchanged, and the reason is worth reading |
| **Impact** | High — crowd density is the game's substrate |
| **Exposure** | High |

> **RE-SCORED AT THE M3 GATE (US-0048), AND IT DID NOT MOVE — BUT WHAT IT MEANS DID.** ADR-0001's
> assumption has now been measured on the **server** and it is comfortable:
> `CrowdDirector.tick()` runs at **0.52 ms mean, 0.59–0.64 p95, 1.26–1.29 max** against §11.2's
> 1.75 ms, with a full physics frame at 16.73 ms against a 16.67 ms deadline.
>
> **THE 0.10 MS MARGIN IS NOT ON THE SERVER, AND THAT HALF IS STILL UNMEASURED.** §11.1's client
> budget is animation-dominated — 1.20 ms of its 1.90 is `AnimationTree` updates — and there is no
> `NpcView`, no mesh and no `AnimationTree` in the project. Any client figure today would measure
> the absence of the expensive part, which is why `test_crowd_perf.gd` asserts that absence
> explicitly and goes red the day `npc_view.tscn` lands.
>
> **So the probability stays Medium on the strength of the half that has not been measured**, and
> rounding it down on the half that has would be exactly the mistake the M2 gate refused.

**Why.** 90 animated agents in GDScript inside `TUN-PERF-CROWD-BUDGET` 2.0 ms/frame is the
hardest technical requirement in the project. Current allocation leaves **0.10 ms of margin** —
the tightest in the corpus.

**Trigger.** `test_crowd_perf.gd` fails, or p99 frame time exceeds 16.6 ms in the standard
scenario.

**Mitigations.** Update-rate LOD (**measured at 46 effective brain updates per tick of 78, not the ~34 of 90 this line assumed** — a 1.7×, not a 2.6×
reduction); flat HFSM rather than behaviour trees; zero allocation in `step()`; a shared spatial
hash serving four consumers; server-side simulation only, so clients pay animation cost alone.

**Response — the pre-decided ladder** ([`PERFORMANCE_BUDGET.md`](PERFORMANCE_BUDGET.md) §6):
coarsen LOD bands → reduce Mid-band fidelity → Far-band impostors → `Steering` to C#/GDExtension
→ **reduce crowd count last, never below 60**.

> Reducing crowd count is first in most people's instincts and last on the ladder on purpose. It
> trades the design's identity for frame time. If the ladder is exhausted and 60 will not fit,
> that is an **ADR-0001 revisit** — engine and language — not a design compromise.

---

## 4. `RISK-NETCODE` — prediction and reconciliation instability

| | |
|---|---|
| **Probability** | **Medium** — was High. Re-scored at the M2 gate, 2026-08-15 |
| **Impact** | Medium — recoverable, but expensive |
| **Exposure** | **Medium** — was High |

> **RE-SCORED AT THE M2 GATE (US-0038).** Prediction and reconciliation are built and converge at
> all four latency profiles, and the measured reconciliation error between a client and the server
> for the same command is **0.00000 m** — the two peers run identical code from identical inputs,
> so *being late is not the same as being wrong*. Measured replays under ordinary play: **zero at
> every profile.**
>
> Probability drops because the hard part is done and instrumented, not because the code is
> assumed good. **Impact is unchanged**: the consumers that make positional error matter — kill,
> stun, contest resolution — are all M4, so nothing has yet *depended* on this being right. The
> risk stops falling here until something does.

**Why.** Client prediction with server reconciliation is the highest-bug-density code in the
project. The game is decided at 2.5 m inside 0.4 s windows, so small positional errors change
outcomes.

**Trigger.** `test_prediction_reconciliation.gd` failing at any latency profile; players
reporting rubber-banding; disputed kills above ~2 % (`TEL-CONTEST-RESOLVED`).

**Mitigations.** Prediction confined to **one system** (the pawn's movement) so the hard part
lives in one file; `PawnState.step()` is a pure function enforced by grep; the simulation snaps
while the visual blends, so error converges rather than compounding; a four-profile latency
matrix in CI; a `noprediction` debug command — **the only way to tell a feel bug from a
prediction bug**.

**Response.** If traversal states prove unstable, make Vault/Mantle/Drop **server-confirmed
rather than predicted**, accepting latency on those manoeuvres only. That is a scoped retreat,
already identified, not a redesign.

---

## 5. `RISK-AGENT-DRIFT` — documentation and code diverge

| | |
|---|---|
| **Probability** | High |
| **Impact** | Medium, compounding |
| **Exposure** | High |

**Why.** This project is built on the premise that an agent with no memory can read the corpus
and trust it. **Drifted documentation is worse than absent documentation, because it is
confidently wrong** — and it misleads precisely the reader most dependent on it.

**Trigger.** `test_tuning_docs_sync.gd` or `test_protocol_docs_sync.gd` failing; a document
describing behaviour the code does not have; an agent implementing from a stale doc.

**Mitigations.**

| Mechanism | Catches |
|---|---|
| `test_tuning_docs_sync.gd` | Bidirectional `TUN-` ID drift — **the primary defence** |
| `test_protocol_docs_sync.gd` | The two message catalogues diverging |
| `test_ids_match_glossary.gd` | ID drift |
| `test_claude_md_synced.gd` | The root brief drifting from its seed |
| **The DoD docs-sync item** | Everything else: *if your change made a document wrong, fix it in the same commit* |
| ASM-0028 | No document passes `draft` until a milestone has exercised it — a `draft` doc invites correction, a `locked` one invites silent divergence |

**Response.** If drift is found, fix the document **first**, then decide whether the code was
wrong. Never fix code to match a stale doc without checking which one is right.

---

## 6. `RISK-NOT-FUN-SOLO` — the loop needs six humans to be fun

| | |
|---|---|
| **Probability** | Medium |
| **Impact** | High |
| **Exposure** | High |

**Why.** Compounds `RISK-POPULATION`. If the game is only good at exactly six, every population
problem doubles. It also means M4's playable loop cannot be evaluated until six people are
assembled — slowing every design decision downstream.

**Trigger.** Playtest question 12 ("would you play again tonight?") below 70 % at 4 players while
passing at 6.

**Mitigations.** 4-player scaling is designed rather than degraded; the contract cycle's
information properties are analysed at every count
([`../10_gdd/07_balance.md`](../10_gdd/07_balance.md) §7.2); `TUN-LOBBY-MIN-PLAYERS` is 4.

**Response.** If 4-player is materially worse, the honest options are to make 4 the design centre
(the single biggest population lever available — [`../10_gdd/08_liveops_and_future.md`](../10_gdd/08_liveops_and_future.md)
§9.2) or to accept a 6-player-only game and treat population as existential.

---

## 7. `RISK-ANIM-SCOPE` — clone parity doubles animation cost

| | |
|---|---|
| **Probability** | **High** — was Medium. Re-scored at the M3 gate, 2026-08-18 |
| **Impact** | Medium |
| **Exposure** | **High** — was Medium |

> **RE-SCORED UP AT THE M3 GATE (US-0048): THE COUNT OF CLIPS IN THIS PROJECT IS ZERO.** Not "the
> parity set is incomplete" — there is no clip on either rig, and M3 is otherwise finished. That
> is not a slip against a schedule, it is a body of work nobody has started, and **three stories
> are already blocked behind it**: US-0046's layers 2 and 3, US-0045's three client-LOD lines, and
> US-0024's input→animation measurement, which has been open since M1.
>
> Probability moves to High because the mitigation below — "greybox primitives are sufficient to
> playtest the entire anonymity system" — is now doing more work than it can bear: greybox
> primitives are sufficient to playtest *movement*, and the anonymity system's two animation
> layers cannot be playtested with no animation at all.

**Why.** The 14-clip parity set must exist **twice** — player rig and clone rig — and match
exactly. 56 clips of the ~195 total carry a 2× multiplier. A fifth persona costs **+14 clips × 2
rigs, minimum**.

**Trigger.** Animation work slipping M3; pressure to share a "close enough" clip between rigs.

**Mitigations.** The parity boundary is precise and *bounded* — parity is required only for
animations reachable while Anonymous, which is exactly the suspicion cliff at stroll speed.
Everything above it (run, sprint, climb, combat) needs no clone equivalent. Four personas, not
six. Greybox primitives are sufficient to playtest the entire anonymity system.

**Response.** Reduce idle variations from four to two (halves the most expensive part of the
parity set) before reducing personas. **Never** ship a player-only animation reachable while
Anonymous — that is `RISK-ANONYMITY-LEAK`.

---

## 8. `RISK-BALANCE-UNFALSIFIABLE` — too few playtests to settle the model

| | |
|---|---|
| **Probability** | High |
| **Impact** | Low — the game still ships |
| **Exposure** | Medium |

**Why.** The balance model predicts patience beats aggression ~2.5×, above the ~60 % design
target. Three external playtests (the M6 exit criterion) is ~18 player-matches — enough for hunt
duration and life length, **almost certainly not enough** for the 1.5–3.5× band on the key
prediction.

**Trigger.** M6 reached with prediction 4 still unresolved.

**Mitigations.** Eight predictions with explicit bands; archetypes classified by *measured*
`TEL-MEAN-SPEED` rather than self-report; the re-fold procedure lets archived matches be re-scored
under candidate values as a pure function; the lever list is pre-ordered so a response does not
need re-deriving.

**Response.** Raise the playtest count, or accept prediction 4 stays open past M6 and ship the
brief's values. **Do not** tune against a model whose inputs are still guesses — that replaces a
defensible starting point with an undefensible one.

---

## 9. `RISK-ART-SCOPE` — art exceeds a small team's capacity

| | |
|---|---|
| **Probability** | Medium |
| **Impact** | Medium |
| **Exposure** | Medium |

**Why.** Four personas × 2 rigs, five filler archetypes, a 120 × 120 m district, ~195 animations,
and a colour-language law constraining every environment texture.

**Trigger.** M6 approaching with the map still greybox and no art pipeline validated.

**Mitigations.** The art gate — **no art begins until the greybox map has been playtested and the
loop is fun on it**. Greybox primitives pass the silhouette test, so art is polish rather than
rescue. Shared atlases and a shared material per persona. `SCOPE_FENCE` §5 explicitly permits
shipping at "legible placeholder" fidelity.

**Response.** Ship greybox. The MVP's question is *is the loop fun with six humans*, and greybox
answers it. An unpolished game that answers the question beats a polished one that never gets
asked.

---

## 10. `RISK-ANONYMITY-LEAK` — a silent discriminator ships

| | |
|---|---|
| **Probability** | **Medium** — was Low. Re-scored at the M3 gate, 2026-08-18 |
| **Impact** | **High** — it breaks the core promise |
| **Exposure** | **High** — was Medium |

> **RE-SCORED UP AT THE M3 GATE (US-0048): THERE IS A LIVE INSTANCE, AND IT IS IN THE LEVEL DATA.**
> This risk was written about an animator adding a clip. The instance that actually arrived is
> geometric and was found by US-0096: **three of `MAP-VETRAIO`'s six spawn points cannot hold
> `TUN-CROWD-CLONE-LOCAL-MIN`**, and **(114, 97.5) can see no NPC at all**. A player spawning
> there begins alone, uniquely identifiable, and on open ground for `TUN-SUSPICION-GAIN-OPEN`
> before they can move.
>
> It is a **release blocker** against GDD-03 §6.3 rule 3, it is the **idle anchors** that fail it
> rather than any code, and `tools/anchor_census.gd` grades a change to them in one run.
> Probability moves off Low because this is no longer hypothetical.
>
> **AND THE FOUR-LAYER MITIGATION IS TWO LAYERS SHORT.** Layers 2 and 3 are animation parity, and
> there are **no animation clips in this project on either rig** — see `RISK-ANIM-SCOPE`, which
> moved up for the same reason. A defence-in-depth argument with half its depth unbuilt is worth
> saying out loud rather than counting.

**Why.** This is the failure mode that **fails silently**. An animator adds a charming idle
variation on the player rig; nothing breaks, no test fails, crowd count is unchanged. Three weeks
later skilled testers pick humans out reliably and cannot say why. The design looks broken; the
balance model looks wrong; the cause is one 40-frame clip.

**Trigger.** `test_clone_animation_parity.gd` or `test_footstep_parity.gd` failing; playtesters
identifying players "somehow"; `TEL-FIRST-CONTACT-OUTCOME` above 40 % correct identification.

**Mitigations — four independent layers**, because a single check gets deleted eventually:

| # | Layer | Catches |
|---|---|---|
| 1 | `PersonaData.anonymous_clip_names` declares the parity set | Authoring drift |
| 2 | `test_clone_animation_parity.gd` | A player animation with no clone equivalent |
| 3 | Debug runtime assert on entering an Anonymous-reachable state | A state playing an off-list clip |
| 4 | `TUN-CROWD-CLONE-LOCAL-MIN` | **Local depletion** — global sufficiency with a local hole. Built, US-0047 (`CloneBalance`, the 2 s director pass) and US-0096 (the opening arrangement) |

Plus `test_footstep_parity.gd` for the audio equivalent, and the no-per-instance-variation rule.

> **A LIVE INSTANCE OF THIS RISK IS OPEN, AND IT IS THE LEVEL'S.** US-0096 measured how many NPC
> seats each spawn point can see within `TUN-CROWD-CLONE-LOCAL-RADIUS`: four personas at the
> minimum need eight, and three of `MAP-VETRAIO`'s six spawn points offer **3, 6 and zero**.
> **A player spawning at (114, 97.5) begins the match with no clone of their persona and no NPC
> of any kind within 25 m** — uniquely identifiable, and on open ground for
> `TUN-SUSPICION-GAIN-OPEN`, before they can move. No arrangement of the crowd fixes it; the idle
> anchors in that corner do not exist. **This is the probability moving off "Low" until the
> anchors are re-authored**, and `test_crowd_seating.gd` prints the census on every run.

> **Layer 4 is the one that matters.** Layers 1–3 catch authoring mistakes, which are visible in
> review. Layer 4 catches all twelve Lucerna clones drifting north while the Lucerna player in
> the south market becomes unique — with every rule still working and nothing broken.

---

## 11. `RISK-BANDWIDTH` — budgets missed

| | |
|---|---|
| **Probability** | **High** — was Medium. Re-scored at the M2 gate, 2026-08-15 |
| **Impact** | **Medium** — was Low. Re-scored at the M3 gate, 2026-08-18 |
| **Exposure** | **High** — was Medium, was Low |

> **RE-SCORED AGAIN AT THE M3 GATE (US-0048), AND IT GOT WORSE A SECOND TIME.** `test_crowd_bandwidth.gd`
> — which the M2 gate recorded as "not written, needs the crowd" — now exists, and **downstream is
> 108.0 kbit/s, 112 % of budget**, not the 93.5 kbit/s / 97 % this register has carried since
> US-0029.
>
> **THE RECORD SIZE WAS NEVER THE PROBLEM.** §7.1's head-counts were very nearly right (41.0 near
> against ~45, 29.2 far against ~30). Its two **change fractions** were not: 0.776 and 0.761
> measured, against 0.55 and 0.70 assumed. Those two numbers decide the total, and they were the
> only inputs never checked — US-0029 shrank the NPC record 10 B → 8 B on the strength of this
> table while `0.55` sat unquestioned in it.
>
> **IT IS THE CROWD'S IDLE DUTY CYCLE WEARING A NETWORK NUMBER'S NAME.** A strolling NPC moves
> 4.7 cm per tick against a 1 cm quantum, so every NPC that walks at all changes its record every
> tick; the fraction is simply how much of the crowd is walking, and that follows from
> `TUN-CROWD-IDLE-DURATION-MIN..MAX`. It could not have been known before US-0040.
>
> **Impact moves to Medium because the fix is no longer free.** Upstream's fix was known, bounded
> and cost nothing a player feels. Downstream's are culling (US-0030, unbuilt — the worst observer
> currently has **70.2 of 78 NPCs** replicated to them) and ADR-0007's seed-derived far crowd,
> which is a design change. **And 112 % is a lower bound**: modelled navigation understates how
> often an NPC is walking.

> **RE-SCORED AT THE M2 GATE (US-0038), AND IT IS THE ONE RISK THAT GOT WORSE.** Upstream is
> **253 % of budget, not the 112 % §7.3 predicted** — measured, not projected, by
> `test_upstream_bandwidth.gd`, which did not exist until the gate went looking for it.
>
> **`NET-C2S-INPUT` is not hand-serialised.** It goes out as RPC arguments, which Godot encodes as
> Variants: **56 bytes, not 9**. §7.3's arithmetic was correct for the format it assumed; nothing
> ever used that format.
>
> Probability moves to High because the miss is realised and larger than believed. **Exposure
> stays Medium rather than High**: the fix is known, bounded and cheap — hand-serialise the
> command the way `Snapshot` already is — and it costs no gameplay latency.

**Status: realised, halved, and still open.** Upstream measured **40.5 kbit/s against a
16 kbit/s budget** at the M2 gate — **payload, not packet overhead**, which reversed §7.3's
diagnosis. **US-0095 hand-serialised the command and brought it to 23.2 kbit/s, 145 %.** What
remains *is* packet overhead: 28 B × 60 Hz is 84 % of the budget on its own, and coalescing —
§7.3's original proposal, right about the mechanism and wrong about which term dominated — would
close it at 91 %. **Downstream as actually built is 107.6 kbit/s — 112 %**, with culling (US-0030), rate LOD and
the NPC delta (US-0031) all in: 155 % → 119 % → 112 %, the last charged against a **lagging ack**
rather than the instant one that first reported 111 % from a delta which never converged in a real
game (US-0045). **Culling was not the lever** (11 of 78
NPCs, on a 70 m radius over a 120 × 120 m map); **rate LOD was**, and the delta was worth eight
points because 0.776 of visible records change every tick anyway. **It agrees with the independent
projection of 108.0 kbit/s, 112 %** on real crowd counts — the 93.5 kbit/s / 97 %
figure carried since US-0029 was a projection on two unmeasured multipliers, and it was itself a
re-derivation of an original claim of 87 %. **Three successive versions of this number, each
believed until somebody measured the next thing down.** TDD-04 §7.1.1.

**Trigger.** `test_upstream_bandwidth.gd` (**written at the M2 gate; reports `pending` with the
number**); `test_crowd_bandwidth.gd` (**written at the M3 gate; reports `pending` with the
number**); real playtest 95th
percentile above 90 kbit/s down.

**Mitigations.** Four downstream mechanisms — culling, quantisation to **8 B/NPC**, delta encoding
(built, US-0031), rate LOD (NPC-only, M3). The ADR-0007 fallback (replicate near, seed-derive far)
is designed but unbuilt.

**Response — step one DONE (US-0095), step two now correct.** Upstream: **hand-serialise
`InputCommand` first** — done, 253 % → 145 %, and it cost nothing a player can feel. **Coalescing
was not the first move and must not have been built first**: it halves the packet rate, so it only halves
the 28-byte overhead, leaving the miss at 211 % while spending up to 16 ms of input latency
against an 80 ms feel budget. It was the right answer when the payload was believed to be 9 bytes
and overhead dominated. **Now that the payload is packed it IS the right next step**: hand-packing
and coalescing together reach **91 %**, under budget. It still costs up to 16 ms of input latency
against an 80 ms feel budget, so measure before committing. Downstream: the ADR-0007 fallback.

---

## 12. `RISK-IP` — a franchise term or asset reaches a public build

| | |
|---|---|
| **Probability** | Low |
| **Impact** | **High** — legal, and a full rename is superlinear in cost |
| **Exposure** | Medium |

**Why.** Names leak into commit history, filenames, screenshots, build artefacts and playtester
vocabulary. Renaming later does not work.

**Trigger.** `ip-guard` failing; a playtester using franchise vocabulary to describe a mechanic
(**a vocabulary bug — file it**).

**Mitigations.** A hard-failing CI grep over the entire repo with exactly two exempt files;
functional-original naming; the original-name-first rule; every name registered in the glossary
before it may be committed; the pre-commit review question.

**Response.** Fix forward, log it, and run a single planned history scrub with an ADR before any
public release. **Do not** rewrite published history reflexively.

**Currently open:** `Sottovoce` is an ordinary Italian/musical term and therefore weakly
distinctive as a trademark — a search is required before any public announcement
([`../00_meta/IP_GUARDRAILS.md`](../00_meta/IP_GUARDRAILS.md) §9.1).

---

## 13. `RISK-SCOPE-CREEP` — the fence erodes

| | |
|---|---|
| **Probability** | Medium |
| **Impact** | Medium |
| **Exposure** | Medium |

**Trigger — the tripwires** from [`../00_meta/SCOPE_FENCE.md`](../00_meta/SCOPE_FENCE.md) §4: a
story with no `SYS-` ID; a second map folder before M6; any `data/cosmetics/`; an ability without
a GDD entry; an HTTP client or database driver in the dependency list; **M5/M6 work in progress
while M4 is unreached**; the word "just" in a scope discussion.

**Mitigations.** An explicit IN list; every OUT item carries a specific reason so it need not be
relitigated; design-blocked items separated from schedule cuts so nobody spends art time on a
problem that needs a design answer; ADR required to add anything.

**Response.** The ADR must name **what is being cut to pay for it**. Scope is not added, it is
exchanged.

---

## 14. Review cadence

| When | What |
|---|---|
| Every milestone exit | Re-score every risk; check every trigger |
| When a trigger fires | Execute the response; log to `DECISION_LOG.md` |
| M3 | `RISK-CROWD-PERF`, `RISK-ANONYMITY-LEAK`, `RISK-ANIM-SCOPE` first measurable |
| M4 | `RISK-NOT-FUN-SOLO` first measurable |
| M6 | `RISK-POPULATION`, `RISK-BALANCE-UNFALSIFIABLE` first measurable |

---

## 15. Acceptance criteria

- [ ] Every risk has a trigger that is **observable**, not a judgement.
- [ ] Every trigger maps to a named test, telemetry event, or playtest question.
- [ ] Every response is specific enough to execute without re-deriving it under pressure.
- [ ] Re-scored at every milestone exit.
- [ ] `RISK-AGENT-DRIFT`'s mitigation appears in the Definition of Done.
- [ ] No risk in this register lacks a mitigation already in the design.

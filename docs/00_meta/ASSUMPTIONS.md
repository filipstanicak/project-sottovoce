---
id: DOC-ASSUMPTIONS
title: Logged Assumptions
version: 0.1.0
status: draft
owner: Documentation Architect
last_updated: 2026-08-03
depends_on: [DOC-GLOSSARY, DOC-SCOPE-FENCE]
---

# Logged Assumptions

Every decision made in the absence of a stakeholder ruling is recorded here with its
rationale and a **revisit-by** milestone. The rule that produced this file: when something
was genuinely undecidable, the option that best serves a shippable MVP was chosen,
implemented, and logged — rather than blocking on a question.

**Reading this file:** an assumption is not a decision that has been ratified. It is a
decision that has been made *provisionally and visibly* so it can be cheaply reversed. If
you disagree with one, the cost of changing it is stated in the row.

**Format:** `ASM-####` — immutable ID. Status is `active`, `ratified` (stakeholder confirmed),
`revised` (superseded — the superseding assumption is named), or `void`.

---

## 1. Fiction and naming

### ASM-0001 — The city is named Vessalia

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | The game's fictional Renaissance-Italian city is **Vessalia**. |
| **Why** | The brief specifies the setting but not a name, and [`IP_GUARDRAILS.md`](IP_GUARDRAILS.md) requires original proper nouns. A real city name (Florence, Venice) would tie us to real architecture and real history we would then have to be accurate about, and would make the level designer's job an act of reconstruction rather than design. An invented name frees the map to be built for gameplay first. *Vessalia* is phonotactically plausible Italian, has no trademark presence in games, and is easy to say in a playtest. |
| **Cost to reverse** | Low before M3, low-medium after. Appears in the string table, the map resource name, and one loading-screen plate. |
| **Revisit by** | M6 (before any public build) |

### ASM-0002 — The MVP map is Rione Vetraio, the Glassmakers' Quarter

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | `MAP-VETRAIO`, "Rione Vetraio" — a glassmakers' district. |
| **Why** | The brief specifies one district but not its character. A glassmakers' quarter gives the level designer concrete, gameplay-useful furniture for free: furnaces (light and heat sources that justify crowd gathering), drying racks and glass panes (sightline-breakers that are *transparent*, which is thematically apt for a game about being seen), cart traffic (mobile cover), and a plausible reason for a dense working crowd at all hours. It also names the district after a **persona**, tying crowd and place together. |
| **Cost to reverse** | Medium after M0 blockout. Folder name, map resource, landmark names. |
| **Revisit by** | M1 |

### ASM-0003 — The four personas are Vetraio, Cantatrice, Lucerna, Pesatore

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | Four playable personas chosen for **silhouette orthogonality**, not for fiction: Vetraio (low + broad), Cantatrice (floor-wide triangle), Lucerna (tall + thin, with a pole line above the head), Pesatore (rounded mid-height mass). |
| **Why** | The brief requires four personas and requires that a persona be identifiable at 40 m. Silhouette identification at that distance is a *shape* problem, not a costume problem. Four shapes that differ on two axes (height and width) and one distinguishing appendage are the smallest set that is reliably discriminable under motion blur, poor contrast, and crowd occlusion. Fiction was chosen afterwards to justify the shapes. |
| **Cost to reverse** | High after M3 (meshes, animations, clone pools, art bible). Low before. |
| **Revisit by** | M3 |

### ASM-0004 — Five non-playable filler archetypes

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | `ARCH-PORTER`, `ARCH-WATERCARRIER`, `ARCH-CHILD`, `ARCH-MENDICANT`, `ARCH-FISHWIFE`. No player can ever be one. |
| **Why** | The brief specifies filler archetypes but not how many or which. Five is enough that the crowd does not read as "four personas repeated"; more than five multiplies animation cost without adding discrimination value. `ARCH-CHILD` is included specifically because its scale is unmistakably non-player — it acts as a *negative* silhouette that trains the eye. |
| **Cost to reverse** | Low. Archetypes are additive. |
| **Revisit by** | M3 |

### ASM-0005 — The Compass keeps the functional name "the Compass"

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | The core instrument is called **the Compass** in all documentation, code and UI. No in-fiction alias. |
| **Why** | "Compass" is an ordinary English noun with no franchise association, describes exactly what the widget does, and is instantly understood by a playtester with no explanation. A poetic alias (*il Sussurro*, "the whisper") was considered and rejected: it would require teaching, and every second spent teaching vocabulary is a second not spent teaching the game. Legibility beats flavour. |
| **Cost to reverse** | Low. |
| **Revisit by** | M6 |

---

## 2. Balance and design centre

### ASM-0006 — The design centre is 6 players; 4 is the scaled-down variant

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | All default tunable values, crowd density figures, map area and score expectations are calibrated for a **6-player** match. The 4-player configuration is derived by the scaling rules in [`../10_gdd/07_balance.md`](../10_gdd/07_balance.md) §7. |
| **Why** | The brief specifies 4–6 without naming a centre. Six is the correct centre because the contract cycle's *information* properties improve with length: at 4 players there is a 1-in-3 chance your contract is also your pursuer, which collapses the hunter/prey asymmetry into a duel. At 6 the cycle is long enough that hunter and prey are usually different people, which is the intended experience. Tuning for 6 and degrading gracefully to 4 is safer than the reverse. |
| **Cost to reverse** | Medium. Would require re-deriving the balance model. |
| **Revisit by** | M6 (after playtest 3) |

### ASM-0007 — Jog and run generate suspicion at 4/s and 14/s

> **PARTLY SUPERSEDED 2026-08-12.** The Jog rung was removed from the ladder, so
> `TUN-SUSPICION-GAIN-JOG` is deprecated and only the run half of this assumption is live.
> The record below is left as written: it is why 14/s was chosen, and that reasoning still
> holds. What changed is that there is no longer a cheap rung between stroll and run — the
> ladder steps from free to 14/s, and `SCORE-PATIENT` keeps 3.4 m/s as
> `TUN-SCORE-PATIENT-SPEED`.

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | `TUN-SUSPICION-GAIN-JOG = 4.0 /s`, `TUN-SUSPICION-GAIN-RUN = 14.0 /s`. |
| **Why** | The brief gives sprint (+25/s) and states that only blend-walk and stroll are suspicion-free, but does not price the two intermediate speeds. Leaving them at zero would make jog a free sprint and delete the speed ramp. Leaving them at sprint rates would make the ramp meaningless. The chosen values give a legible ladder: jog reaches **Noticed** in 7.5 s, run in 2.1 s, sprint in 1.2 s. Jog remains compatible with the `SCORE-PATIENT` bonus (which permits jog), so a patient player can still cover ground under mild pressure. |
| **Cost to reverse** | Trivial — two tunables. |
| **Revisit by** | M4 (first balance pass) |

### ASM-0008 — Suspicion decay applies only at stroll speed or slower

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | `TUN-SUSPICION-DECAY-BASE` (8/s) applies when the pawn's speed state is Idle, Blend-walk or Stroll. At Jog and above, gain sources apply with no concurrent decay. |
| **Why** | The brief says decay happens "when walking or idle". Reading that as "at any speed" would make gains net-of-decay and flatten the ladder (sprint would become +17/s net, jog would become *negative*). Reading it as "walking = stroll or slower" preserves the intended cliff between civilian speeds and non-civilian speeds — which is the thesis of the game expressed as a single conditional. |
| **Cost to reverse** | Trivial — one branch in the suspicion tick. |
| **Revisit by** | M4 |

### ASM-0009 — Tier hysteresis is 5 points

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | `TUN-SUSPICION-HYSTERESIS = 5.0`. A tier is entered at its threshold and exited 5 points below it. |
| **Why** | Not specified in the brief. Without hysteresis, a player hovering at exactly 30 suspicion flickers between Anonymous and Noticed at tick rate, producing a strobing silhouette tint that is both ugly and — worse — an *unreliable information channel*. Since the whole game is an information economy, an unreliable channel is a design defect, not a polish defect. 5 points ≈ 0.6 s of decay, long enough to be stable and short enough not to feel sticky. |
| **Cost to reverse** | Trivial. |
| **Revisit by** | M4 |

### ASM-0010 — The kill facing cone is 60°

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | `TUN-KILL-FACING-CONE = 60°` (±30° from forward). |
| **Why** | The brief says "roughly facing the target" without a number. 60° total is generous enough that a kill does not fail because of a 100 ms camera wobble at 2.5 m range — which would feel like the game cheating — while being tight enough that you cannot kill someone standing beside you. It deliberately does **not** require facing *toward each other*: you may kill a target facing away from you, which is the intended patient play. |
| **Cost to reverse** | Trivial. |
| **Revisit by** | M4 |

### ASM-0011 — Compass pulse curve is a power curve with exponent 2.2

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | `pulse_period = lerp(MIN, MAX, (d / RANGE) ^ (1 / 2.2))`, i.e. `TUN-COMPASS-PULSE-EXP = 2.2`. |
| **Why** | The brief demands an ease-in curve where "the last 15 m must feel dramatically different from 40 m" but does not give a formula. The reciprocal exponent makes the curve flat far away and steep close in. It produces: 60 m → 1.11 Hz, 40 m → 1.29 Hz, 15 m → 1.82 Hz, 5 m → 2.55 Hz, 1 m → 3.75 Hz, 0 m → 6.67 Hz. From 60 m to 20 m the pulse *rate* creeps up ~8 % per 10 m; inside 10 m each step adds 15–25 %, and the final metre nearly doubles it. The rate at 15 m is 41 % faster than at 40 m; at 1 m it is triple. That asymmetry is the requirement, expressed as a curve. Sampled table in [`../50_tuning/TUNABLES.md`](../50_tuning/TUNABLES.md) §4.2. |
| **Cost to reverse** | Trivial — one tunable. |
| **Revisit by** | M4 |

### ASM-0012 — The Compass direction cone has ±12° of deliberate error

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | `TUN-COMPASS-CONE-HALFWIDTH = 12°`. The Compass renders a *cone*, not a needle, and the cone's rendered centre carries a slow, deterministic wobble within ±4°. |
| **Why** | The brief requires the Compass be "deliberately imprecise" and give "a direction cone", but does not quantify it. Zero error makes the Compass a laser and deletes search gameplay. Too much error makes it noise. ±12° at 30 m is a ±6 m positional ambiguity — roughly one market stall — which is the right unit of uncertainty: it tells you *which part of the plaza*, never *which body*. The wobble is deterministic (seeded per contract) so that it is a stable property of the hunt, not a per-frame lie. |
| **Cost to reverse** | Trivial. |
| **Revisit by** | M4 |

### ASM-0013 — Compass lock fills in 1.6 s

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | `TUN-COMPASS-LOCK-FILL-TIME = 1.6 s` (1.23 s with `PASV-COLDREAD`). |
| **Why** | Not specified. The lock must take long enough that holding it is a *commitment* — you are standing still, looking at one person, not scanning — but short enough to be achievable in a crowd that keeps breaking line of sight. 1.6 s is slightly longer than a typical NPC's stride cycle, so a lock cannot be completed through incidental gaps in a walking group; you must actually have a clear view. |
| **Cost to reverse** | Trivial. |
| **Revisit by** | M4 |

### ASM-0014 — Respawn is at least 40 m from the killer

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | `TUN-RESPAWN-MIN-DIST-FROM-KILLER = 40.0 m`, with fallback to the farthest available spawn if no point satisfies the constraint. |
| **Why** | The brief says "far from your killer" without a number. 40 m on a 120 × 120 m map is one third of the map's diagonal — far enough that an immediate revenge encounter is not the default, close enough that the map does not feel like it has teleporters. The fallback matters: with 6 spawn points and 6 players, a hard constraint can be unsatisfiable, and a spawn system that can fail is a crash waiting for a playtest. |
| **Cost to reverse** | Trivial. |
| **Revisit by** | M4 |

### ASM-0015 — Two abilities equipped from four; loadout locked at match start

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | Players equip 2 of the 4 abilities plus 1 of the 3 passives, chosen in the lobby, immutable for the match's duration including across deaths. |
| **Why** | The brief says "2 equipped + 1 passive" and "loadouts are pre-match-locked". Locking across respawn (rather than allowing a re-pick on death) is the load-bearing part: if a player can change loadout on death, then reading an opponent's kit — a core skill — becomes worthless information, and dying becomes a way to counter-pick. Loadout permanence makes information about other players *durable*, which is what a social-stealth game trades in. |
| **Cost to reverse** | Low. |
| **Revisit by** | M6 |

### ASM-0016 — `SCORE-POISONED` is defined but unreachable in MVP

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | The `SCORE-POISONED` bonus (+75, delayed-kill) is fully specified in the scoring table and implemented in the score fold, but **no MVP ability triggers it**. It is reserved for the post-MVP ability `ABIL-NIGHTSHADE`. It does not appear in the HUD's bonus legend in MVP. |
| **Why** | The brief's bonus table includes Poisoned and describes it as a "delayed-kill ability", but the brief's MVP ability set (Cinderfall, Whisperbolt, Second Face, Lunge) contains no delayed-kill ability, and [`SCOPE_FENCE.md`](SCOPE_FENCE.md) forbids adding a fifth ability without an ADR. Adding one silently would breach the fence; deleting the bonus would contradict the brief. Specifying it as a reserved, dormant bonus honours both: the scoring system is complete and tested, and the ability that uses it is a clean post-MVP addition requiring no scoring work. |
| **Cost to reverse** | Trivial to activate (one ability, zero scoring changes) — which is the point. |
| **Revisit by** | Post-M6 |

### ASM-0017 — `SCORE-VARIETY` counts distinct bonus *types* earned since the current life began

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | On each kill, `Variety = 50 × n` where `n` is the number of bonus types earned *on this kill* that have **not** been earned at any earlier point in the current life. The counter resets on death, not on kill. `SCORE-VARIETY` never counts itself, and never counts `SCORE-CONTRACT` (the base) or `SCORE-RECKLESS` (the penalty). |
| **Why** | The brief's wording ("n = distinct bonus types earned this life, not yet repeated") admits several readings. The chosen reading rewards *changing your approach across a streak* rather than repeating the same optimal kill — which is the behaviour worth paying for. Excluding the base and the penalty prevents a free +50 on every kill and prevents being paid for a mistake. Resetting on death rather than on kill makes a long, varied life the high-skill expression. |
| **Cost to reverse** | Low — one function in the score fold, fully unit-tested. |
| **Revisit by** | M5 |

### ASM-0018 — Suspicion sources are additive per tick, with instant sources applied as impulses

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | Continuous sources (sprint, roof, climb, open-ground) sum linearly per tick. Instant sources (bump, loud ability, failed kill) are impulses applied once at the triggering event. Total is clamped to [0, 100]. |
| **Why** | Not specified. Additive-with-clamp is the only model that is both predictable to the player and trivially unit-testable. Multiplicative or max-of models produce cases where adding a second bad behaviour has no cost, which teaches players that once they are running, everything else is free — the opposite of the intended lesson. |
| **Cost to reverse** | Low. |
| **Revisit by** | M4 |

### ASM-0030 — The contract portrait is unknown until a lock completes

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | The HUD's contract portrait shows a featureless unknown silhouette when a contract is assigned. Completing a Compass lock (`TUN-COMPASS-LOCK-FILL-TIME`) fills it with the contract's persona **permanently for the duration of that contract**. It resets to unknown on reassignment. |
| **Why** | The brief lists a "contract portrait" as a HUD element, while [`../10_gdd/03_social_stealth.md`](../10_gdd/03_social_stealth.md) §8.5 states the hunter is deliberately never told their contract's persona — knowing the persona collapses the candidate set from 60–90 NPCs to 8–13 and is the single most valuable piece of information in the game. A portrait that is populated on assignment would hand that over for free and gut the crowd. A portrait that is *earned* satisfies both: it is unknown by default, so the search is preserved, and it becomes the durable payoff for the hardest skill in the game. It also solves a separate problem — the lock reveal lasts only `TUN-COMPASS-REVEAL-DURATION` 1.5 s, which is too brief to be worth the 1.6 s of standing still it costs; making the lock *also* permanently identify the persona is what makes locking worth doing. |
| **Cost to reverse** | Low. One view-model field and a reveal-completion hook. |
| **Revisit by** | M5 |

---

## 3. Technical

### ASM-0019 — Godot 4.7.1 stable, Forward+, GDScript-first

| Field | Value |
|---|---|
| **Status** | revised by ADR-0011 — version now 4.7.1; language and renderer unchanged |
| **Decision** | Engine and language per the brief. C# only where profiling proves a hotspot, recorded as an ADR. |
| **Why** | Stakeholder decision. Logged here for completeness because downstream documents depend on it. |
| **Cost to reverse** | Very high. |
| **Revisit by** | — |

### ASM-0020 — Server tick 30 Hz is the authority clock for *all* gameplay, not just movement

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | Suspicion accumulation, detection resolution, ability cooldowns, contract state and score events all advance on the 30 Hz server tick. Nothing gameplay-relevant advances in `_process`. |
| **Why** | The brief specifies a 30 Hz server tick for netcode but does not say whether gameplay systems share it. Sharing it is strictly better: it makes suspicion math frame-rate-independent and deterministic, makes the whole simulation replayable from an input log (which makes the test plan possible), and removes a class of bug where a 144 Hz client accrues suspicion differently from a 60 Hz one. The cost is 33 ms of granularity on suspicion, which is imperceptible. |
| **Cost to reverse** | High after M2. |
| **Revisit by** | M2 |

### ASM-0021 — Snapshot interpolation buffer is 100 ms, fixed, not adaptive

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | `TUN-NET-INTERP-BUFFER = 100 ms`, a constant. No adaptive jitter buffer in MVP. |
| **Why** | The brief specifies 100 ms. Making it adaptive is a well-known improvement and is deliberately deferred: an adaptive buffer changes remote-player timing between matches and between opponents, which makes "did I mistime that stun or did the netcode change?" unanswerable during a balance pass. Fixed first, adaptive after the feel is locked. |
| **Cost to reverse** | Low, and planned. |
| **Revisit by** | Post-M6 |

### ASM-0022 — Lag compensation rewind window is 100–200 ms, clamped

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | `TUN-NET-LAGCOMP-MIN = 100 ms`, `TUN-NET-LAGCOMP-MAX = 200 ms`. A client's rewind is `clamp(rtt/2 + interp_buffer, MIN, MAX)`. |
| **Why** | The brief gives the range but not the selection rule. Clamping at 200 ms is the important half: without a ceiling, a player on a 600 ms connection can kill someone who left the position half a second ago, which from the victim's side is indistinguishable from the game being broken. The ceiling makes high-ping play *worse for the high-ping player* rather than worse for everyone else — the correct place to put the cost. |
| **Cost to reverse** | Low. |
| **Revisit by** | M4 |

### ASM-0023 — All user-facing text goes through a string table from the first commit

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | No literal user-facing string in any script or scene. All text is a key into `data/strings/en.csv`, resolved through Godot's translation system. Localisation itself is out of scope. |
| **Why** | Localisation is out of scope ([`SCOPE_FENCE.md`](SCOPE_FENCE.md) OUT #17), but retrofitting a string table across a finished UI is a multi-day refactor with a long tail of missed strings. Doing it from commit one costs approximately nothing and makes the deferred work a data task. This also gives the score feed a single place where every bonus name is defined, which the [IP guardrails](IP_GUARDRAILS.md) benefit from. |
| **Cost to reverse** | N/A — this is the cheap direction. |
| **Revisit by** | — |

### ASM-0024 — Crowd NPCs are server-simulated and replicated as compressed transforms, not client-simulated deterministically

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | The server owns all NPC state. Clients receive quantised position/yaw/anim-state per NPC in the snapshot stream. NPCs are **not** independently simulated on clients from a shared seed. |
| **Why** | Deterministic client-side crowd simulation would save bandwidth, and is the tempting choice. It is rejected because the crowd is not decoration: an NPC's exact position determines whether a player is inside a blend group, whether the open-ground suspicion source applies, and whether line of sight is broken. Any client/server divergence in NPC position therefore becomes a *gameplay* divergence — a player who believes they are blended and is not. Bandwidth is the cheaper problem; the budget is worked in [`../20_tdd/04_networking.md`](../20_tdd/04_networking.md) §7 and fits. |
| **Cost to reverse** | Very high after M3. |
| **Revisit by** | M3 (if the bandwidth budget is missed) |

### ASM-0025 — NPC clone appearance is deterministic from a match seed

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | Which persona each clone uses, and its per-instance variation, is derived from `match_seed` + NPC index. The server sends the seed once; clients derive appearance locally. |
| **Why** | Appearance must be identical on every client — if two players see different clone distributions, "I saw a Lucerna by the furnace" becomes a lie, and the social layer breaks. Deriving from a seed is cheaper than replicating and is verifiable by a test that hashes the derived roster on each peer and asserts equality. Note this is *appearance* only; position is still server-replicated per ASM-0024. |
| **Cost to reverse** | Low. |
| **Revisit by** | M3 |

### ASM-0026 — `IProfileStore` is a no-op in-memory implementation in MVP

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | The interface exists with the full method set a real store would need; the MVP implementation returns defaults and discards writes. No file I/O, no network. |
| **Why** | The brief requires the interface stubbed with no persistence. A no-op that *implements the full eventual surface* is more useful than a minimal stub: it forces the call sites to be written correctly now, so that adding a real store later is a single class, not a hunt. |
| **Cost to reverse** | N/A. |
| **Revisit by** | Post-M6 |

---

## 4. Process

### ASM-0027 — Commits are per-document during the documentation phase; per-story afterwards

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | Documentation commits follow `docs(<section>): <what>`. Story files are committed in batches by milestone rather than individually, because ~75 near-identical single-file commits obscure history rather than clarifying it. |
| **Why** | The brief specifies committing after each file. Applied literally to 75 story files that share one template, this produces a history that is harder to read, not easier. Substantive documents get their own commit; the story corpus is committed per milestone batch, which is the unit anyone would actually want to diff or revert. |
| **Cost to reverse** | N/A. |
| **Revisit by** | — |

### ASM-0028 — Documentation `status` is `draft` until it survives one implementation milestone

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | No document is promoted to `review` or `locked` on the strength of being finished. A document reaches `review` when the milestone that implements it exits, and `locked` when a second milestone passes without contradicting it. |
| **Why** | A design document that has never met an implementation is a hypothesis. Marking it `locked` before code exists inverts the authority relationship: it makes reality the thing that has to justify itself. This rule is also the primary defence against **agent drift** (`RISK-AGENT-DRIFT`) — a `draft` document invites correction, a `locked` one invites silent divergence. |
| **Cost to reverse** | N/A. |
| **Revisit by** | — |

### ASM-0029 — The greybox map is authored as a Godot scene of primitives, not imported geometry

| Field | Value |
|---|---|
| **Status** | active |
| **Decision** | `MAP-VETRAIO`'s blockout is `CSGBox3D`/`MeshInstance3D` primitives placed in-editor, committed as a `.tscn`, with a documented conversion path to imported meshes at M6. |
| **Why** | The brief requires primitive/procedural placeholder art. Authoring in-engine keeps the level designer's iteration loop at seconds rather than a DCC round-trip, and keeps the navmesh and the metrics bible honest, since both are derived from the actual committed geometry. The `.tscn` is text, so it diffs — badly, but it diffs. |
| **Cost to reverse** | Medium at M6, and planned for. |
| **Revisit by** | M6 |

---

## 5. Assumption register summary

| ID | Subject | Status | Revisit by | Reversal cost |
|---|---|---|---|---|
| ASM-0001 | City name: Vessalia | active | M6 | Low |
| ASM-0002 | Map: Rione Vetraio | active | M1 | Medium |
| ASM-0003 | Four personas by silhouette | active | M3 | High |
| ASM-0004 | Five filler archetypes | active | M3 | Low |
| ASM-0005 | "the Compass" keeps its functional name | active | M6 | Low |
| ASM-0006 | Design centre is 6 players | active | M6 | Medium |
| ASM-0007 | Jog 4/s, run 14/s suspicion | active | M4 | Trivial |
| ASM-0008 | Decay only at stroll or slower | active | M4 | Trivial |
| ASM-0009 | Hysteresis 5 points | active | M4 | Trivial |
| ASM-0010 | Kill facing cone 60° | active | M4 | Trivial |
| ASM-0011 | Pulse curve exponent 2.2 | active | M4 | Trivial |
| ASM-0012 | Compass cone ±12° | active | M4 | Trivial |
| ASM-0013 | Lock fill 1.6 s | active | M4 | Trivial |
| ASM-0014 | Respawn ≥ 40 m from killer | active | M4 | Trivial |
| ASM-0015 | Loadout locked across respawn | active | M6 | Low |
| ASM-0016 | `SCORE-POISONED` reserved, dormant | active | Post-M6 | Trivial |
| ASM-0017 | `SCORE-VARIETY` counts per-life firsts | active | M5 | Low |
| ASM-0018 | Suspicion additive with clamp | active | M4 | Low |
| ASM-0019 | Godot 4.7.1 / Forward+ / GDScript | ratified | — | Very high |
| ASM-0020 | 30 Hz tick is the authority clock for all gameplay | active | M2 | High |
| ASM-0021 | Fixed 100 ms interpolation buffer | active | Post-M6 | Low |
| ASM-0022 | Lag-comp rewind clamped to 200 ms | active | M4 | Low |
| ASM-0023 | String table from commit one | active | — | N/A |
| ASM-0024 | NPCs server-simulated, not client-deterministic | active | M3 | Very high |
| ASM-0025 | Clone appearance derived from match seed | active | M3 | Low |
| ASM-0026 | `IProfileStore` no-op with full surface | active | Post-M6 | N/A |
| ASM-0027 | Per-document / per-milestone commit granularity | active | — | N/A |
| ASM-0028 | Docs stay `draft` until implemented | active | — | N/A |
| ASM-0029 | Greybox authored in-engine as primitives | active | M6 | Medium |
| ASM-0030 | Contract portrait unknown until a lock completes | active | M5 | Low |

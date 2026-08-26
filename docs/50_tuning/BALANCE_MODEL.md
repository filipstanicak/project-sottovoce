---
id: TUN-BALANCE-MODEL
title: Balance Model — The Math Behind Scoring and Pacing
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [TUN-INDEX, GDD-03-SOCIAL-STEALTH, GDD-07-BALANCE]
---

# Balance Model — The Math Behind Scoring and Pacing

> **What this document is.** The arithmetic behind every scoring value and pacing target in
> Project Sottovoce, stated so that it can be checked, disagreed with, and — most importantly —
> **refuted by measurement**. [`../10_gdd/07_balance.md`](../10_gdd/07_balance.md) §4 states
> the model's conclusions; this document shows the work.
>
> **What this document is not.** A justification. Every input below is an *estimate* about how
> humans will play a game that does not yet exist. The model's value is not that it is right —
> it is that it is specific enough to be wrong in a detectable way.

---

## 1. Assumptions, labelled by confidence

Every number the model consumes, with how much it should be trusted. **This table is the most
important part of the document**, because a conclusion is only as good as its worst input.

| # | Assumption | Value | Confidence | Basis |
|---|---|---|---|---|
| A1 | Match duration | 480 s | **Certain** | `TUN-MATCH-DURATION` |
| A2 | Respawn dead time | 5 s | **Certain** | `TUN-RESPAWN-DELAY` |
| A3 | Contract reassignment dead time | 3 s | **Certain** | `TUN-CONTRACT-REASSIGN-DELAY` |
| A4 | All scoring values | per §3 | **Certain** | `TUNABLES` §11 |
| A5 | A contract can only be killed by its holder | true | **Certain** | Structural — [`../10_gdd/03_social_stealth.md`](../10_gdd/03_social_stealth.md) §7 |
| A6 | Target kills per player per match | 4.6 | **Medium** | Stated target in `TUNABLES` §16; itself a design choice, not a measurement |
| A7 | Hunt and death processes are memoryless (exponential) | — | **Medium** | Reasonable for a search process in a crowd; breaks down if players systematically camp known locations |
| A8 | Patient hunt duration | 96 s | **Low** | *Derived* from A6, then sanity-checked against a phase decomposition. Circular unless A6 is independently validated |
| A9 | Aggressor hunt duration | 86 s | **Low** | Estimated from attempt rate × stun failure rate |
| A10 | Aggressor stun-failure rate per attempt | 45 % | **Low** | Pure estimate. The single most load-bearing guess in the model |
| A11 | Pursuer's hunt duration against an Aggressor | 55 s | **Low** | Estimate: Exposed targets are found ~1.75× faster |
| A12 | Bonus-fire probabilities | §3.2 | **Low** | Estimates from the mechanics, not from play |
| A13 | Kills per life ≈ 1.0 | 1.0 | **Medium** | Falls out of A6 and symmetric kill/death rates |
| A14 | Score variance ≈ Poisson in kills | — | **Medium** | Ignores bonus-level variance, so it *understates* spread |

**Read A8–A12 together:** five of the model's inputs are low-confidence estimates, and they all
push the same direction (patience good, aggression bad). If they are jointly optimistic, the
model's headline conclusion is overstated. This is why §5's sensitivity analysis exists and why
no value is being pre-tuned.

---

## 2. The pacing model

### 2.1 Setup

By A5, each player runs exactly one hunt and is the subject of exactly one hunt. There is no
kill-stealing and no third-party interruption, so both can be modelled as independent competing
processes.

| Symbol | Meaning |
|---|---|
| `M` | Match duration, 480 s |
| `T` | Mean uninterrupted hunt duration for this player (their offence) |
| `T′` | Mean duration of the hunt *against* this player (their defence — determined by **their own** visibility, not their pursuer's skill) |
| `A` | Active (alive, contracted) time |

The asymmetry between `T` and `T′` is the model's engine: aggression improves `T` slightly and
degrades `T′` severely.

### 2.2 Active time

Each kill costs `A3` = 3 s of reassignment; each death costs `A2` = 5 s of respawn.

```
A + 3·(A/T) + 5·(A/T′)  =  M
A·(1 + 3/T + 5/T′)      =  480
A                        =  480 / (1 + 3/T + 5/T′)

kills  = A/T
deaths = A/T′
```

### 2.3 Calibrating T from the kill target

With all players identical (`T = T′`) and A6's target of 4.6 kills:

```
kills = A/T = 4.6
A     = 480 / (1 + 8/T)

4.6 = 480 / (T·(1 + 8/T))
4.6 = 480 / (T + 8)
T + 8 = 104.3
T     = 96.3 s
```

Check: `A = 480/(1 + 8/96.3) = 480/1.0831 = 443.2 s`. Kills `= 443.2/96.3 = 4.60` ✓.
Deaths `= 4.60` ✓. Dead time `= 4.6×3 + 4.6×5 = 36.8 s`; `443.2 + 36.8 = 480` ✓.

### 2.4 Sanity check against a phase decomposition

96 s is *derived*, so it needs an independent plausibility check. Decomposing a patient hunt
from the mechanics:

| Phase | Reasoning | Duration |
|---|---|---|
| **Acquisition** | Mean player separation on a 120 × 120 m map ≈ 0.52 × 120 ≈ 63 m euclidean; path distance ~75 m. Closing at stroll (2.2 m/s) with cone-correction overhead ≈ 1.6 m/s effective, but targets also move and sometimes converge. Net to within 20 m. | ~35 s |
| **Identification** | Position for LOS in a crowd, fill the lock arc (`TUN-COMPASS-LOCK-FILL-TIME` 1.6 s), typically 3–5 attempts as the crowd breaks line of sight. | ~15 s |
| **Approach / wait** | Close from ~15 m to 2.5 m at blend-walk (1.4 m/s ≈ 9 s), plus waiting for the target to be positioned well — the patient player's defining behaviour. | ~45 s |
| **Kill** | `TUN-KILL-ANIM-DURATION` | 1.4 s |
| **Total** | | **~96 s** |

The decomposition lands on the derived figure without being fitted to it. That is weak
evidence, but it is evidence.

### 2.5 Consequence: expected life

Because the hunt against you completes at rate `1/T′`, and by memorylessness (A7) a pursuer's
death and replacement does not reset your hazard, **expected life = T′ = 96 s** for a patient
player.

> This **resolves open question 2 in [`../10_gdd/01_vision.md`](../10_gdd/01_vision.md) §12**,
> which asked whether that chapter's 90-second paranoia curve matches the real expected life.
> It does, to within 7 %. The paranoia curve's four phases (baseline → ambient → confirmation
> → acute) can be authored against a ~96 s life with confidence.

### 2.6 Per-archetype pacing

| | Patient | Opportunist | Aggressor |
|---|---|---|---|
| `T` (own hunt) | 96 s | 70 s | 86 s |
| `T′` (hunt against them) | 96 s | 78 s | 55 s |
| `A = 480/(1 + 3/T + 5/T′)` | 443 s | 428 s | 426 s |
| **Kills** = A/T | **4.6** | **6.1** | **5.0** |
| **Deaths** = A/T′ | **4.6** | **5.5** | **7.7** |

*(The Opportunist's 6.1 is rounded to 5.6 in
[`../10_gdd/07_balance.md`](../10_gdd/07_balance.md) §4.3 to account for a ~10 % stun-failure
rate on their committed finishes, which the simple formula does not capture.)*

### 2.7 Deriving the Aggressor's `T` = 86 s

The Aggressor's attempts are fast but often fail. Per A10, 45 % are stunned.

```
attempts per kill      = 1 / 0.55            = 1.82
time per attempt       = 40 s                            (fast acquisition + committed approach)
stun penalty           = TUN-STUN-FREEZE 4 s
                       + TUN-STUN-LOCKOUT 12 s           = 16 s
failed attempts per kill = 1.82 - 1          = 0.82

T = 1.82 × 40  +  0.82 × 16
  = 72.8 + 13.1
  = 85.9 s
```

**This is the model's most interesting result.** Sprinting halves acquisition time (40 s per
attempt versus 96 s) and yet produces an effective hunt duration of 86 s — barely better than
patience. The stun counter eats almost the entire speed advantage. `TUN-STUN-LOCKOUT` (12 s) is
doing most of that work: at a 0 s lockout, `T` would be `1.82 × 40 + 0.82 × 4 = 76 s`.

**And `T′` is where the Aggressor actually loses.** Being Exposed for much of the match means
their own pursuer finds them in 55 s instead of 96 s (A11), so they die 67 % more often, losing
5 s of respawn each time.

---

## 3. The scoring model

### 3.1 Derivation of each value

Every bonus is priced as a multiple of `TUN-SCORE-CONTRACT` = 100, the unit of account.

| Bonus | Value | Derivation |
|---|---|---|
| `SCORE-CONTRACT` | 100 | **The unit.** Fixed by definition. |
| `SCORE-SILENT` | +100 | **1.0×.** The difference between playing the game and not — it is earned by simply never sprinting. The floor of competence is worth exactly one unit. |
| `SCORE-PATIENT` | +150 | **1.5×.** Silent is a *state at one instant*; Patient is *sustained discipline over 10 s*. Sustained conditions are harder to hold and easier to lose accidentally, so they price 50 % higher. |
| `SCORE-MASKED` | +150 | **1.5×, equal to Patient by design.** A different route to the same virtue; equal pricing says the game prefers neither. |
| `SCORE-FOCUS` | +100 | **1.0×.** A single perceptual skill rather than sustained restraint, and partially subsumed by the approach a patient player makes anyway. |
| `SCORE-FROMABOVE` | +100 | **Derived from the roof's cost.** A roof approach forfeits Silent (−100) and usually Patient (−150) = −250. +100 reduces the net penalty to −150. Deliberately *not* break-even: the roof should be a ~150-point investment in speed and position. |
| `SCORE-BLENDED` | +200 | **2.0×, the largest.** The only bonus that cannot be earned reactively — it requires predicting where the target will be and being there first, motionless. |
| `SCORE-LONGHUNT` | +50 / +150 | **Derived from foregone time.** A patient player earns 815 points per 104 s of cycle = **7.84 pts/s** (re-derived 2026-08-26; was 7.13 before the ADR-0013 re-pricing). A 45 s hunt versus a 20 s hunt costs 25 s ≈ **196 points**. The +100 step between tiers compensates 51 % of that — down from 56 %, because the same step now covers a more valuable second. A long hunt stays roughly time-neutral rather than time-punished, and **the margin has narrowed**: if the step ever compensates under half, rushing becomes correct again and this row is where it will show. |
| `SCORE-VENDETTA` | +100 | **Not model-derived** — an emotional payoff. Priced at exactly one base kill so it is noticeable but never worth *seeking*; at 200 deliberately dying to set up revenge would become viable. |
| `SCORE-VARIETY` | +50 × n | See §4 — this value behaves differently from its stated intent. |
| `SCORE-RECKLESS` | −50 | **−0.5×, deliberately not −1.0×.** At −100 a Reckless kill would be worth zero, making *abandoning a kill mid-approach* correct once spotted — which is worse behaviour than the behaviour being punished. −50 leaves a caught-out player a reason to finish while making the outcome clearly bad. |
| `SCORE-STUN` | 100 | **Exactly one base kill.** A statement rather than a calculation: defence pays like offence. Locked by `TUNABLES` invariant §17.19. |
| Death | 0 | **Costs time, never points.** A points penalty makes a trailing player's position unrecoverable and drives them toward passive play — the opposite of what a trailing player should do. |

### 3.2 Bonus-fire probabilities (A12 — low confidence)

| Bonus | Patient | Opportunist | Aggressor | Reasoning |
|---|---|---|---|---|
| Silent | 0.92 | 0.55 | 0.08 | Patient players are Anonymous at initiation almost always; Aggressors almost never. |
| Patient | 0.85 | 0.35 | 0.05 | Requires staying under `TUN-SCORE-PATIENT-SPEED` for 10 s. |
| Focus | 0.45 | 0.30 | 0.20 | 6 s unbroken LOS is hard in a crowd for everyone. |
| Blended | 0.35 | 0.10 | 0.03 | Requires pre-positioning. |
| From Above | 0.05 | 0.15 | 0.20 | Aggressors use roofs. |
| Masked | 0.15 | 0.12 | 0.05 | Only when `ABIL-SECONDFACE` is equipped (~1/3 of loadouts) and timed. |
| Long Hunt +50 | 0.45 | 0.55 | 0.55 | Measured from first lock. |
| Long Hunt +150 | 0.40 | 0.20 | 0.10 | Patient approaches routinely exceed 45 s. |
| Vendetta | 0.12 | 0.16 | 0.20 | Scales with death rate. |
| Reckless | 0.02 | 0.25 | 0.55 | |

### 3.3 Expected points per kill

Re-derived 2026-08-26 against the re-priced values (ADR-0013): Silent 100 → 200, Patient
150 → 100, Focus 100 → 150, Reckless −50 → 0. **The probabilities are untouched** — only the
values moved, so this is arithmetic, not a new model.

**Patient:**

```
Contract    1.00 × 100  = 100.0
Silent      0.92 × 200  = 184.0
Patient     0.85 × 100  =  85.0
Focus       0.45 × 150  =  67.5
Blended     0.35 × 200  =  70.0
FromAbove   0.05 × 100  =   5.0
Masked      0.15 × 150  =  22.5
LongHunt    0.45×50 + 0.40×150 = 22.5 + 60.0 = 82.5
Vendetta    0.12 × 100  =  12.0
Reckless    0.02 ×   0  =   0.0
                        ---------
subtotal                = 628.5

Variety: n̄ = 0.92+0.85+0.45+0.35+0.05+0.15+0.85+0.12 = 3.74 distinct types
         3.74 × 50      = 187.0
                        ---------
TOTAL per kill          = 815.5
```

**Aggressor:**

```
Contract    1.00 × 100  = 100.0
Silent      0.08 × 200  =  16.0
Patient     0.05 × 100  =   5.0
Focus       0.20 × 150  =  30.0
Blended     0.03 × 200  =   6.0
FromAbove   0.20 × 100  =  20.0
Masked      0.05 × 150  =   7.5
LongHunt    0.55×50 + 0.10×150 = 27.5 + 15.0 = 42.5
Vendetta    0.20 × 100  =  20.0
Reckless    0.55 ×   0  =   0.0
                        ---------
subtotal                = 247.0

Variety: n̄ = 0.08+0.05+0.20+0.03+0.20+0.05+0.65+0.20 = 1.46
         1.46 × 50      =  73.0
                        ---------
TOTAL per kill          = 320.0
```

**Per-kill ratio = 815.5 / 320.0 = 2.55 : 1 — down from 2.68 : 1.**

**THE RE-PRICING NARROWED THE GAP RATHER THAN WIDENING IT.** The Patient gained 73 per kill and
the Aggressor 43. The cause is isolable: **removing `SCORE-RECKLESS` is worth +27.5 per kill to
the Aggressor and +1.0 to the Patient**, which consumes most of what the stealth uplift bought.
Converging on the reference makes this game *less* punishing of aggression, because the
reference under-pays carelessness rather than charging for it.

### 3.4 Match totals

| | Patient | Opportunist | Aggressor | Defender |
|---|---|---|---|---|
| Kills | 4.6 | 5.6 | 5.0 | 1.5 |
| Points / kill | 815 | 510 | 320 | 815 |
| Kill points | 3 751 | 2 856 | 1 600 | 1 223 |
| Stuns | 1.2 | 0.8 | 0.4 | 6.0 |
| Stun points | 120 | 80 | 40 | 600 |
| **Total** | **3 871** | **2 936** | **1 640** | **1 823** |
| Points / minute | 484 | 367 | 205 | 228 |

**Match ratio, Patient : Aggressor = 2.36 : 1 — down from 2.48 : 1.**

> **THE KILLS ROW IS STALE AND THE POINTS ROW IS NOT.** ADR-0013 also removed the stun's
> ability to interrupt a committed kill, so §3.2's modelled 45 % stun-per-attempt rate is too
> high and every kills-per-match figure above depends on it. The point values are re-derived
> and correct; what they are multiplied by is not. `TEL-STUN-RATE` settles it, and nothing
> here should be re-derived from a guess before then.

### 3.5 Win probability

Kills are approximately Poisson (A14), so `σ_kills ≈ √4.6 ≈ 2.14`.

```
σ_Patient    ≈ 815 × 2.14  ≈ 1 744
σ_Aggressor  ≈ 277 × 2.24  ≈  620

D = Patient − Aggressor  ~  N(2 108, √(1588² + 620²)) = N(2 108, 1 705)

P(Aggressor wins) = Φ(−2108 / 1705) = Φ(−1.236) ≈ 0.108
```

> **The patient player wins ~89 % of head-to-head matches. The design target is ~60 %.**

Note A14 *understates* variance by ignoring bonus-level spread, so the true figure is likely a
little lower than 89 % — but not near 60 %.

---

## 4. The `SCORE-VARIETY` finding

`SCORE-VARIETY` pays 50 × *n*, where *n* counts bonus types earned **for the first time in the
current life** (ASM-0017, resetting on death).

From §2.6, a patient player has 4.6 kills and 4.6 deaths — **≈ 1.0 kills per life** (A13).

At one kill per life, every bonus on that kill is necessarily "first time this life".
Therefore:

> **`SCORE-VARIETY` currently behaves as a flat +50 uplift per bonus type earned, not as a
> reward for varying your approach.**

Magnitude:

| | Variety contribution | As % of per-kill total |
|---|---|---|
| Patient | +187 | 25 % |
| Opportunist | +~110 | 24 % |
| Aggressor | +73 | 26 % |

It is the **second-largest single contributor** to a patient player's per-kill score, behind
only the base, and it arrives without the player doing anything the bonus was designed to
encourage.

**Note it is roughly ratio-neutral** (25 % vs 26 %), so removing it would not close the
patient/aggressive gap — it inflates both sides similarly. The problem is not balance; it is
that the bonus does not mean what it says.

### 4.1 The recommended fix, if measurement confirms it

Change the reset from **death** to **contract**. Then *n* counts within a single hunt, so a
player who kills twice in one life must vary their approach on the second kill to be paid — the
stated intent — without changing a single tuning value.

**Measure first:** `TEL-KILLS-PER-LIFE` and `TEL-VARIETY-N`. If kills-per-life is genuinely
near 1.0, apply the fix. If strong players routinely reach 2–3 kills per life, the bonus is
already working for the players it was aimed at and should be left alone.

---

## 5. Sensitivity analysis

Because five inputs are low-confidence (A8–A12), the honest question is: **how wrong would they
have to be for the conclusion to flip?**

Varying one input at a time, holding all else fixed. The conclusion "patience dominates" flips
when the match ratio approaches 1.0.

| Input | Model value | Value at which ratio → 1.5× | Value at which ratio → 1.0× | Plausible? |
|---|---|---|---|---|
| **A10** Aggressor stun-failure rate | 45 % | 22 % | 8 % | **Yes.** If stun is harder to land than assumed — bad netcode on the Lunge tell, or players not reacting to the warning — this is the input most likely to be badly wrong. |
| **A11** `T′` against an Aggressor | 55 s | 78 s | 94 s | **Yes.** If Exposed players are not actually found faster (occlusion, distance, hunters not looking), the aggressor's main cost vanishes. |
| **A12** Aggressor Silent probability | 0.08 | 0.45 | 0.75 | No. An Exposed sprinting player cannot be Anonymous at initiation; this is near-structural. |
| **A12** Patient Blended probability | 0.35 | 0.05 | — | Partially. If blend prediction proves too hard, this collapses — but Silent and Patient carry the gap regardless. |
| **A8** Patient hunt duration | 96 s | 145 s | 190 s | Partially. A longer patient hunt reduces kill count; but it also raises Long Hunt frequency, which partly self-corrects. |
| **A6** Kills per match | 4.6 | — | — | Scales both archetypes; ratio-neutral. |

**The two inputs that matter** are A10 and A11 — both concern *whether aggression is actually
punished in practice*, rather than whether patience is rewarded. Both are directly measurable
from `TEL-STUN-LANDED` / `TEL-KILL-ATTEMPT` and `TEL-LIFE-DURATION` split by `TEL-MEAN-SPEED`.

**This is a useful result:** it says the balance risk is concentrated in the *counter-play*
mechanics, not in the scoring table. If the game turns out unbalanced, the scoring values are
probably not the place to look first.

---

## 6. Deriving `TUN-MATCH-FINALPHASE-MULT`

The Final Contract phase must make the last 30 seconds decisive without making the preceding
7:30 irrelevant.

At the patient rate of 7.13 pts/s, 30 seconds of normal play is worth ~214 points — noise
against a 3 871-point total. The phase needs to be worth substantially more than that, and less
than a match-winning margin.

| Multiplier | One maximal final kill (900 base) | As % of a patient match total | Verdict |
|---|---|---|---|
| 1.5× | 1 350 | 38 % | Too weak — a trailing player still cannot catch up. |
| **2.0×** | **1 800** | **51 %** | **Chosen.** Overturns a moderate deficit; cannot overturn a large one. |
| 3.0× | 2 700 | 76 % | Too strong — one final kill nearly rewrites the match. |

At 2.0×, a player trailing by up to ~1 500 points (roughly two patient kills) has a live path
to victory via one excellent final kill, while a player trailing by 3 000 does not. That is the
intended shape: **a comeback must be possible and must require excellence.**

### 6.1 Why the multiplier is frozen at append time

Per ADR-0004 rule 3, the multiplier is resolved when the `ScoreEvent` is appended, from the
event's tick — not at fold time. Consequence: a kill **initiated** at 7:29:5 and **landing** at
7:31 scores at 1.0×, because every bonus condition in the game is judged at initiation. This is
consistent with `SCORE-SILENT`, `SCORE-PATIENT`, `SCORE-BLENDED` and the rest, all of which
evaluate at the moment of initiation.

---

## 7. Player-count scaling math

### 7.1 Crowd count

Crowd is sized so that **clones per persona per player** stays roughly constant:

```
clones_per_persona(n) = 8 + round(4 × (n - 4) / 2)      # 10 at n=4, 11 at n=5, 12 at n=6
crowd_total(n)        = 4 × clones_per_persona(n) + filler(n)
filler(n)             ≈ 26 + 2×(n - 4)
```

| n | Clones/persona | Clone total | Filler | **Crowd** |
|---|---|---|---|---|
| 4 | 10 | 40 | 26 | **66** |
| 5 | 11 | 44 | 28 | **72** |
| 6 | 12 | 48 | 30 | **78** |

All within `TUN-CROWD-COUNT-MIN` 60 and `TUN-CROWD-COUNT-MAX` 90.

### 7.2 Compass range and area

Signal density is held constant by scaling range with the linear dimension of the playable
area:

```
range(n) = TUN-COMPASS-RANGE-MAX × (side(n) / 120)
```

| n | Playable side | Area | Compass range | Range / side |
|---|---|---|---|---|
| 4 | 90 m (soft-bounded) | 8 100 m² | 50 m | 0.56 |
| 5 | ~110 m | 12 100 m² | 55 m | 0.50 |
| 6 | 120 m | 14 400 m² | 60 m | 0.50 |

*(The 4-player ratio is deliberately slightly generous — with fewer players, a stalled hunt is
more damaging because there are fewer other events happening to fill the time.)*

### 7.3 Expected kills by player count

Mean separation scales with the map's linear dimension, so acquisition time scales with it too:

```
T(n) ≈ 96 × (side(n) / 120) ... for the acquisition component only (~35 s of the 96 s)
```

| n | Acquisition | Other phases | `T` | Kills = 480/(T+8) |
|---|---|---|---|---|
| 4 | 26 s | 61 s | 87 s | **5.1** |
| 5 | 32 s | 61 s | 93 s | **4.8** |
| 6 | 35 s | 61 s | 96 s | **4.6** |

Slightly *more* kills at 4 players, offset in practice by the shorter cycle spending more time
near degeneracy (§7.2 of [`../10_gdd/07_balance.md`](../10_gdd/07_balance.md)). The published
targets of ~4.0 / ~4.3 / ~4.6 in `TUNABLES` §16 apply a ~20 % downward correction at n=4 for
that effect.

---

## 8. The re-fold procedure

The single most valuable property of the event-sourced scoring design (ADR-0004): **a past
match can be re-scored under new tuning values, as a pure function.**

```gdscript
# Given an archived ScoreEvent log and a candidate ScoringTuning,
# compute what the match WOULD have scored. No engine, no network, no scene.
func what_if(log: Array[ScoreEvent], candidate: ScoringTuning) -> Dictionary:
    return ScoreLog.fold(log, candidate)
```

### 8.1 Procedure for any proposed tuning change

1. Collect ≥ 20 archived match logs with their `TEL-MATCH-START.tuning_profile_hash`.
2. Classify every player-match by `TEL-MEAN-SPEED` tercile into Patient / Opportunist /
   Aggressor. **Archetypes are measured, never self-reported.**
3. Fold each log under the current values → baseline distribution.
4. Fold each log under the candidate values → candidate distribution.
5. Compute the Patient : Aggressor ratio and the head-to-head win probability for both.
6. Only then change the value, and record the measurement in
   [`../00_meta/DECISION_LOG.md`](../00_meta/DECISION_LOG.md).

### 8.2 What re-folding cannot tell you

Honest limitation: re-folding holds **behaviour** constant. It answers *"what would this match
have scored?"*, never *"how would players have played differently?"*. A change to
`SCORE-BLENDED` would change how often players attempt blend kills, and re-folding cannot see
that.

**Therefore:** re-folding is for *screening* candidates cheaply, not for validating them.
Anything that survives a re-fold still needs a playtest.

---

## 9. Open questions

| # | Question | Position | Needed by |
|---|---|---|---|
| 1 | A10 (45 % stun-failure rate) is the model's most load-bearing guess and the most likely to be wrong. | Measure `TEL-STUN-LANDED` / `TEL-KILL-ATTEMPT` at the first 6-player playtest, before anything else. | M4 |
| 2 | A8's 96 s hunt duration is derived from A6's kill target, then sanity-checked — mildly circular. Should `T` be estimated independently instead? | The §2.4 decomposition is the independent estimate and it agrees. Treat both as provisional until `TEL-HUNT-DURATION` exists. | M4 |
| 3 | The model assumes pure archetypes. Real players mix, which compresses the gap. By how much is unknown. | Terciles by `TEL-MEAN-SPEED` will show the real distribution. If it is unimodal, the archetype framing itself is wrong and this model needs rebuilding around a continuous speed variable. | M6 |
| 4 | Should the ~60 % target itself be revisited? A game whose thesis is "patience wins" arguably *should* have patience win more than 60 % of the time; 60 % may be the wrong goal rather than the model being wrong. | Genuinely open, and a stakeholder question rather than a designer one. Raised in the final report. | M6 |
| 5 | Score variance is modelled as Poisson-in-kills only (A14), ignoring bonus-level spread. This understates variance and therefore overstates win probability. | Recompute with the empirical per-kill variance once `TEL-BONUS-FIRED` data exists. | M5 |

---
id: GDD-04-ABILITIES
title: "GDD Part 4 — Abilities, Passives and Loadouts"
version: 0.2.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-27
depends_on: [DOC-GLOSSARY, TUN-INDEX, GDD-01-VISION, GDD-03-SOCIAL-STEALTH]
---

# GDD Part 4 — Abilities, Passives and Loadouts

> **Context restated.** Project Sottovoce is a 4–6 player social-stealth free-for-all. Each
> player holds a **contract** on one other player and is the contract of an unknown third.
> A hidden **suspicion** value (0–100) governs three tiers — Anonymous (< 30), Noticed
> (30–69), Exposed (≥ 70) — which determine whether your hunter can see you and whether your
> prey is warned about you. Speed generates suspicion; standing still in a crowd erases it.
> Kills are worth 3–13× more when made patiently.
>
> Players equip **two abilities and one passive**, chosen in the lobby and locked for the
> whole match including across deaths.
>
> Implements: `SYS-ABILITY`, `SYS-LOADOUT`.

---

## 1. The legibility law

> **No ability may resolve without the victim having had a perceivable chance to read it.**
>
> Every ability ships with a **tell**: a visual signal, an audio signal, or both, perceivable
> by the victim *in time to react*. There are no invisible instant-wins.

This is Design Law 3 ([`01_vision.md`](01_vision.md) §2). It is the constraint that shapes
every entry in this chapter, and it is the reason the four MVP abilities are as slow and as
loud as they are.

**Why it is absolute.** The game's core promise is that outcomes are reconstructable
(Pillar 3, Legibility). A player who dies to something they could not perceive learns nothing,
and a player who learns nothing from dying quits — this is the "Tobias" persona's failure mode
from [`01_vision.md`](01_vision.md) §3.2. An ability with no tell converts a social-stealth
game into a lottery.

**The test, applied to every ability before it ships:** *Describe the tell in one sentence. If
you cannot, the ability is not finished.*

---

## 2. The ability template

Every ability — MVP and post-MVP — is specified against exactly these twelve fields. An
ability specification with a blank field is not ready to implement.

| Field | What it must state |
|---|---|
| **ID** | `ABIL-<NAME>`, immutable once merged. |
| **Original name** | Listed first, always. Functional-original per [`../00_meta/IP_GUARDRAILS.md`](../00_meta/IP_GUARDRAILS.md) §3.1. |
| **Fiction** | One sentence. What the character is physically doing. Constrains the animation and the audio. |
| **Input & cast time** | Which input, and how long before the effect begins. |
| **Effect** | Exactly what changes, in tunable terms. |
| **Duration** | How long the effect persists. |
| **Cooldown** | From *activation*, not from effect end. |
| **Suspicion cost** | The `TUN-` value, or the forced tier. |
| **Tell** | The mandatory perceivable signal, split into visual / audio / animation. **Stated in one sentence.** |
| **Counterplay** | What the victim or a third party can do about it. Must be specific, not "move away". |
| **Why it exists** | The design hole it fills. If two abilities have the same answer, one is redundant. |
| **Failure mode** | How this ability makes the game worse if mistuned, and the symptom to watch for. |

---

## 3. The MVP abilities

> **`ABIL-WHISPERBOLT` WAS DEFERRED TO POST-MVP ON 2026-08-27, SO THE MVP SET IS THREE:
> Cinderfall, Second Face and Lunge.** It is the cut that pays for the escape verb
> (`ADR-0014`, `SCOPE_FENCE.md` IN #5 and OUT #18), chosen on engineering cost rather than
> design merit — it is the only one of the four needing a replicated moving entity and hit
> validation at an impact half a second after the press, which `RewindClamp` has no rule for.
>
> **§3.2 below is kept in full and unchanged, and so is every number behind it.** A deferral
> that deletes the design has to redesign it to come back; this one is a `.tres` and a
> behaviour once `SYS-ABILITY` exists. `US-0068` carries the deferral, §8 lists it beside the
> post-MVP candidates, and the pair analysis in §7 is a superset that stays valid.
>
> **What it costs is recorded in OUT #18**: loadout variety halves, and **nothing in the MVP
> can reach a player on a roof** — which is the job §3.2 gives this ability. The roof stratum
> stays priced by `TUN-SUSPICION-GAIN-ROOF` (+18/s, permanently Exposed) and by scoring nothing
> while you sit there. Revisit if `TEL-TIME-BY-STRATUM` shows roof time rising.

### 3.1 **Cinderfall** — `ABIL-CINDERFALL`

| Field | Specification |
|---|---|
| **Fiction** | A fired ash-pot, thrown underarm. It bursts into a low, choking cloud of hot cinders and glass dust — the district's own material, turned into cover. |
| **Input & cast** | `INPUT-ABILITY-*`. Cast `TUN-CINDERFALL-CAST-TIME` 0.45 s (the wind-and-throw). |
| **Effect** | A cloud of radius `TUN-CINDERFALL-RADIUS` 5.0 m at the impact point, placeable up to `TUN-CINDERFALL-THROW-RANGE` 8.0 m away or at your feet. Blocks line of sight for all detection, Compass lock and `SCORE-FOCUS` accumulation (`TUN-CINDERFALL-BLOCKS-LOS`). **Forbids kill *initiation* inside the radius, by anyone, including the caster** (`TUN-CINDERFALL-BLOCKS-KILL`). A kill already in progress completes. |
| **Duration** | `TUN-CINDERFALL-DURATION` 4.0 s. Long enough to break a 1.6 s lock and leave; short enough that it cannot camp a corner. |
| **Cooldown** | `TUN-CINDERFALL-COOLDOWN` 45 s. Roughly once per hunt cycle. |
| **Suspicion** | `TUN-CINDERFALL-SUSPICION` +40 (= `TUN-SUSPICION-GAIN-LOUD-ABILITY`). From Anonymous this is instant **Noticed**, requiring 5 s of walking to clear. |
| **Tell** | *A hot orange burst and a hard crack, and every NPC within 9 m runs.* Visual: the cloud itself, visible at 40 m. Audio: a sharp crack at `TUN-CINDERFALL-TELL-AUDIO-RADIUS`, ducked ambience. Animation: 0.45 s underarm throw. **Startle radius `TUN-CINDERFALL-STARTLE-RADIUS` 9.0 m** — the crowd itself becomes the tell. |
| **Counterplay** | Do not enter the cloud — you cannot initiate a kill inside it either, so pursuing into it is pointless. Instead **wait at its edge**: it lasts 4 s, the caster is now Noticed for at least 5 s afterwards, and the Startle wave has told everyone within 30 m roughly where they are. The correct counter to Cinderfall is patience, which is the correct counter to most things here. |
| **Why it exists** | **To give a punished attacker exactly one escape.** Without it, a hunter who is spotted and locked has no recourse but to sprint, and sprinting into Exposed is a death sentence. Cinderfall converts "I have lost this hunt" into "I have lost this hunt but I will survive to try again". One per 45 s, and it costs your anonymity to use. |
| **Failure mode** | *If the radius or duration grows*, it becomes a corner-camping tool: a player who cannot be killed inside a cloud they refresh. Symptom: players deploying it *pre-emptively* rather than reactively. *If the kill-block is removed*, it becomes an offensive tool for forcing blind kills, which is the opposite of legible. |

**The design detail that carries the ability:** the kill-block applies **to the caster too**.
That single symmetry is what makes Cinderfall purely defensive. Without it, the dominant play
would be "cloud, then kill inside it", and a kill nobody can see is a legibility-law violation
wearing an ability's clothes.

---

### 3.2 **Whisperbolt** — `ABIL-WHISPERBOLT` — **DEFERRED TO POST-MVP (2026-08-27)**

*Specified in full and kept unchanged. Not in the MVP loadout; see the banner at the top of
§3 and `SCOPE_FENCE.md` OUT #18.*

| Field | Specification |
|---|---|
| **Fiction** | A weighted glass-cutter's blade, drawn from the sleeve, sighted, and thrown flat. |
| **Input & cast** | `INPUT-ABILITY-*`, then **hold** through `TUN-WHISPERBOLT-WINDUP` 1.0 s. Releasing early cancels with the cooldown spent. |
| **Effect** | A ranged kill on your contract at `TUN-WHISPERBOLT-RANGE-MIN` 3.0 m to `TUN-WHISPERBOLT-RANGE-MAX` 12.0 m. Projectile speed `TUN-WHISPERBOLT-PROJECTILE-SPEED` 22 m/s — 0.55 s of flight at maximum range, so there is a real, small dodge window after release. Requires line of sight at release *and* at impact, validated server-side against the lag-compensated world. |
| **Duration** | Instantaneous on hit. |
| **Cooldown** | `TUN-WHISPERBOLT-COOLDOWN` 40 s. |
| **Suspicion** | **Forced Exposed** for the full wind-up plus `TUN-WHISPERBOLT-EXPOSED-TAIL` 1.5 s after release, hit or miss (`TUN-WHISPERBOLT-FORCES-EXPOSED`). A miss additionally applies `TUN-WHISPERBOLT-SUSPICION-ON-MISS` +30 — a miss is a failed kill. |
| **Tell** | *For one full second you are outlined, standing still, with your arm cocked — and your target's screen has already flashed red.* Visual: forced Exposed outline, visible through geometry at 60 m to your contract's hunter and to your own prey. Animation: a static, unmistakable throwing pose. Audio: a rising metallic draw at `TUN-WHISPERBOLT-TELL-AUDIO-RADIUS`. **This is the loudest tell in the game, and that is the entire balance of the ability.** |
| **Counterplay** | One second is a long time. Break line of sight — step behind a column, into a Cinderfall, or simply behind a walking group's mass (NPCs do not block LOS, but they do block *your view of the thrower*, and the thrower needs to track you). Or close the distance: inside 3.0 m the ability is illegal, and at 3.0 m you are inside `TUN-STUN-RANGE`, so a target who charges a winding-up Whisperbolt user can stun them mid-cast. |
| **Why it exists** | **To punish rooftop campers.** The roof stratum gives information and safety; `TUN-SUSPICION-GAIN-ROOF` (+18/s) prices the safety, but a camper who accepts being Noticed still has an unreachable position. Whisperbolt reaches from the street to the balcony (12 m) and from the balcony to the roof. It is the answer to "there is a player up there and I cannot get to them". |
| **Failure mode** | *If the wind-up shortens*, it becomes a ranged assassination tool and the approach phase — the entire game — becomes optional. Symptom: mean kill distance rising above ~4 m. *If the range grows*, it becomes sniping and the crowd stops mattering. *If the Exposed tail is removed*, a missed throw carries no consequence and it becomes a free probe. |

**The number that carries the ability:** the 1.0 s wind-up. Everything else is decoration.
A player who fires Whisperbolt has announced themselves to the entire district for a full
second in exchange for a chance at a kill they could not otherwise make. That trade is
correct; shortening it is not a buff, it is a different ability.

---

### 3.3 **Second Face** — `ABIL-SECONDFACE`

| Field | Specification |
|---|---|
| **Fiction** | A reversible over-garment and a change of carriage. You are not becoming someone else; you are becoming *a different kind of nobody*. |
| **Input & cast** | `INPUT-ABILITY-*`. Cast `TUN-SECONDFACE-CAST-TIME` 0.8 s. |
| **Effect** | You adopt the appearance — mesh, materials and full animation set — of another persona. **You do not choose which**: `TUN-SECONDFACE-PERSONA-SOURCE` is `nearest_clone`, so you become whichever persona's clone is nearest and visible. Falls back to a random other persona if no clone is visible. |
| **Duration** | `TUN-SECONDFACE-DURATION` 15.0 s — two full hunt cycles. |
| **Cooldown** | `TUN-SECONDFACE-COOLDOWN` 60 s. The longest in the set, because it is the strongest ability: it attacks identity, which is what the whole game is made of. |
| **Suspicion** | `TUN-SECONDFACE-SUSPICION` +10. Cheap. The cost is the cooldown, not the noise — this is the one quiet ability. |
| **Breaks on** | Sprinting (`TUN-SECONDFACE-BREAK-SPEED` = `TUN-SPEED-SPRINT`; you may run, you may not sprint), being hit or stunned, or completing a kill (`TUN-SECONDFACE-BREAK-ON-KILL`, resolved *after* the kill so `SCORE-MASKED` still pays). |
| **Tell** | *A figure in the crowd visibly changes shape over three-quarters of a second — and changes back just as visibly when it ends.* Visual: a silhouette morph readable at 20 m. Animation: 0.8 s transition in, `TUN-SECONDFACE-BREAK-TELL-DURATION` 0.6 s transition out. Audio: a soft cloth rush, `TUN-SECONDFACE-TELL-AUDIO-RADIUS`. **The un-morph is the more important tell**, because it happens at a moment the player did not choose. |
| **Counterplay** | Watch for the morph. A player who sees a Cantatrice become a Vetraio knows two things: *that person is a player*, and *what they now look like*. Second Face converts a certainty into a different certainty; it does not create ambiguity for anyone who was looking. Additionally: your **Compass still points at your contract** regardless of what they look like, so a disguise never breaks a hunt — only an identification. |
| **Why it exists** | **To reward reading the crowd.** The `nearest_clone` rule is the whole design: the ability's value depends entirely on *where you stand when you use it*. Cast it beside a lone Lucerna and you become the fifth Lucerna in an area with four; cast it in the middle of a Pesatore cluster and you vanish. It converts crowd literacy into a mechanical advantage, which is the skill the game most wants to teach. |
| **Failure mode** | *If the player may choose the persona*, it stops being about the crowd and becomes a menu. *If it does not break on kill*, a player becomes untrackable across multiple kills and the social layer dies. *If the morph tell is subtle*, it becomes an invisible identity swap — the clearest possible legibility-law violation. |

**The design detail that carries the ability:** you do not choose. `nearest_clone` makes
Second Face a *positional* ability disguised as a transformation ability, and positional
abilities reward map and crowd knowledge, which is what this game is about.

---

### 3.4 **Lunge** — `ABIL-LUNGE`

| Field | Specification |
|---|---|
| **Fiction** | You stop pretending. Three fast steps and a shoulder. |
| **Input & cast** | `INPUT-ABILITY-*`. Wind-up `TUN-LUNGE-WINDUP` 0.25 s, then the dash. |
| **Effect** | A committed dash of `TUN-LUNGE-DISTANCE` 6.0 m at `TUN-LUNGE-SPEED` 9.0 m/s (0.67 s of travel — faster than sprint). If the dash ends within `TUN-KILL-RANGE` and cone of your contract, the kill **auto-initiates** (`TUN-LUNGE-AUTO-KILL`): it is one button, not two, because it is the panic button. Direction is locked at wind-up; you cannot steer mid-dash. |
| **Duration** | 0.92 s total (wind-up + dash). |
| **Cooldown** | `TUN-LUNGE-COOLDOWN` 30 s. The shortest in the set — it is the weakest ability by expected value and the strongest by desperation value. |
| **Suspicion** | `TUN-LUNGE-SUSPICION` +40 (= `TUN-SUSPICION-GAIN-LOUD-ABILITY`), applied at wind-up. You are **Noticed the instant you press it**, and if the kill lands from a suspicion above 70 you take `SCORE-RECKLESS` (−50). |
| **Tell** | *A shout, a drop into a run, and the crowd scatters along your path.* Audio: a sharp intake and footfall at 0.25 s wind-up, audible at `TUN-LUNGE-TELL-AUDIO-RADIUS`. Visual: a movement speed no civilian has. **`TUN-LUNGE-STARTLE-RADIUS` 7.0 m** — the dash paints a fleeing-NPC arrow directly at you. |
| **Counterplay** | **Stun it.** `TUN-LUNGE-STUNNABLE` is true for the entire wind-up and dash (`TUN-STUN-VS-LUNGE-WINDOW`), and the +40 suspicion at wind-up guarantees the lunger is at least Noticed, which satisfies `TUN-STUN-MIN-TIER`. A prepared defender **always** beats a Lunge: 0.92 s of telegraphed, unsteerable approach against a 0.7 s stun animation with a 120° cone. Missing costs the lunger `TUN-LUNGE-WHIFF-STAGGER` 1.2 s standing in the open, Noticed. |
| **Why it exists** | **The "I have been made, commit now" button.** [`02_player_controller.md`](02_player_controller.md) §1.5 deliberately makes sprint awkward to enter, because sprint is for *planned* speed. Lunge is for *unplanned* speed: one press, no timing, when your target has turned and you have one second to decide whether to abandon the hunt or spend everything on it. It is the mechanically correct answer to panic, which means panic has an answer that is not "mash sprint". |
| **Failure mode** | *If the distance grows or the cooldown shortens*, it becomes the primary opener and the approach phase collapses — the failure this whole design most fears. Symptom: `TEL-KILLS-BY-METHOD` showing Lunge above ~15 % of kills. *If it were not stunnable*, it would hard-counter the defensive play the game is built on, inverting Law 5. |

---

### 3.5 The four in comparison

*Kept at four. Whisperbolt's column is what the MVP is doing without, and it is the row-by-row
record of what returns when the deferral is lifted.*

| | Cinderfall | Whisperbolt | Second Face | Lunge |
|---|---|---|---|---|
| **Role** | Escape | Reach | Concealment | Commitment |
| **Cooldown** | 45 s | 40 s | 60 s | 30 s |
| **Suspicion** | +40 | forced Exposed | +10 | +40 |
| **Loudness** | Very (9 m startle) | Very (Exposed 2.5 s) | Quiet | Very (7 m startle) |
| **Wins you** | Time | Distance | Identity | Range |
| **Costs you** | Anonymity | Anonymity, publicly | 60 s and a tell | Anonymity and the initiative |
| **Best used** | Reactively, when locked | From cover, at a camper | Pre-emptively, in a crowd | When already discovered |
| **Enables bonus** | — | — | `SCORE-MASKED` +150 | — |
| **Countered by** | Waiting at the edge | Breaking LOS, or closing to 3 m | Watching for the morph | Stun |

**Note the pattern:** three of four abilities cost anonymity — **two of the three MVP
abilities, after the Whisperbolt deferral** — and the one that does not
(Second Face) costs a full minute. **There is no cheap ability.** This is deliberate: an
ability that is free to use becomes part of the baseline moveset, and the baseline moveset in
this game is *walking slowly*.

---

## 4. The three passives

One passive is equipped. Passives have no input, no cooldown and no tell — which is
permissible *only* because none of them affects what another player perceives. A passive that
changed your visibility would need a tell and would therefore not be a passive.

### 4.1 **Stillness** — `PASV-STILLNESS`

| Field | Specification |
|---|---|
| **Effect** | Suspicion decay is `TUN-PASV-STILLNESS-MULT` 1.40× faster while stationary — 11.2/s instead of 8.0/s. "Stationary" means speed below `TUN-PASV-STILLNESS-SPEED-CEILING` 0.15 m/s, which is non-zero so that micro-drift in a walking-group slot does not disable it. |
| **In practice** | Full 100 → 0 in 8.9 s instead of 12.5 s. Exposed → Anonymous in 6.3 s instead of 8.8 s. |
| **Why it exists** | The passive for a player who commits to the thesis. It does not make you safer while moving; it makes *recovery* faster, which shortens the punishment for a mistake and lengthens the time you can spend usefully hidden. |
| **Who takes it** | Players who play the crowd-pocket ambush game. Pairs naturally with Second Face. |

### 4.2 **Cold Read** — `PASV-COLDREAD`

| Field | Specification |
|---|---|
| **Effect** | The Compass lock arc fills `TUN-PASV-COLDREAD-MULT` 1.30× faster — 1.23 s instead of 1.60 s. |
| **In practice** | 1.23 s is *below* the NPC stride cycle (~1.1 s… marginally above it). This is deliberate: Cold Read brings a lock from "impossible through a walking group" to "just barely possible through a walking group". It changes a category, not just a number. |
| **Why it exists** | The offensive passive, and the only one that improves identification rather than survival. It is the pick for a player who hunts by watching from a fixed position. |
| **Who takes it** | Players who use the campanile and the loggia as observation posts. Pairs with Whisperbolt. |

### 4.3 **Second Wind** — `PASV-SECONDWIND`

| Field | Specification |
|---|---|
| **Effect** | `TUN-STUN-LOCKOUT` is reduced by `TUN-PASV-SECONDWIND-REDUCTION` 4.0 s for this player — 12 s becomes 8 s. |
| **Explicitly does *not*** | Reduce `TUN-STUN-FREEZE` (4.0 s). Being stunned must always be catastrophic *in the moment*; the passive only shortens the exile afterwards. |
| **Why it exists** | The recovery passive, for aggressive players who expect to be stunned. It is deliberately the narrowest of the three — it does nothing at all until you make a mistake, which is an honest description of what aggression buys you here. |
| **Who takes it** | Players running Lunge. Also, in practice, new players, who get stunned a lot. |

### 4.4 Why exactly these three

Each passive improves a different phase of the loop, and none improves two:

| Passive | Improves | Phase |
|---|---|---|
| Stillness | Recovery from suspicion | *After* a mistake, before the next attempt |
| Cold Read | Identification speed | *During* the approach |
| Second Wind | Recovery from a stun | *After* being countered |

A fourth passive would need to improve a phase none of these touches. The obvious candidate —
something that improves the *kill itself* — is deliberately absent, because the kill is
already the most reliable part of the loop and making it more reliable would reduce the value
of everything preceding it.

---

## 5. Loadout rules

| Rule | Value | Rationale |
|---|---|---|
| Active slots | `TUN-ABILITY-SLOTS-ACTIVE` 2 | Two, fixed. Three would make loadout reading — a core skill — too high-dimensional to learn in one session. With two, there are only 6 possible ability pairs; a player can learn all six in an evening. |
| Passive slots | `TUN-ABILITY-SLOTS-PASSIVE` 1 | |
| Total combinations | 6 pairs × 3 passives = **18** | Small enough to be learnable, large enough to matter. |
| Selected | In the lobby, before the countdown | |
| Locked | `TUN-ABILITY-LOCK-AT-MATCH-START` true — **for the entire match, including across deaths** | See §5.1. |
| Global cooldown | `TUN-ABILITY-GLOBAL-COOLDOWN` 0.5 s | Prevents ability-chaining combos no victim can read. |
| Input buffer | `TUN-ABILITY-INPUT-BUFFER` 0.20 s | An ability pressed slightly early is queued, not dropped. |
| Cooldowns on death | **Reset to zero** | Death already costs 5 s and a life's worth of `SCORE-VARIETY` progress. Carrying cooldowns through death would compound the punishment and push players toward passivity. |

### 5.1 Why loadouts are pre-match-locked

The load-bearing part is not that loadouts are chosen in the lobby — it is that they **cannot
change on death**.

**The argument:** in this game, information about other players is the primary resource. If
you have seen someone use Cinderfall, you know something durable about them: they have an
escape, it is on a 45 s cooldown, and they do not have whichever ability they did not take.
That knowledge is worth acting on — you can time an approach around their cooldown.

If a player could re-pick on death, that knowledge would decay to nothing after their first
death, which in an 8-minute match is roughly every 90 seconds. Kit knowledge would become
worthless within one hunt cycle, and the deduction it enables — *the single most social skill
in the game* — would disappear.

There is also a fairness argument: re-picking on death is counter-picking. A player who dies
to a Whisperbolt could respawn with Cinderfall specifically to answer it. That converts death
from a cost into a tactical option, which inverts the incentive the respawn delay is meant to
create.

**The cost, stated honestly:** a player who picks a loadout they dislike is stuck with it for
8 minutes. This is real and is accepted. The mitigation is that the lobby shows each ability's
full specification, and that with only 18 combinations the space is learnable quickly.

### 5.2 What the lobby must show

Because the choice is permanent and because reading opponents' kits is a skill, the lobby is
an information surface, not a menu:

- Every ability's cooldown, suspicion cost and tell, stated plainly.
- **Other players' selections are hidden.** You learn their kit by watching them use it.
- Persona selection is separate from loadout and *is* visible to others — because your persona
  is visible in the world anyway, and hiding it in the lobby would create a pointless
  information asymmetry that evaporates at match start.

---

## 6. The tell taxonomy

Every tell decomposes into three channels. An ability must have at least two of the three, and
**must have at least one that survives the victim not looking at the caster.**

| Channel | What it is | Survives the victim not looking? | Example |
|---|---|---|---|
| **Visual — direct** | Something on the caster's body | ❌ No | Whisperbolt's throwing pose |
| **Visual — environmental** | Something in the world the ability causes | ✅ Yes | Cinderfall's cloud; Lunge's Startle wave |
| **Audio** | A sound at a stated radius | ✅ Yes | Lunge's 0.25 s wind-up at 20 m; Cinderfall's crack at 25 m |
| **Animation** | The caster's motion, distinct from any civilian motion | ❌ No | Second Face's 0.8 s morph |
| **State** | A forced suspicion tier change | ⚠️ Partial — only if the victim is the caster's contract or pursuer | Whisperbolt's forced Exposed |

### 6.1 The tell audit

| Ability | Visual direct | Visual environmental | Audio | Animation | State | Survives not-looking? |
|---|---|---|---|---|---|---|
| **Cinderfall** | — | ✅ 5 m cloud, 40 m visibility | ✅ crack, 25 m | ✅ throw | ✅ +40 | ✅✅ (environment + audio) |
| **Whisperbolt** | ✅ pose | — | ✅ metallic draw | ✅ static hold | ✅ **forced Exposed** | ⚠️ audio + state only |
| **Second Face** | ✅ morph | — | ✅ cloth rush, 8 m | ✅ 0.8 s in, 0.6 s out | — | ⚠️ audio only, and quiet |
| **Lunge** | — | ✅ 7 m Startle wave | ✅ shout + footfall, 20 m | ✅ dash | ✅ +40 | ✅✅ (environment + audio) |

**Two abilities are weaker on the not-looking axis, and both are deliberate:**

- **Whisperbolt** is compensated by *duration*: 1.0 s is long enough that a victim who is
  scanning at all will complete a sweep. And its state tell (forced Exposed) is the strongest
  in the game for the two people who matter most — the caster's own hunter and prey.
- **Second Face** is the quietest ability in the game and is *meant to be*. It is the only
  ability whose tell is genuinely missable, and that is priced into its 60 s cooldown. But note
  what it *cannot* do: it never breaks a Compass. Your contract's bearing points at them
  whether or not you recognise them. Second Face fools **people**, never **systems** — and
  every fooled person had a chance to see the morph.

### 6.2 The tell rule for future abilities

> A new ability must fill at least two tell channels, and at least one must be environmental
> or audio. An ability whose only tells are direct-visual and animation is invisible to
> anyone not already looking at the caster, and therefore violates the legibility law.

---

## 7. Anti-synergy audit

Every ability pair, checked for degeneracy. A combination is degenerate if it removes
counterplay rather than adding options.

### 7.1 The six pairs

#### Cinderfall + Whisperbolt — "the vanishing sniper"

| | |
|---|---|
| **The theoretical combo** | Whisperbolt from range; if it misses, Cinderfall to break the retaliation. |
| **Degenerate?** | **No.** The two cooldowns are 40 s and 45 s but the *sequence* costs both, leaving you with nothing for 40+ seconds. And Cinderfall does not remove the +40 suspicion you now carry on top of Whisperbolt's Exposed tail — you emerge from your own cloud Noticed at minimum, having announced yourself twice. |
| **Verdict** | Strong and fair. This is the "commit to range" build. |

#### Cinderfall + Second Face — "the disappearing act"

| | |
|---|---|
| **The theoretical combo** | Cinderfall to break line of sight, then Second Face *inside the cloud* so nobody sees the morph. Emerge as a different persona with no witnesses. |
| **Degenerate?** | **This is the one genuinely concerning combination**, and it is the reason `TUN-CINDERFALL-STARTLE-RADIUS` is 9 m rather than 5 m. The cloud hides the morph, but the Startle wave marks the position for everyone within 30 m, and anyone watching sees a Vetraio enter a cloud and a Lucerna leave it — the *absence* of the expected persona is itself the tell. |
| **Mitigation in place** | Second Face's `nearest_clone` rule: inside a cloud you may have no visible clone, triggering the random-persona fallback. You do not control what you become. |
| **Residual risk** | Real but bounded. Watch `TEL-SECONDFACE-IN-CLOUD` frequency. If it exceeds ~20 % of Second Face uses, the fix is to forbid casting Second Face inside a Cinderfall volume — a one-line validation, deliberately not applied pre-emptively because the combo is *clever*, and clever should be allowed to exist until it is proven dominant. |

#### Cinderfall + Lunge — "the smash and grab"

| | |
|---|---|
| **The theoretical combo** | Lunge in, kill, Cinderfall to escape the aftermath. |
| **Degenerate?** | **No, and it is barely viable.** Lunge costs +40 suspicion; the kill from that state incurs `SCORE-RECKLESS` (−50) if you crossed 70, which Lunge alone nearly does. Then Cinderfall costs another +40. Net result: a 50-point kill and 6+ seconds at Exposed, during which your own pursuer sees you outlined through walls. |
| **Verdict** | Self-punishing. This is the "I have given up on scoring" build, and the scoring makes that explicit. |

#### Whisperbolt + Second Face — "the masked shot"

| | |
|---|---|
| **The theoretical combo** | Second Face for `SCORE-MASKED` (+150), then Whisperbolt for the kill — a disguised ranged kill. |
| **Degenerate?** | **No — the abilities actively fight each other.** Whisperbolt forces Exposed for 2.5 s, and being Exposed does not break Second Face, but it *does* mean the outline is drawn on your disguised body. Your contract's hunter sees an outlined Vetraio who was a Lucerna a moment ago. The disguise is preserved mechanically and destroyed informationally. |
| **Verdict** | A trap build that looks strong. It will be discovered and abandoned, which is healthy — the lobby's ability descriptions should not spoil this. |

#### Whisperbolt + Lunge — "the double commit"

| | |
|---|---|
| **The theoretical combo** | Whisperbolt at range; if it misses, Lunge to close before they escape. |
| **Degenerate?** | **No.** Both are loud, both cost anonymity, and the sequence puts you at Exposed with a 1.2 s whiff stagger if the Lunge misses too. But it is *fun*, and it gives a player one full commitment chain to spend on a target they have identified. |
| **Verdict** | The aggressive build. Correctly high-variance: it produces either a fast kill or a very public failure. |

#### Second Face + Lunge — "the wolf in the crowd"

| | |
|---|---|
| **The theoretical combo** | Blend as another persona, walk to conversational distance, Lunge for the kill. |
| **Degenerate?** | **No, and it is the most interesting pair in the set.** If you have got close enough to Lunge (6 m), you were close enough to simply walk up and kill — for 650 points instead of ~250. The combo *pays worse than not using it*. Its actual use is different: Second Face to approach, and Lunge held in reserve for the moment your target turns around. |
| **Verdict** | Excellent. It rewards the patient play and keeps the panic button in the pocket. |

### 7.2 Ability × passive interactions worth naming

| Combination | Effect | Concerning? |
|---|---|---|
| Second Face + **Stillness** | Faster recovery while disguised and stationary — the maximally passive ambush build. | No. It is the thesis build. If it dominates, the thesis is working. |
| Whisperbolt + **Cold Read** | Faster identification at range, then a ranged kill: the observation-post build. | Watch it. Cold Read's 1.23 s lock plus Whisperbolt's 12 m reach makes the campanile strong. `TUN-SUSPICION-GAIN-ROOF` (+18/s) is the counter, and it is applied for *presence*, so a camper is permanently Noticed. |
| Lunge + **Second Wind** | Aggression with faster recovery from the stun that aggression invites. | No. It is the correct passive for that playstyle and it does not reduce `TUN-STUN-FREEZE`. |
| Cinderfall + **Stillness** | Cloud, then stand still inside it and clear 40 suspicion in 3.6 s. | **Mildly concerning.** The cloud blocks LOS for exactly `TUN-CINDERFALL-DURATION` 4.0 s, and 40 suspicion clears in 3.6 s at 11.2/s. The timings are suspiciously aligned. Watch whether "cloud and stand" becomes the default escape; if so, the fix is shortening the cloud to 3.5 s, not nerfing Stillness. |

### 7.3 The audit's conclusion

**No pair is degenerate. Two need monitoring** (Cinderfall + Second Face; Cinderfall +
Stillness), both with a named telemetry signal and a named one-line fix.

The reason the space is clean is structural rather than lucky: three of four abilities cost
anonymity, and anonymity is a *shared* resource across everything you do. Abilities cannot
combo freely because they are all drawing on the same account.

---

## 8. Post-MVP ability backlog

**Explicitly out of scope.** Listed so the ideas are recorded and so nobody re-derives them
mid-milestone. Adding any of these requires an ADR per [`../00_meta/SCOPE_FENCE.md`](../00_meta/SCOPE_FENCE.md).

| Name | One-line pitch | Fills the hole | Risk |
|---|---|---|---|
| **Whisperbolt** *(deferred, not a new idea)* | Already specified in §3.2 and fully tuned. | Reach — **the roof stratum has no mechanical answer without it**. | None design-side; the cost is netcode. **First in the queue when the deferral lifts**, ahead of everything below, because it is the only row here that is already designed, tuned, ID'd and storied (`US-0068`). |
| **Nightshade** | A contact poison: your contract dies 6 s after you touch them in passing. | The delayed kill. **Activates the dormant `SCORE-POISONED` bonus** (ASM-0016), which is already implemented and tested. | Tell is very hard: a kill with a 6 s delay is a kill with no perceivable cause. Would need the victim to receive an unmistakable "you have been poisoned" state. |
| **Lantern Call** | Summon a walking group to reroute toward your position over ~8 s. | Mobile cover on demand — makes crowd manipulation an active verb rather than a passive resource. | Powerful and quiet. Would need the reroute itself to be a visible tell. |
| **Chalk Mark** | Mark a location; you are alerted if any *player* passes within 5 m of it. | Area denial for the defensive player. Gives prey a proactive tool, which the current set lacks. | May encourage corner-parking, which is an audited degenerate strategy. |
| **False Coin** | Drop an object that draws 3–5 NPCs to gawk at it for 5 s. | A portable crowd. Lets a player *create* a blend pocket. | Trivially strong if it can be used to fabricate a pocket during a chase. Would need a long cast. |
| **Understudy** | Your next death leaves a corpse of a *different* persona. | Misdirection about who died. Attacks the corpse information channel, which nothing currently does. | Attacks a public information channel — needs very careful handling under the legibility law. |
| **Long Sight** | Extend `TUN-COMPASS-LOCK-RANGE` from 20 m to 32 m for 8 s. | Identification at range without a kill tool attached. | Least interesting of the set; probably a passive rather than an ability. |
| **Quiet Step** | Reduce footstep audio radius by 60 % for 12 s. | Attacks the one unblockable channel (§11 channel 17 of Part 3). | **Dangerous.** Footstep audio is the floor of the information economy; an ability that removes it is an ability that removes the floor. Would need a compensating visual tell. |

**Ranking for post-MVP consideration:** **`ABIL-WHISPERBOLT` first and separately** — it is a
restoration rather than a new design, and the roof stratum is unanswered until it lands. Then
of the genuinely new ones: Nightshade first (the scoring already exists), then
False Coin (deepest interaction with the crowd), then Chalk Mark. Quiet Step last, and
possibly never.

---

## 9. How to add an ability

The process, so it is not improvised:

1. Fill the §2 template completely. A blank field blocks.
2. Answer the §6.2 tell rule: at least two channels, at least one environmental or audio.
3. Run the §7 anti-synergy audit against **every** existing ability and passive. With 4
   abilities that is 4 pairs plus 3 passive interactions; the cost grows quadratically, which
   is itself an argument for a small set.
4. Add the ability's information channel(s) to the master table in
   [`03_social_stealth.md`](03_social_stealth.md) §11.1 with all six columns.
5. Add its tunables to [`../50_tuning/TUNABLES.md`](../50_tuning/TUNABLES.md) §8 with ranges
   and rationales.
6. Write an ADR if it is outside the scope fence (all post-MVP abilities are).
7. Implementation is ≤ 3 files by design — see
   [`../20_tdd/09_ability_system.md`](../20_tdd/09_ability_system.md) §5.

---

## 10. Acceptance criteria

- [ ] All four MVP abilities are implemented as `AbilityData` resources with every §2 template field populated.
- [ ] No ability has a hardcoded constant; every value traces to a `TUN-` ID.
- [ ] Every ability's tell fills at least two channels from §6, with at least one environmental or audio.
- [ ] `TUN-CINDERFALL-BLOCKS-KILL` applies to the caster; `test_cinderfall_self_block.gd` asserts a caster cannot initiate a kill inside their own cloud.
- [ ] Cinderfall startles NPCs within `TUN-CINDERFALL-STARTLE-RADIUS` 9 m.
- [ ] Whisperbolt forces Exposed for wind-up + `TUN-WHISPERBOLT-EXPOSED-TAIL`, on hit **and** on miss.
- [ ] Whisperbolt cannot be released below `TUN-WHISPERBOLT-RANGE-MIN` 3.0 m (invariant §17.11: greater than `TUN-KILL-RANGE`).
- [ ] A Whisperbolt caster can be stunned during wind-up if the target reaches 3.0 m.
- [ ] Second Face selects `nearest_clone`, never a player choice; falls back to a random other persona when no clone is visible.
- [ ] Second Face breaks on sprint, on damage, and *after* kill resolution so `SCORE-MASKED` still applies.
- [ ] Second Face's morph and un-morph are both visible at 20 m.
- [ ] Second Face never affects the Compass: a hunter's bearing to a disguised contract is unchanged. Asserted by `test_secondface_compass_unaffected.gd`.
- [ ] Lunge is stunnable for its entire wind-up and dash (`TUN-STUN-VS-LUNGE-WINDOW`).
- [ ] Lunge's direction locks at wind-up and cannot be steered.
- [ ] Lunge auto-initiates the kill only against the caster's contract, never against another player.
- [ ] All three passives are implemented and none affects what another player perceives.
- [ ] `PASV-SECONDWIND` reduces `TUN-STUN-LOCKOUT` only, never `TUN-STUN-FREEZE`.
- [ ] Loadouts are immutable from match start through every respawn; `test_loadout_lock.gd` asserts a death does not reopen selection.
- [ ] Cooldowns reset on death.
- [ ] `TUN-ABILITY-GLOBAL-COOLDOWN` 0.5 s prevents two abilities resolving within half a second.
- [ ] Other players' loadouts are not visible in the lobby; persona selection is.
- [ ] `TEL-SECONDFACE-IN-CLOUD` and `TEL-KILLS-BY-METHOD` are logged, so §7's two monitored combinations are measurable.

---

## 11. Failure modes

| # | Failure | Symptom | Root cause to check |
|---|---|---|---|
| 1 | **An ability becomes the opener.** | `TEL-KILLS-BY-METHOD` shows any single ability above ~15 % of kills. | Almost certainly Lunge (distance or cooldown) or Whisperbolt (wind-up). The approach phase is the game; if an ability short-circuits it, the ability is wrong. |
| 2 | **Abilities are never used.** | Below ~1 use per player per match. | Cooldowns too long, or the suspicion costs make them net-negative. An unused ability is a wasted loadout slot and a wasted design. |
| 3 | **Cinderfall becomes proactive.** | Players deploy it before being spotted, to pre-place cover. | Duration or radius too large. Cinderfall must be a *reaction*. |
| 4 | **Second Face is invisible.** | Players report opponents "just becoming someone else" with no warning. | Morph tell too subtle, or the 0.8 s cast is being masked (by Cinderfall — see §7.1). |
| 5 | **Second Face is useless.** | Nobody takes it; the morph is spotted every time. | Either the tell is too strong, or players are always being watched — which would suggest the crowd is too small, not that the ability is weak. Diagnose before tuning. |
| 6 | **Whisperbolt kills from safety.** | Mean kill distance rises above ~4 m; rooftop kill rate rises. | Wind-up too short, range too long, or the Exposed tail too short. |
| 7 | **Lunge is unstunnable in practice.** | Defenders report being unable to react to a 0.92 s telegraphed dash. | Network: the wind-up may not be replicating early enough. This is a netcode bug wearing a balance costume — check `NET-S2C-ABILITY-STARTED` latency before touching tunables. |
| 8 | **A passive is mandatory.** | One passive is taken above ~60 % of the time. | Likely Cold Read (identification is the hardest skill, so speeding it up is the most valuable help). If so, reduce `TUN-PASV-COLDREAD-MULT` rather than buffing the others. |
| 9 | **Loadout lock feels punitive.** | Players report being stuck with a bad pick and disengaging. | The lobby's information surface (§5.2) is insufficient. Fix the lobby, not the lock. |
| 10 | **Cooldown reset on death is exploited.** | Players suicide to refresh abilities. | Would require dying to be cheap, which `TUN-RESPAWN-DELAY` 5 s and `SCORE-VARIETY` resetting should prevent. If it happens, the fix is to preserve cooldowns across death — reversing the §5 rule — not to add a death penalty. |

---

## 12. Open questions

| # | Question | Position taken | Needed by |
|---|---|---|---|
| 1 | Should Second Face be castable inside a Cinderfall volume? Currently yes; §7.1 records the concern and the one-line fix. | Allow it. Clever combinations should exist until proven dominant. Monitor `TEL-SECONDFACE-IN-CLOUD`. | M5 |
| 2 | Should cooldowns persist across death? Currently they reset. The argument for persistence is that it closes the (unlikely) suicide-to-refresh exploit; the argument against is that it compounds the punishment for dying, which pushes players toward passivity. | Reset. Revisit only if failure mode 10 is observed. | M5 |
| 3 | Is two active abilities the right number? Three would deepen the space but square the audit cost and make kit-reading much harder. | Two. This is close to a design law rather than a tunable. | — |
| 4 | Should the lobby reveal opponents' loadouts? Hiding them makes kit-reading a skill; revealing them would remove an information asymmetry that some players will find unfair. | Hide. Kit-reading is the skill; removing it removes a reason to watch people. | M6 |
| 5 | `TUN-CINDERFALL-DURATION` (4.0 s) and Stillness's clear-time for 40 suspicion (3.6 s) are suspiciously aligned (§7.2). Is this a problem or a happy accident? | Unresolved. Measure before touching. If "cloud and stand" becomes the default escape, shorten the cloud to 3.5 s. | M5 |
| 6 | Whisperbolt's tell is weakest on the "victim is not looking" axis (§6.1). Should the wind-up add an environmental tell — e.g. NPCs within 5 m turning to look at the thrower? | Tempting and cheap. Deferred to M5 as a polish item rather than a balance one. | M5 |

## **THE SUSPICION INTEGRATOR.** GDD-03 §3.3 and §3.4, TDD-07 §2, US-0051. PURE.
##
## One tick of the scalar that the entire social layer reads: detection renders from
## the tier, the Compass warns on it, stun is gated by it and four score bonuses are
## judged against it. TDD-07 calls it the highest-value test target in the project
## after the contract cycle, and it is one function.
##
## **GAIN AND DECAY ARE MUTUALLY EXCLUSIVE, AND THAT IS NOT AN OPTIMISATION**
## (ASM-0008). Above stroll speed there is no concurrent decay, so the ladder's
## costs are the **full** costs in §3.2 rather than net-of-decay ones. Run against a
## concurrent −8/s would cost 6/s instead of 14, and `TUN-SUSPICION-GAIN-OPEN` at
## +6 would be exactly **free** — the ladder would invert and standing alone in an
## empty plaza would cost nothing.
##
## **SOURCES ARE ADDITIVE WITH A CLAMP** (ASM-0018). A sprinting player on a roof
## with nobody nearby pays 25 + 18 + 6 = **49/s** and is Exposed in 1.4 s.
## Max-of-sources would make the second bad choice free, and compounding bad choices
## is exactly what should compound.
class_name SuspicionMath
extends RefCounted

## What observers are told. **Three values, and the wire spends two bits on it** —
## the tier is all an observer ever learns, never the scalar.
enum Tier { ANONYMOUS, NOTICED, EXPOSED }


## One tick. Returns the new value; the caller owns the state.
static func integrate(s: SuspicionState, t: SuspicionTuning, dt: float) -> float:
	# **BLEND OVERRIDES BOTH.** A linear crush toward zero, independent of gain and
	# decay, because a blend is not "decaying faster" — it is a different promise:
	# `TUN-BLEND-CRUSH-TIME` seconds from wherever you are to nothing.
	if s.blending:
		return move_toward(s.value, 0.0, (t.max_value / t.blend_crush_time) * dt)
	var gain := gain_rate(s, t)
	var decay := decay_rate(s, t, gain)
	return clampf(s.value + (gain - decay) * dt, t.min, t.max_value)


## Points per second of gain. **Public because the owner needs the same answer this
## function used** to decide whether the tick counted as a gain — a caller that
## re-derived it could disagree with the integrator about what a gain was, and the
## decay delay would arm on a different tick from the one that earned it.
static func gain_rate(s: SuspicionState, t: SuspicionTuning) -> float:
	var gain := 0.0
	if s.speed_state == PawnStateId.RUN:
		gain += t.gain_run
	elif s.speed_state == PawnStateId.SPRINT:
		gain += t.gain_sprint
	elif s.speed_state == PawnStateId.CLIMB:
		gain += t.gain_climb
	if s.on_roof:
		gain += t.gain_roof
	if s.nearest_npc_distance > t.open_radius:
		gain += t.gain_open
	return gain


## Did this tick earn anything? The owner resets `ticks_since_gain` on true.
static func gained(s: SuspicionState, t: SuspicionTuning) -> bool:
	return not s.blending and gain_rate(s, t) > 0.0


## Points per second of decay, given the gain this tick already produced.
##
## **THREE CONDITIONS, ALL REQUIRED.** No gain at all (the mutual exclusion), at or
## below the civilian speed ceiling, and `TUN-SUSPICION-DECAY-DELAY` since the last
## gain. That last one closes the tap-sprint exploit: without it, alternating sprint
## and stroll at 4 Hz nets +8.5/s while averaging ~4.2 m/s — cheaper per metre than
## simply running. The delay makes stop-start strictly worse than committing.
static func decay_rate(s: SuspicionState, t: SuspicionTuning, gain: float) -> float:
	if gain > 0.0 or s.speed > t.decay_speed_ceiling:
		return 0.0
	if s.ticks_since_gain < Tuning.ticks(&"TUN-SUSPICION-DECAY-DELAY"):
		return 0.0
	var decay := t.decay_base
	if s.has_stillness and s.speed <= t.stillness_speed_ceiling:
		decay *= t.stillness_mult
	return decay


## An instant source. **Applied outside the integrator, once, at the event** —
## TDD-07 §2.2 — so ordering within a tick is deterministic regardless of what fired
## first. Clamped like everything else.
static func apply_impulse(value: float, impulse: float, t: SuspicionTuning) -> float:
	return clampf(value + impulse, t.min, t.max_value)


## **ENTERED AT THE THRESHOLD, EXITED `TUN-SUSPICION-HYSTERESIS` BELOW IT.**
##
## Without this a player hovering at exactly 30.0 — which happens constantly,
## because 30.0 is where a slow climb crosses — flickers between tiers at 30 Hz. The
## visible result is a strobing silhouette tint. The **actual** result is that the
## tint stops being trustworthy, and an unreliable information channel is worse than
## a missing one: players spend attention on it and get nothing back.
##
## **A RISE MAY SKIP A RUNG AND A FALL MAY NOT, WHICH AMENDS TDD-07 §2.3's
## SKETCH.** That one walks one rung per tick in both directions, so a stunned
## player — `TUN-STUN-FORCES-EXPOSED` sets the scalar to 100 outright — would read
## **Noticed** for a tick before reaching Exposed. A rule that forces a tier is not
## kept if it takes effect a tick late, and the same is true of `ABIL-WHISPERBOLT`'s
## wind-up. **Nothing forces a tier downward**: the only way down is decay or a
## blend crush, and a crush takes `TUN-BLEND-CRUSH-TIME` 1.2 s — 36 ticks — so
## passing through Noticed on the way is a real moment rather than an artefact.
static func evaluate_tier(value: float, current: int, t: SuspicionTuning) -> int:
	if value >= t.tier_exposed:
		return Tier.EXPOSED
	if current == Tier.EXPOSED:
		return Tier.EXPOSED if value >= t.tier_exposed - t.hysteresis else Tier.NOTICED
	if value >= t.tier_noticed:
		return Tier.NOTICED
	if current == Tier.NOTICED and value >= t.tier_noticed - t.hysteresis:
		return Tier.NOTICED
	return Tier.ANONYMOUS

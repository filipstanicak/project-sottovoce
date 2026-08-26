## **HOW FAR INTO THE PAST A VALIDATION MAY REACH.** ADR-0010, TDD-04 §8.1,
## US-0060. PURE Core.
##
## Its own file, and not a method on `KillSystem`, for the reason ADR-0010's
## compliance list gives: *"only two call sites invoke the rewind"*. A clamp
## written inside the system that uses it is one the stun system copies, and two
## copies of a ceiling drift the first time somebody retunes one of them.
##
## **THE CEILING IS THE HALF THAT MATTERS.** The floor exists because
## `TUN-NET-INTERP-BUFFER` is unavoidable — every client draws remotes 100 ms in
## the past whatever its ping. The ceiling puts the cost of a bad connection on
## the player who has one: above `TUN-NET-LAGCOMP-MAX` of round trip, their kills
## begin to fail, because the server will not reach as far back as their client
## drew.
class_name RewindClamp
extends RefCounted


## Milliseconds of rewind for a peer whose smoothed round trip is `rtt_ms`.
##
## **HALF THE ROUND TRIP, NOT ALL OF IT.** What the attacker saw is the world as
## it left the server one trip-half ago, drawn a further `TUN-NET-INTERP-BUFFER`
## in the past by the interpolator. Using the whole round trip would double-count
## the return leg and reach a full trip too far back.
static func milliseconds_for(rtt_ms: float) -> float:
	var raw := maxf(rtt_ms, 0.0) * 0.5 + Tuning.net.interp_buffer
	return clampf(raw, Tuning.net.lagcomp_min, Tuning.net.lagcomp_max)


## The same, in server ticks. **Rounded, not truncated**: truncating biases every
## rewind toward the present, which is the direction that denies a legitimate kill.
static func ticks_for(rtt_ms: float) -> int:
	return int(round(milliseconds_for(rtt_ms) / 1000.0 * Tuning.net.server_tick))


## `TUN-NET-LAGCOMP-MAX` in ticks — the furthest back anything may ever look.
## Anything that has to outlive a rewind sizes itself from this rather than from
## its own guess.
static func max_ticks() -> int:
	return maxi(int(round(Tuning.net.lagcomp_max / 1000.0 * Tuning.net.server_tick)), 1)


## The tick a validation for `rtt_ms` resolves against, given the current tick.
##
## Never below zero: a kill in the opening second of a match would otherwise ask
## the ring for a negative tick, and `LagCompHistory` answers a tick outside the
## ring with the nearest one it holds rather than refusing — so the request would
## silently resolve against the oldest frame instead of the intended one.
static func tick_for(now: int, rtt_ms: float) -> int:
	return maxi(now - ticks_for(rtt_ms), 0)

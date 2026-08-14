## Smoothed round-trip time per peer, from `NET-C2S-PING` / `NET-S2C-PONG`.
##
## PURE. Given samples in milliseconds it returns a smoothed number; it does not
## know what a peer is, when a second passed, or which end of the wire it is on.
##
## **THIS IS THE CLIENT'S OWN ESTIMATE, NOT THE SERVER'S AUTHORITY.** The server
## reads ENet's continuously measured statistic instead (`Net.rtt_ms`), for two
## reasons that both matter: the transport already measures it on every packet
## rather than once a second, and a pong's `client_time` is **client-supplied and
## therefore forgeable**. Lag compensation rewinds the world by an amount derived
## from RTT, so an RTT a client could inflate is an RTT a client could use to
## reach further into the past — and ADR-0010 spends its length refusing exactly
## that shape of trust.
##
## Exponentially smoothed rather than averaged over a window: a window has to be
## sized, and every size is wrong for some connection. One coefficient is a
## single thing to reason about, and a spike decays instead of being remembered
## for exactly N samples and then forgotten all at once.
class_name RttTable
extends RefCounted

## Weight of each new sample. 0.25 keeps roughly the last handful in view.
const SMOOTHING := 0.25

var _rtt: Dictionary = {}


## Fold a fresh measurement in. The first sample for a peer is taken whole:
## smoothing toward a zero the peer never had would report half the truth for
## several seconds, which is worst precisely at a join.
func record(peer: int, sample_ms: float) -> void:
	var clean := maxf(sample_ms, 0.0)
	if not _rtt.has(peer):
		_rtt[peer] = clean
		return
	_rtt[peer] = lerpf(_rtt[peer], clean, SMOOTHING)


## The smoothed RTT, or 0.0 for a peer never measured.
##
## **ZERO MEANS UNKNOWN, AND CALLERS MUST NOT READ IT AS "FAST".** Lag
## compensation clamps to `TUN-NET-LAGCOMP-MIN` at the bottom, so an unmeasured
## peer rewinds by the floor rather than by nothing.
func rtt_ms(peer: int) -> float:
	return _rtt.get(peer, 0.0)


func has_peer(peer: int) -> bool:
	return _rtt.has(peer)


## Drop a peer that left. Not merely tidiness: peer ids are reused by ENet, so a
## stale entry would hand the next joiner the last one's connection quality.
func forget(peer: int) -> void:
	_rtt.erase(peer)


func clear() -> void:
	_rtt.clear()


func peer_count() -> int:
	return _rtt.size()

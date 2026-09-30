## **WHO HAS JUST TAKEN THE LEAD.** US-0105, ADR-0024. PURE — no autoload, no scene.
##
## The reference tells a player the moment they become first. **Taking** the lead
## means becoming the *sole* top scorer, above zero: a shared top is nobody's lead,
## and nobody leads a match in which nobody has scored. Holding the lead is not
## news, so the same leader is never announced twice in a row — but a leader who
## is caught and then pulls clear again has taken it again, and is told so.
class_name ScoreLead
extends RefCounted

const NOBODY := 0

var _leader: int = NOBODY


## The sole top scorer in `totals` (peer -> points), or `NOBODY` when the top is
## shared or no total is above zero.
static func sole_leader(totals: Dictionary) -> int:
	var best := 0
	var leader := NOBODY
	for peer: int in totals:
		var points := int(totals[peer])
		if points > best:
			best = points
			leader = peer
		elif points == best and points > 0:
			leader = NOBODY
	return leader


## The peer who has **just** taken the lead, or `NOBODY`. Stateful: it remembers
## the last sole leader, and a shared top forgets it so that pulling clear again
## is news.
func taken_by(totals: Dictionary) -> int:
	var now := sole_leader(totals)
	if now == _leader:
		return NOBODY
	_leader = now
	return now


func clear() -> void:
	_leader = NOBODY

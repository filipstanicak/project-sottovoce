## **WHO IS TOLD WHICH CIVILIANS FORM A GROUP.** US-0107, `NET-S2C-CROWD-GROUPS`.
## SERVER ONLY. Hangs off `MatchDirector.tick_completed`, so it never runs outside
## a match.
##
## Everybody is told the same tags. A player is sent the whole table on the first
## tick they are in the match, and only the changed pairs after that, so a crowd
## standing still costs nothing on the wire.
##
## **A PEER THAT LEAVES IS FORGOTTEN THE SAME TICK.** ENet reuses peer ids, and a
## newcomer handed the departed player's id would otherwise be sent changes to a
## table they never received.
class_name CrowdGroupAnnouncer
extends RefCounted

## How many sends `sent` keeps. Bounded, because a crowd changes every few ticks
## for eight minutes.
const KEPT := 64

## `[peer, full, pairs]` for the last `KEPT` messages sent. Diagnostics, and what
## the tests read: `send_crowd_groups` returns early off a server.
var sent: Array = []

var groups := CrowdGroups.new()
var _told: Dictionary = {}


func report(ctx: MatchContext, _dt: float) -> void:
	if ctx == null or ctx.crowd == null:
		return
	announce(
		ctx.slots.peers(), groups.refresh(ctx.crowd, ctx.formations, ctx.lean_spots, ctx.crowd_hash)
	)


## Tell each of `peers` what it is owed: the whole table if it has not had one,
## else `changed`, if anything did.
func announce(peers: Array, changed: PackedByteArray) -> void:
	var here: Dictionary = {}
	for peer: int in peers:
		here[peer] = true
		if not _told.has(peer):
			_told[peer] = true
			_send(peer, true, groups.full_table())
		elif not changed.is_empty():
			_send(peer, false, changed)
	for peer: int in _told.keys():
		if not here.has(peer):
			_told.erase(peer)


func _send(peer: int, full: bool, pairs: PackedByteArray) -> void:
	sent.append([peer, full, pairs])
	if sent.size() > KEPT:
		sent.remove_at(0)
	Net.events.crowd.send_crowd_groups(peer, full, pairs)

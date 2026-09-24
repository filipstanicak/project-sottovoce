## Client-side read-only mirror of match phase, local peer and lobby roster.
##
## WRITTEN ONLY BY NET. Everything else reads.
##
## The one-writer rule is the whole value of this object. The moment a second
## system can write here, "what phase are we in" has two answers depending on
## when you ask, and the bug that follows is a HUD disagreeing with the server —
## which the never-do list calls worse than no HUD at all.
##
## `test_game_state_single_writer.gd` asserts it, because the rule is a
## convention that nothing in the language enforces.
extends Node

## Emitted after any mutation, so a view model never polls.
signal state_replaced

enum Phase { LOBBY, WARMUP, ACTIVE, FINAL, RESULTS }

var local_peer_id: int = 0
var phase: Phase = Phase.LOBBY

## peer id -> display name. The roster is identity ONLY: no persona, no score, no
## suspicion. Anything anonymity-sensitive stays server-side, and a client that
## never receives it cannot leak it.
var roster: Dictionary = {}

## **slot -> persona, from `NET-S2C-LOBBY-STATE` (US-0101).** Kept apart from
## `roster` on purpose: that one is identity, this one is what a body is *drawn*
## as — which every client sees the moment the figure is in view, so knowing it
## gives away nothing the district does not. What stays server-side is which
## figure is a player, and no field here says so. `&""` is a seat not dealt yet.
var personas: Dictionary = {}

## **THE MATCH SEED, AND IT IS NOT A DEBUG FIELD.** `CrowdRoster` derives every
## NPC's persona from it, identically on every peer — which is how ninety
## identities reach a client for nothing. Zero until `NET-S2C-MATCH-START`
## arrives, and **zero is also a legal seed**, so a reader must ask
## `has_match()` rather than testing this for truth.
var match_seed: int = 0

## The server tick play began on, and the crowd it began with. Both arrive in the
## same message and neither is derivable from anything else a client holds.
var start_tick: int = 0
var crowd_count: int = 0

## Whether `NET-S2C-MATCH-START` has arrived. **A flag rather than a sentinel
## value**, because every field above has a legal zero.
var match_known: bool = false


func is_lobby() -> bool:
	return phase == Phase.LOBBY


func is_playing() -> bool:
	return phase == Phase.ACTIVE or phase == Phase.FINAL


## Whether this client has been told which match it is in.
func has_match() -> bool:
	return match_known


func peer_count() -> int:
	return roster.size()


func has_peer(peer: int) -> bool:
	return roster.has(peer)


## Replace everything at once. One entry point rather than a settable property
## per field, so a partially-applied update is not expressible.
func replace(new_peer_id: int, new_phase: Phase, new_roster: Dictionary) -> void:
	local_peer_id = new_peer_id
	phase = new_phase
	roster = new_roster.duplicate(true)
	state_replaced.emit()


## **THE SECOND MUTATOR, AND THE ONE-WRITER RULE IS UNCHANGED.** The rule is one
## *writer* — `scripts/net/` — not one function; widening `replace` instead would
## have taken it to six arguments, which `.gdlintrc` caps and calls a design
## signal, and every existing caller would have had to name three fields it knows
## nothing about. `test_game_state_single_writer.gd` derives its mutator list from
## this file rather than listing it, so this one could not be forgotten.
func adopt_match(seed_value: int, began_at: int, crowd: int) -> void:
	match_seed = seed_value
	start_tick = began_at
	crowd_count = crowd
	match_known = true
	state_replaced.emit()


## Adopt `NET-S2C-LOBBY-STATE`'s roster whole. **Replaced, never merged**: a seat
## the server stopped mentioning is a player who left, and a merge would keep
## dressing a body nobody is wearing.
func adopt_personas(by_slot: Dictionary) -> void:
	personas = by_slot.duplicate()
	state_replaced.emit()


## Reset to lobby. Called on disconnect, so a stale roster never outlives the
## session that produced it.
func clear() -> void:
	# **A SEED OUTLIVING ITS SESSION WOULD DRESS THE NEXT MATCH'S CROWD**, which
	# is the exact failure this function exists to prevent for the roster. Reset
	# BEFORE `replace` emits, so nothing hearing `state_replaced` reads a stale seed.
	match_seed = 0
	start_tick = 0
	crowd_count = 0
	match_known = false
	personas = {}
	replace(0, Phase.LOBBY, {})

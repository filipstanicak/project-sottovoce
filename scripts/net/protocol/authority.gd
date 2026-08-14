## **WHO IS ALLOWED TO SAY WHAT, AND WHEN.** TDD-04 §2, NETWORK_PROTOCOL §2.
##
## PURE. Given a message and four facts about the sender's situation it returns
## a verdict, and it does this with no peer, no socket and no phase authority
## standing up — so every row of the catalogue's authority column is a unit test.
##
## **THE TABLE IS THE CONTRACT.** NETWORK_PROTOCOL §2 says every C2S message must
## have a non-empty authority check; here that stops being a promise in prose and
## becomes a row that either exists or does not. A message absent from `RULE` is
## `UNKNOWN_MESSAGE` — refused — rather than allowed by default, so inventing a
## message in code does not quietly invent permission to send it.
##
## What this does NOT do is check a rule that belongs to a system: whether a
## cooldown has expired, whether a target is in range, whether a kill lands.
## Those are `SYS-ABILITY`'s and `SYS-COMBAT`'s and they need world state. This
## answers only the prior question — **may this peer be speaking at all** — which
## is exactly the question that has one answer for every message and therefore
## belongs in one place.
class_name Authority
extends RefCounted

## Why a message was refused. `NONE` is the accept case.
enum Denial { NONE, UNKNOWN_MESSAGE, FORBIDDEN, NOT_A_PLAYER, WRONG_PHASE, NO_PAWN }

## When a message is legal. `ANY` still requires the other two conditions.
enum When { ANY, LOBBY, PLAYING, RESULTS }

## msg -> [needs_player, when, needs_pawn].
##
## Every C2S message in the catalogue appears exactly once, which
## `test_authority.gd` asserts against `Messages.CHANNEL_FOR` in both directions.
##
## `NET-C2S-HELLO` is deliberately absent: it is the message that *establishes*
## whether a peer is a player, so requiring authority for it would be circular.
## `Net` owns it, before the router exists for that peer.
const RULE: Dictionary = {
	Ids.NET_C2S_PING: [false, When.ANY, false],
	Ids.NET_C2S_LOADOUT: [true, When.LOBBY, false],
	Ids.NET_C2S_READY: [true, When.LOBBY, false],
	Ids.NET_C2S_SKIP_RESULTS: [true, When.RESULTS, false],
	Ids.NET_C2S_INPUT: [true, When.PLAYING, true],
	Ids.NET_C2S_ABILITY_REQUEST: [true, When.PLAYING, true],
	Ids.NET_C2S_BLEND_REQUEST: [true, When.PLAYING, true],
}


## The verdict. **CHECKED IN THIS ORDER, AND THE ORDER IS THE DIAGNOSIS**: the
## most fundamental disagreement is reported first, so a log line names the cause
## rather than a symptom of it. A peer who is not a player is also, always,
## a peer without a pawn.
static func check(msg: StringName, is_player: bool, phase: int, has_pawn: bool) -> Denial:
	if Messages.is_forbidden(msg):
		return Denial.FORBIDDEN
	if not RULE.has(msg):
		return Denial.UNKNOWN_MESSAGE
	var rule: Array = RULE[msg]
	if bool(rule[0]) and not is_player:
		return Denial.NOT_A_PLAYER
	if not _phase_allows(int(rule[1]), phase):
		return Denial.WRONG_PHASE
	if bool(rule[2]) and not has_pawn:
		return Denial.NO_PAWN
	return Denial.NONE


## `PLAYING` is Active or Final, never Warmup: a pawn exists in warmup but the
## match has not begun, and an input applied then would move a player before the
## clock they are being scored against started.
static func _phase_allows(when: int, phase: int) -> bool:
	match when:
		When.LOBBY:
			return phase == GameState.Phase.LOBBY
		When.RESULTS:
			return phase == GameState.Phase.RESULTS
		When.PLAYING:
			return phase == GameState.Phase.ACTIVE or phase == GameState.Phase.FINAL
		_:
			return true


## A reason for the log. Every denial renders differently — a rejection nobody
## can act on is most of what a rejection is for.
static func denial_text(denial: Denial) -> String:
	match denial:
		Denial.UNKNOWN_MESSAGE:
			return "no authority rule exists for this message"
		Denial.FORBIDDEN:
			return "the protocol forbids this message entirely"
		Denial.NOT_A_PLAYER:
			return "the sender has not completed the handshake"
		Denial.WRONG_PHASE:
			return "not legal in this match phase"
		Denial.NO_PAWN:
			return "the sender owns no living pawn"
		_:
			return "allowed"

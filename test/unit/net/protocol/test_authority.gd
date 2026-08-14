## Who may say what, and when. TDD-04 §2, US-0026.
##
## The catalogue promises that **every C2S message has a non-empty authority
## check**. That promise is only worth what a test makes of it, so the first two
## cases below compare `Authority.RULE` against `Messages.CHANNEL_FOR` in both
## directions: a message with no rule, and a rule for no message.
extends GutTest

const PEER := 7


func _c2s_messages() -> Array:
	var out: Array = []
	for id: StringName in Messages.CHANNEL_FOR.keys():
		if String(id).begins_with("NET-C2S-"):
			out.append(id)
	return out


func test_every_c2s_message_has_a_rule() -> void:
	# **THE CATALOGUE'S PROMISE, AS A TEST.** `NET-C2S-HELLO` is the one exclusion
	# and it is not an oversight: it is the message that establishes whether a peer
	# is a player at all, so requiring authority for it would be circular.
	for id: StringName in _c2s_messages():
		if id == Ids.NET_C2S_HELLO:
			continue
		assert_true(Authority.RULE.has(id), "%s has no authority rule" % id)


func test_every_rule_is_for_a_real_message() -> void:
	# The other direction. A rule for a message that does not exist protects
	# nothing while reading exactly like protection.
	for id: StringName in Authority.RULE:
		assert_ne(Messages.channel_for(id), -1, "%s has a rule but no channel" % id)


func test_an_unknown_message_is_refused_rather_than_allowed() -> void:
	# Absence is a refusal, never a default permission. Inventing a message in
	# code must not quietly invent the right to send it.
	assert_eq(
		Authority.check(&"NET-C2S-INVENTED", true, GameState.Phase.ACTIVE, true),
		Authority.Denial.UNKNOWN_MESSAGE
	)


func test_a_forbidden_message_is_refused_before_anything_else() -> void:
	# **THE PROTOCOL'S CENTRAL CLAIM.** Even from a fully authorised player with a
	# living pawn in the right phase, a message that asserts an outcome is refused.
	for id: StringName in Messages.FORBIDDEN:
		assert_eq(
			Authority.check(id, true, GameState.Phase.ACTIVE, true),
			Authority.Denial.FORBIDDEN,
			"%s was not refused" % id
		)


func test_a_stranger_cannot_send_anything_that_needs_a_player() -> void:
	for id: StringName in Authority.RULE:
		if not bool((Authority.RULE[id] as Array)[0]):
			continue
		assert_eq(
			Authority.check(id, false, GameState.Phase.ACTIVE, true),
			Authority.Denial.NOT_A_PLAYER,
			"%s was accepted from a peer that never handshook" % id
		)


func test_lobby_messages_are_refused_outside_the_lobby() -> void:
	for phase: int in [GameState.Phase.WARMUP, GameState.Phase.ACTIVE, GameState.Phase.RESULTS]:
		assert_eq(
			Authority.check(Ids.NET_C2S_READY, true, phase, false),
			Authority.Denial.WRONG_PHASE,
			"ready was accepted in phase %d" % phase
		)
	assert_eq(
		Authority.check(Ids.NET_C2S_READY, true, GameState.Phase.LOBBY, false),
		Authority.Denial.NONE
	)


func test_input_is_refused_before_the_match_starts() -> void:
	# **WARMUP IS NOT PLAYING.** A pawn exists then, so `has_pawn` is true and only
	# the phase stands between an input and the simulation — which is the whole
	# reason the phase is checked at all rather than inferred from the pawn.
	assert_eq(
		Authority.check(Ids.NET_C2S_INPUT, true, GameState.Phase.WARMUP, true),
		Authority.Denial.WRONG_PHASE
	)
	for phase: int in [GameState.Phase.ACTIVE, GameState.Phase.FINAL]:
		assert_eq(
			Authority.check(Ids.NET_C2S_INPUT, true, phase, true),
			Authority.Denial.NONE,
			"input was refused during play, phase %d" % phase
		)


func test_input_from_a_player_with_no_pawn_is_refused() -> void:
	assert_eq(
		Authority.check(Ids.NET_C2S_INPUT, true, GameState.Phase.ACTIVE, false),
		Authority.Denial.NO_PAWN
	)


func test_a_ping_needs_nothing_but_a_connection() -> void:
	# The catalogue's authority column says "none needed — echo only". It stores
	# nothing and answers with nothing the sender did not already have.
	assert_eq(
		Authority.check(Ids.NET_C2S_PING, false, GameState.Phase.LOBBY, false),
		Authority.Denial.NONE
	)


func test_the_most_fundamental_disagreement_is_reported_first() -> void:
	# Order is diagnosis. A peer who never handshook is also, always, a peer with
	# no pawn and possibly in the wrong phase — and a log line saying "no pawn"
	# would send someone hunting a spawn bug.
	assert_eq(
		Authority.check(Ids.NET_C2S_INPUT, false, GameState.Phase.LOBBY, false),
		Authority.Denial.NOT_A_PLAYER
	)


func test_every_denial_says_something_different() -> void:
	var seen: Dictionary = {}
	for denial: int in Authority.Denial.values():
		if denial == Authority.Denial.NONE:
			continue
		var text := Authority.denial_text(denial as Authority.Denial)
		assert_false(seen.has(text), "two denials render identically: %s" % text)
		seen[text] = true

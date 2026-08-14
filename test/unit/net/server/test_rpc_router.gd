## The chokepoint as a node. US-0026.
##
## `Authority` and `SequenceGate` are tested on their own, where the decisions
## are. This file tests the wiring: that the router asks the right question, logs
## and announces a refusal, and forgets a peer completely when one leaves.
##
## The `@rpc` handlers themselves are not driven here — they read
## `multiplayer.get_remote_sender_id()`, which has no answer without a peer on
## the other end. What they contain is one authorise call and one emit, and
## `test_no_client_authority.gd` proves by source scan that the call is there and
## comes first.
extends GutTest

const PEER := 9

var _router: RpcRouter


func before_each() -> void:
	_router = RpcRouter.new()
	add_child_autofree(_router)


func _admit(peer: int) -> void:
	_router.set_player(peer, true)
	_router.set_pawn_owner(peer, true)
	_router.set_phase(GameState.Phase.ACTIVE)


func test_it_refuses_a_peer_that_never_handshook() -> void:
	_router.set_phase(GameState.Phase.ACTIVE)
	_router.set_pawn_owner(PEER, true)
	assert_false(_router._authorise(PEER, Ids.NET_C2S_INPUT), "a stranger was authorised")


func test_it_admits_a_player_with_a_pawn_in_play() -> void:
	# The premise for everything below. Without it, every refusal in this file
	# would be true for the same uninteresting reason.
	_admit(PEER)
	assert_true(_router._authorise(PEER, Ids.NET_C2S_INPUT), "a legitimate input was refused")


func test_a_refusal_is_announced_with_its_reason() -> void:
	# **THE REASON, NOT ONLY THE REFUSAL.** A test that could see only "nothing
	# happened" would pass on a router that dropped everything for any cause.
	watch_signals(_router)
	_router.set_phase(GameState.Phase.ACTIVE)
	_router._authorise(PEER, Ids.NET_C2S_INPUT)
	assert_signal_emitted(_router, "message_denied")
	var args: Array = get_signal_parameters(_router, "message_denied")
	assert_eq(args[0], PEER, "the wrong peer was named")
	assert_eq(args[1], Ids.NET_C2S_INPUT, "the wrong message was named")
	assert_eq(args[2], Authority.Denial.NOT_A_PLAYER, "the wrong reason was given")


func test_the_phase_is_the_servers_own() -> void:
	# Set by `MatchDirector` in M4. Until then it is told, not read from
	# `GameState` — which is the CLIENT's mirror, and a server that trusted a
	# client-side phase would take its authority from the thing it is guarding.
	_admit(PEER)
	_router.set_phase(GameState.Phase.RESULTS)
	watch_signals(_router)
	assert_false(_router._authorise(PEER, Ids.NET_C2S_INPUT), "input was accepted in results")
	assert_eq(
		(get_signal_parameters(_router, "message_denied") as Array)[2],
		Authority.Denial.WRONG_PHASE,
		"the phase the router was told was not the phase it used"
	)


func test_pawn_ownership_is_recorded_and_revoked() -> void:
	# Asserted against a peer who IS a player, so the refusal can only be about
	# the pawn. The version of this test that did not admit the peer first passed
	# with pawn tracking entirely removed.
	_admit(PEER)
	_router.set_pawn_owner(PEER, false)
	watch_signals(_router)
	assert_false(_router._authorise(PEER, Ids.NET_C2S_INPUT), "a peer with no pawn was authorised")
	assert_eq(
		(get_signal_parameters(_router, "message_denied") as Array)[2], Authority.Denial.NO_PAWN
	)


func test_the_ack_is_unknown_until_something_is_accepted() -> void:
	assert_eq(_router.last_acked_seq(PEER), -1)


func test_forgetting_a_peer_clears_everything_about_it() -> void:
	# ENet reuses peer ids, and every half matters: a stale sequence makes the
	# next joiner's input arrive in the past, a stale pawn flag authorises input
	# for somebody else's pawn, and a stale roster entry admits a stranger.
	_admit(PEER)
	assert_true(_router._authorise(PEER, Ids.NET_C2S_INPUT), "the premise failed")
	_router.forget(PEER)
	assert_eq(_router.last_acked_seq(PEER), -1, "a recycled peer inherited a sequence")
	watch_signals(_router)
	assert_false(_router._authorise(PEER, Ids.NET_C2S_INPUT), "a recycled peer id was admitted")
	assert_eq(
		(get_signal_parameters(_router, "message_denied") as Array)[2],
		Authority.Denial.NOT_A_PLAYER,
		"forgetting left the peer on the roster"
	)

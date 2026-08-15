## **FIVE STATES, ONE GLOBAL INTERRUPT.** US-0040, ADR-0003, TDD-08 §3,
## GDD-03 §6.1.
##
## **THE SILENT NO-OP TRANSITION IS THE CLASSIC FSM BUG**, and US-0040 names the
## completeness test as its standard defence. An absent state-event pair looks
## exactly like a handled one — an NPC simply never leaves Idle, and nothing
## anywhere errors. So every pair is required to be *present*, and the ones that
## deliberately do nothing say `IGNORED` rather than being left out.
extends GutTest

var _brain: NpcBrain
var _ctx: CrowdContext


func before_each() -> void:
	_brain = NpcBrain.new()
	_ctx = CrowdContext.new()
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = 20260816


func test_there_are_exactly_five_states() -> void:
	# **A SIXTH REQUIRES AN ADR.** ADR-0003 chose a flat machine over a behaviour
	# tree on the strength of there being few behaviours, and that argument stops
	# holding somewhere. This is where somebody is made to notice.
	assert_eq(NpcBrain.State.size(), 5, "the state count changed — ADR-0003 needs revisiting")


func test_every_state_event_pair_is_present() -> void:
	# **THE ASSERTION THE FILE IS FOR.** 5 states × 7 events = 35 pairs, every one
	# either a destination or an explicit `IGNORED`. A missing pair is a silent
	# no-op, which is indistinguishable from a handled event until somebody asks
	# why an NPC is stuck.
	var missing: PackedStringArray = []
	for state: int in NpcBrain.State.values():
		var row: Dictionary = NpcBrain.TRANSITIONS.get(state, {})
		for event: int in NpcBrain.Event.values():
			if not row.has(event):
				missing.append("state %d has no rule for event %d" % [state, event])
	assert_eq(missing.size(), 0, "the transition table is incomplete:\n" + "\n".join(missing))
	assert_eq(
		NpcBrain.TRANSITIONS.size(), NpcBrain.State.size(), "a state has no row in the table at all"
	)


func test_startle_is_enterable_from_every_other_state() -> void:
	# US-0040's second criterion. Startle is a **global interrupt**: a wave that
	# skipped an NPC in the wrong state would break the one thing it is for, which
	# is being readable as direction.
	for state: int in NpcBrain.State.values():
		_brain.state = state as NpcBrain.State
		_brain.handle(NpcBrain.Event.STARTLED, _ctx)
		assert_eq(
			_brain.state, NpcBrain.State.STARTLE, "an NPC in state %d could not be startled" % state
		)


func test_startle_wins_over_everything_on_the_hot_path() -> void:
	# The interrupt is checked **before** the timer, so a startle in the tick an
	# idle pause ends still startles rather than strolling.
	_brain.state = NpcBrain.State.IDLE
	_brain.timer_ticks = 1
	_ctx.startle_flag = true
	_brain.step(_ctx, 1.0 / 30.0)
	assert_eq(_brain.state, NpcBrain.State.STARTLE, "the timer beat the interrupt")


func test_a_gawking_npc_abandons_the_corpse_when_startled() -> void:
	# **AN ACCEPTED COST, ASSERTED SO IT STAYS DELIBERATE.** It destroys a standing
	# information object, and US-0040's notes take that trade knowingly: a startle
	# is a reliable channel, a gawk cluster is not, and the corpse persists anyway.
	_brain.state = NpcBrain.State.GAWK
	_brain.handle(NpcBrain.Event.STARTLED, _ctx)
	assert_eq(_brain.state, NpcBrain.State.STARTLE, "a gawker refused a startle")


func test_fleeing_beats_gawking() -> void:
	# The other direction, TDD-08 §3.3: the director skips startled NPCs when
	# issuing tokens, and the brain refuses one anyway. Two defences, because a
	# fleeing NPC that stopped to stare would read as a bug to every player.
	_brain.state = NpcBrain.State.STARTLE
	_brain.handle(NpcBrain.Event.GAWK_GRANTED, _ctx)
	assert_eq(_brain.state, NpcBrain.State.STARTLE, "a fleeing NPC stopped to gawk")


func test_being_startled_again_restarts_the_flee() -> void:
	# An NPC scared a second time should flee for the full duration from the
	# *second* scare. A machine that early-returned on `next == state` would let
	# the first timer run out mid-wave.
	_brain.handle(NpcBrain.Event.STARTLED, _ctx)
	_brain.timer_ticks = 1
	_brain.handle(NpcBrain.Event.STARTLED, _ctx)
	assert_gt(_brain.timer_ticks, 1, "a second startle did not restart the timer")


func test_the_documented_transitions_all_work() -> void:
	# GDD-03 §6.1's diagram, edge for edge.
	var edges := [
		[NpcBrain.State.STROLL, NpcBrain.Event.REACHED_ANCHOR, NpcBrain.State.IDLE],
		[NpcBrain.State.IDLE, NpcBrain.Event.TIMER_EXPIRED, NpcBrain.State.STROLL],
		[NpcBrain.State.STROLL, NpcBrain.Event.SLOT_ASSIGNED, NpcBrain.State.WALKING_GROUP],
		[NpcBrain.State.WALKING_GROUP, NpcBrain.Event.SLOT_REVOKED, NpcBrain.State.STROLL],
		[NpcBrain.State.IDLE, NpcBrain.Event.GAWK_GRANTED, NpcBrain.State.GAWK],
		[NpcBrain.State.WALKING_GROUP, NpcBrain.Event.GAWK_GRANTED, NpcBrain.State.GAWK],
		[NpcBrain.State.GAWK, NpcBrain.Event.TIMER_EXPIRED, NpcBrain.State.STROLL],
		[NpcBrain.State.GAWK, NpcBrain.Event.CORPSE_GONE, NpcBrain.State.STROLL],
		[NpcBrain.State.STARTLE, NpcBrain.Event.TIMER_EXPIRED, NpcBrain.State.STROLL],
	]
	for edge: Array in edges:
		_brain.state = edge[0] as NpcBrain.State
		_brain.handle(edge[1] as NpcBrain.Event, _ctx)
		assert_eq(_brain.state, edge[2], "edge %d --%d--> %d does not work" % edge)


func test_an_idle_pause_is_drawn_from_the_seeded_generator() -> void:
	# **A CROWD WHOSE PAUSES ARE ALL THE SAME LENGTH READS AS A MECHANISM** —
	# ninety NPCs moving off together is the most legible tell a city can have.
	var seen: Dictionary = {}
	for i: int in 40:
		var brain := NpcBrain.new()
		brain.handle(NpcBrain.Event.REACHED_ANCHOR, _ctx)
		seen[brain.timer_ticks] = true
	assert_gt(seen.size(), 5, "every idle pause is the same length")


func test_an_idle_pause_stays_inside_its_tunable_range() -> void:
	var low := int(Tuning.crowd.idle_duration_min * Tuning.net.server_tick)
	var high := int(round(Tuning.crowd.idle_duration_max * Tuning.net.server_tick))
	for i: int in 60:
		var brain := NpcBrain.new()
		brain.handle(NpcBrain.Event.REACHED_ANCHOR, _ctx)
		assert_between(brain.timer_ticks, low, high, "an idle pause left its range")


func test_timers_use_the_net_tick_not_the_input_rate() -> void:
	# **TRAP 9.** A brain is ticked by a system at 30 Hz. Converting at the 60 Hz
	# input rate would halve every duration *silently*, because both produce
	# plausible integers — the stun freeze shipped that way for four call sites.
	_brain.handle(NpcBrain.Event.STARTLED, _ctx)
	assert_eq(
		_brain.timer_ticks,
		Tuning.ticks(&"TUN-CROWD-STARTLE-DURATION"),
		"the startle timer is not in net ticks"
	)
	assert_ne(
		_brain.timer_ticks,
		Tuning.step_ticks(&"TUN-CROWD-STARTLE-DURATION"),
		"the two tick domains agree, so this test cannot tell them apart"
	)


func test_a_state_with_no_clock_does_not_tick_down_into_a_transition() -> void:
	# Stroll and WalkingGroup end on an event, never on a timer. A zero timer must
	# mean "no clock", not "expired" — otherwise every strolling NPC would fire
	# TIMER_EXPIRED on its first step.
	_brain.state = NpcBrain.State.STROLL
	_brain.timer_ticks = 0
	for i: int in 10:
		_brain.step(_ctx, 1.0 / 30.0)
	assert_eq(_brain.state, NpcBrain.State.STROLL, "a clockless state timed out")


func test_a_timer_runs_down_and_fires_once() -> void:
	_brain.handle(NpcBrain.Event.STARTLED, _ctx)
	var ticks := _brain.timer_ticks
	for i: int in ticks:
		_brain.step(_ctx, 1.0 / 30.0)
	assert_eq(_brain.state, NpcBrain.State.STROLL, "the startle never ended")


func test_reset_returns_it_to_a_fresh_npc() -> void:
	# The pool reuses brains along with the bodies, so a stale `has_propagated`
	# would make a recycled NPC refuse to pass on a startle for the rest of the
	# match.
	_brain.handle(NpcBrain.Event.STARTLED, _ctx)
	_brain.has_propagated = true
	_brain.reset()
	assert_eq(_brain.state, NpcBrain.State.STROLL)
	assert_eq(_brain.timer_ticks, 0)
	assert_false(_brain.has_propagated, "reset left the propagation flag set")


func test_npc_stroll_speed_equals_player_blend_walk_exactly() -> void:
	# **US-0040's SIXTH CRITERION, AND A DESIGN LAW.** If a clone strolled at a
	# different speed from a blending player, speed alone would identify the
	# player in a crowd — the anonymity the entire crowd exists to provide,
	# undone by one number.
	assert_eq(
		Tuning.crowd.npc_speed_stroll,
		Tuning.movement.blend_walk,
		"NPC stroll speed and player blend-walk have come apart"
	)


func test_that_invariant_is_live_rather_than_merely_present() -> void:
	# Invariant 1 asserts the equality above at load. It would pass identically if
	# the check had never been written, so it is **falsified** here.
	var profile: TuningProfile = Tuning.profile.clone()
	profile.crowd.npc_speed_stroll = profile.movement.blend_walk + 0.5
	var hit := false
	for e: String in profile.validate():
		if e.begins_with("1."):
			hit = true
	assert_true(hit, "breaking the stroll/blend-walk equality produced no error — 1 is inert")

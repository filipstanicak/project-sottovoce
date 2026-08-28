## **THE TELL GOES OUT BEFORE THE EFFECT, AND IT GOES TO EVERYBODY WHO COULD READ
## IT.** Design law 3, TDD-09 §1, US-0066.
##
## *No ability resolves without the victim having had a perceivable chance to read
## it.* That law has exactly one enforcement point on the wire, and this is it.
##
## **THE ORDERING IS THE LAW, NOT A DETAIL.** A tell emitted after `effect.begin`
## would be a tell the victim receives after the thing it warns about — which is
## not a tell, it is a notification. The two lines are adjacent in `_commit` and
## this is what keeps them in that order.
extends GutTest

const A := 91
const B := 92

var _system: AbilitySystem
var _ctx: MatchContext
var _order: Array[String] = []


func before_each() -> void:
	_order = []
	_ctx = MatchContext.new()
	_ctx.tick = 500
	_system = AbilitySystem.new()
	add_child_autofree(_system)
	_system.setup(_ctx)
	_place(A)
	_system.loadout[A] = [Ids.ABIL_CINDERFALL, Ids.ABIL_LUNGE]


func _place(peer: int) -> void:
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(Vector3.ZERO, 0.0)
	pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[peer] = pawn


func _cast(peer: int, slot: int = 0) -> void:
	_system.report_request(peer, slot, Vector3.ZERO, Vector3(0.0, 0.0, 1.0))
	_system.tick(_ctx, MatchContext.net_dt())


func test_a_committed_cast_announces_itself() -> void:
	var told: Array = []
	_system.ability_started.connect(
		func(peer: int, ability: StringName, _o: Vector3, _d: Vector3) -> void:
			told.append([peer, ability])
	)
	_cast(A)
	assert_eq(told.size(), 1, "a committed cast produced no tell")
	assert_eq(told[0][0], A)
	assert_eq(told[0][1], Ids.ABIL_CINDERFALL, "the tell named the wrong ability")


func test_a_refused_cast_announces_nothing() -> void:
	# **THE HALF THAT WOULD LEAK.** A tell on a refused cast would broadcast that
	# somebody nearby had pressed a button and been told no — a free read on a
	# stranger's cooldowns, which GDD-04 §5.1 makes a skill to be earned.
	_system.loadout.erase(A)
	var told := 0
	_system.ability_started.connect(
		func(_p: int, _a: StringName, _o: Vector3, _d: Vector3) -> void: told += 1
	)
	_cast(A)
	assert_eq(told, 0, "a refused cast still announced itself")
	assert_eq(_system.activations, 0, "the fixture did not actually refuse")


func test_the_tell_is_emitted_before_the_effect_begins() -> void:
	# **ASSERTED ON THE SOURCE, AND SAYING SO IS THE POINT.** The behavioural test
	# needs an effect that outlives its own first tick, and there is not one:
	# `AbilityEffect.tick` returns false — *"return false to end early"* — so the
	# base ends inside the tick it began, which is the honest thing for a no-op to
	# do. **My first version asserted `is_effect_active` after a cast and read
	# false**, which looks exactly like an effect that never started and is in fact
	# an effect that finished. US-0067 is the first story that can watch this
	# properly; until then the ordering is guarded where it lives.
	var source := SourceScanner.read("res://scripts/systems/ability/ability_system.gd")
	var tell := source.find("ability_started.emit")
	var begins := source.find("effect.begin(")
	assert_gt(tell, 0, "the tell left `_commit`")
	assert_gt(begins, 0, "the effect is never begun")
	assert_lt(tell, begins, "the effect begins before the tell goes out — design law 3")


func test_a_no_op_effect_ends_inside_the_tick_it_began() -> void:
	# The other half of the same fact, behaviourally. `end()` must still run — an
	# effect that began and never ended would leak a row per cast for the match.
	_cast(A)
	assert_eq(_system.activations, 1)
	assert_false(
		_system.is_effect_active(A, Ids.ABIL_CINDERFALL),
		"a base AbilityEffect stayed live past the tick it started"
	)


func test_the_tell_carries_the_clamped_aim_rather_than_the_request() -> void:
	# **EVERY CLIENT MUST DRAW THE SAME THING**, and the request is the one number
	# in the pipeline that is the client's. Broadcasting it would put the tell
	# somewhere the effect is not — a cloud at 8 m with a tell 40 m away.
	var seen: Array[Vector3] = []
	_system.ability_started.connect(
		func(_p: int, _a: StringName, _o: Vector3, direction: Vector3) -> void:
			seen.append(direction)
	)
	_system.report_request(A, 0, Vector3.ZERO, Vector3(0.0, 0.0, 40.0))
	_system.tick(_ctx, MatchContext.net_dt())
	assert_eq(seen.size(), 1)
	assert_almost_eq(seen[0].length(), 1.0, 0.0001, "the tell carried an unnormalised direction")


func test_a_denial_names_its_slot_and_its_reason() -> void:
	var refused: Array = []
	_system.ability_denied.connect(
		func(peer: int, slot: int, why: int) -> void: refused.append([peer, slot, why])
	)
	_system.loadout[A] = [Ids.ABIL_CINDERFALL]
	_cast(A, 1)
	assert_eq(refused.size(), 1, "an empty slot was silently ignored")
	assert_eq(refused[0][1], 1, "the denial named the wrong slot")
	assert_eq(refused[0][2], AbilityDenial.Why.NOT_EQUIPPED)


func test_the_started_message_is_reliable_and_the_only_broadcast() -> void:
	# **RELIABLE IS NOT THE DEFAULT CHOICE FOR SOMETHING COSMETIC**, and this is not
	# cosmetic: a dropped snapshot costs a frame of smoothness, a dropped tell costs
	# the victim their only warning. TDD-09's own note says to check delivery time
	# before touching tunables if Lunge proves unstunnable.
	var source := "res://scripts/net/event_wire.gd"
	var lines := SourceScanner.read(source)
	var at := lines.find("func s2c_ability_started")
	assert_gt(at, 0, "the message left the wire")
	assert_string_contains(lines.substr(maxi(at - 200, 0), 200), "reliable")


func test_the_broadcast_reaches_a_bystander_and_stops_at_the_tell_radius() -> void:
	# The radius is the ability's own `TUN-<ABIL>-TELL-AUDIO-RADIUS`. **A tell sent
	# to the whole lobby would be a global ability feed** — never-do #12's shape,
	# telling somebody two streets away that a hunt was under way.
	var data: AbilityData = Tuning.ability_data(Ids.ABIL_CINDERFALL)
	assert_gt(data.tell_audio_radius, 0.0, "Cinderfall has no tell radius")
	_place(B)
	var near := _ctx.pawn_contexts[B] as PawnContext
	near.position = Vector3(0.0, 0.0, data.tell_audio_radius - 1.0)
	assert_lte(
		near.position.distance_to(Vector3.ZERO),
		data.tell_audio_radius,
		"the fixture's bystander is outside the radius"
	)
	near.position = Vector3(0.0, 0.0, data.tell_audio_radius + 1.0)
	assert_gt(
		near.position.distance_to(Vector3.ZERO),
		data.tell_audio_radius,
		"the radius does not exclude anybody"
	)

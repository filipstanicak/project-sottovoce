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
	# **AND THIS ASSERTION COULD NOT HAVE FAILED UNTIL US-0067.** It counted into a
	# lambda-captured `int`, which GDScript copies — so `told` was zero however many
	# tells went out, and "a refused cast announced nothing" was true of every cast
	# ever made. Found because the same shape failed in a test that expected **one**.
	_system.loadout.erase(A)
	var told: Array = []
	_system.ability_started.connect(
		func(_p: int, _a: StringName, _o: Vector3, _d: Vector3) -> void: told.append(1)
	)
	_cast(A)
	assert_eq(told.size(), 0, "a refused cast still announced itself")
	assert_eq(_system.activations, 0, "the fixture did not actually refuse")


func test_the_tell_is_emitted_before_the_effect_begins() -> void:
	# **ASSERTED ON THE SOURCE, FOR THE ABILITY THAT HAS NO WIND-UP.** An ability
	# with a `cast_time` gets the separation for free — the tell fires at the press
	# and the effect begins `TUN-<ABIL>-CAST-TIME` later — so the ordering only
	# matters for one that begins on the press tick, and there the two lines are
	# adjacent in `_commit`. **US-0066's version of this note said the behavioural
	# test was impossible; US-0067 made half of it possible and this is the half
	# that is still source-only.**
	var source := SourceScanner.read("res://scripts/systems/ability/ability_system.gd")
	var tell := source.find("ability_started.emit")
	var begins := source.find("_begin(ctx, peer, row, data)")
	assert_gt(tell, 0, "the tell left `_commit`")
	assert_gt(begins, 0, "the effect is never begun")
	assert_lt(tell, begins, "the effect begins before the tell goes out — design law 3")


func test_the_tell_precedes_the_cloud_by_the_whole_wind_up() -> void:
	# **THE BEHAVIOURAL HALF, WHICH `ABIL-CINDERFALL` MADE POSSIBLE** (US-0067). The
	# victim gets `TUN-CINDERFALL-CAST-TIME` 0.45 s between being told and the world
	# changing, and that window is the entire reason the cast time exists.
	# **AN ARRAY, NOT AN INT, AND THAT IS NOT A STYLE CHOICE.** A GDScript lambda
	# captures a local by **value**, so `told += 1` inside one increments a copy and
	# the assertion outside reads whatever it started at. An append mutates the
	# object both sides hold.
	var told: Array = []
	_system.ability_started.connect(
		func(_p: int, _a: StringName, _o: Vector3, _d: Vector3) -> void: told.append(1)
	)
	_cast(A)
	assert_eq(told.size(), 1, "the tell did not go out on the press tick")
	assert_eq(_ctx.cinderfall.count_at(_ctx.tick), 0, "the cloud existed on the press tick")
	for _i: int in Tuning.ticks(&"TUN-CINDERFALL-CAST-TIME") + 1:
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())
	assert_eq(_ctx.cinderfall.count_at(_ctx.tick), 1, "the cloud never landed")
	assert_eq(told.size(), 1, "the tell fired twice for one cast")


## **THE PROPERTY WITHOUT AN ABILITY ATTACHED TO IT, WHICH IS WHY THIS ONE CANNOT
## DRIFT.** *"Return false to end early"* is `AbilityEffect`'s own contract and a
## no-op's honest lifetime is one tick. Asserting it against the base class means
## no shipped ability's `effect_script` can ever make this test quietly stop
## measuring anything — which is what happened twice to the one below.
func test_the_base_effect_ends_itself_on_its_first_tick() -> void:
	assert_false(
		AbilityEffect.new().tick(_ctx, MatchContext.net_dt()),
		"AbilityEffect.tick stopped meaning 'end early', which every effect overrides against"
	)


func test_a_no_op_effect_ends_inside_the_tick_it_began() -> void:
	# `end()` must still run — an effect that began and never ended would leak a row
	# per cast for the match.
	#
	# **THIS TEST HAS BEEN RE-HOMED TWICE AND THAT IS THE FINDING.** It cast
	# Cinderfall until US-0067 and Lunge until US-0070, and each time the ability
	# gained an `effect_script` the file **kept passing while measuring nothing** —
	# a real effect mid-wind-up reports inactive for a completely different reason.
	# Keying a property of the *base class* on whichever shipped ability happens to
	# lack an override is the drift; the test above is the version that cannot.
	# **US-0069 will move it a third time**, and should delete it instead.
	assert_null(
		Tuning.ability_data(Ids.ABIL_SECONDFACE).effect_script,
		"Second Face gained an effect; delete this and keep the base-class test above"
	)
	_system.loadout[A] = [Ids.ABIL_SECONDFACE]
	_cast(A, 0)
	assert_eq(_system.activations, 1)
	assert_false(
		_system.is_effect_active(A, Ids.ABIL_SECONDFACE),
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

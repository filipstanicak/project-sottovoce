## **THE GAWK CAP, AND WHY IT IS SIX.** US-0044, GDD-03 §6.4, TDD-08 §3.3.
##
## The cap looks like a performance measure and is not. Without it a corpse in a
## dense market pocket recruits every nearby NPC, drops the pocket below
## `TUN-BLEND-POCKET-MIN-NPC`, and destroys it as a blend location — which makes
## the site of a kill **safer to stand in afterwards**. Exactly backwards.
##
## **SO THE POCKET TEST ASSERTS THE COUNTERFACTUAL TOO.** "At least four NPCs
## remain" is trivially true of a corpse that recruited nobody, and equally true
## of a pocket nothing was ever eligible to leave. It is only evidence about the
## *cap* if more than `TUN-CROWD-GAWK-MAX` NPCs were in range to begin with.
extends GutTest

const SEED := 20260816

var _pool: NpcPool
var _hash: SpatialHash
var _register: CorpseRegister
var _points: PackedVector3Array


## `count` NPCs packed into a disc of `radius` around `centre`, on a fixed spiral
## so the layout is reproducible and readable rather than random.
func _pocket(count: int, centre: Vector3, radius: float) -> void:
	_pool = NpcPool.new()
	add_child_autofree(_pool)
	_pool.preallocate(count)
	_pool.activate(count, SEED, CrowdRoster.PLAYABLE, 6)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_points = PackedVector3Array()
	for index: int in count:
		var angle := float(index) * 2.399963
		var out := radius * sqrt(float(index + 1) / float(count))
		var at := centre + Vector3(cos(angle) * out, 0.0, sin(angle) * out)
		_pool.set_position(index, at)
		_points.append(at)
		_pool.context_of(index).rng = rng
	_hash = SpatialHash.new()
	_hash.setup(AABB(Vector3(-60.0, -2.0, -60.0), Vector3(160.0, 10.0, 160.0)), count)
	_hash.rebuild(_points, _pool.roster, count)
	_register = CorpseRegister.new()


## The dispatch order `CrowdDirector._advance` uses: step, then the flags the
## brain's hot path deliberately does not read, then clear.
func _dispatch(count: int) -> void:
	for index: int in count:
		var brain := _pool.brain_of(index)
		var cctx := _pool.context_of(index)
		brain.step(cctx, MatchContext.net_dt())
		if cctx.gawk_granted:
			brain.handle(NpcBrain.Event.GAWK_GRANTED, cctx)
		if cctx.corpse_gone:
			brain.handle(NpcBrain.Event.CORPSE_GONE, cctx)
		cctx.clear_events()


func _gawking(count: int) -> int:
	var found := 0
	for index: int in count:
		if _pool.brain_of(index).state == NpcBrain.State.GAWK:
			found += 1
	return found


func test_a_corpse_recruits_at_most_the_capped_number() -> void:
	_pocket(20, Vector3.ZERO, 4.0)
	_register.add(Corpse.at(Vector3(3.0, 0.0, 0.0), 0), _hash, _pool)
	_dispatch(20)
	gut.p("%d of 20 NPCs are gawking, cap is %d" % [_gawking(20), int(Tuning.crowd.gawk_max)])
	assert_eq(_gawking(20), int(Tuning.crowd.gawk_max), "the cluster is not TUN-CROWD-GAWK-MAX")
	assert_eq(_register.watcher_count(), int(Tuning.crowd.gawk_max))


func test_a_corpse_beside_a_pocket_never_drops_it_below_four() -> void:
	# **US-0044's fifth criterion, with its own counterfactual.** Twelve NPCs in a
	# pocket, a body at its edge: at most six may leave, so at least six stay —
	# comfortably above `TUN-BLEND-POCKET-MIN-NPC`.
	var centre := Vector3.ZERO
	_pocket(12, centre, Tuning.suspicion.blend_pocket_radius)
	var eligible := _hash.query(Vector3(4.0, 0.0, 0.0), Tuning.crowd.gawk_radius).size()
	gut.p(
		(
			"%d NPCs were within the gawk radius; the cap is %d"
			% [eligible, int(Tuning.crowd.gawk_max)]
		)
	)
	assert_gt(
		eligible,
		int(Tuning.crowd.gawk_max),
		"fewer NPCs were in range than the cap allows — this proves nothing about the cap"
	)

	_register.add(Corpse.at(Vector3(4.0, 0.0, 0.0), 0), _hash, _pool)
	_dispatch(12)
	var left_standing := 12 - _gawking(12)
	gut.p("%d of 12 stayed in the pocket" % left_standing)
	assert_true(
		left_standing >= int(Tuning.suspicion.blend_pocket_min_npc),
		(
			"the corpse emptied the pocket: %d left, needs %d"
			% [left_standing, int(Tuning.suspicion.blend_pocket_min_npc)]
		)
	)


func test_a_fleeing_npc_is_skipped_rather_than_given_a_wasted_token() -> void:
	# **FLEEING BEATS GAWKING**, TDD-08 §3.3. And `NpcBrain.TRANSITIONS` refuses
	# `GAWK_GRANTED` from `STARTLE` anyway, so a token spent on one would vanish and
	# the cluster would come up short with nothing saying why.
	_pocket(20, Vector3.ZERO, 4.0)
	for index: int in 8:
		_pool.brain_of(index).handle(NpcBrain.Event.STARTLED, _pool.context_of(index))
	_register.add(Corpse.at(Vector3.ZERO, 0), _hash, _pool)
	for index: int in 8:
		assert_false(_register.watching(index), "a fleeing NPC %d was given a token" % index)
	assert_eq(
		_register.watcher_count(),
		int(Tuning.crowd.gawk_max),
		"the cap went unfilled because tokens were wasted on fleeing NPCs"
	)


func test_nobody_out_of_range_is_recruited() -> void:
	_pocket(20, Vector3.ZERO, 4.0)
	var far := Vector3(Tuning.crowd.gawk_radius + 30.0, 0.0, 0.0)
	_register.add(Corpse.at(far, 0), _hash, _pool)
	assert_eq(_register.watcher_count(), 0, "a corpse 40 m away recruited a cluster")


func test_the_two_information_phases_are_the_documented_lengths() -> void:
	# Invariant 13 in numbers a reader can check: the cluster is gone at six
	# seconds and the body at twenty. Collapse the two and a corpse says one thing
	# instead of two — see `Corpse`.
	var corpse := Corpse.at(Vector3.ZERO, 0)
	var rate: float = Tuning.net.server_tick
	assert_true(corpse.gathering(int(rate * 5.0)), "the cluster dispersed before 6 s")
	assert_false(corpse.gathering(int(rate * 7.0)), "the cluster outlasted TUN-CROWD-GAWK-DURATION")
	assert_false(corpse.expired(int(rate * 19.0)), "the body faded before 20 s")
	assert_true(corpse.expired(int(rate * 21.0)), "the body outlasted TUN-CORPSE-LIFETIME")
	assert_lt(Tuning.crowd.gawk_duration, Tuning.crowd.corpse_lifetime, "invariant 13 — two phases")


func test_a_gawker_leaves_by_its_own_timer_before_the_body_fades() -> void:
	# The usual path, and the reason `corpse_gone` is the *unusual* one.
	_pocket(20, Vector3.ZERO, 4.0)
	_register.add(Corpse.at(Vector3.ZERO, 0), _hash, _pool)
	_dispatch(20)
	assert_gt(_gawking(20), 0, "nobody gawked — the timer claim is vacuous")
	for _tick: int in Tuning.ticks(&"TUN-CROWD-GAWK-DURATION") + 2:
		_dispatch(20)
	assert_eq(_gawking(20), 0, "the cluster outlasted TUN-CROWD-GAWK-DURATION")
	assert_eq(_register.corpses.size(), 1, "the body left with its onlookers")


func test_a_body_removed_early_tells_its_own_onlookers() -> void:
	# Two corpses, one expiring: only its cluster is dispersed. A single "a corpse
	# went" flag would scatter every cluster in the district.
	_pocket(20, Vector3.ZERO, 4.0)
	_register.add(Corpse.at(Vector3.ZERO, 0), _hash, _pool)
	_dispatch(20)
	var watched := _register.watcher_count()
	assert_gt(watched, 0, "nobody was watching — the expiry claim is vacuous")

	var gone := int(Tuning.net.server_tick * (Tuning.crowd.corpse_lifetime + 1.0))
	assert_eq(_register.expire(gone, _pool), 1, "the body did not expire")
	var told := 0
	for index: int in 20:
		if _pool.context_of(index).corpse_gone:
			told += 1
	assert_eq(told, watched, "the expiring body did not tell its own onlookers")
	assert_eq(_register.watcher_count(), 0, "the register kept watchers of a body that is gone")


func test_the_register_empties_at_match_end() -> void:
	_pocket(20, Vector3.ZERO, 4.0)
	_register.add(Corpse.at(Vector3.ZERO, 0), _hash, _pool)
	_register.clear()
	assert_eq(_register.corpses.size(), 0)
	assert_eq(_register.watcher_count(), 0, "a body survived into the next match")


func test_flee_is_slower_than_sprint() -> void:
	# US-0044's last criterion. It is invariant 14 and `test_tuning_ranges.gd`
	# already asserts the whole set; it is repeated here because the story names it
	# and because the consequence is worth stating where the crowd code is read: a
	# sprinting player who could outrun a startle wave would be able to hide
	# *inside* one, using the crowd's own alarm as cover.
	assert_lt(
		Tuning.crowd.npc_speed_flee,
		Tuning.movement.sprint,
		"a sprinting player can hide inside a startle wave"
	)

## **NINETY BODIES, ALLOCATED ONCE.** US-0039, TDD-08 §2.
##
## An integration test rather than a unit one, because the thing being asserted
## is that `npc_server.tscn` really instantiates ninety times into real
## `CharacterBody3D`s. A double would pass while the pool allocated array slots
## and nothing else — which is exactly the shape this story could have taken and
## still read as done. Trap 4.
##
## **THE COST THIS STORY MOVES OFF THE HOT PATH IS THE BODY, NOT THE ARRAY
## ENTRY.** US-0039's own note says why: instantiating a `CharacterBody3D` with a
## `NavigationAgent3D` mid-match is a frame spike, and a frame spike in a game
## decided at 2.5 m inside a 0.4 s window is a lost kill.
extends GutTest

const SEED := 20260815

var _pool: NpcPool
var _personas: Array = [
	Ids.PERSONA_CANTATRICE, Ids.PERSONA_LUCERNA, Ids.PERSONA_PESATORE, Ids.PERSONA_VETRAIO
]


func before_each() -> void:
	_pool = NpcPool.new()
	add_child_autofree(_pool)


func test_it_allocates_real_bodies_not_just_slots() -> void:
	# **THE ASSERTION THE FILE IS FOR.** `body_count()` reads the node list, so a
	# pool that only sized an array fails here and passes everything else.
	_pool.preallocate()
	assert_eq(
		_pool.body_count(), int(Tuning.crowd.count_max), "the pool did not allocate 90 bodies"
	)
	assert_eq(_pool.capacity(), 90, "TUN-CROWD-COUNT-MAX is not 90")
	for index: int in [0, 45, 89]:
		assert_not_null(_pool.body_of(index), "NPC %d has no body" % index)


func test_it_is_sized_to_the_maximum_regardless_of_the_active_count() -> void:
	# TDD-08 §2's actual requirement, and the reason it matters: the difference
	# between a 4-player crowd and a 6-player crowd must cost nothing at the
	# moment it changes.
	_pool.preallocate()
	_pool.activate(66, SEED, _personas, 4)
	assert_eq(_pool.body_count(), 90, "a 4-player match shrank the allocation")
	assert_eq(_pool.active_count(), 66, "the 4-player crowd is not TUNABLES' 66")


func test_activating_does_not_allocate() -> void:
	# **THE NO-MID-MATCH-INSTANTIATE RULE, MEASURED.** Counted as nodes rather
	# than asserted from the source, because the failure is a body appearing at
	# runtime however it got there.
	_pool.preallocate()
	var before := _pool.get_child_count()
	_pool.activate(78, SEED, _personas, 6)
	_pool.activate(66, SEED + 1, _personas, 4)
	_pool.activate(90, SEED + 2, _personas, 6)
	assert_eq(_pool.get_child_count(), before, "activate() changed the number of bodies")


func test_deactivating_frees_nothing() -> void:
	# Deactivation is **not** deallocation and must never become it. The pool
	# outlives a match precisely so the next one does not pay for it.
	_pool.preallocate()
	_pool.activate(78, SEED, _personas, 6)
	_pool.deactivate_all()
	assert_eq(_pool.body_count(), 90, "deactivate_all freed bodies")
	assert_eq(_pool.active_count(), 0, "deactivate_all left NPCs active")


func test_inactive_npcs_are_hidden_and_skipped() -> void:
	# **COLLISION OFF AS WELL AS VISIBILITY.** An inactive NPC that still had a
	# collider would be an invisible wall in the middle of the district — the kind
	# of defect that reads as a level bug for a week.
	_pool.preallocate()
	_pool.activate(66, SEED, _personas, 4)

	var live := _pool.body_of(0)
	assert_true(live.visible, "an active NPC is hidden")
	assert_ne(live.process_mode, Node.PROCESS_MODE_DISABLED, "an active NPC is disabled")

	var spare := _pool.body_of(89)
	assert_false(spare.visible, "an inactive NPC is visible")
	assert_eq(spare.process_mode, Node.PROCESS_MODE_DISABLED, "an inactive NPC still processes")
	assert_false(_pool.is_active(89), "an inactive index reports as active")


func test_preallocate_twice_does_not_reallocate() -> void:
	# A second call would be exactly the mid-match spike this exists to prevent.
	_pool.preallocate()
	var before := _pool.get_child_count()
	_pool.preallocate()
	assert_eq(_pool.get_child_count(), before, "preallocate ran twice")


func test_it_refuses_to_grow_rather_than_spiking() -> void:
	# Growing to fit is the frame spike. Refusing is loud and survivable; growing
	# is silent and costs a kill.
	#
	# The refusal logs an error **on purpose**, so the log is quieted for exactly
	# this call rather than the assertion being softened. GUT counts a
	# `push_error` as a failure, and the alternative — a pool that refused
	# silently — is the one thing worse than refusing.
	var was: Log.Level = Log.min_level
	Log.min_level = Log.Level.ERROR + 1 as Log.Level
	_pool.preallocate(20)
	var grew := _pool.activate(50, SEED, _personas, 6)
	Log.min_level = was

	assert_false(grew, "the pool grew past its allocation")
	assert_eq(_pool.body_count(), 20, "a refused activation still allocated")


func test_the_roster_reaches_the_pool() -> void:
	_pool.preallocate()
	_pool.activate(78, SEED, _personas, 6)
	assert_eq(_pool.roster.size(), 78, "the pool holds no roster")
	assert_ne(_pool.identity_of(0), &"", "NPC 0 has no identity")
	assert_eq(_pool.identity_of(89), &"", "an inactive NPC reported an identity")


func test_two_pools_on_one_seed_agree() -> void:
	# The parity property, through the pool rather than the pure derivation —
	# because a pool that shuffled again after deriving would break it while
	# `test_crowd_roster.gd` stayed green.
	var other := NpcPool.new()
	add_child_autofree(other)
	_pool.preallocate()
	other.preallocate()
	_pool.activate(78, SEED, _personas, 6)
	other.activate(78, SEED, _personas, 6)
	assert_eq(
		CrowdRoster.fingerprint(_pool.roster),
		CrowdRoster.fingerprint(other.roster),
		"two pools derived different rosters from one seed"
	)


func test_a_position_reaches_the_body() -> void:
	# The pool keeps a packed array for the systems that will read it every tick,
	# and the body needs to actually be there — two places that could silently
	# disagree.
	_pool.preallocate()
	_pool.activate(78, SEED, _personas, 6)
	_pool.set_position(3, Vector3(12.0, 0.0, 34.0))
	assert_eq(_pool.position_of(3), Vector3(12.0, 0.0, 34.0), "the array did not take the position")
	assert_eq(_pool.body_of(3).global_position, Vector3(12.0, 0.0, 34.0), "the body did not move")

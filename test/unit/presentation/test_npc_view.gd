## **THE FIRST THING THAT DRAWS A CROWD.** TDD-08 §9, US-0045/US-0046.
##
## **THE TWO WAYS THIS CLASS CAN BE WRONG BOTH LOOK CORRECT FROM OUTSIDE.**
##
## It can free too eagerly. Absence in a snapshot means "no update this tick" for
## an NPC — culling, rate LOD and the delta all omit ones the client must keep
## drawing — so a `RemotePawns`-shaped rule would delete most of the crowd on most
## ticks and leave a district that flickers. A timeout is worse rather than
## better: it deletes precisely the NPCs standing still at an anchor, which is the
## crowd's most common state and the one blend pockets are made of.
##
## And it can free too reluctantly. An NPC left behind at the cull boundary is a
## statue at 70 m, and one that is drawn where it was a minute ago is worse than
## one that is not drawn at all.
##
## Every test below exists because a plausible implementation gets one of those
## two wrong while passing "the crowd renders".
extends GutTest

var _view: NpcView


func before_each() -> void:
	_view = NpcView.new()
	add_child_autofree(_view)


## A snapshot carrying `count` NPCs in a line east of the observer.
func _snapshot(tick: int, observer: Vector3, spots: Array) -> Snapshot:
	var snap := Snapshot.new()
	snap.server_tick = tick
	snap.own_position = observer
	for index: int in spots.size():
		snap.add_npc(index, spots[index] as Vector3, 0.0, 1, 0)
	return snap


func _line(observer: Vector3, count: int, distance: float) -> Array:
	var out: Array = []
	for index: int in count:
		out.append(observer + Vector3(distance, 0.0, float(index)))
	return out


# ---------------------------------------------------------------------------
# The guard against vacuous success comes first.
# ---------------------------------------------------------------------------


## **A VIEW THAT DRAWS NOTHING PASSES EVERY "IT DOES NOT OVER-DRAW" TEST**, and
## that was the true state of this project for a milestone: NPC records reached
## the wire and no client instantiated a body for one.
func test_a_snapshot_full_of_npcs_produces_bodies() -> void:
	var here := Vector3.ZERO
	_view.apply_snapshot(_snapshot(1, here, _line(here, 8, 10.0)))
	assert_eq(_view.count(), 8, "the view drew nothing, so nothing below means anything")
	assert_true(_view.has_npc(0), "NPC 0 was not drawn")
	assert_true(_view.has_npc(7), "NPC 7 was not drawn")


# ---------------------------------------------------------------------------
# Absence is not departure.
# ---------------------------------------------------------------------------


## **THE SINGLE MOST IMPORTANT ASSERTION IN THE FILE.** `RemotePawns` frees a slot
## the snapshot stopped mentioning and is right to; doing the same here deletes
## every NPC the delta omitted for being unchanged, which after the first tick is
## most of them.
func test_an_npc_the_snapshot_stopped_mentioning_is_kept() -> void:
	var here := Vector3.ZERO
	_view.apply_snapshot(_snapshot(1, here, _line(here, 6, 10.0)))
	assert_eq(_view.count(), 6, "the crowd was not drawn to begin with")

	# Five ticks in which the server mentions nobody: everything is unchanged, or
	# not due this tick. Both are ordinary.
	for tick: int in range(2, 7):
		_view.apply_snapshot(_snapshot(tick, here, []))
	assert_eq(
		_view.count(),
		6,
		(
			"an NPC was freed for being absent. Absence is 'no update', not 'gone' — that is "
			+ "the protocol gap TDD-04 §7.1.2 records, and this class is where it is absorbed."
		)
	)


## A standing NPC is never re-sent once acknowledged, so it must survive an
## arbitrary silence. Asserted over a longer gap than any plausible timeout, since
## the tempting wrong fix is a timeout.
func test_a_motionless_npc_survives_a_long_silence() -> void:
	var here := Vector3.ZERO
	_view.apply_snapshot(_snapshot(1, here, _line(here, 3, 5.0)))
	for tick: int in range(2, 400):
		_view.apply_snapshot(_snapshot(tick, here, []))
	assert_eq(_view.count(), 3, "a motionless NPC timed out; idle is the crowd's normal state")


# ---------------------------------------------------------------------------
# But leaving is departure.
# ---------------------------------------------------------------------------


## The client culls by the same distance the server did, so an NPC the observer
## walks away from is dropped rather than left standing at the boundary forever.
func test_an_npc_the_observer_walks_away_from_is_dropped() -> void:
	var here := Vector3.ZERO
	var reach: float = Tuning.net.npc_cull_radius
	_view.apply_snapshot(_snapshot(1, here, _line(here, 4, reach * 0.5)))
	assert_eq(_view.count(), 4, "nothing was drawn to walk away from")

	# The observer moves far enough that the last known positions are outside the
	# radius. The server sent nothing, because it culled them.
	_view.apply_snapshot(_snapshot(2, here + Vector3(reach * 3.0, 0.0, 0.0), []))
	assert_eq(_view.count(), 0, "an NPC well outside the cull radius was still being drawn")


## **THE MARGIN MUST BE POSITIVE, AND WHICH SIDE IT FALLS ON IS THE WHOLE POINT.**
## A client that culled at or inside the server's radius would drop an NPC the
## server still believes it holds — and a standing one is then never mentioned
## again, because its delta baseline says the client has it.
func test_the_client_culls_later_than_the_server_never_earlier() -> void:
	assert_gt(
		_view.drop_margin(),
		0.0,
		"the client's cull is not wider than the server's; it will drop NPCs it cannot get back"
	)
	var here := Vector3.ZERO
	var reach: float = Tuning.net.npc_cull_radius
	# Exactly on the server's boundary: inside the client's, so still drawn.
	_view.apply_snapshot(_snapshot(1, here, [here + Vector3(reach, 0.0, 0.0)]))
	_view.apply_snapshot(_snapshot(2, here, []))
	assert_eq(_view.count(), 1, "an NPC on the server's own boundary was dropped by the client")


## Derived from two tunables rather than chosen, so it stays correct when either
## is retuned. Asserted against the arithmetic, not against 0.62.
func test_the_margin_comes_from_the_tunables() -> void:
	assert_almost_eq(
		_view.drop_margin(),
		Tuning.net.interp_buffer / 1000.0 * Tuning.movement.sprint,
		0.0001,
		"the drop margin is a literal; retuning the buffer or the sprint would not move it"
	)


# ---------------------------------------------------------------------------
# What it deliberately does not do.
# ---------------------------------------------------------------------------


## **NO NPC WEARS A PERSONA, AND THAT IS ASSERTED RATHER THAN LEFT TO DRIFT.**
## `CrowdRoster` derives identity from `match_seed` and no client is ever told it
## — `NET-S2C-MATCH-START` carries it and `SYS-MATCH` is M4's. Guessing would put
## the wrong clone on screen, which is an anonymity leak that looks exactly like
## correct behaviour. This goes red the day a client learns the seed, which is
## when somebody should be deciding this deliberately.
func test_nothing_is_dressed_as_a_persona_yet() -> void:
	var here := Vector3.ZERO
	_view.apply_snapshot(_snapshot(1, here, _line(here, 2, 5.0)))
	for child: Node in _view.get_children():
		assert_false(
			child is PersonaBody,
			(
				"an NPC is wearing a persona. The client cannot know the roster without "
				+ "match_seed, so this is a guess — and a wrong clone is an anonymity leak."
			)
		)
		assert_true(child is GreyboxBody, "an NPC body is neither greybox nor a persona")


## **A CLONE DRAWN A DIFFERENT SIZE FROM A PLAYER IS A SILENT DISCRIMINATOR**, and
## right now three separate declarations happen to agree with nothing tying them
## together: `pawn_local.tscn`'s collider, `npc_server.tscn`'s collider, and
## `GreyboxBody`'s fallback — which is what an NPC body actually uses, because it
## reads its size from a parent collider and `NpcView` is not a pawn.
##
## Resize the pawn and the crowd keeps the old silhouette. Nothing errors, no test
## fails, and skilled testers start picking humans out of a crowd without being
## able to say why. That is `RISK-ANONYMITY-LEAK` in one sentence, and US-0039
## made the NPC capsule match the pawn's for exactly this reason.
func test_an_npc_is_drawn_the_same_size_as_a_player() -> void:
	var pawn := _capsule_in("res://scenes/pawn/pawn_local.tscn")
	var npc := _capsule_in("res://scenes/npc/npc_server.tscn")
	assert_eq(pawn, npc, "the NPC collider and the pawn collider are different sizes")
	assert_eq(
		Vector2(GreyboxBody.FALLBACK_RADIUS, GreyboxBody.FALLBACK_HEIGHT),
		pawn,
		(
			"the body an NPC is DRAWN with is a different size from the pawn. A crowd "
			+ "member with a player's silhouette is the whole anonymity promise."
		)
	)


## The capsule declared in a scene, read from the file rather than instantiated —
## `pawn_local.tscn` brings a state machine and a camera rig with it.
func _capsule_in(path: String) -> Vector2:
	var scene := load(path) as PackedScene
	assert_not_null(scene, "could not load %s" % path)
	var state := scene.get_state()
	for i: int in state.get_node_count():
		for p: int in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) != &"shape":
				continue
			var shape := state.get_node_property_value(i, p) as CapsuleShape3D
			if shape != null:
				return Vector2(shape.radius, shape.height)
	return Vector2.ZERO


## **AN NPC THAT WALKS AWAY WHILE THE PLAYER STANDS STILL IS A STATUE FOREVER**,
## and the distance cull cannot see it. The server stops sending at 70 m, so the
## last position this view was ever told is **inside** the radius by definition —
## it can never exceed the client's own threshold, however far the NPC actually
## goes.
##
## `test_an_npc_the_observer_walks_away_from_is_dropped` passes because the
## OBSERVER moves, which drags every last-known position out of range at once.
## That is the easy half. The half a live watch found is the other one: eight
## seconds of a stationary player produced **zero drops**, which reads like good
## news and is not.
##
## The fix cannot be a timeout — the delta means a motionless NPC is never
## re-sent, so any timeout deletes exactly the crowd standing at anchors.
func test_an_npc_that_walks_away_is_dropped_even_if_the_player_does_not_move() -> void:
	var here := Vector3.ZERO
	var reach: float = Tuning.net.npc_cull_radius
	# In range, and drawn.
	_view.apply_snapshot(_snapshot(1, here, [here + Vector3(reach - 5.0, 0.0, 0.0)]))
	assert_eq(_view.count(), 1, "the NPC was never drawn")

	# It walks out of range. The server sends ONE final record carrying the real,
	# now-out-of-range position — a farewell — and then never mentions it again.
	_view.apply_snapshot(_snapshot(2, here, [here + Vector3(reach + 2.0, 0.0, 0.0)]))
	assert_eq(
		_view.count(),
		0,
		(
			"a farewell was ignored. A received position beyond the cull radius is the "
			+ "server saying goodbye — it never sends one for any other reason."
		)
	)

	# And silence afterwards must not resurrect it.
	for tick: int in range(3, 10):
		_view.apply_snapshot(_snapshot(tick, here, []))
	assert_eq(_view.count(), 0, "a dropped NPC came back from silence")


## **THE WHOLE CLIENT PATH, BECAUSE THIS VIEW NEVER SEES A RAW SNAPSHOT.** `Net`
## runs `SnapshotAssembler` before it emits `snapshot_received`, and every test
## above hands this class the wire snapshot instead — which silently assumes the
## one thing the assembler does not do: go quiet about an NPC.
##
## **THAT ASSUMPTION HID A DEFECT THROUGH A WHOLE STORY.** The assembler carries
## the crowd forward, so a farewell record it has been given is re-presented in
## every later snapshot; this view reads each replay as a fresh goodbye, spawns a
## body for an index it no longer holds and frees it again. Measured on a running
## server: **199 create/free pairs from one record the server sent once.**
##
## The count is asserted at exactly one because "small" is not the property — a
## boundary is either quiet or it is not.
func test_a_departing_npc_is_created_and_freed_exactly_once() -> void:
	var assembler := SnapshotAssembler.new()
	var here := Vector3.ZERO
	var reach: float = Tuning.net.npc_cull_radius
	# **A DICTIONARY, BECAUSE A GDSCRIPT LAMBDA CAPTURES BY VALUE.** Counting into
	# two local ints leaves them at zero however many times the signal fires, which
	# reads as a view that never drew anything.
	var tally := {"born": 0, "died": 0}
	_view.npc_appeared.connect(func(_i: int) -> void: tally["born"] += 1)
	_view.npc_dropped.connect(func(_i: int) -> void: tally["died"] += 1)

	_view.apply_snapshot(assembler.assemble(_full(1, here, [here + Vector3(reach - 5.0, 0, 0)])))
	assert_eq(int(tally["born"]), 1, "the NPC was never drawn, so nothing below is evidence")

	# One farewell, then the silence a culled NPC gets for the rest of the match.
	_view.apply_snapshot(assembler.assemble(_full(2, here, [here + Vector3(reach + 2.0, 0, 0)])))
	for tick: int in range(3, 40):
		_view.apply_snapshot(assembler.assemble(_full(tick, here, [])))

	assert_eq(_view.count(), 0, "the departed NPC is still drawn")
	assert_eq(
		int(tally["died"]), 1, "the cull boundary chatters: one departure, %d drops" % tally["died"]
	)
	assert_eq(
		int(tally["born"]), 1, "a departed NPC was re-created from a carried-forward farewell"
	)


## A snapshot the assembler will accept: full, so it needs no baseline.
func _full(tick: int, observer: Vector3, spots: Array) -> Snapshot:
	var snap := _snapshot(tick, observer, spots)
	snap.baseline_age = Snapshot.FULL
	return snap


## **A STALE POSITION BEYOND THE RADIUS IS NOT A FAREWELL**, and telling the two
## apart is the reason the client tracks which indices this snapshot carried. When
## the observer walks away, every last-known position goes out of range at once
## without the server saying anything — that is rule 2's case, and it keeps its
## margin. Treating it as a farewell would drop NPCs on a boundary the server has
## not agreed to.
func test_a_stale_far_position_is_not_mistaken_for_a_farewell() -> void:
	var here := Vector3.ZERO
	var reach: float = Tuning.net.npc_cull_radius
	# Just inside the server's radius, and just inside the client's margin too.
	_view.apply_snapshot(_snapshot(1, here, [here + Vector3(reach - 0.1, 0.0, 0.0)]))
	for tick: int in range(2, 20):
		_view.apply_snapshot(_snapshot(tick, here, []))
	assert_eq(
		_view.count(),
		1,
		"an NPC inside the radius was dropped on a stale reading rather than a farewell"
	)


## **A NEW NPC IS DRAWN WHERE THE SERVER PUT IT, NEVER AT THE OBSERVER.**
##
## `_spawn` used to read `_last_seen` for the body's first position — and it runs
## *before* that entry is written, so the fallback won. The fallback was the
## observer, so **every newly admitted NPC was placed on top of the player** and
## then jumped to where it really was on the next physics frame.
##
## It is not a rare path. An NPC crosses `TUN-NET-NPC-CULL-RADIUS` whenever the
## player walks, and every re-admission is a fresh `_spawn`, so a moving player
## produced a steady stream of figures materialising at their feet and teleporting
## away. Reported from the controls as "some figures teleport" one build after the
## interpolation work that introduced it.
func test_a_new_npc_is_placed_where_the_server_said() -> void:
	var here := Vector3(10.0, 0.0, 10.0)
	var there := here + Vector3(30.0, 0.0, 0.0)
	_view.apply_snapshot(_snapshot(1, here, [there]))

	assert_eq(_view.count(), 1, "the NPC was never drawn, so nothing below is evidence")
	var body := _view.get_child(0) as Node3D
	assert_almost_eq(
		body.global_position,
		there,
		Vector3.ONE * 0.01,
		"a newly admitted NPC was placed at the observer instead of at its own position"
	)

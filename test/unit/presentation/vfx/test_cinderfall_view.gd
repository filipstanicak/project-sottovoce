## **THE CLOUD IS DRAWN WHERE IT IS, FOR AS LONG AS IT IS.** US-0067, drawn
## 2026-09-03.
##
## `ABIL-CINDERFALL` blocks line of sight and forbids kill initiation, and until
## this view existed **no client drew any of it** — so the ability presented as the
## Compass going quiet and the reticle refusing, with nothing on screen to explain
## either. Every assertion here is about the drawing agreeing with the volume,
## because GDD-04 §3.1 makes the counter to this ability *wait at the cloud's edge*
## and an edge drawn anywhere but its real place is a counterplay that lies.
extends GutTest

const CASTER := 3

var _view: CinderfallView


func before_each() -> void:
	_view = CinderfallView.new()
	add_child_autofree(_view)


func after_each() -> void:
	# The bus is an autoload and outlives this test — US-0037's lesson.
	if EventBus.ability_started.is_connected(_view._on_ability_started):
		EventBus.ability_started.disconnect(_view._on_ability_started)


func _data() -> AbilityData:
	return Tuning.ability_data(Ids.ABIL_CINDERFALL)


func _throw(at: Vector3) -> void:
	EventBus.ability_started.emit(CASTER, Ids.ABIL_CINDERFALL, Vector3.ZERO, at)


## Frames are not available in a unit test and are not needed: the view's clock is
## whatever `delta` it is handed.
func _run(seconds: float, step: float = 0.05) -> void:
	var spent := 0.0
	while spent < seconds:
		_view._process(step)
		spent += step


func _clouds() -> Array[Node]:
	return _view.get_children()


# --- the wind-up ----------------------------------------------------------


## **THE POT IS IN THE AIR FOR `TUN-CINDERFALL-CAST-TIME` AND THERE IS NO CLOUD
## YET.** That window is the one design law 3 buys the victim; drawing early would
## delete the warning it exists to give.
func test_nothing_is_drawn_while_the_pot_is_still_in_the_air() -> void:
	_throw(Vector3(4.0, 0.0, 0.0))
	_run(_data().cast_time * 0.5)
	assert_eq(_view.live_count(), 0, "the cloud was drawn before the pot landed")


func test_the_cloud_appears_when_the_pot_bursts() -> void:
	# **THE PREMISE.** Every "it is not there" assertion in this file is satisfied
	# by a view that never draws anything at all.
	_throw(Vector3(4.0, 0.0, 0.0))
	_run(_data().cast_time + 0.1)
	assert_eq(_view.live_count(), 1, "the pot burst and no cloud appeared")


# --- the geometry ---------------------------------------------------------


## **WHERE IT LANDED, NOT WHERE IT WAS THROWN FROM.** The throw reaches
## `TUN-CINDERFALL-THROW-RANGE` 8 m, so a view drawing at the caster's origin puts
## cover where there is none and leaves none where there is cover. This is the
## assertion that would have failed while `HudBridge` dropped the aim.
func test_the_cloud_is_centred_on_the_landing_point() -> void:
	var landed := Vector3(7.0, 0.0, -3.0)
	_throw(landed)
	_run(_data().cast_time + 0.1)
	assert_eq(_clouds().size(), 1, "no cloud to place")
	assert_eq((_clouds()[0] as Node3D).position, landed, "the cloud was drawn somewhere else")


## The drawn radius is `TUN-CINDERFALL-RADIUS` and not a metre of artistic licence
## either way — `CinderfallVolumes` tests against that exact number.
func test_the_drawn_radius_is_the_tuned_radius() -> void:
	_throw(Vector3.ZERO)
	_run(_data().cast_time + 0.1)
	# **BY TYPE, NOT BY INDEX.** The cloud is several shells plus a ring, and an
	# index worked only while it was one of each.
	var volume: SphereMesh = null
	var edge: TorusMesh = null
	for child: Node in _clouds()[0].get_children():
		var mesh := (child as MeshInstance3D).mesh
		if mesh is SphereMesh and (volume == null or (mesh as SphereMesh).radius > volume.radius):
			volume = mesh
		elif mesh is TorusMesh:
			edge = mesh
	assert_not_null(volume, "the cloud has no volume")
	assert_not_null(edge, "the cloud has no edge, so there is nowhere to wait")
	assert_almost_eq(volume.radius, _data().radius, 0.001, "the volume is not the tuned radius")
	assert_almost_eq(edge.outer_radius, _data().radius, 0.001, "the edge is not at the boundary")


## **VISIBLE FROM INSIDE.** A back-face-culled sphere shows nothing to the player
## standing in it, who is exactly the player who cannot initiate a kill and cannot
## be seen — the one who most needs to know where they are.
func test_the_cloud_is_visible_from_within() -> void:
	_throw(Vector3.ZERO)
	_run(_data().cast_time + 0.1)
	var material := (_clouds()[0].get_child(0) as MeshInstance3D).material_override
	assert_eq(
		(material as StandardMaterial3D).cull_mode,
		BaseMaterial3D.CULL_DISABLED,
		"the cloud is invisible to whoever is standing in it"
	)


# --- the lifetime ---------------------------------------------------------


func test_the_cloud_lasts_its_tuned_duration() -> void:
	_throw(Vector3.ZERO)
	_run(_data().cast_time + _data().duration * 0.5)
	assert_eq(_view.live_count(), 1, "the cloud went out inside its own duration")


## **AND IT IS NOT DRAWN FOR THE LAG-COMPENSATION GRACE.**
## `CinderfallVolumes.expire` keeps a burnt-out cloud for `RewindClamp.max_ticks()`
## longer so a kill validated in the past still meets one that was up when the
## attacker pressed. That window is **validation, not cover**: drawing it would
## promise up to 200 ms of concealment that no live query grants.
func test_the_cloud_is_gone_at_its_duration_and_not_at_the_rewind_grace() -> void:
	_throw(Vector3.ZERO)
	_run(_data().cast_time + _data().duration + 0.1)
	assert_eq(_view.live_count(), 0, "the cloud outlived its own duration")
	var grace := float(RewindClamp.max_ticks()) / Tuning.net.server_tick
	assert_gt(grace, 0.0, "the rewind grace is zero, so this test proves nothing")


# --- what it ignores ------------------------------------------------------


## The view answers one ability. A Lunge's tell arrives on the same signal and its
## effect is a body moving at 9 m/s, which the client already draws.
func test_another_ability_draws_no_cloud() -> void:
	EventBus.ability_started.emit(CASTER, Ids.ABIL_LUNGE, Vector3.ZERO, Vector3(6.0, 0.0, 0.0))
	_run(_data().cast_time + 0.1)
	assert_eq(_view.live_count(), 0, "a Lunge dropped a cinder cloud")


func test_two_throws_draw_two_clouds() -> void:
	_throw(Vector3(2.0, 0.0, 0.0))
	_throw(Vector3(-9.0, 0.0, 0.0))
	_run(_data().cast_time + 0.1)
	assert_eq(_view.live_count(), 2, "a second cloud replaced the first instead of joining it")


## **AS OPAQUE AS THE RULE IS.** `TUN-CINDERFALL-BLOCKS-LOS` makes every sight
## query through this cloud fail, so a drawing you can see the district through
## promises **less** concealment than the game grants — and a player who watches
## their cover fail to hide anything stops using it. It shipped at 0.72 and was
## caught by looking at `tools/cinderfall_probe.tscn`, not by any assertion here.
func test_the_cloud_is_as_opaque_as_the_rule_that_makes_it_cover() -> void:
	assert_true(_data().blocks_los, "the premise: this test is about an ability that blocks sight")
	assert_gt(
		_view.density(),
		0.85,
		"the cloud is see-through, so it draws less cover than TUN-CINDERFALL-BLOCKS-LOS grants"
	)


## **AND THE DENSITY COMES FROM DEPTH, WHICH IS WHY ONE SHELL WAS NOT ENOUGH.** A
## single translucent sphere tints only what is beyond it, so from inside one the
## ground at your feet came through untouched and the cloud read as absent. The
## assertion is on the *layers*, because raising one shell's alpha until the
## outside looked right is exactly the fix that leaves the inside wrong.
func test_the_cloud_is_drawn_as_a_volume_rather_than_a_shell() -> void:
	_throw(Vector3.ZERO)
	_run(_data().cast_time + 0.1)
	var shells := 0
	var radii: Array[float] = []
	for child: Node in _clouds()[0].get_children():
		var mesh := (child as MeshInstance3D).mesh
		if mesh is SphereMesh:
			shells += 1
			radii.append((mesh as SphereMesh).radius)
	assert_gt(shells, 1, "the cloud is one shell, so it is invisible from inside itself")
	assert_eq(radii[0], _data().radius, "the outermost shell is not the tuned radius")
	assert_lt(radii[1], radii[0], "the shells are concentric and identical, so they add no depth")

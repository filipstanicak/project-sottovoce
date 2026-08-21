## **NOTHING MAY FALL OUT OF THE WORLD AND STAY THERE.** US-0041.
##
## Found from the controls twice, as two different-sounding complaints that were
## the same four bodies: NPCs "floating" over a hole, and NPCs standing inside a
## wall. `CIRC-B`'s procession walks off the Loggia's north edge where the floor
## ends, and the members fall for the rest of the match.
##
## **THE WIRE CANNOT REPORT IT**, which is why it took two reports:
## `Quantise.height_to_u8` spans 0 to 12.75 m, so a body at −207 m encodes as 0 and
## the client draws it standing on the street.
extends GutTest

const MAP := "res://data/maps/map_vetraio.tres"

var _pool: NpcPool
var _map: MapData
var _rescue: CrowdRescue


func before_each() -> void:
	_map = load(MAP) as MapData
	_pool = NpcPool.new()
	add_child_autofree(_pool)
	_pool.preallocate(8)
	_pool.activate(6, 4242, CrowdRoster.PLAYABLE, 6)
	_rescue = CrowdRescue.new()


## **THE GUARD AGAINST VACUOUS SUCCESS COMES FIRST.** A sweep that never fires
## satisfies every assertion below about a healthy crowd, so the count must be
## shown to move at all before "it stayed zero" means anything.
func test_a_crowd_standing_on_the_street_is_left_alone() -> void:
	_rescue.sweep(_pool, _map)
	assert_eq(_rescue.rescued, 0, "a crowd on the street was teleported for no reason")


func test_a_body_below_the_world_is_put_back_and_counted() -> void:
	var body := _pool.body_of(0)
	body.global_position = Vector3(101.0, VetraioLayout.NAV_BAKE_FLOOR - 200.0, 62.0)
	body.velocity = Vector3(0.0, -63.0, 0.0)

	_rescue.sweep(_pool, _map)

	assert_eq(_rescue.rescued, 1, "a body 200 m under the district was left falling")
	assert_gt(
		body.global_position.y,
		VetraioLayout.NAV_BAKE_FLOOR,
		"the body was counted as rescued and left where it was"
	)
	assert_eq(body.velocity, Vector3.ZERO, "it was put back still falling, so it falls again")


## **PUT BACK ON AN ANCHOR, NEVER AT THE ORIGIN.** A crowd that reappeared at
## (0, 0, 0) the first time a route broke would stack in one corner, which is the
## failure `CrowdPlacement`'s scatter exists to prevent.
func test_it_is_put_back_on_a_map_anchor() -> void:
	var body := _pool.body_of(1)
	body.global_position = Vector3(0.0, -400.0, 0.0)
	_rescue.sweep(_pool, _map)
	var landed := body.global_position
	var found := false
	for anchor: Vector3 in _map.idle_anchors:
		if anchor.is_equal_approx(landed):
			found = true
			break
	assert_true(found, "the body was put back somewhere that is not an idle anchor")


## The threshold is the bake's own idea of "below the district", so a map that
## moves its ground carries this with it rather than needing a second number.
func test_the_floor_is_the_bakes_own() -> void:
	var body := _pool.body_of(2)
	body.global_position = Vector3(60.0, VetraioLayout.NAV_BAKE_FLOOR + 0.5, 45.0)
	_rescue.sweep(_pool, _map)
	assert_eq(_rescue.rescued, 0, "a body above the bake floor was rescued anyway")


## A sweep with nothing to work with must do nothing rather than crash: the
## director calls it every tick, including before a map is set.
func test_it_survives_having_no_map() -> void:
	_rescue.sweep(_pool, null)
	assert_eq(_rescue.rescued, 0, "a sweep with no map counted a rescue")

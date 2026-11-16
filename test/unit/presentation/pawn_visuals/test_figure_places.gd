## **A FIGURE SITS WHERE THE BENCH IS AND LEANS WHERE THE COUNTER IS.** US-0109.
##
## The places are the map's own `static_props`, the same record `LeanSpots` holds
## seats and counters on for players and civilians alike.
extends GutTest

var _survey: DressingSurvey
var _props: Array


func before_each() -> void:
	var map: Node3D = (load(MapCatalogue.client_scene("vetraio")) as PackedScene).instantiate()
	add_child_autofree(map)
	_survey = DressingSurvey.new(map)
	_props = (load(MapCatalogue.data_path("vetraio")) as MapData).static_props
	FigurePlaces.set_from(_survey, _props)


func after_each() -> void:
	FigurePlaces.clear()


func _postures() -> Dictionary:
	var count := {}
	for prop: Vector3 in _props:
		var place := FigurePlaces.at(prop)
		if not place.is_empty():
			count[place[0]] = int(count.get(place[0], 0)) + 1
	return count


func _facing(place: Array) -> Vector2:
	return Vector2(sin(float(place[1])), cos(float(place[1])))


func _part_at(role: DressingSurvey.Role, at: Vector2, reach: float) -> DressingSurvey.Part:
	for part: DressingSurvey.Part in _survey.of(role):
		if part.rect().grow(reach).has_point(at):
			return part
	return null


func test_every_static_prop_is_a_place() -> void:
	assert_gt(_props.size(), 20, "the map declares no seats or counters to test with")
	assert_eq(FigurePlaces.count(), _props.size())


func test_the_seats_are_seats_and_the_counters_are_counters() -> void:
	var seats := VetraioGround.bench_seat_points().size()
	var counters := VetraioGround.stall_lean_points().size()
	assert_eq(_postures().get(FigureMotion.Posture.SIT, 0), seats)
	assert_eq(_postures().get(FigureMotion.Posture.LEAN, 0), counters)


func test_a_seated_figure_has_its_back_to_the_bench_and_sits_on_it() -> void:
	var checked := 0
	for prop: Vector3 in _props:
		var place := FigurePlaces.at(prop)
		if place[0] != FigureMotion.Posture.SIT:
			continue
		checked += 1
		var at := Vector2(prop.x, prop.z)
		var bench := _part_at(DressingSurvey.Role.BENCH, at, FigurePlaces.BENCH_NEAR)
		assert_not_null(bench)
		var away := at - bench.rect().get_center()
		assert_gt(_facing(place).dot(away.normalized()), 0.2, "a sitter faces its own bench")
		var hips := at - _facing(place) * float(place[2])
		assert_true(bench.rect().has_point(hips), "a sitter's hips are %s, off the bench" % hips)
	assert_gt(checked, 0)


func test_a_leaning_figure_faces_its_counter() -> void:
	var checked := 0
	for prop: Vector3 in _props:
		var place := FigurePlaces.at(prop)
		if place[0] != FigureMotion.Posture.LEAN:
			continue
		checked += 1
		var at := Vector2(prop.x, prop.z)
		var stall := _part_at(DressingSurvey.Role.STALL, at, FigurePlaces.STALL_NEAR)
		assert_not_null(stall)
		var reached := at + _facing(place) * FigurePlaces.STALL_NEAR
		assert_true(stall.rect().has_point(reached), "a leaner faces away from its counter")
	assert_gt(checked, 0)


func test_a_step_away_is_no_place() -> void:
	var prop: Vector3 = _props[0]
	assert_false(FigurePlaces.at(prop + Vector3(FigurePlaces.REACH * 0.8, 0.0, 0.0)).is_empty())
	assert_true(FigurePlaces.at(prop + Vector3(FigurePlaces.REACH * 1.5, 0.0, 0.0)).is_empty())


func test_a_storey_up_is_not_the_seat_below() -> void:
	var prop: Vector3 = _props[_props.size() - 1]
	assert_true(FigurePlaces.at(prop + Vector3(0.0, VetraioLayout.BALCONY_Y, 0.0)).is_empty())


func test_a_cleared_map_has_no_places() -> void:
	FigurePlaces.clear()
	assert_eq(FigurePlaces.count(), 0)
	assert_true(FigurePlaces.at(_props[0]).is_empty())

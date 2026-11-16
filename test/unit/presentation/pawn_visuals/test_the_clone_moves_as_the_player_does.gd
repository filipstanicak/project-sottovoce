## **A CLONE AND A PLAYER, MOVED ALIKE, ARE POSED ALIKE.** ANIMATION_SPEC §1, US-0109.
##
## The spec guards clone parity with four layers because it expected two rigs and
## two clip libraries that could drift. There is one of each here, so the claim to
## hold is narrower and absolute: **the same movement through the same place gives
## the same figure, whoever is behind it.** One is built as another player's pawn
## is, one as `NpcView` builds a civilian, and they are walked down the same line.
extends GutTest

const DT := 1.0 / 60.0
const REMOTE := "res://scenes/pawn/pawn_remote.tscn"
const ASKS_WHO: Array[String] = [
	"NpcView",
	"RemotePawns",
	"LocalPawnDriver",
	"GameState",
	"is_dressed",
	"is_filler",
	"persona",
	"peer",
	"slot",
]
const MOTION_FILES: Array[String] = [
	"res://scripts/presentation/pawn_visuals/figure_animator.gd",
	"res://scripts/presentation/pawn_visuals/figure_motion.gd",
	"res://scripts/presentation/pawn_visuals/figure_acts.gd",
	"res://scripts/presentation/pawn_visuals/figure_pose.gd",
]

var _pawn: Node3D
var _player: PersonaBody
var _clone: PersonaBody


func _stand_up(persona: StringName) -> void:
	_pawn = (load(REMOTE) as PackedScene).instantiate()
	add_child_autofree(_pawn)
	_player = _pawn.get_node("PersonaVisuals") as PersonaBody
	var crowd := NpcView.new()
	add_child_autofree(crowd)
	_clone = PersonaBody.new()
	crowd.add_child(_clone)
	_player.dress(persona)
	_clone.dress(persona)


func after_each() -> void:
	FigurePlaces.clear()


## Put both at `at`, facing `yaw`, and move them a frame on.
func _step(at: Vector3, yaw: float) -> void:
	_pawn.global_position = at
	_pawn.rotation.y = yaw
	_clone.global_position = at
	_clone.rotation.y = yaw
	_player.advance(DT)
	_clone.advance(DT)


## Every joint's turn and place, in the order the rig holds them.
func _joints(body: PersonaBody) -> Array:
	var rig := body.rig()
	var joints: Array[Node3D] = [rig.root, rig.hips, rig.spine]
	joints.append_array(rig.shoulders)
	joints.append_array(rig.elbows)
	joints.append_array(rig.thighs)
	joints.append_array(rig.knees)
	var out: Array = []
	for joint: Node3D in joints:
		out.append([joint.position.snappedf(0.0001), joint.rotation.snappedf(0.0001)])
	return out


func test_walked_down_the_same_street_they_are_the_same_figure() -> void:
	for persona: StringName in CrowdRoster.PLAYABLE:
		_stand_up(persona)
		var at := Vector3(10.0, 0.0, 10.0)
		var differing := 0
		for frame: int in 240:
			# A walk, a turn, a stretch at a stroll, a stop.
			var speed: float = [1.4, 1.4, 2.2, 0.0][frame / 60]
			var yaw := 0.6 if frame > 90 else 0.0
			at += Vector3(sin(yaw), 0.0, cos(yaw)) * speed * DT
			_step(at, yaw)
			# Compared once both are walking. Standing, each figure keeps its own
			# offset into the idle — a civilian and a player alike, from one sequence
			# — and the first half second still carries a trace of it.
			if frame >= 60 and frame < 180 and _joints(_player) != _joints(_clone):
				differing += 1
		assert_eq(differing, 0, "a %s clone and player differ on %d frames" % [persona, differing])
		assert_gt(absf(_player.rig().thighs[0].rotation.x) + 1.0, 1.0)


func test_they_walked_at_all() -> void:
	# The comparison above passes over two figures frozen at rest.
	_stand_up(Ids.PERSONA_PESATORE)
	var at := Vector3.ZERO
	var widest := 0.0
	for _frame: int in 120:
		at += Vector3(0.0, 0.0, 1.4 * DT)
		_step(at, 0.0)
		widest = maxf(widest, absf(_clone.rig().thighs[0].rotation.x))
	assert_gt(widest, 0.25, "the clone slid down the street without taking a step")


func test_stopped_on_the_same_seat_they_both_sit() -> void:
	_stand_up(Ids.PERSONA_CANTATRICE)
	var seat := Vector3(40.0, 0.0, 2.9)
	FigurePlaces.add(seat, FigureMotion.Posture.SIT, 0.0, 0.65)
	for _frame: int in 120:
		_step(seat, 2.0)
	for body: PersonaBody in [_player, _clone]:
		var rig := body.rig()
		assert_lt(rig.hips.position.y, rig.shape.hip_y() - 0.2, "one of the two is still standing")
	# The same seat, the same way round, whichever way each pawn was facing.
	assert_almost_eq(
		_player.rig().root.global_rotation.y, _clone.rig().root.global_rotation.y, 0.001
	)
	assert_eq(_joints(_player).slice(3), _joints(_clone).slice(3), "they sit differently")


func test_a_seated_figure_faces_its_bench_not_its_pawn() -> void:
	_stand_up(Ids.PERSONA_VETRAIO)
	var seat := Vector3(40.0, 0.0, 2.9)
	FigurePlaces.add(seat, FigureMotion.Posture.SIT, 0.0, 0.65)
	for _frame: int in 180:
		_step(seat, 2.0)
	assert_almost_eq(_player.rig().root.global_rotation.y, 0.0, 0.02)


func test_nothing_that_poses_a_figure_asks_who_it_is() -> void:
	# The structural half: there is no argument for it to branch on.
	var asked: PackedStringArray = []
	for path: String in MOTION_FILES:
		assert_gt(SourceScanner.read(path).length(), 500, "%s is missing or tiny" % path)
		for needle: String in ASKS_WHO:
			if SourceScanner.code_contains(path, needle):
				asked.append("%s names %s" % [path.get_file(), needle])
	assert_eq(asked.size(), 0, "\n".join(asked))

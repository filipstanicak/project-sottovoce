## **THE CINDER CLOUD, DRAWN.** GDD-04 §3.1, US-0067. CLIENT ONLY.
##
## `ABIL-CINDERFALL` has been the only ability in this game that changes the world
## since US-0067, and **nothing has ever drawn it**. A cloud blocks every line of
## sight through it and forbids kill initiation inside it — including the caster's
## own — and on a client it was an *absence* of information: the Compass stops
## pointing and the reticle stops offering, with nothing on screen to say why.
##
## **THE DRAWN CLOUD IS THE GAMEPLAY VOLUME, EXACTLY.** Same centre, same
## `TUN-CINDERFALL-RADIUS`, same `TUN-CINDERFALL-DURATION` — no fade, no bloom, no
## generous edge. GDD-04 §3.1 names the counter to this ability as **patience**:
## *wait at the cloud's edge*. A player cannot wait at an edge the game draws in a
## different place from the one it tests against, so every softening here would
## take away the counterplay it looks like it is decorating.
##
## **AND IT MUST NOT BE DRAWN FOR THE LAG-COMPENSATION GRACE.**
## `CinderfallVolumes.expire` deliberately keeps a burnt-out cloud for
## `RewindClamp.max_ticks()` longer, so a kill validated in the past still meets a
## cloud that was up when the attacker pressed. That window is **validation**, not
## cover: drawing it would promise 200 ms of concealment that no live query grants.
class_name CinderfallView
extends Node3D

## The ring that marks the edge. **Presentation, not tuning**: its *radius* is
## `TUN-CINDERFALL-RADIUS` exactly and that is the number that matters — these two
## only say how thickly a boundary already decided elsewhere is inked.
const EDGE_WIDTH := 0.18
const EDGE_HEIGHT := 0.06

## **A CLOUD IS A VOLUME AND ONE SHELL IS NOT.** The first version drew a single
## translucent sphere, and from *inside* it the district was perfectly readable —
## a shell only tints what is **beyond** it, so the ground at your feet, which is
## the ground inside the cloud, came through untouched and the whole thing read as
## no cloud at all. Found by looking; no assertion here could have said it.
##
## Nested shells approximate the volume: how opaque the cloud is becomes how much
## of it stands between you and what you are looking at. From outside you look
## through six surfaces and it is solid; from the middle, three; **from the edge,
## one — which is thin, and is exactly right**, because GDD-04 §3.1's counter is to
## wait at the edge and an edge you cannot see past is not a place to wait.
const SHELLS := 3
const SHELL_STEP := 0.28

var palette: Palette = Palette.fallback()

## `[point, seconds until the pot bursts]`. The pot is in the air for
## `TUN-CINDERFALL-CAST-TIME` and there is no cloud yet — which is the window the
## tell exists to give a victim, so drawing early would delete it.
var _pending: Array = []

## `[node, seconds of cloud left]`.
var _live: Array = []


func _ready() -> void:
	EventBus.ability_started.connect(_on_ability_started)


## **THE LANDING POINT, NOT THE CASTER.** `EVT-ABILITY-STARTED` carries both, and
## the difference is the whole ability: an 8 m throw drawn at the thrower's feet
## would put cover where there is none and none where there is cover.
func _on_ability_started(
	_caster_slot: int, ability: StringName, _origin: Vector3, at: Vector3
) -> void:
	if ability != Ids.ABIL_CINDERFALL:
		return
	var data := Tuning.ability_data(ability)
	if data == null or data.radius <= 0.0:
		return
	_pending.append([at, maxf(data.cast_time, 0.0)])


## **A RENDER-FRAME CLOCK, WHICH IS RIGHT HERE AND WOULD BE WRONG ANYWHERE ELSE.**
## Nothing about this decides an outcome — the volume that does lives on the
## server — so this is a drawing, and a drawing belongs on the frame it is drawn.
func _process(delta: float) -> void:
	_advance_pending(delta)
	_advance_live(delta)


func _advance_pending(delta: float) -> void:
	var waiting: Array = []
	for row: Array in _pending:
		row[1] = float(row[1]) - delta
		if float(row[1]) > 0.0:
			waiting.append(row)
			continue
		_burst(row[0] as Vector3)
	_pending = waiting


func _advance_live(delta: float) -> void:
	var living: Array = []
	for row: Array in _live:
		row[1] = float(row[1]) - delta
		if float(row[1]) > 0.0:
			living.append(row)
			continue
		(row[0] as Node3D).queue_free()
	_live = living


func _burst(at: Vector3) -> void:
	var data := Tuning.ability_data(Ids.ABIL_CINDERFALL)
	if data == null:
		return
	var cloud := _cloud(at, data.radius)
	add_child(cloud)
	_live.append([cloud, maxf(data.duration, 0.0)])


## A volume and its edge. **Two meshes rather than one**, because they answer
## different questions: the sphere says *you cannot see through this* and the ring
## says *this is where it stops*, and only the second is the one you stand at.
func _cloud(at: Vector3, radius: float) -> Node3D:
	var root := Node3D.new()
	root.position = at
	for shell: int in SHELLS:
		root.add_child(_volume(radius * (1.0 - float(shell) * SHELL_STEP)))
	root.add_child(_edge(radius))
	return root


## What a viewer at the centre sees through, given `SHELLS` layers each at the
## palette's alpha. **Public because the test asserts the property rather than the
## number**: the requirement is that you cannot read the street through your own
## cover, not that any one shell has a particular alpha.
func density() -> float:
	return 1.0 - pow(1.0 - palette.cinderfall.a, float(SHELLS))


## **CULLING IS DISABLED, AND THE PLAYER IT IS FOR IS THE ONE INSIDE.** A
## back-face-culled sphere is invisible from within, and somebody standing in a
## cinder cloud is precisely who most needs to be told they are in one — they
## cannot initiate a kill and nobody can see them.
func _volume(radius: float) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	body.mesh = sphere
	body.material_override = _material(palette.cinderfall)
	return body


func _edge(radius: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.outer_radius = radius
	torus.inner_radius = maxf(radius - EDGE_WIDTH, 0.0)
	ring.mesh = torus
	ring.position = Vector3(0.0, EDGE_HEIGHT, 0.0)
	ring.material_override = _material(palette.cinderfall_edge)
	return ring


## **UNSHADED, BECAUSE ASH IS NOT A SURFACE.** A lit translucent sphere picks up
## the district's one directional light and reads as a glass ball; unshaded, it
## reads as something you cannot see through, which is what it is.
func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## What is drawn right now. For the probe and the tests; nothing in the game reads
## it, because nothing in the game may ask a drawing a question.
func live_count() -> int:
	return _live.size()

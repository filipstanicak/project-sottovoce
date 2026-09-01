## **THE HUD'S ONLY NODE THAT IS ALLOWED TO REACH.** ADR-0006, US-0072. CLIENT ONLY.
##
## Widgets read view models; view models read the event bus (never-do #7). Something
## still has to *build* that graph and hand each widget its model, and this is it —
## one node, at the top, whose whole job is wiring.
##
## **IT IS ALSO WHERE THE CAMERA YAW ENTERS.** The Compass is camera-relative and
## the yaw is not on the event bus, so the root pushes it into `CompassVm` each
## frame rather than letting the view model or the widget fetch a rig. That keeps
## the one-way flow intact and keeps the reach in the one class that admits to
## having it.
class_name HudRoot
extends CanvasLayer

## The rig, by path, the way `LocalPawnDriver` and `CameraRig` take theirs.
## **Optional**: a HUD with no camera draws a Compass in world space, which is
## wrong but not fatal, and is what a test harness with no rig gets.
@export var camera_path: NodePath

## **INJECTED INTO EVERY WIDGET** (UI_UX_SPEC §7), so swapping it swaps the whole
## HUD. Only `DEFAULT` is authored; the three colourblind variants are US-0083's
## at M6, and they are a data question because this seam exists.
@export var palette: Palette = null

var camera: Node3D = null

var compass_vm := CompassVm.new()
var score_vm := ScoreFeedVm.new()
var chase_vm := ChaseVm.new()

var _bridge: HudBridge = null
var _widgets: Array[Control] = []


func _ready() -> void:
	if not camera_path.is_empty():
		camera = get_node_or_null(camera_path) as Node3D
	if palette == null:
		palette = Palette.fallback()
	_bridge = HudBridge.new()
	_bridge.name = "HudBridge"
	add_child(_bridge)
	var compass := CompassWidget.new()
	compass.vm = compass_vm
	var feed := ScoreFeedWidget.new()
	feed.vm = score_vm
	var chase := ChaseRingWidget.new()
	chase.vm = chase_vm
	# **THE VIGNETTE IS ADDED FIRST SO IT SITS BEHIND EVERYTHING.** It is the only
	# full-screen effect in the game (§4.2) and it must never cover a widget the
	# player is trying to read at the exact moment they most need to read it.
	_add(VignetteWidget.new(), "Vignette")
	_add(compass, "Compass")
	# **AFTER THE COMPASS, SO THE BARS SIT OVER ITS RIM RATHER THAN UNDER IT.** The
	# two never overlap by construction — the arcs are outside `LOCK_RADIUS` — but
	# order decides which wins if either radius is ever retuned, and the bar losing
	# to the instrument it annotates is the wrong way round.
	_add(chase, "ChaseRing")
	_add(TierWidget.new(), "Tier")
	_add(PortraitWidget.new(), "Portrait")
	_add(CrosshairWidget.new(), "Crosshair")
	_add(feed, "ScoreFeed")
	EventBus.compass_updated.connect(_on_compass)
	EventBus.score_event_appended.connect(_on_score)
	EventBus.pursuit_changed.connect(_on_pursuit)


func _exit_tree() -> void:
	if EventBus.compass_updated.is_connected(_on_compass):
		EventBus.compass_updated.disconnect(_on_compass)
	if EventBus.score_event_appended.is_connected(_on_score):
		EventBus.score_event_appended.disconnect(_on_score)
	if EventBus.pursuit_changed.is_connected(_on_pursuit):
		EventBus.pursuit_changed.disconnect(_on_pursuit)


## **THE YAW IS READ ON THE RENDER FRAME**, like the Compass's phase, because the
## cone must track the mouse rather than the tick. `CameraRig` writes its own
## transform every rendered frame (US-0045), so this reads the same value the
## player is looking through.
##
## **AND IT IS CONVERTED, WHICH IT WAS NOT IN US-0072.** `global_rotation.y` is
## the engine's heading and the Compass speaks the game's; they differ by pi, so
## the cone pointed at the opposite of the contract. `CameraArm.yaw_from_camera`
## owns that conversion and says why.
func _process(_delta: float) -> void:
	if camera != null:
		compass_vm.camera_yaw = CameraArm.yaw_from_camera(camera.global_rotation.y)


## **THE BUS TYPES THIS `RefCounted` AND THE ROOT NARROWS IT.** `EventBus` may hold
## no `func` and no `class`, so its signals carry the widest type that fits; a cast
## that fails is a report this build does not understand, which is dropped rather
## than passed on as null.
func _on_score(event: RefCounted) -> void:
	var report := event as ScoreReport
	if report != null:
		score_vm.report(report)


func _on_pursuit(hunting: float, hunted: float) -> void:
	chase_vm.apply(hunting, hunted)


func _on_compass(bearing: float, bucket: int, lock: float) -> void:
	compass_vm.bearing = bearing
	compass_vm.bucket = bucket
	compass_vm.lock = lock


## **THE PALETTE IS SET BEFORE THE CHILD ENTERS THE TREE.** Every widget falls back
## to `Palette.fallback()` in its own `_ready`, so setting it afterwards would let
## the first frame draw from the default and the second from the real one.
func _add(widget: Control, widget_name: String) -> void:
	widget.name = widget_name
	widget.set("palette", palette)
	_widgets.append(widget)
	add_child(widget)

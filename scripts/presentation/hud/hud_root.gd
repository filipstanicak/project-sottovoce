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

var camera: Node3D = null

var compass_vm := CompassVm.new()

var _compass: CompassWidget = null
var _bridge: HudBridge = null


func _ready() -> void:
	if not camera_path.is_empty():
		camera = get_node_or_null(camera_path) as Node3D
	_bridge = HudBridge.new()
	_bridge.name = "HudBridge"
	add_child(_bridge)
	_compass = CompassWidget.new()
	_compass.name = "Compass"
	_compass.vm = compass_vm
	add_child(_compass)
	EventBus.compass_updated.connect(_on_compass)


func _exit_tree() -> void:
	if EventBus.compass_updated.is_connected(_on_compass):
		EventBus.compass_updated.disconnect(_on_compass)


## **THE YAW IS READ ON THE RENDER FRAME**, like the Compass's phase, because the
## cone must track the mouse rather than the tick. `CameraRig` writes its own
## transform every rendered frame (US-0045), so this reads the same value the
## player is looking through.
func _process(_delta: float) -> void:
	if camera != null:
		compass_vm.camera_yaw = camera.global_rotation.y


func _on_compass(bearing: float, bucket: int, lock: float) -> void:
	compass_vm.bearing = bearing
	compass_vm.bucket = bucket
	compass_vm.lock = lock

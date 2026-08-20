## **THE NETCODE, WHILE YOU PLAY IT.** US-0028, US-0045.
##
## Built because a jitter was reported four times from the controls and diagnosed
## wrongly three times from prose. "It tugs to the right of the walking direction,
## as if S were tapped" turned out to be a stale input command applied twice — but
## it took a round trip through rendering, interpolation and teleports to find,
## because nothing let the person feeling it read the number that described it.
##
## **EVERY LINE IS SOMETHING THAT WOULD OTHERWISE HAVE TO BE INFERRED**, and the
## most important one is the correction **direction in the player's own frame**:
## `FWD/BACK` and `LEFT/RIGHT`, the same words a player uses.
##
## | It reads | Then the fault is |
## |---|---|
## | corrections along `FWD`/`BACK` | a step-count disagreement: the server ran short or long |
## | corrections to `LEFT`/`RIGHT` | the server integrated a **different input** |
## | `refused` climbing | the transport: snapshots arriving with no baseline to apply them to |
## | `unacked` climbing | commands are not reaching the server, or acks are not coming back |
##
## **STRIPPED FROM RELEASE, AND NOT REFERENCED BY ANY SCENE.** The three release
## presets exclude `scripts/debug/*`, so a `.tscn` naming this file would export a
## scene pointing at a script that is not there. `LocalPawnDriver` loads it at
## runtime behind `OS.has_feature("debug")` and an existence check, exactly as it
## loads `feel_readout.gd`, and `test_no_scene_references_debug.gd` keeps it that
## way.
##
## Literals are allowed here. `test_no_literal_strings.gd` scans every layer
## except this one: nothing below is ever shown to a player, so it is not part of
## the vocabulary `data/strings/en.csv` holds.
extends CanvasLayer

## Corrections remembered for the running summary. Twenty is a few seconds of a
## bad connection and long enough that one unlucky snapshot does not dominate.
const HISTORY := 20

## A correction smaller than this is float noise and prediction lead, not
## something a player can feel. It is still counted, just not called out.
const NOTABLE := 0.02

## Commands remembered for the "were you driving?" line. Two seconds at
## `TUN-NET-CLIENT-INPUT-RATE`, so it covers the moment a screenshot describes
## rather than the single frame it was taken on.
const INPUT_WINDOW := 120

## Comparisons remembered for the typical-error line. Roughly ten seconds at the
## snapshot rate.
const ERROR_WINDOW := 300

var _driver: LocalPawnDriver
var _reconciler: Node
var _label: Label
var _corrections: Array = []
var _worst: Array = [Vector3.ZERO, 0.0]
var _errors: PackedFloat32Array = PackedFloat32Array()
var _seq: int = 0
var _move := Vector2.ZERO
var _recent: Array[bool] = []


## Built by `LocalPawnDriver`, like `feel_readout.gd`, for the export reason above.
## The reconciler is found rather than passed: it is a sibling in the client scene
## and the driver has no reference to it, deliberately — the driver does not know
## reconciliation exists.
static func attach(to: Node, driver: LocalPawnDriver) -> Node:
	var readout: CanvasLayer = (load("res://scripts/debug/net_readout.gd") as GDScript).new()
	readout.name = "NetReadout"
	readout._driver = driver
	to.add_child(readout)
	return readout


func _ready() -> void:
	layer = 128
	_label = Label.new()
	_label.position = Vector2(16.0, 220.0)
	_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_label.add_theme_font_size_override("font_size", 13)
	add_child(_label)
	_reconciler = _find_reconciler(get_tree().get_root())
	if _reconciler != null:
		_reconciler.connect("corrected", Callable(self, "_on_corrected"))
	if _driver != null:
		_driver.command_sampled.connect(_on_command)


## **EVERY COMPARISON, NOT ONLY THE ONES THAT SNAPPED.** `replays` counts
## corrections that exceeded `TUN-NET-RECONCILE-THRESHOLD`; anything under it is
## absorbed silently and left in place. So a client sitting a persistent 9 cm from
## the server — which is most of the threshold, and plenty to feel once it finally
## tips over — reported as "3 replays" and looked healthy. The typical error is the
## number that says whether the two peers actually agree.
func _on_corrected(error: float, replayed: bool) -> void:
	_errors.append(error)
	while _errors.size() > ERROR_WINDOW:
		_errors.remove_at(0)
	if not replayed:
		return
	var at := _reconciler.get("last_error_vector") as Vector3
	var yaw: float = _driver.ctx.yaw if _driver != null else 0.0
	_corrections.append([at, yaw])
	if at.length() > (_worst[0] as Vector3).length():
		_worst = [at, yaw]
	while _corrections.size() > HISTORY:
		_corrections.remove_at(0)


func _on_command(command: InputCommand) -> void:
	_seq = command.seq
	_move = command.move
	_recent.append(command.move.length() > 0.01)
	while _recent.size() > INPUT_WINDOW:
		_recent.remove_at(0)


## **POLLED, NOT SIGNALLED.** `Reconciler` emits `corrected` only when it compares;
## the counters below must keep reading true between comparisons, and a readout
## that froze on a quiet connection would look exactly like one on a broken one.
func _process(_delta: float) -> void:
	if _label == null:
		return
	_label.text = "\n".join(_lines())


func _lines() -> Array[String]:
	var out: Array[String] = []
	out.append("NET  (debug build only)")
	out.append("  rtt %d ms   unacked %d   sent #%d" % [_rtt(), _unacked(), _seq])
	out.append("  move (%+.2f,%+.2f)   %s" % [_move.x, _move.y, _driving()])
	out.append("  error   %s" % _error_line())
	out.append("  replays %d   worst %s" % [_replays(), _framed(_worst)])
	out.append("  last    %s" % _framed(_latest()))
	out.append("  bias    %s   over %d" % [_framed(_bias()), _corrections.size()])
	out.append("  ground  %s" % _ground_line())
	out.append("  wire    %d refused   %d held" % [_refused(), _held()])
	return out


## **THE TYPICAL DISAGREEMENT, WHICH IS THE NUMBER THAT WAS MISSING.** Under
## `TUN-NET-RECONCILE-THRESHOLD` nothing snaps and nothing was counted, so a client
## sitting persistently just inside the threshold looked identical to one in
## perfect agreement. p95 is the honest summary; a mean hides the spikes that are
## the whole complaint.
func _error_line() -> String:
	if _errors.is_empty():
		return "-"
	var sorted := Array(_errors)
	sorted.sort()
	var total := 0.0
	for value: float in sorted:
		total += float(value)
	return (
		"mean %.3f  p95 %.3f  max %.3f m over %d (snap at %.2f)"
		% [
			total / float(sorted.size()),
			float(sorted[int(float(sorted.size()) * 0.95)]),
			float(sorted[-1]),
			sorted.size(),
			Tuning.net.reconcile_threshold
		]
	)


## Whether client and server agreed about standing on something, last compare.
func _ground_line() -> String:
	if _reconciler == null:
		return "-"
	var server := bool(_reconciler.get("last_server_grounded"))
	var client := bool(_reconciler.get("last_client_grounded"))
	var verdict := "agree" if server == client else "DISAGREE"
	return "server %s   client %s   %s" % [server, client, verdict]


func _replays() -> int:
	return int(_reconciler.get("replays")) if _reconciler != null else 0


func _latest() -> Array:
	return _corrections[-1] if not _corrections.is_empty() else [Vector3.ZERO, 0.0]


## **WAS ANYBODY DRIVING?** `move` alone is the value on the frame the reader
## happens to look at, and a screenshot of `(0.00, 0.00)` beside a dozen
## corrections reads as a pawn being shoved with nobody at the controls. It cost
## exactly that misreading once: the corrections were the owner's own input, taken
## from a frame between keystrokes.
func _driving() -> String:
	if _recent.is_empty():
		return "no input yet"
	var moving := 0
	for active: bool in _recent:
		if active:
			moving += 1
	if moving == 0:
		return "STILL for the last %d commands" % _recent.size()
	return "driving: %d of the last %d commands moved" % [moving, _recent.size()]


## **THE CORRECTION IN THE WORDS A PLAYER USES.** Decomposed onto the pawn's own
## heading, because "0.04 m at (0.03, 0, -0.02)" and "BACK 0.03 RIGHT 0.02" are the
## same fact and only one of them can be reported from the controls.
## **DECOMPOSED WITH THE YAW IT HAPPENED AT, NOT THE ONE YOU FACE NOW.** Using the
## current heading made a stored correction change direction whenever the player
## turned: the first version printed `worst BACK/LEFT` and `last FWD/RIGHT` for one
## vector seen from two headings, which reads as an oscillation that is not there.
func _framed(entry: Array) -> String:
	var error := entry[0] as Vector3
	if error.length() < 0.0005:
		return "-"
	var yaw := float(entry[1])
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(forward.z, 0.0, -forward.x)
	var along := error.dot(forward)
	var across := error.dot(right)
	# **AND THE VERTICAL, WHICH THE FIRST VERSION SILENTLY DROPPED.** Printing only
	# FWD/BACK and LEFT/RIGHT meant a correction of 0.163 m displayed as
	# "BACK 0.053 LEFT 0.053" — components that account for 0.075 of it. The other
	# 0.145 was Y, invisible, and by far the largest part of the disagreement.
	return (
		"%.3f m  %s %.3f  %s %.3f  %s %.3f"
		% [
			error.length(),
			"FWD " if along >= 0.0 else "BACK",
			absf(along),
			"RIGHT" if across >= 0.0 else "LEFT ",
			absf(across),
			"UP  " if error.y >= 0.0 else "DOWN",
			absf(error.y)
		]
	)


## **AVERAGED IN THE PLAYER'S FRAME, NOT THE WORLD'S.** Two corrections that both
## pulled the player backwards cancel in world space when they were walking in
## opposite directions — the common case — and would report "no bias" for the most
## systematic fault there is. The result is already in the pawn frame, so it is
## printed with a yaw of zero.
func _bias() -> Array:
	if _corrections.is_empty():
		return [Vector3.ZERO, 0.0]
	var along := 0.0
	var across := 0.0
	for entry: Array in _corrections:
		var error := entry[0] as Vector3
		var yaw := float(entry[1])
		var forward := Vector3(sin(yaw), 0.0, cos(yaw))
		along += error.dot(forward)
		across += error.dot(Vector3(forward.z, 0.0, -forward.x))
	var n := float(_corrections.size())
	return [Vector3(across / n, 0.0, along / n), 0.0]


## **KEYED ON THE SERVER, BECAUSE THAT IS WHERE `PingClock` FILES IT.** The client
## records its own pongs under `MultiplayerPeer.TARGET_PEER_SERVER`; asking for any
## other peer returns 0 and would read as a dead connection.
func _rtt() -> int:
	return int(round(Net.rtt_ms(MultiplayerPeer.TARGET_PEER_SERVER)))


func _unacked() -> int:
	if _driver == null or _driver.history == null:
		return 0
	return _driver.history.unacked().size()


func _refused() -> int:
	return int(Net.assembler.unappliable)


func _held() -> int:
	return int(Net.assembler.crowd_size())


func _find_reconciler(node: Node) -> Node:
	if node.get_script() != null and node.get_script().resource_path.ends_with("reconciler.gd"):
		return node
	for child: Node in node.get_children():
		var hit := _find_reconciler(child)
		if hit != null:
			return hit
	return null

## **THE HUD, AS PICTURES.** UI_UX_SPEC §9, US-0072, US-0073.
##
## No suite in this repository has a window, and **every visual defect this project
## has ever had was found by somebody looking at the running game** — the inverted
## camera pitch, the district that rendered near-black, the swapped A and D, the
## shoulder offset that changed nothing. Five widgets now exist that nobody has
## seen.
##
## **A LIVE FRAME IS THE WRONG PICTURE.** In a real match most of the HUD is dark
## most of the time: the crosshair ring appears for the second before a kill, the
## vignette only at Exposed, the source list only while something contributes. A
## screenshot of a live client mostly shows what the HUD looks like when there is
## nothing to say. So this drives the bus through the states instead, and captures
## each one.
##
## **IT BOOTS THE REAL `client_root.tscn`**, so the scene wiring is under test too
## — a HUD that works when a tool builds it and not when the scene does is trap
## 4's shape, and it has bitten this project twice.
##
## Run it **windowed**. `--headless` renders nothing and would write six blank
## files, which is trap 13: a probe that cannot see reports the same as a quiet
## machine.
##
##     godot --path . res://tools/hud_probe.tscn
##
## Writes `user://hud_*.png` and prints each path with what it should show.
extends Node

const CLIENT := "res://scenes/client_root.tscn"

## Frames to settle between states. The vignette fades over
## `TUN-UI-DAMAGE-VIGNETTE-TIME`, so a capture taken on the next frame would show
## it part-way up and read as a rendering fault rather than as a design.
const SETTLE := 90

var _root: Node = null
var _hud: Node = null
var _shots: PackedStringArray = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("REFUSING: headless renders nothing, and six blank PNGs read like a broken HUD.")
		get_tree().quit(1)
		return
	_run()


func _run() -> void:
	# **`add_child` FROM `_ready` FAILS: the parent is still setting up children.**
	# It errors to the log and returns, and the first version of this tool then went
	# on to write six PNGs of an empty root — output that looks exactly like output.
	_root = (load(CLIENT) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_root)
	for _i: int in 30:
		await get_tree().process_frame
		if _root.is_inside_tree():
			break

	# **THE VACUOUS-SUCCESS GUARD, AND A PROBE NEEDS ONE AS MUCH AS A TEST DOES.**
	# A blank capture reads as a broken HUD, and a HUD with no widgets in it reads
	# as a blank capture. Refusing is the only honest answer to either.
	_hud = _root.get_node_or_null("Hud")
	if _hud == null or _hud.get_child_count() == 0:
		print("REFUSING: the HUD has no widgets in it, so every capture would be of nothing.")
		print("  client_root in tree: ", _root.is_inside_tree(), "   Hud node: ", _hud)
		get_tree().quit(1)
		return
	print("HUD widgets in the scene: ", _names(_hud))

	await _capture_every_state()
	await _capture_the_chase()
	await _capture_the_score_feed()
	_report()
	get_tree().quit()


## What was written, and what to look for in it. **Split out for the length guard**
## — trap 11, and the seam is honest: above is *capture*, here is *tell somebody*.
func _report() -> void:
	print("")
	print("wrote %d frames:" % _shots.size())
	for line: String in _shots:
		print("  ", line)
	print("")
	print("LOOK FOR: is the cone soft-edged rather than a needle? Does the pulse read as a")
	print("BEAT rather than a throb? Can you tell the tier without reading the word? Is the")
	print("centre of the screen empty apart from the dot? And do 09, 10 and 11 read as ONE")
	print("arc opening rather than three unrelated shapes?")
	print("AND IN 15-17: are the two chase arcs TELLABLE APART without reading the colour —")
	print("different radius, opposite directions — and do they stay clear of the lock arc?")
	print("Is each bar's FRACTION judgeable against its track, or only its gap visible?")


## One scripted state: set it, let it settle, capture it.
## **`settle` IS OVERRIDABLE FOR ONE REASON: A TRANSIENT CANNOT BE CAUGHT AT
## 1.5 s.** Ninety frames is right for a state — it makes a capture reproducible —
## and it is exactly wrong for the chase pulse, which lasts `ChaseVm.FLASH_SECONDS`
## 0.45 s and would have decayed to nothing by then. Capturing it at the default
## and captioning it as a pulse would be an instrument wrong in a plausible
## direction, which is worse than no instrument.
func _state(id: String, expect: String, setup: Callable, settle: int = SETTLE) -> void:
	setup.call()
	for _i: int in settle:
		await get_tree().process_frame
	var path := "user://hud_%s.png" % id
	get_tree().root.get_texture().get_image().save_png(path)
	_shots.append("%s — %s" % [ProjectSettings.globalize_path(path), expect])


## **EMITTED ON THE BUS, NOT WRITTEN INTO THE WIDGETS.** This drives exactly the
## path a snapshot drives, so a widget that only works when a tool pokes its
## fields would fail here.
func _bus(tier: int, sources: int, bucket: int, lock: float, kill: bool, stun: bool) -> void:
	EventBus.suspicion_tier_changed.emit(tier, sources)
	EventBus.compass_updated.emit(0.6, bucket, lock)
	EventBus.kill_ready_changed.emit(kill, stun)


func _names(hud: Node) -> String:
	var out: PackedStringArray = []
	for child: Node in hud.get_children():
		out.append(child.name)
	return ", ".join(out)


## The scripted states, in the order a player meets them: quiet, hunting,
## noticed, exposed, stunnable, identified — then two diagnostics that isolate
## the cone. **Split out of `_run` for the length guard**, and the seam is real:
## above is *stand the client up*, here is *what to show*.
func _capture_every_state() -> void:
	await _state(
		"01_quiet",
		"Anonymous, no contract. Open circle, no source line, bare crosshair dot, dark plate.",
		func() -> void:
			_bus(SuspicionMath.Tier.ANONYMOUS, SuspicionSources.NONE, 255, 0.0, false, false)
	)
	await _state(
		"02_hunting",
		"Anonymous, contract at ~12 m, lock half filled. Cone up-left, ring pulsing, arc at 180deg.",
		func() -> void:
			_bus(SuspicionMath.Tier.ANONYMOUS, SuspicionSources.NONE, 24, 0.5, false, false)
	)
	await _state(
		"03_noticed",
		"Noticed + sprinting/alone. Half-disc, amber, two words under it. No vignette.",
		func() -> void:
			_bus(
				SuspicionMath.Tier.NOTICED,
				SuspicionSources.SPRINT | SuspicionSources.OPEN,
				12,
				0.85,
				false,
				false
			)
	)
	await _capture_the_loud_states()


## Exposed, stunnable, identified. **Split from the calm three for the length
## guard**, and they do read as a pair: these are the states a player is *in
## trouble* in, and they are the ones where the HUD has the most to say at once.
func _capture_the_loud_states() -> void:
	await _state(
		"04_exposed_kill",
		"Exposed + vignette at full + kill ring. Filled triangle, red, screen edges dark.",
		func() -> void:
			_bus(
				SuspicionMath.Tier.EXPOSED,
				SuspicionSources.RUN | SuspicionSources.ROOF,
				5,
				1.0,
				true,
				false
			)
	)
	await _state(
		"05_stun_available",
		"Stun brackets instead of the ring — a DIFFERENT SHAPE, not a different colour.",
		func() -> void: _bus(SuspicionMath.Tier.EXPOSED, SuspicionSources.RUN, 6, 1.0, false, true)
	)
	await _capture_cone_diagnostics()
	await _state(
		"06_portrait_revealed",
		"Portrait no longer says Unknown. It shows THAT you know, not WHO — ASM-0030.",
		func() -> void: EventBus.contract_portrait_revealed.emit(&"")
	)


## **THE TWO THAT ISOLATE THE CONE.** Everything above shows the HUD as a player
## meets it; these answer one question with a yes or a no, which the busy frames
## cannot — the first version of this probe read a cone pointing *down* off a
## crowded capture and called the widget inverted. It was the camera's yaw.
func _capture_cone_diagnostics() -> void:
	# **A CONE ALONE, POINTING STRAIGHT AHEAD.** No lock arc to be mistaken for it,
	# and a bearing of exactly zero, so "is it drawn where it is aimed" has a
	# yes-or-no answer instead of an argument about which blob is which.
	#
	# **THE CAMERA IS UNHOOKED FIRST, AND THE FIRST VERSION OF THIS PROBE WAS WRONG
	# WITHOUT IT.** The cone is *camera-relative*, so a world bearing of zero points
	# straight up only when the camera's yaw is also zero — and the client scene's
	# rig is not. It drew the cone pointing **down** and read exactly like a widget
	# inverted by pi. The widget was right; the expectation was not.
	_hud.camera = null
	_hud.compass_vm.camera_yaw = 0.0
	await _state(
		"07_cone_straight_ahead",
		"Bearing 0: the cone MUST point straight UP from the centre dot. No lock arc.",
		func() -> void:
			EventBus.suspicion_tier_changed.emit(
				SuspicionMath.Tier.ANONYMOUS, SuspicionSources.NONE
			)
			EventBus.compass_updated.emit(0.0, 20, 0.0)
			EventBus.kill_ready_changed.emit(false, false)
	)
	# **A CONTRACT ON THE PLAYER'S RIGHT IS BEARING MINUS 90, NOT PLUS.** This game's
	# yaw increases toward a turn to the LEFT, so +Z rotated by +90 degrees is +X,
	# which is the player's left shoulder. Getting this label the wrong way round
	# would turn the one diagnostic that catches a mirrored cone into one that
	# demands the mirror.
	await _state(
		"08_cone_quarter_right",
		"A contract on the player's RIGHT: the cone MUST point RIGHT. Left means a mirror.",
		func() -> void: EventBus.compass_updated.emit(-PI * 0.5, 20, 0.0)
	)
	await _capture_the_arc_widening()


## **THE SECOND PROXIMITY CHANNEL, WHICH A SINGLE FRAME CANNOT SHOW AT ALL.** The
## arc covers a constant patch of ground, so it widens as the contract closes and
## becomes a whole ring at `CompassMath.full_ring_distance`. Three frames at one
## bearing is the only way to see that it is a *sequence* rather than three
## unrelated shapes.
func _capture_the_arc_widening() -> void:
	var frames: Array = [
		["09_wide_far", 110, "55 m: 15 deg. The NARROWEST the arc ever gets, and clearly aimed."],
		["10_wide_near", 60, "30 m: 66 deg. Four times as wide, and still pointing."],
		["11_wide_ring", 40, "20 m: a COMPLETE RING, evenly lit. It has stopped saying which way."],
	]
	for frame: Array in frames:
		await _state(
			str(frame[0]),
			str(frame[2]),
			func() -> void: EventBus.compass_updated.emit(0.0, int(frame[1]), 0.0)
		)


## **THE FEED, WHICH IS THE ONE ELEMENT A STILL FRAME UNDERSTATES.** Its whole
## design is a sequence — four bonuses `TUN-UI-SCOREFEED-STAGGER` apart — so two
## frames of one kill are the minimum that shows the stack building rather than
## arriving. The penalty frame is separate because §5.2's requirement is that the
## **THE PURSUIT BARS** (US-0097). The third frame is the one worth looking at:
## a Hamiltonian cycle makes every player a hunter and a prey simultaneously, so
## both arcs live at once is the ordinary case rather than the corner case — and it
## is the case a single `pursuit_fraction:u8` could not have carried.
##
## **THEY ARE CAPTURED BEFORE THE SCORE FEED ON PURPOSE.** A feed line lives four
## seconds and the settle is a handful of frames, so running these afterwards would
## put a stack of bonuses in every chase frame.
func _capture_the_chase() -> void:
	await _state(
		"15_chase_hunting",
		"ONE arc, the OUTER one, about half round, winding CLOCKWISE from the top.",
		func() -> void: EventBus.pursuit_changed.emit(0.5, 0.0)
	)
	await _state(
		"16_chase_hunted",
		"ONE arc, the INNER one, nearly full, winding ANTICLOCKWISE.",
		func() -> void: EventBus.pursuit_changed.emit(0.0, 0.95)
	)
	# Captured mid-pulse, twelve frames after the rise, because the pulse is gone
	# long before the default settle. It is the moment a prey is re-acquired.
	await _state(
		"16b_chase_reacquired",
		"The SAME inner arc, visibly THICKER: the pulse on being seen again.",
		func() -> void: EventBus.pursuit_changed.emit(0.0, 0.3),
		1
	)
	await _state(
		"16c_chase_pulse",
		"Thicker still — full bar, freshly re-acquired. Compare against 16.",
		func() -> void: EventBus.pursuit_changed.emit(0.0, 1.0),
		12
	)
	await _state(
		"17_chase_both",
		"BOTH arcs, at different lengths, clear of each other and of the lock arc.",
		func() -> void: EventBus.pursuit_changed.emit(0.85, 0.3)
	)
	# **CLEARED, OR EVERY FRAME AFTER THIS ONE HAS A CHASE IN IT.** The bus holds
	# the last value it carried, so leaving 17's state up would put two arcs behind
	# the score-feed captures and read as though the feed had grown a ring.
	EventBus.pursuit_changed.emit(0.0, 0.0)


## one negative event does **not** read as a smaller positive one, which is a
## comparison and needs both on screen at once.
func _capture_the_score_feed() -> void:
	await _state(
		"12_feed_building",
		"ONE line so far: +100 Contract. The stack has not arrived yet.",
		func() -> void: _kill_awards()
	)
	await _state(
		"13_feed_full",
		"FOUR lines, right side above centre. Values in a straight column, names under them.",
		func() -> void: pass
	)
	await _state(
		"14_feed_penalty",
		"A WARM plate on the negative line against neutral ones. Not a smaller positive.",
		func() -> void: _penalty_awards()
	)


## One patient kill's worth of bonuses, on the bus, in one group.
func _kill_awards() -> void:
	var awards: Array = [
		[Ids.SCORE_CONTRACT, 100],
		[Ids.SCORE_SILENT, 200],
		[Ids.SCORE_PATIENT, 100],
		[Ids.SCORE_BLENDED, 200],
	]
	for award: Array in awards:
		EventBus.score_event_appended.emit(
			ScoreReport.new(award[0] as StringName, int(award[1]), 7)
		)


## A zero-point marker beside a penalty. `SCORE-RECKLESS` pays **zero** since
## ADR-0013 and must not wear the penalty treatment; the negative one must.
##
## **THE NEGATIVE LINE IS HYPOTHETICAL AND SAYING SO MATTERS.** No shipped bonus
## pays below zero — ADR-0013 neutralised the only one that did — so §5.2's penalty
## treatment is built and has no producer, and this frame is the only place it can
## be looked at. `SCORE-DEATH` is used because it is the kind a penalty would most
## plausibly attach to; the courier withholds it, so this shape cannot reach a
## player today.
func _penalty_awards() -> void:
	EventBus.score_event_appended.emit(ScoreReport.new(Ids.SCORE_RECKLESS, 0, 8))
	EventBus.score_event_appended.emit(ScoreReport.new(Ids.SCORE_DEATH, -50, 8))

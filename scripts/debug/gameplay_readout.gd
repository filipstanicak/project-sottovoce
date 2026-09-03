## **WHAT THE DEBUG OVERLAY KNOWS ABOUT THE GAME RATHER THAN ABOUT THE WIRE.**
## Split out of `net_readout.gd` on 2026-09-03. DEBUG ONLY.
##
## That file is called `net_readout` and had grown to print the Compass range, both
## ability cooldowns, the last refusal, the last kill and the cinder cloud — **none
## of which is the wire** — and it passed 400 lines saying so. The seam is the
## name: everything here is a fact about the match, and nothing here knows what an
## ack or a reconciliation is.
##
## **IT EXISTS FOR JUDGEMENTS ONLY A PERSON CAN MAKE.** Every line was added
## because a report from the controls could not be priced without it: the Compass
## ring radius was guessed twice off screenshots, the Lunge was reported broken
## three times, and `TUN-CINDERFALL-DURATION` is being judged now.
##
## **STRIPPED FROM RELEASE**: `scripts/debug/` is excluded from all three presets,
## so a player is never told a cooldown or how long their own cover has. Literals
## are allowed here for the reason `net_readout.gd` gives.
class_name GameplayReadout
extends RefCounted

var _bucket: int = CompassBoard.NO_CONTRACT

## The drawn cloud, asked rather than mirrored — see `CinderfallView.seconds_left`.

var _cinderfall: CinderfallView = null

## Remaining cooldown ticks per ability slot, `EVT-ABILITY-COOLDOWN-CHANGED`.

var _cooldowns: Array[int] = [0, 0]

## `[reason, msec, slot]` of the last refusal, `EVT-ABILITY-DENIED`.

var _denial: Array = [0, 0.0, 0]

## `[killer_slot, victim_slot, msec]` of the last kill this player was part of.

var _kill: Array = [0, 0, 0.0]

## Built by `LocalPawnDriver`, like `feel_readout.gd`, for the export reason above.
## The reconciler is found rather than passed: it is a sibling in the client scene
## and the driver has no reference to it, deliberately — the driver does not know
## reconciliation exists.


## Subscribe, and find the drawn cloud in the client scene.
func attach(root: Node) -> void:
	EventBus.compass_updated.connect(_on_compass)
	EventBus.ability_cooldown_changed.connect(_on_cooldown)
	EventBus.ability_denied.connect(_on_denied)
	EventBus.kill_resolved.connect(_on_kill)
	_cinderfall = _find_by_script(root, "cinderfall_view.gd") as CinderfallView


func lines() -> Array[String]:
	var out: Array[String] = []
	out.append("  compass %s" % _compass_line())
	out.append("  ability %s" % _ability_line())
	out.append("  combat  %s" % _combat_line())
	out.append("  cinder  %s" % _cinder_line())
	return out


## **THE ONE NUMBER NOBODY CAN JUDGE WITHOUT SEEING IT.**
## `TUN-CINDERFALL-DURATION` is 4.0 s and the cloud is centred on the caster since
## 2026-09-03, so a cast costs four seconds of not being able to read the street —
## and "that felt like eight" and "that was too dense" are different findings that
## look identical from inside the smoke.
func _cinder_line() -> String:
	if _cinderfall == null:
		return "no view in this scene"
	if _cinderfall.pending_count() > 0:
		return "pot in the air"
	if _cinderfall.live_count() == 0:
		return "-"
	return (
		"up, %.1f s of %.1f left   %d cloud(s)"
		% [
			_cinderfall.seconds_left(),
			Tuning.ability_data(Ids.ABIL_CINDERFALL).duration,
			_cinderfall.live_count()
		]
	)


## **THE RANGE TO THE CONTRACT, IN THE BUCKET THE SERVER SENT.** Debug only, and
## `scripts/debug/` is excluded from all three release presets — a player is told
## *nearer*, never *how far* (GDD-03 §8.5), and the Compass widget draws no text at
## all so it cannot leak one.
##
## **IT EXISTS BECAUSE `TUN-COMPASS-CONE-FULL-RADIUS` WAS SET TWICE FROM A GUESS.**
## Both times the judgement was "I have to stand right next to them", and both
## times the only way to price it was to estimate the distance off a screenshot —
## once from apparent capsule height, to ±2.5 m. This turns the next judgement into
## a reading. It prints the bucket, the arc it produces, and how far the ring still
## is, so a report can say *the ring should close here* and mean a number.


func _compass_line() -> String:
	if _bucket == CompassBoard.NO_CONTRACT:
		return "no contract"
	var metres := Quantise.bucket_to_distance(_bucket)
	var half := CompassMath.cone_halfwidth_for(metres, Tuning.compass)
	var closes := CompassMath.full_ring_distance(Tuning.compass)
	var state := "FULL RING" if half >= 179.9 else "%.0f m to full" % (metres - closes)
	return "%.1f m   arc %.0f deg   %s" % [metres, half * 2.0, state]


## **THE THREE QUESTIONS SOMEBODY PRESSING A KEY THAT SEEMS TO DO NOTHING HAS**:
## did the press reach the server, was it refused and why, and did anything
## resolve. All three were answerable only by reading a server log.
##
## **`remaining` IS WHAT IT SAYS, DESPITE THE WIRE FIELD BEING CALLED
## `cooldown_a_tick`.** `AbilitySystem.cooldown_ticks` returns `ready_at - now`
## clamped at zero, so this is a countdown and not a deadline — checked rather than
## inferred from the name, because dividing a deadline by the tick rate would have
## printed a plausible and completely wrong number.


func _on_cooldown(slot: int, remaining: int) -> void:
	if slot >= 0 and slot < _cooldowns.size():
		_cooldowns[slot] = remaining


func _on_denied(slot: int, reason: int) -> void:
	_denial = [reason, float(Time.get_ticks_msec()), slot]


func _on_kill(killer_slot: int, victim_slot: int) -> void:
	_kill = [killer_slot, victim_slot, float(Time.get_ticks_msec())]


## **THE KEY, READ FROM `InputMap` RATHER THAN WRITTEN AS "Q".** A label that goes
## stale the first time somebody rebinds is a label that lies, and `INPUT-ABILITY-*`
## are both rebindable.


func _key_for(slot: int) -> String:
	var id: StringName = Ids.INPUT_ABILITY_1 if slot == 0 else Ids.INPUT_ABILITY_2
	for event: InputEvent in InputMap.action_get_events(InputActions.action_name(id)):
		if event is InputEventKey:
			return OS.get_keycode_string((event as InputEventKey).physical_keycode)
	return "slot%d" % slot


func _ability_line() -> String:
	var parts: PackedStringArray = []
	for slot: int in _cooldowns.size():
		var left := float(_cooldowns[slot]) / maxf(Tuning.net.server_tick, 1.0)
		var state := "ready" if _cooldowns[slot] <= 0 else "%.1fs" % left
		parts.append("%s %s" % [_key_for(slot), state])
	if int(_denial[0]) > 0:
		parts.append(
			"denied %s %s" % [AbilityDenial.Why.keys()[int(_denial[0])], _ago(float(_denial[1]))]
		)
	return "   ".join(parts)


## **A KILL YOU WERE PART OF, WHICHEVER END.** `EVT-KILL-RESOLVED` reaches the two
## players involved and nobody else, so this line is silent for a match somebody
## else is deciding — which is the design, not a gap in the instrument.


func _combat_line() -> String:
	if float(_kill[2]) <= 0.0:
		return "no kill resolved yet"
	return "slot %d killed slot %d   %s" % [int(_kill[0]), int(_kill[1]), _ago(float(_kill[2]))]


func _ago(msec: float) -> String:
	return "%.1fs ago" % ((float(Time.get_ticks_msec()) - msec) / 1000.0)


func _on_compass(_bearing: float, bucket: int, _lock: float) -> void:
	_bucket = bucket


## **THE TYPICAL DISAGREEMENT, WHICH IS THE NUMBER THAT WAS MISSING.** Under
## `TUN-NET-RECONCILE-THRESHOLD` nothing snaps and nothing was counted, so a client
## sitting persistently just inside the threshold looked identical to one in
## perfect agreement. p95 is the honest summary; a mean hides the spikes that are
## the whole complaint.


## The same walk as `_find_reconciler`, by script filename. **A debug overlay finds
## its subjects rather than being handed them**, because `LocalPawnDriver` builds
## this and knows about neither.
func _find_by_script(node: Node, filename: String) -> Node:
	var script := node.get_script() as GDScript
	if script != null and script.resource_path.ends_with(filename):
		return node
	for child: Node in node.get_children():
		var found := _find_by_script(child, filename)
		if found != null:
			return found
	return null

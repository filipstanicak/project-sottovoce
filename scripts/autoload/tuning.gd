## Global access to every gameplay value (ADR-0005).
##
## The ONLY autoload a pawn state may touch, because prediction replay must be
## deterministic and reaching for anything else would make it not so.
##
## Lives in scripts/autoload/ rather than scripts/core/ because an autoload MUST
## extend Node, and Core's contract is that it never does. The TuningProfile
## RESOURCES stay in scripts/core/tuning/ — pure data, and they belong there.
## This split was forced by test_core_is_pure.gd catching the contradiction on
## its first run.
extends Node

## Emitted after a hot reload or a server profile sync. Anything holding a
## DERIVED tuning value must listen, or it silently keeps the old one. That is
## the classic hot-reload bug and a Definition of Done checklist item.
signal reloaded

# preload rather than the `TuningIndex` global class: an autoload compiles before
# Godot has finished registering script classes, so a class_name reference here
# resolves inconsistently on a cold import.
const Index := preload("res://scripts/core/tuning/tuning_index.gd")

const DEFAULT_PROFILE := "res://data/tuning/default/profile.tres"

## Debug-only override, gitignored. A playtester's local experiment must never
## reach a build or a teammate's machine.
const LOCAL_PROFILE := "res://data/tuning/local/profile.tres"

var profile: TuningProfile

# One property per sub-resource, so call sites read `Tuning.movement.sprint`
# rather than `Tuning.profile.movement.sprint`.
var movement: MovementTuning
var suspicion: SuspicionTuning
var compass: CompassTuning
var combat: CombatTuning
var contract: ContractTuning
var crowd: CrowdTuning
var match_rules: MatchTuning
var scoring: ScoringTuning
var camera: CameraTuning
var net: NetTuning
var perf: PerfTuning
var ui_audio: UiAudioTuning
var ability: AbilityTuning
var flags: FeatureFlags

var _ticks: Dictionary = {}
var _step_ticks: Dictionary = {}


func _ready() -> void:
	var path := DEFAULT_PROFILE
	if _hot_reload_available() and ResourceLoader.exists(LOCAL_PROFILE):
		path = LOCAL_PROFILE
		Log.warn("Tuning: using LOCAL override %s" % LOCAL_PROFILE)
	if not _install(load(path) as TuningProfile):
		Log.error("Tuning: default profile is invalid — the build is not playable")
		return
	Log.info("Tuning: %d values, hash %d" % [Index.FIELD.size(), profile.compute_hash()])


## Precomputed integer server ticks for a duration tunable.
##
## SYSTEMS COMPARE INTEGERS, NEVER ACCUMULATED FLOATS. A cooldown counted by
## adding delta drifts differently on every machine, and a server-authoritative
## outcome that depends on accumulated float error is a desync waiting for a
## slow frame. Returns 0 for a non-duration or an unknown ID.
func ticks(id: StringName) -> int:
	return int(_ticks.get(id, 0))


## Precomputed integer ticks of `PawnState.step()`, which runs at
## `TUN-NET-CLIENT-INPUT-RATE` 60 Hz — NOT at the 30 Hz net tick.
##
## **THERE ARE TWO TICK DOMAINS AND MIXING THEM HALVES A DURATION.** TDD-03 §1.1:
## every gameplay *decision* happens at 30 Hz, but pawn *integration* substeps at
## 60 Hz, once per received `InputCommand`. So a counter incremented inside
## `step()` — `ctx.state_timer_ticks`, the action buffers — advances twice as
## fast as `ticks()` assumes, and comparing the two makes every window expire at
## half its tuned length.
##
## It did exactly that, silently, from US-0013 until US-0016 found it: the stun
## freeze ran 1.0 s instead of 2.0, the kill animation 0.7 s instead of 1.4, and
## Jog escalated to Run in 0.18 s instead of 0.35. Nothing failed, because both
## numbers are plausible integers.
##
## **If a counter is incremented in `step()`, compare it against this.** If it is
## incremented once per net tick, compare it against `ticks()`.
func step_ticks(id: StringName) -> int:
	return int(_step_ticks.get(id, 0))


## True when `id` is a duration and therefore has a tick count.
func has_ticks(id: StringName) -> bool:
	return _ticks.has(id)


## Re-read from disk, re-validate, recompute ticks, announce.
##
## Returns false and KEEPS THE PREVIOUS PROFILE if the new one fails validation.
## A half-applied tuning change is worse than none: it produces a game that
## matches no document, and the playtest that follows measures nothing.
func reload() -> bool:
	if not _hot_reload_available():
		Log.warn("Tuning: hot reload is debug-only and was ignored")
		return false
	var path := LOCAL_PROFILE if ResourceLoader.exists(LOCAL_PROFILE) else DEFAULT_PROFILE
	var candidate: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return _install(candidate as TuningProfile)


## Apply a profile sent by the server, so a playtest never runs on mixed values.
func adopt(incoming: TuningProfile) -> bool:
	return _install(incoming)


## Debug builds only. In a release export this returns false and `reload()`
## refuses, so a shipped client cannot be re-tuned by dropping a file beside it.
func _hot_reload_available() -> bool:
	return OS.is_debug_build()


func _install(candidate: TuningProfile) -> bool:
	if candidate == null:
		Log.error("Tuning: profile failed to load — keeping previous")
		return false
	var errors: Array[String] = candidate.validate()
	if not errors.is_empty():
		Log.error("Tuning: REJECTED, %d invariant failure(s) — keeping previous" % errors.size())
		for e: String in errors:
			Log.error("  " + e)
		return false
	profile = candidate
	_bind_sections()
	_recompute_ticks()
	reloaded.emit()
	return true


func _bind_sections() -> void:
	movement = profile.movement
	suspicion = profile.suspicion
	compass = profile.compass
	combat = profile.combat
	contract = profile.contract
	crowd = profile.crowd
	match_rules = profile.match_rules
	scoring = profile.scoring
	camera = profile.camera
	net = profile.net
	perf = profile.perf
	ui_audio = profile.ui_audio
	ability = profile.ability
	flags = profile.flags


func _recompute_ticks() -> void:
	_ticks.clear()
	_step_ticks.clear()
	for id: StringName in Index.FIELD:
		var entry: Array = Index.FIELD[id]
		var unit: String = entry[2]
		if not Index.DURATION_UNITS.has(unit):
			continue
		var holder: Variant = _resolve_holder(entry[0])
		if holder == null:
			continue
		var seconds := float(holder.get(StringName(entry[1])))
		if unit == "ms":
			seconds /= 1000.0
		_ticks[id] = int(round(seconds * net.server_tick))
		# The second domain. See step_ticks(): a counter advanced once per
		# PawnState.step() runs at the input rate, not the net tick.
		_step_ticks[id] = int(round(seconds * net.client_input_rate))


func _resolve_holder(name: String) -> Variant:
	if name.begins_with("ABIL-"):
		return profile.abilities.get(StringName(name))
	return get(StringName(name))

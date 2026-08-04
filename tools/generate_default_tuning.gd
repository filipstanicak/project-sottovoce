## Writes data/tuning/default/*.tres from the class defaults.
##
##     godot --headless -s res://tools/generate_default_tuning.gd
##
## The defaults live in the resource classes, which are themselves generated from
## TUNABLES.md — so this makes the .tres files a THIRD copy of the same numbers.
## That is deliberate: Godot must be able to load a profile without executing
## GDScript defaults, and a hand-written .tres is a transcription of 260-odd numbers
## with no check on it. Generating them means the only way to change a shipped
## value is to change TUNABLES.md.
extends SceneTree

const OUT_DIR := "res://data/tuning/default"

const SECTIONS := {
	"movement": "res://scripts/core/tuning/movement_tuning.gd",
	"suspicion": "res://scripts/core/tuning/suspicion_tuning.gd",
	"compass": "res://scripts/core/tuning/compass_tuning.gd",
	"combat": "res://scripts/core/tuning/combat_tuning.gd",
	"contract": "res://scripts/core/tuning/contract_tuning.gd",
	"crowd": "res://scripts/core/tuning/crowd_tuning.gd",
	"match": "res://scripts/core/tuning/match_tuning.gd",
	"scoring": "res://scripts/core/tuning/scoring_tuning.gd",
	"camera": "res://scripts/core/tuning/camera_tuning.gd",
	"net": "res://scripts/core/tuning/net_tuning.gd",
	"perf": "res://scripts/core/tuning/perf_tuning.gd",
	"ui_audio": "res://scripts/core/tuning/ui_audio_tuning.gd",
	"ability": "res://scripts/core/tuning/ability_tuning.gd",
	"flags": "res://scripts/core/tuning/feature_flags.gd",
}

## Per-ability values from TUNABLES §8. Fields an ability does not use stay at the
## class default, which is the inert zero — so a field that means something for
## one ability can never be inherited by another.
const ABILITIES := {
	"cinderfall":
	{
		"id": &"ABIL-CINDERFALL",
		"display_key": &"ability.cinderfall.name",
		"tell_sfx": &"SFX-CINDERFALL-THROW",
		"cooldown": 45.0,
		"cast_time": 0.45,
		"throw_range": 8.0,
		"radius": 5.0,
		"blocks_los": true,
		"blocks_kill": true,
		"suspicion_cost": 40.0,
		"startle_radius": 9.0,
		"tell_audio_radius": 25.0,
	},
	"lunge":
	{
		"id": &"ABIL-LUNGE",
		"display_key": &"ability.lunge.name",
		"tell_sfx": &"SFX-LUNGE-WINDUP",
		"cooldown": 30.0,
		"distance": 6.0,
		"speed": 9.0,
		"windup": 0.25,
		"stunnable_during": true,
		"suspicion_cost": 40.0,
		"auto_kill": true,
		"whiff_stagger": 1.2,
		"startle_radius": 7.0,
		"tell_audio_radius": 20.0,
	},
	"secondface":
	{
		"id": &"ABIL-SECONDFACE",
		"display_key": &"ability.secondface.name",
		"tell_sfx": &"SFX-SECONDFACE-MORPH-IN",
		"cooldown": 60.0,
		"cast_time": 0.8,
		"duration": 15.0,
		"break_speed": 6.2,
		"break_on_hit": true,
		"break_on_kill": true,
		"suspicion_cost": 10.0,
		"persona_source": &"nearest_clone",
		"break_tell_duration": 0.6,
		"tell_audio_radius": 8.0,
	},
	"whisperbolt":
	{
		"id": &"ABIL-WHISPERBOLT",
		"display_key": &"ability.whisperbolt.name",
		"tell_sfx": &"SFX-WHISPERBOLT-DRAW",
		"cooldown": 40.0,
		"windup": 1.0,
		"range_min": 3.0,
		"range_max": 12.0,
		"projectile_speed": 22.0,
		"forces_exposed": true,
		"exposed_tail": 1.5,
		"suspicion_on_miss": 30.0,
		"requires_los": true,
		"tell_audio_radius": 30.0,
	},
}

## Passives carry no numbers — their magnitudes live in the domain they modify.
const PASSIVES := {
	"stillness": {"id": &"PASV-STILLNESS", "display_key": &"passive.stillness.name"},
	"coldread": {"id": &"PASV-COLDREAD", "display_key": &"passive.coldread.name"},
	"secondwind": {"id": &"PASV-SECONDWIND", "display_key": &"passive.secondwind.name"},
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var written := 0
	for name: String in SECTIONS:
		var script: GDScript = load(SECTIONS[name])
		var res: Resource = script.new()
		var path := "%s/%s.tres" % [OUT_DIR, name]
		var err := ResourceSaver.save(res, path)
		if err != OK:
			push_error("failed to write %s: %d" % [path, err])
			quit(1)
			return
		written += 1
	written += _write_content("abilities", ABILITIES, AbilityData)
	written += _write_content("passives", PASSIVES, PassiveData)
	_write_profile()
	print("wrote %d resource files plus profile.tres" % written)
	quit(0)


func _write_content(folder: String, table: Dictionary, type: Variant) -> int:
	var dir := "%s/%s" % [OUT_DIR, folder]
	DirAccess.make_dir_recursive_absolute(dir)
	var n := 0
	for name: String in table:
		var res: Resource = type.new()
		for field: String in table[name]:
			res.set(field, table[name][field])
		if ResourceSaver.save(res, "%s/%s.tres" % [dir, name]) != OK:
			push_error("failed to write %s/%s.tres" % [dir, name])
			quit(1)
			return n
		n += 1
	return n


func _write_profile() -> void:
	var profile := TuningProfile.new()
	for name: String in SECTIONS:
		var field := "match_rules" if name == "match" else name
		profile.set(field, load("%s/%s.tres" % [OUT_DIR, name]))
	for name: String in ABILITIES:
		var res: AbilityData = load("%s/abilities/%s.tres" % [OUT_DIR, name])
		profile.abilities[res.id] = res
	for name: String in PASSIVES:
		var res: PassiveData = load("%s/passives/%s.tres" % [OUT_DIR, name])
		profile.passives[res.id] = res
	var errors: Array[String] = profile.validate()
	for e: String in errors:
		print("  validate: %s" % e)
	var err := ResourceSaver.save(profile, "%s/profile.tres" % OUT_DIR)
	if err != OK:
		push_error("failed to write profile.tres: %d" % err)
		quit(1)

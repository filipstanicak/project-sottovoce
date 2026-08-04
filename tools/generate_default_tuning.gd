## Writes data/tuning/default/*.tres from the class defaults.
##
##     godot --headless -s res://tools/generate_default_tuning.gd
##
## The defaults live in the resource classes, which are themselves generated from
## TUNABLES.md — so this makes the .tres files a THIRD copy of the same numbers.
## That is deliberate: Godot must be able to load a profile without executing
## GDScript defaults, and a hand-written .tres is a transcription of 224 numbers
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
	"flags": "res://scripts/core/tuning/feature_flags.gd",
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
	_write_profile()
	print("wrote %d section files plus profile.tres" % written)
	quit(0)


func _write_profile() -> void:
	var profile := TuningProfile.new()
	for name: String in SECTIONS:
		var field := "match_rules" if name == "match" else name
		profile.set(field, load("%s/%s.tres" % [OUT_DIR, name]))
	var errors: Array[String] = profile.validate()
	for e: String in errors:
		print("  validate: %s" % e)
	var err := ResourceSaver.save(profile, "%s/profile.tres" % OUT_DIR)
	if err != OK:
		push_error("failed to write profile.tres: %d" % err)
		quit(1)

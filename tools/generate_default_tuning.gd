## Writes data/tuning/default/*.tres from the class defaults.
##
##     godot --headless --path . res://tools/generate_default_tuning.tscn
##
## **A SCENE, NOT A `-s` SCRIPT, AND THAT IS A FIX RATHER THAN A STYLE CHOICE.**
## A `-s` script is compiled **before the autoloads are registered**, so `Tuning`
## is an unresolvable identifier — and the **sixteen Core classes that read it**
## (ADR-0005 makes it the one permitted autoload there) then fail to compile, along
## with everything depending on them. GDScript caches that failure, so the classes
## stay broken for the rest of the process **even after the autoloads exist**.
##
## What that cost here: `_write_profile` calls `TuningProfile.validate()`, which
## reaches `CompassMath.full_ring_distance` for **invariant 33** — and got
## *"Nonexistent function 'full_ring_distance' in base 'GDScript'"* on every run
## from M0 until 2026-09-05. **This tool checked 36 of 37 invariants and printed an
## error saying so, twice, and it was read as noise.** As a scene it checks all 37.
##
## The same conversion was made to `tools/anchor_census.gd` for the same reason:
## there it silently disabled a ground check through `CrowdRoster`. **Any tool that
## touches a Core class needs the autoloads, and only a scene gets them.**
##
## The defaults live in the resource classes, which are themselves generated from
## TUNABLES.md — so this makes the .tres files a THIRD copy of the same numbers.
## That is deliberate: Godot must be able to load a profile without executing
## GDScript defaults, and a hand-written .tres is a transcription of 260-odd numbers
## with no check on it. Generating them means the only way to change a shipped
## value is to change TUNABLES.md.
##
## **THE ABILITIES ARE THE ONE SECTION THAT CANNOT WORK THAT WAY**, because
## `AbilityData` is one class holding four abilities' fields — `duration` is 6 s of
## smoke for Cinderfall and 15 s of a false face for Second Face, and a class default
## can only be one of them. Their values come from `AbilityDefaults`, generated from
## §8 beside `ability_data.gd`; what stays here is `ABILITY_WIRING`, which is the
## content and the code rather than the numbers. It was a hand-written fourth copy of
## the numbers until 2026-09-04, and it had drifted — see the comment on it.
extends Node

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

## **THE WIRING ONLY. THE NUMBERS COME FROM `AbilityDefaults`**, which is generated
## from TUNABLES.md §8 alongside `ability_data.gd`.
##
## **THIS USED TO BE A HAND-WRITTEN TABLE OF 45 NUMBERS AND IT HAD DRIFTED.** Running
## this tool on 2026-09-04 reverted `TUN-CINDERFALL-THROW-RANGE` 0.0 -> 8.0, undoing
## ADR-0013; dropped `TUN-CINDERFALL-DURATION` 6.0, which the owner set at the
## controls the day before; and dropped `effect_script` from both live abilities,
## which makes Cinderfall and Lunge do nothing at all. Silently, from a run that
## printed success — and **the codegen README tells you to run this after every
## regeneration**, so the documented workflow was destructive.
##
## And this table never had a `duration` key for Cinderfall in the first place, which
## is **trap 17's own original instance**: the cloud shipped at 0.0 from M0 against a
## published 4.0, and nothing asked how long a cloud lives until `SYS-KILL` did.
##
## What is left is content and code rather than tuning, so it cannot come from
## TUNABLES: an id, a string key, a sound id, and the server-only effect script.
## **`effect_script` was never in the old table either** — US-0067 hand-patched it
## into `cinderfall.tres`, against trap 1, which is the other half of why
## regenerating lost it.
const ABILITY_WIRING := {
	"cinderfall":
	{
		"id": &"ABIL-CINDERFALL",
		"display_key": &"ability.cinderfall.name",
		"tell_sfx": &"SFX-CINDERFALL-THROW",
		"effect_script": preload("res://scripts/systems/ability/cinderfall_effect.gd"),
	},
	"lunge":
	{
		"id": &"ABIL-LUNGE",
		"display_key": &"ability.lunge.name",
		"tell_sfx": &"SFX-LUNGE-WINDUP",
		"effect_script": preload("res://scripts/systems/ability/lunge_effect.gd"),
	},
	"secondface":
	{
		"id": &"ABIL-SECONDFACE",
		"display_key": &"ability.secondface.name",
		"tell_sfx": &"SFX-SECONDFACE-MORPH-IN",
	},
	"whisperbolt":
	{
		"id": &"ABIL-WHISPERBOLT",
		"display_key": &"ability.whisperbolt.name",
		"tell_sfx": &"SFX-WHISPERBOLT-DRAW",
	},
}

## Passives carry no numbers — their magnitudes live in the domain they modify.
const PASSIVES := {
	"stillness": {"id": &"PASV-STILLNESS", "display_key": &"passive.stillness.name"},
	"coldread": {"id": &"PASV-COLDREAD", "display_key": &"passive.coldread.name"},
	"secondwind": {"id": &"PASV-SECONDWIND", "display_key": &"passive.secondwind.name"},
}


## **`_ready`, NOT `_init`.** A node's `_init` still runs before it is in the tree,
## so `get_tree()` would be null — and this file quits through the tree.
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var written := 0
	for name: String in SECTIONS:
		var script: GDScript = load(SECTIONS[name])
		var res: Resource = script.new()
		var path := "%s/%s.tres" % [OUT_DIR, name]
		var err := ResourceSaver.save(res, path)
		if err != OK:
			push_error("failed to write %s: %d" % [path, err])
			get_tree().quit(1)
			return
		written += 1
	written += _write_abilities()
	written += _write_content("passives", PASSIVES, PassiveData)
	_write_profile()
	print("wrote %d resource files plus profile.tres" % written)
	get_tree().quit(0)


## **THE VALUES ARE WRITTEN FIRST AND THE WIRING SECOND**, so a field named in both
## takes the wiring's. Nothing is in both today, and the ordering is stated rather
## than left to be discovered: the wiring is the half a human edits.
func _write_abilities() -> int:
	var dir := "%s/abilities" % OUT_DIR
	DirAccess.make_dir_recursive_absolute(dir)
	var n := 0
	for name: String in ABILITY_WIRING:
		var res := AbilityData.new()
		var values: Dictionary = AbilityDefaults.VALUES.get(name, {})
		for field: String in values:
			res.set(field, values[field])
		for field: String in ABILITY_WIRING[name]:
			res.set(field, ABILITY_WIRING[name][field])
		if ResourceSaver.save(res, "%s/%s.tres" % [dir, name]) != OK:
			push_error("failed to write %s/%s.tres" % [dir, name])
			get_tree().quit(1)
			return n
		n += 1
	return n


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
			get_tree().quit(1)
			return n
		n += 1
	return n


func _write_profile() -> void:
	var profile := TuningProfile.new()
	for name: String in SECTIONS:
		var field := "match_rules" if name == "match" else name
		profile.set(field, load("%s/%s.tres" % [OUT_DIR, name]))
	for name: String in ABILITY_WIRING:
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
		get_tree().quit(1)

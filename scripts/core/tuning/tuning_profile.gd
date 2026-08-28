## The root tuning resource. DATA_SCHEMA §2.
##
## Every gameplay number in Project Sottovoce reaches code through this object.
## No script contains a gameplay literal (CLAUDE.md never-do #1), so if a value
## is not reachable from here, it does not exist.
class_name TuningProfile
extends Resource

## Smallest plausible payload; anything shorter cannot encode a Dictionary.
const _MIN_SERIALISED_BYTES := 8

const _SECTIONS: Array[StringName] = [
	&"movement",
	&"suspicion",
	&"compass",
	&"combat",
	&"contract",
	&"crowd",
	&"match_rules",
	&"scoring",
	&"camera",
	&"net",
	&"perf",
	&"ui_audio",
	&"ability",
]

@export var movement: MovementTuning = MovementTuning.new()
@export var suspicion: SuspicionTuning = SuspicionTuning.new()
@export var compass: CompassTuning = CompassTuning.new()
@export var combat: CombatTuning = CombatTuning.new()
@export var contract: ContractTuning = ContractTuning.new()
@export var crowd: CrowdTuning = CrowdTuning.new()
@export var match_rules: MatchTuning = MatchTuning.new()
@export var scoring: ScoringTuning = ScoringTuning.new()
@export var camera: CameraTuning = CameraTuning.new()
@export var net: NetTuning = NetTuning.new()
@export var perf: PerfTuning = PerfTuning.new()
@export var ui_audio: UiAudioTuning = UiAudioTuning.new()
@export var ability: AbilityTuning = AbilityTuning.new()
@export var flags: FeatureFlags = FeatureFlags.new()

## StringName(ABIL-*) -> AbilityData.
@export var abilities: Dictionary = {}

## StringName(PASV-*) -> PassiveData.
@export var passives: Dictionary = {}


## A genuinely independent copy.
##
## `duplicate(true)` IS NOT ENOUGH. The sections are EXTERNAL resources — separate
## .tres files referenced by profile.tres — and Godot's deep duplicate only
## copies *embedded* sub-resources. So `duplicate(true)` hands back a new
## TuningProfile whose sections are the same shared objects, and writing to
## `copy.movement.sprint` silently rewrites the live profile everyone else holds.
##
## Anything that intends to modify a profile must clone it first.
func clone() -> TuningProfile:
	var out := TuningProfile.new()
	for section: StringName in _SECTIONS:
		var res: Resource = get(section)
		out.set(section, null if res == null else res.duplicate(true))
	out.flags = null if flags == null else flags.duplicate(true)
	for key: Variant in abilities:
		out.abilities[key] = (abilities[key] as Resource).duplicate(true)
	for key: Variant in passives:
		out.passives[key] = (passives[key] as Resource).duplicate(true)
	return out


## Stable over VALUES only. Excludes resource paths and metadata, so two files
## with identical numbers hash identically no matter where they came from —
## which is what lets TEL-MATCH-START record *which tuning* a match was played
## under without recording the whole profile.
func compute_hash() -> int:
	var parts: PackedStringArray = []
	for section: StringName in _SECTIONS:
		var res: Resource = get(section)
		if res == null:
			parts.append("%s=null" % section)
			continue
		parts.append("%s{%s}" % [section, _section_fingerprint(res)])
	parts.append("flags{%s}" % _section_fingerprint(flags))
	return String("|").join(parts).hash()


static func _section_fingerprint(res: Resource) -> String:
	var parts: PackedStringArray = []
	for prop: Dictionary in res.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var name: String = prop["name"]
		if name == "resource_local_to_scene" or name.begins_with("script"):
			continue
		parts.append("%s=%s" % [name, res.get(name)])
	return String(",").join(parts)


## Every field within its documented range, plus the 29 cross-field invariants
## from TUNABLES.md §17. Empty array means valid.
func validate() -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(_validate_sections_present())
	if not errors.is_empty():
		return errors
	errors.append_array(TuningInvariants.check(self))
	return errors


func _validate_sections_present() -> Array[String]:
	var errors: Array[String] = []
	for section: StringName in _SECTIONS:
		if get(section) == null:
			errors.append("section '%s' is null" % section)
	if flags == null:
		errors.append("section 'flags' is null")
	return errors


## Round-trips field-for-field through Godot's own resource serialisation, so a
## profile sent over the wire is the same object the server loaded.
func serialise() -> PackedByteArray:
	return var_to_bytes_with_objects(_to_dict())


static func deserialise(bytes: PackedByteArray) -> TuningProfile:
	# Reject undersized input before the engine sees it. bytes_to_var_with_objects
	# pushes an engine error rather than returning quietly, and a decoder that
	# logs on every malformed packet is a denial-of-service vector on a server
	# that receives bytes from clients.
	if bytes.size() < _MIN_SERIALISED_BYTES:
		return null
	var raw: Variant = bytes_to_var_with_objects(bytes)
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	return _from_dict(raw)


func _to_dict() -> Dictionary:
	var out: Dictionary = {}
	for section: StringName in _SECTIONS:
		out[section] = get(section)
	out[&"flags"] = flags
	out[&"abilities"] = _wireable(abilities)
	out[&"passives"] = _wireable(passives)
	return out


## **NUMBERS TRAVEL; CODE AND SCENES DO NOT.** `NET-S2C-TUNING-SYNC`, US-0067.
##
## `serialise` is `var_to_bytes_with_objects`, so every field of every
## `AbilityData` goes on the wire as an object — and two of them are not numbers.
## `effect_script` is a `Script`, and TDD-09 §3 makes effects **server only**:
## `scripts/systems/` is excluded from the client export, so a client has no
## business holding the code and every reason not to be handed it by whatever it
## connected to. `tell_vfx` is a `PackedScene` and is null for all four abilities
## today, stripped here so it cannot start travelling by being filled in.
##
## **THIS WAS FOUND BY THE ENGINE REFUSING IT, NOT BY REVIEW.** The moment
## `cinderfall.tres` gained an `effect_script`, `test_tuning_serialise_roundtrip.gd`
## went red with *"Class CinderfallEffect hides a global script class"* —
## `bytes_to_var_with_objects` re-parsing a script that is already registered. The
## parse error is a symptom; the defect is that the script was in the payload.
##
## **THE HASH IS UNAFFECTED**, because `compute_hash` walks `_SECTIONS` and has
## never included abilities — so a client and a server still agree about the tuning
## they are playing under, and `Handshake` cannot start refusing peers over this.
static func _wireable(rows: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in rows:
		var row: Resource = (rows[key] as Resource).duplicate()
		if &"effect_script" in row:
			row.set(&"effect_script", null)
		if &"tell_vfx" in row:
			row.set(&"tell_vfx", null)
		out[key] = row
	return out


static func _from_dict(raw: Dictionary) -> TuningProfile:
	var profile := TuningProfile.new()
	for key: Variant in raw:
		profile.set(StringName(key), raw[key])
	return profile

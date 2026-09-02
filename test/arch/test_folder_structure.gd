## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## Every folder declared in TDD-02 section 1 exists, and no script sits outside
## one. The layer rule is enforced by FOLDER MEMBERSHIP, so a missing folder
## invites a file into the wrong layer — and once it is there, the dependency
## it creates looks legitimate.
extends GutTest

const REQUIRED: Array[String] = [
	"res://scripts/core",
	"res://scripts/core/math",
	"res://scripts/core/contract",
	"res://scripts/core/score",
	"res://scripts/core/tuning",
	"res://scripts/core/data",
	"res://scripts/systems",
	"res://scripts/systems/crowd",
	"res://scripts/systems/ability",
	"res://scripts/net",
	"res://scripts/net/server",
	"res://scripts/net/client",
	"res://scripts/net/protocol",
	"res://scripts/pawn",
	"res://scripts/pawn/states",
	"res://scripts/pawn/traversal",
	"res://scripts/mirrors",
	"res://scripts/presentation",
	"res://scripts/presentation/view_models",
	"res://scripts/presentation/ui",
	"res://scripts/presentation/camera",
	"res://scripts/presentation/audio",
	"res://scripts/server",
	"res://scripts/debug",
	"res://data/tuning/default",
	"res://data/strings",
	"res://test/unit",
	"res://test/arch",
	"res://test/integration",
]


func test_every_declared_folder_exists() -> void:
	var missing: PackedStringArray = []
	for folder: String in REQUIRED:
		if not DirAccess.dir_exists_absolute(folder):
			missing.append(folder)
	assert_eq(missing.size(), 0, "Declared folder missing:\n" + "\n".join(missing))


func test_no_script_directly_in_scripts_root() -> void:
	# A script at scripts/ belongs to no layer, so the layer rule cannot see it.
	var stray: PackedStringArray = []
	var dir := DirAccess.open("res://scripts")
	if dir != null:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if not dir.current_is_dir() and name.ends_with(".gd"):
				stray.append("res://scripts/" + name)
			name = dir.get_next()
		dir.list_dir_end()
	assert_eq(
		stray.size(),
		0,
		"Script sits outside a layer folder — the layer rule cannot see it.\n" + "\n".join(stray)
	)

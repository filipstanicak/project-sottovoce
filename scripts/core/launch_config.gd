## The command line, parsed. TDD-12 §4.
##
## PURE CORE: it takes a `PackedStringArray` rather than calling `OS`, so the
## whole flag contract is unit-testable without booting a game. `boot.gd` is the
## only thing that touches `OS.get_cmdline_user_args()`, and it does nothing else.
##
## `max_players` is passed IN rather than defaulted here, because it is
## TUN-LOBBY-MAX-PLAYERS and a gameplay constant may not appear in a script
## (CLAUDE.md never-do #1). Core cannot reach the Tuning autoload, so the caller
## supplies it.
class_name LaunchConfig
extends RefCounted

const DEFAULT_PORT := 27015

## Flag -> field it writes. TDD-12 §4 is the contract; this is that table.
const VALUE_FLAGS := {
	"--port": "port",
	"--max-players": "max_players",
	"--connect": "connect_address",
	"--tuning": "tuning_profile",
	"--seed": "seed_value",
	"--record": "record_path",
}

## Of those, the ones whose value is a number.
const INT_FLAGS: Array[String] = ["--port", "--max-players", "--seed"]

## Server topology, headless.
var is_server: bool = false

## Not a tunable: changing it cannot change how the game plays or feels.
var port: int = DEFAULT_PORT

var max_players: int = 0

## `ip:port`. Skips the menu and joins directly — THE PLAYTEST FLAG.
var connect_address: String = ""

## Alternative tuning profile, server only.
var tuning_profile: String = "default"

## Deterministic clone roster, for reproducing a bug. -1 means "pick one".
var seed_value: int = -1

## Dump the ScoreEvent log and telemetry on match end.
##
## **PARSED, VALIDATED AND READ BY NOTHING.** `boot.gd` warns when it is given, so
## a facilitator does not plan a session around an export that will not appear.
## The blocker is upstream of the writer: `TelemetrySink` is a stub and 28 of
## GDD-07 §8's 29 events have no emitter.
var record_path: String = ""

## Flags that were not recognised. Reported rather than ignored: a typo'd
## `--max-player` silently running a 6-player lobby is the kind of thing that
## invalidates a playtest nobody realises was misconfigured.
var unknown: PackedStringArray = []


## Parse `args`, using `default_max_players` for TUN-LOBBY-MAX-PLAYERS.
static func parse(args: PackedStringArray, default_max_players: int) -> LaunchConfig:
	var config := LaunchConfig.new()
	config.max_players = default_max_players

	var i := 0
	while i < args.size():
		var value := args[i + 1] if i + 1 < args.size() else ""
		if config._apply(args[i], value):
			i += 1
		i += 1
	return config


## Apply one flag. Returns true when it consumed the following argument.
##
## Table-driven rather than a switch with a branch per flag: the table IS the
## documented contract in TDD-12 §4, so adding a flag is one row and cannot
## silently forget to consume its value.
func _apply(arg: String, value: String) -> bool:
	if arg == "--server":
		is_server = true
		return false
	if VALUE_FLAGS.has(arg):
		var field: String = VALUE_FLAGS[arg]
		set(field, int(value) if INT_FLAGS.has(arg) else value)
		return true
	if arg.begins_with("--"):
		unknown.append(arg)
	return false


## Complaints about the parsed result, as sentences. Empty means usable.
##
## Validated rather than clamped. A silently corrected port is a server nobody
## can find, and a silently clamped player count is a lobby that quietly differs
## from the one written on the playtest sheet.
func problems(min_players: int, tuning_max: int) -> Array[String]:
	var out: Array[String] = []
	if port < 1024 or port > 65535:
		out.append("--port %d is outside 1024-65535" % port)
	if max_players < min_players or max_players > tuning_max:
		out.append(
			(
				"--max-players %d is outside %d-%d (TUN-LOBBY-MIN/MAX-PLAYERS)"
				% [max_players, min_players, tuning_max]
			)
		)
	if is_server and connect_address != "":
		out.append("--server and --connect are mutually exclusive")
	if connect_address != "" and not connect_address.contains(":"):
		out.append("--connect expects ip:port, got '%s'" % connect_address)
	for flag: String in unknown:
		out.append("unrecognised flag %s" % flag)
	return out


## **A FLAG THAT IS VALID AND WILL NOT DO ANYTHING.** Separate from `problems()`
## because the two mean opposite things: a problem says *the launch is not what you
## asked for* and refuses to start, where a warning says *the launch is exactly
## what you asked for and one thing will be missing*. Refusing would stop a
## playtest that is otherwise fine.
##
## **`--record` IS PARSED, VALIDATED, STORED AND READ BY NOTHING**, while
## `docs/40_backlog/playtests/README.md` tells a facilitator to *"attach the
## telemetry export"* — so a silent flag costs a session its evidence and nobody
## finds out until it is over.
##
## **THE BLOCKER IS UPSTREAM OF THE FILE WRITER.** `TelemetrySink.append` and
## `flush` are stubs and 28 of GDD-07 §8's 29 events have no emitter, so an
## implemented `--record` would export one event kind and read as a working export
## of an empty match.
func warnings() -> Array[String]:
	var out: Array[String] = []
	if not record_path.is_empty():
		out.append(
			(
				(
					"--record %s does nothing: it is read by no code. TelemetrySink is a stub "
					+ "and 28 of 29 telemetry events have no emitter. Do not plan a playtest "
					+ "around the export."
				)
				% record_path
			)
		)
	return out


## True when a client should skip the menu and dial straight in.
func should_autoconnect() -> bool:
	return not is_server and connect_address != ""


## The host half of `--connect ip:port`.
##
## Split here rather than at the call site because `problems()` has already
## guaranteed the colon, and a second parser somewhere else is a second place for
## "what does an empty address mean" to be answered differently.
func connect_host() -> String:
	return connect_address.substr(0, connect_address.rfind(":"))


## The port half. Falls back to `port`, which is `DEFAULT_PORT` unless `--port`
## moved it — so `--connect 127.0.0.1:` is a bad line rather than a dial to zero.
func connect_port() -> int:
	var colon := connect_address.rfind(":")
	var tail := connect_address.substr(colon + 1)
	return int(tail) if tail.is_valid_int() else port

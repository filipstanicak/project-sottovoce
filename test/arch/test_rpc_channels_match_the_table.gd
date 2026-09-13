## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **EVERY `@rpc` DECLARES ITS CHANNEL AS A CONSTANT, AND `Messages.CHANNEL_FOR`
## DECLARES IT AGAIN.** An annotation cannot read a table, so the table is not
## what the wire obeys — it is what the catalogue, the tests and every reader
## believe. Two sources with nothing between them drift: on 2026-09-09
## `NET-C2S-SKIP-RESULTS` was built on `EVENT`, the table still said `SESSION`,
## and both catalogues said X. Found by the second agent on 2026-09-13, reviewing
## the correction of the catalogues — which had left the table as a third source
## in disagreement.
##
## This reads the channel off every `@rpc` under `scripts/net/`, derives the
## message id from the handler's name, and holds the table to it. A message with
## a handler and no row is refused as well: `channel_for()` answers -1 for it,
## which is the "invented in code, never documented" case the table's own
## docstring names.
extends GutTest

const NET_ROOT := "res://scripts/net"
const IDS := "res://scripts/core/ids.gd"

## The handshake handlers predate the `c2s_`/`s2c_` naming (US-0025) and are
## named here rather than derived. `_rejected` is `NET-C2S-HELLO`'s answer and
## has no id of its own. A premise below refuses this list going stale.
const HANDSHAKE: Dictionary = {
	"_hello": "NET_C2S_HELLO",
	"_welcome": "NET_S2C_WELCOME",
	"_tuning_sync": "NET_S2C_TUNING_SYNC",
	"_rejected": "",
}


## `[[handler, channel_name, path, line], ...]` for every `@rpc` under `scripts/net/`.
static func _declared_rpcs() -> Array:
	var out: Array = []
	for path: String in SourceScanner.gd_files(NET_ROOT):
		var lines := SourceScanner.code_lines(path)
		for i: int in lines.size():
			var line := String(lines[i][1]).strip_edges()
			if not line.begins_with("@rpc("):
				continue
			var at := line.find("Messages.Channel.")
			var channel := line.substr(at + 17).trim_suffix(")").strip_edges() if at >= 0 else ""
			var next := String(lines[i + 1][1]).strip_edges() if i + 1 < lines.size() else ""
			var handler := next.substr(5, next.find("(") - 5) if next.begins_with("func ") else ""
			out.append([handler, channel, path, lines[i][0]])
	return out


## `c2s_skip_results` -> `NET_C2S_SKIP_RESULTS`; the handshake four by name.
static func _constant_for(handler: String) -> String:
	if HANDSHAKE.has(handler):
		return String(HANDSHAKE[handler])
	if handler.begins_with("c2s_") or handler.begins_with("s2c_"):
		return "NET_" + handler.to_upper()
	return ""


func test_the_scan_found_the_wire() -> void:
	# PREMISE. A regex that matched nothing would make every assertion below vacuous.
	var rpcs := _declared_rpcs()
	assert_gt(rpcs.size(), 15, "found almost no @rpc under scripts/net")
	for row: Array in rpcs:
		assert_ne(
			String(row[0]), "", "an @rpc at %s:%d is not followed by a func" % [row[2], row[3]]
		)
		assert_ne(
			String(row[1]), "", "an @rpc at %s:%d names no Messages.Channel" % [row[2], row[3]]
		)
	var handlers: Array = []
	for row: Array in rpcs:
		handlers.append(row[0])
	for named: String in HANDSHAKE.keys():
		assert_has(handlers, named, "HANDSHAKE names %s, which is no longer an @rpc" % named)


func test_every_rpc_channel_matches_the_table() -> void:
	var constants: Dictionary = (load(IDS) as Script).get_script_constant_map()
	var wrong: PackedStringArray = []
	for row: Array in _declared_rpcs():
		var handler := String(row[0])
		var constant := _constant_for(handler)
		if constant == "":
			if not HANDSHAKE.has(handler):
				wrong.append("%s:%d %s follows neither naming rule" % [row[2], row[3], handler])
			continue
		if not constants.has(constant):
			wrong.append("%s:%d %s has no Ids.%s" % [row[2], row[3], handler, constant])
			continue
		var declared: int = Messages.Channel[String(row[1])]
		var tabled := Messages.channel_for(constants[constant])
		if tabled != declared:
			wrong.append(
				(
					"%s:%d %s is declared on %s but CHANNEL_FOR says %d"
					% [row[2], row[3], handler, String(row[1]), tabled]
				)
			)
	wrong.sort()
	assert_eq(
		wrong.size(),
		0,
		(
			"An @rpc and Messages.CHANNEL_FOR disagree about a channel.\n"
			+ "The annotation is what the wire obeys; the table is what everybody\n"
			+ "reads. Fix the one that is wrong, and both catalogues with it.\n"
			+ "\n".join(wrong)
		)
	)

## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **EVERY `any_peer` RPC HANDLER AUTHORISES BEFORE IT DOES ANYTHING ELSE.**
## TDD-04 §12, US-0026.
##
## `@rpc("any_peer", ...)` is the only door a client can knock on, and every one
## of them is reachable by a modified client sending whatever it likes, whenever
## it likes. The rule the whole authority model rests on is that each of those
## doors calls the chokepoint *first*.
##
## Why review misses this: a handler that forgets to authorise is shorter,
## simpler and works perfectly in every test — because every test is written by
## someone sending well-formed messages at the right time. It fails only against
## an adversary, which is to say only in production, which is to say never in a
## way anyone traces back to the missing line.
##
## The scan is textual on purpose. A runtime test would have to *be* the
## adversary to find the gap; this finds it by reading, and finds it in a handler
## nobody has written a test for yet.
extends GutTest

const ROOTS: Array[String] = ["res://scripts/net", "res://scripts/systems", "res://scripts/server"]

## The call every handler must make first.
const CHOKEPOINT := "_authorise("

## Handlers that legitimately precede authority, each with the reason it does.
##
## **THIS LIST IS THE ONLY WAY PAST THE GUARD, AND EVERY ENTRY IS AN ARGUMENT.**
## Adding one to make a failure go away is how the rule dies, so each is a
## message that *cannot* be authorised rather than one that merely is not:
##
## - `_hello` establishes whether a peer is a player at all. Requiring authority
##   for it is circular — nobody could ever complete a handshake.
## - `_ping` stores nothing and answers with nothing the sender did not send. Its
##   authority column in NETWORK_PROTOCOL §2 reads "none needed — echo only".
const PRE_AUTHORITY: Array[String] = ["_hello", "_ping"]


## Source lines with comments dropped and **string literals kept**.
##
## `SourceScanner.code_lines` strips literals so a guard is never tripped by its
## own documentation — and that is exactly wrong here, because the thing being
## matched IS a string literal: the `"any_peer"` inside the annotation. Scanned
## the wrong way this guard finds zero handlers and passes, vacuously, forever.
func _lines_with_literals(path: String) -> Array:
	var out: Array = []
	var n := 0
	for line: String in SourceScanner.read(path).split("\n"):
		n += 1
		if line.strip_edges().begins_with("#"):
			continue
		out.append([n, line])
	return out


## Every `@rpc` handler that any peer may call: [path, line, name, body].
func _client_facing_handlers() -> Array:
	var out: Array = []
	for root: String in ROOTS:
		for path: String in SourceScanner.gd_files(root):
			out.append_array(_handlers_in(path))
	return out


func _handlers_in(path: String) -> Array:
	var out: Array = []
	var lines: Array = _lines_with_literals(path)
	for i: int in lines.size():
		var line: String = String(lines[i][1]).strip_edges()
		if not (line.begins_with("@rpc(") and line.contains("any_peer")):
			continue
		var body := _body_after(lines, i)
		if body.is_empty():
			continue
		out.append([path, int(lines[i][0]), body[0], body[1]])
	return out


## The handler's name and its body, from the `func` line following the
## annotation. Returns [] if the annotation is not followed by one, which is a
## parse error the compiler will report far more clearly than this guard could.
func _body_after(lines: Array, from: int) -> Array:
	for i: int in range(from + 1, mini(from + 4, lines.size())):
		var line: String = String(lines[i][1]).strip_edges()
		if not line.begins_with("func "):
			continue
		var name := line.substr(5).split("(")[0].strip_edges()
		var body: PackedStringArray = []
		for j: int in range(i + 1, lines.size()):
			var next: String = String(lines[j][1])
			if next.strip_edges().begins_with("func ") or next.strip_edges().begins_with("@rpc("):
				break
			body.append(next)
		return [name, "\n".join(body)]
	return []


func test_handlers_exist_to_be_checked() -> void:
	# Guards the guard. An empty scan makes every assertion below vacuously true,
	# which is the failure shape this project has hit three times.
	assert_gt(
		_client_facing_handlers().size(), 2, "found almost no client-facing RPCs — the scan broke"
	)


func test_every_client_facing_handler_authorises() -> void:
	var offenders: PackedStringArray = []
	for handler: Array in _client_facing_handlers():
		var name: String = handler[2]
		if PRE_AUTHORITY.has(name):
			continue
		if not String(handler[3]).contains(CHOKEPOINT):
			offenders.append("%s:%d `%s`" % [handler[0], handler[1], name])
	offenders.sort()

	assert_eq(
		offenders.size(),
		0,
		(
			"An @rpc handler any peer can call does not authorise.\n"
			+ "A modified client reaches this directly, with any argument, at any time.\n"
			+ "Call _authorise(peer, msg) FIRST, or — if the message genuinely cannot\n"
			+ "be authorised — add it to PRE_AUTHORITY with the argument for why.\n"
			+ "\n".join(offenders)
		)
	)


func test_authorisation_happens_before_the_work() -> void:
	# **FIRST, NOT MERELY SOMEWHERE.** A handler that validates after acting has
	# already acted, and reads exactly like one that did it in the right order.
	# The check: nothing but the sender lookup may precede the chokepoint.
	var offenders: PackedStringArray = []
	for handler: Array in _client_facing_handlers():
		if PRE_AUTHORITY.has(handler[2]):
			continue
		for line: String in String(handler[3]).split("\n"):
			var code := line.strip_edges()
			if code.is_empty() or code.begins_with("#"):
				continue
			if code.contains(CHOKEPOINT):
				break
			if code.contains("get_remote_sender_id"):
				continue
			offenders.append(
				(
					"%s:%d `%s` acts before authorising: %s"
					% [handler[0], handler[1], handler[2], code]
				)
			)
			break
	offenders.sort()

	assert_eq(offenders.size(), 0, "Work happens before authorisation.\n" + "\n".join(offenders))


func test_the_check_can_actually_fail() -> void:
	# Falsification. A guard that cannot fail is a guard nobody can trust, and
	# this one is a text scan — the easiest kind to render inert by accident.
	var planted := "\tvar peer := multiplayer.get_remote_sender_id()\n\tsystem.apply(peer)\n"
	assert_false(planted.contains(CHOKEPOINT), "the chokepoint string no longer detects anything")

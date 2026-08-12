## `PawnTransitions` matches the normative Mermaid diagram in GDD-02 §3, EDGE FOR
## EDGE, in both directions.
##
## This is the test the whole state-object pattern rests on. ADR-0008 accepted a
## known weakness — the transition graph exists only in the reader's head — on
## the explicit condition that it be declared in one place and checked against
## the design. Without this file that condition is unmet and the pattern is worse
## than the `enum` it replaced, because at least a `match` block is exhaustive.
##
## The diagram is parsed here INDEPENDENTLY of the table. `PawnTransitions` is
## hand-declared and never reads this document, so a match means two separate
## representations agree — not that one was derived from the other.
##
## **If they disagree, the diagram is right** until an ADR says otherwise.
extends GutTest

const GDD := "res://docs/10_gdd/02_player_controller.md"


## Every `A --> B` in the §3 diagram, with `Loco` expanded to its six members and
## the `[*]` start marker dropped.
func _diagram_edges() -> Array:
	var text := SourceScanner.read(GDD)
	var start := text.find("```mermaid")
	var finish := text.find("```", start + 10)
	assert_gt(start, -1, "the GDD-02 §3 mermaid diagram is missing")
	var block := text.substr(start, finish - start)

	var out: Array = []
	var re := RegEx.create_from_string("([A-Za-z*\\[\\]]+)\\s-->\\s([A-Za-z]+)")
	for m: RegExMatch in re.search_all(block):
		var from := m.get_string(1)
		var to := m.get_string(2)
		if from.contains("["):
			continue  # the [*] entry marker is not an edge between states
		for a: StringName in _members(from):
			for b: StringName in _members(to):
				out.append([a, b])
	return out


## `Loco` is a group in the diagram; every other name is a single state.
static func _members(name: String) -> Array[StringName]:
	if name == "Loco":
		return PawnStateId.LOCOMOTION
	var out: Array[StringName] = [StringName(name)]
	return out


static func _key(edge: Array) -> String:
	return "%s -> %s" % [edge[0], edge[1]]


func test_the_diagram_parsed() -> void:
	# Guards the guard. A regex that stopped matching would make every comparison
	# below pass over an empty set and report success.
	assert_gt(_diagram_edges().size(), 40, "the diagram scan matched almost nothing")


func test_every_diagram_edge_is_declared() -> void:
	var declared: Dictionary = {}
	for edge: Array in PawnTransitions.edges():
		declared[_key(edge)] = true

	var missing: PackedStringArray = []
	for edge: Array in _diagram_edges():
		if not declared.has(_key(edge)):
			missing.append(_key(edge))
	missing.sort()
	assert_eq(
		missing.size(),
		0,
		(
			"The diagram declares an edge PawnTransitions does not.\n"
			+ "The diagram is normative — add the edge, do not edit the diagram.\n"
			+ "\n".join(missing)
		)
	)


func test_every_declared_edge_is_in_the_diagram() -> void:
	# The more dangerous direction: an edge in code that no design describes is a
	# transition nobody decided on, and it will be reachable in play.
	var drawn: Dictionary = {}
	for edge: Array in _diagram_edges():
		drawn[_key(edge)] = true

	var extra: PackedStringArray = []
	for edge: Array in PawnTransitions.edges():
		if not drawn.has(_key(edge)):
			extra.append(_key(edge))
	extra.sort()
	assert_eq(
		extra.size(),
		0,
		(
			"PawnTransitions declares an edge the diagram does not.\n"
			+ "Either it is a bug, or the design changed and needs an ADR.\n"
			+ "\n".join(extra)
		)
	)


func test_every_state_appears_in_the_table() -> void:
	var built := PawnTransitions.table()
	var missing: PackedStringArray = []
	for id: StringName in PawnStateId.ALL:
		if not built.has(id):
			missing.append(String(id))
	assert_eq(missing.size(), 0, "states with no outgoing edges: " + ", ".join(missing))


func test_no_edge_points_at_an_unknown_state() -> void:
	var strays: PackedStringArray = []
	for edge: Array in PawnTransitions.edges():
		if not PawnStateId.exists(edge[1]):
			strays.append(_key(edge))
	assert_eq(strays.size(), 0, "edges to unknown states: " + ", ".join(strays))


func test_the_speed_ladder_cannot_be_skipped() -> void:
	# Escalation is a decision taken one rung at a time. A direct Idle -> Sprint
	# would make speed free, which inverts the design thesis outright.
	assert_false(PawnTransitions.allows(PawnStateId.IDLE, PawnStateId.RUN), "Idle -> Run")
	assert_false(PawnTransitions.allows(PawnStateId.IDLE, PawnStateId.SPRINT), "Idle -> Sprint")
	assert_false(PawnTransitions.allows(PawnStateId.STROLL, PawnStateId.SPRINT), "Stroll -> Sprint")
	# Legal since the Jog rung was deprecated, and the one edge that changed:
	# Stroll is the rung below Run now.
	assert_true(PawnTransitions.allows(PawnStateId.STROLL, PawnStateId.RUN), "Stroll -> Run")
	assert_true(PawnTransitions.allows(PawnStateId.RUN, PawnStateId.SPRINT), "Run -> Sprint")


func test_death_and_respawn_close_the_loop() -> void:
	assert_true(PawnTransitions.allows(PawnStateId.DEAD, PawnStateId.RESPAWNING))
	assert_true(PawnTransitions.allows(PawnStateId.RESPAWNING, PawnStateId.IDLE))
	assert_false(
		PawnTransitions.allows(PawnStateId.DEAD, PawnStateId.IDLE),
		"death must route through Respawning, which is where suspicion is zeroed"
	)

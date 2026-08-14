## Base class for every server-authoritative gameplay system. TDD-01 §5.
##
## SERVER ONLY. A system exists in `server_root.tscn` and nowhere else; a client
## never instantiates one, which is what makes "is this server-only?" answerable
## by looking at which scene a node is in.
##
## **A SYSTEM NEVER REFERENCES PRESENTATION.** Not the camera, not the HUD, not
## audio. The dependency rule points one way — Presentation → Net → Systems →
## Core — and a system that reached upward would put a rule that decides an
## outcome inside code the server export does not contain.
##
## **TICKED EXPLICITLY, IN THE ORDER `SystemOrder` DECLARES.** Not by
## `_physics_process`, and not in scene-tree order. A system that ticked itself
## would run at the physics rate rather than the net rate, and would run in
## whatever order the tree happened to hold — `test_no_gameplay_in_process.gd`
## refuses both.
class_name GameSystem
extends Node


## Which stage of `SystemOrder` this system occupies. Overridden by every
## subclass; the director refuses to register a system that does not name one,
## and refuses one that names a stage no system may occupy.
func stage() -> StringName:
	return &""


## Wired once by `MatchDirector` before the first tick. Dependencies arrive here
## rather than being looked up, so the graph is visible in one file.
func setup(_ctx: MatchContext) -> void:
	pass


## Advance one server tick. `dt` is always `1.0 / TUN-NET-SERVER-TICK`.
##
## **NEVER CALLED ON A CLIENT**, and never called twice for one tick. A system
## that needs finer resolution than 33.3 ms does not get it by ticking faster —
## the pawn substep exists for the one thing that genuinely needs 60 Hz, and it
## is not a system.
func tick(_ctx: MatchContext, _dt: float) -> void:
	pass


## Release all per-match state. Called when the match ends, before the context
## is discarded, so nothing survives into the next match's first tick.
func teardown() -> void:
	pass

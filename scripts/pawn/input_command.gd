## One tick of player intent. TDD-06 §3.
##
## MINIMAL — the input map, dual buffering and the wire format arrive in US-0016.
## It exists now because it is the second parameter of `PawnState.step()`, and
## the whole point of the state pattern is that step() is a pure function of
## (ctx, input, delta) that a unit test can call with no scene tree.
##
## THE CLIENT SENDS INTENT, NEVER OUTCOME. There is no "I killed X" here and
## there never will be: kill and stun are buttons, validated server-side against
## the lag-compensated world (CLAUDE.md never-do #2).
class_name InputCommand
extends RefCounted

## Server tick this command is for. Integer, because reconciliation replays
## commands by tick and a float would drift.
var tick: int = 0

## Desired movement on the ground plane, length <= 1.
var move: Vector2 = Vector2.ZERO

## Facing, radians.
var yaw: float = 0.0

# --- Modifiers. Held, not edge-triggered. ---
var slow: bool = false
var run: bool = false
var sprint: bool = false

# --- Requests. Edge-triggered; the state machine consumes them. ---
var traverse: bool = false
var blend: bool = false
var kill: bool = false
var stun: bool = false


func wants_movement() -> bool:
	return move.length_squared() > 0.0


## A fresh command for `tick`, so tests do not have to remember which fields
## default to what.
static func empty(for_tick: int = 0) -> InputCommand:
	var command := InputCommand.new()
	command.tick = for_tick
	return command

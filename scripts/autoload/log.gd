## Structured logging and the TEL- telemetry sink.
##
## STUB — telemetry sink arrives in US-0080.
extends Node


func info(message: String) -> void:
	print("[info] ", message)


func warn(message: String) -> void:
	push_warning(message)


## Runtime conditions the world can legitimately produce. Programmer errors use
## assert() instead, which compiles out of release (CODING_STANDARDS section 10).
func error(message: String) -> void:
	push_error(message)


## Appends a TEL- event. No-op until US-0080.
func telemetry(_id: StringName, _fields: Dictionary) -> void:
	pass

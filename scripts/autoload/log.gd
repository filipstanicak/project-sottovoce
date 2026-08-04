## Structured logging, and the TEL- telemetry sink.
##
## One place, because a playtest produces a server log, six client logs and a
## telemetry file that must be readable side by side afterwards. Every line
## carries a SCOPE, so `grep compass` recovers one system's story from a log with
## six players talking at once.
extends Node

## Levels. `error` is for runtime conditions the world can legitimately produce.
## A PROGRAMMER error uses `assert()` instead, which compiles out of release
## (CODING_STANDARDS §10) — the distinction is whether a correct build could ever
## reach it.
enum Level { DEBUG, INFO, WARN, ERROR }

## Below this, nothing is emitted. Raised to WARN on a release export so a
## shipped client does not spend frame budget formatting strings nobody reads.
var min_level: Level = Level.DEBUG

var _sink: TelemetrySink = TelemetrySink.null_sink()


func _ready() -> void:
	if not OS.is_debug_build():
		min_level = Level.WARN


func debug(message: String, scope: StringName = &"") -> void:
	_emit(Level.DEBUG, message, scope)


func info(message: String, scope: StringName = &"") -> void:
	_emit(Level.INFO, message, scope)


func warn(message: String, scope: StringName = &"") -> void:
	_emit(Level.WARN, message, scope)


## Runtime conditions the world can legitimately produce.
func error(message: String, scope: StringName = &"") -> void:
	_emit(Level.ERROR, message, scope)


## Appends a TEL- event. Routed through the sink so telemetry is never a `print`
## that someone later has to parse back out of a log.
func telemetry(id: StringName, fields: Dictionary) -> void:
	_sink.append(id, fields)


## Swap the sink. US-0080 installs a real one; tests install a recording one.
## Never left null — call sites must not branch on whether telemetry is enabled.
func set_sink(sink: TelemetrySink) -> void:
	_sink = TelemetrySink.null_sink() if sink == null else sink


func flush() -> void:
	_sink.flush()


func _emit(level: Level, message: String, scope: StringName) -> void:
	if level < min_level:
		return
	var line := message if scope == &"" else "[%s] %s" % [scope, message]
	match level:
		Level.WARN:
			push_warning(line)
		Level.ERROR:
			push_error(line)
		_:
			print("[%s] %s" % [_label(level), line])


func _label(level: Level) -> String:
	match level:
		Level.DEBUG:
			return "debug"
		Level.WARN:
			return "warn"
		Level.ERROR:
			return "error"
		_:
			return "info"

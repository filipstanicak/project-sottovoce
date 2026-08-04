## Where TEL- events go. The interface, not an implementation.
##
## Pure Core: no Node, no engine singletons, so the balance model's arithmetic
## can be exercised in a unit test without a running game.
##
## Stubbed deliberately at M0. The event CATALOGUE is settled
## (10_gdd/07_balance.md §8) and the interface is fixed here so that call sites
## written between now and US-0080 do not have to change when a real sink lands.
## A sink that appears late is a sink whose call sites were never written.
class_name TelemetrySink
extends RefCounted


## Append one event. `fields` is flat: no nesting, because a flat record is
## trivially convertible to CSV and every analysis of this data will start in a
## spreadsheet.
func append(_id: StringName, _fields: Dictionary) -> void:
	pass


## Flush anything buffered. Called at match end and on clean shutdown.
func flush() -> void:
	pass


## A discarding sink, so `Log` is never null-checking and no call site branches
## on whether telemetry happens to be enabled.
static func null_sink() -> TelemetrySink:
	return TelemetrySink.new()

## **HOW LONG DO I HAVE, AND IS THE FINAL CONTRACT COMING?** GDD-06 §E, UI_UX_SPEC
## §1.1 element E, US-0073. CLIENT ONLY.
##
## The snapshot's match block, as the timer needs it: the phase and the multiplier
## arrive on `EVT-MATCH-PHASE-CHANGED`, and the remaining ticks arrive through
## `HudBridge.match_time_changed`, the same composition wiring `ResultsRoot` gets
## its clock through — a local signal, not a second phase channel (bus catalogue,
## *Results time forwarding*).
##
## **THE BAR IS DERIVED FROM THE AUTHORITATIVE CLOCK, NEVER COUNTED DOWN HERE.**
## GDD-06 fills a thin bar during the last `TUN-MATCH-FINALPHASE-WARNING` before
## the Final Contract. The server's warning is a signal that reaches no client, so
## the bar reads the server's `ticks_remaining` against the same two tunables
## `MatchClock.warning_at` uses — the arithmetic of a number the server sent, on
## the same tick tables, which is not a prediction of gameplay state. What it must
## never do is advance between snapshots: a HUD that runs ahead of the wire is
## never-do #3, and UI_UX_SPEC §3.3 forbids anything newer than the simulation.
##
## **`ACTIVE` AND `FINAL` SHARE ONE COUNTDOWN**, so `ticks_remaining` in `ACTIVE`
## already includes the whole of `FINAL` (`MatchClock.remaining`). The distance to
## the Final Contract is therefore the remainder minus `FINAL`'s own length, and
## the timer never jumps back up when the phase turns.
class_name MatchVm
extends RefCounted

signal changed

## Nothing has arrived yet. A flag rather than a sentinel tick, because zero ticks
## is what the last snapshot of a match legitimately carries.
var known: bool = false
var phase: int = MatchPhase.Phase.LOBBY
var multiplier: float = 1.0
var ticks_remaining: int = 0


func apply_phase(new_phase: int, new_multiplier: float) -> void:
	if new_phase == phase and is_equal_approx(new_multiplier, multiplier):
		return
	phase = new_phase
	multiplier = new_multiplier
	changed.emit()


func apply_ticks(ticks: int) -> void:
	var next := maxi(ticks, 0)
	if known and next == ticks_remaining:
		return
	known = true
	ticks_remaining = next
	changed.emit()


## The element matters for about forty seconds of a match and is ignorable for the
## rest; it is *absent* outside play, because a lobby has no clock to show and a
## results screen has its own.
func is_shown() -> bool:
	return known and MatchPhase.is_playing(phase)


func is_final() -> bool:
	return phase == MatchPhase.Phase.FINAL


## **ROUNDED UP**, so the last tick of a match reads `0:01` rather than `0:00`: a
## clock that shows zero while the server is still simulating a tick tells the
## player the match is over one tick before it is.
func seconds_left() -> int:
	return ceili(float(ticks_remaining) / Tuning.match_rules.tick_rate)


func minutes() -> int:
	return seconds_left() / 60


func seconds() -> int:
	return seconds_left() % 60


## How full the thin bar is: 0.0 until `TUN-MATCH-FINALPHASE-WARNING` before the
## Final Contract, 1.0 at the boundary, and held at 1.0 through `FINAL`, where the
## whole element carries the phase treatment instead.
func warning_fraction() -> float:
	if not is_shown():
		return 0.0
	if is_final():
		return 1.0
	var warning := Tuning.ticks(&"TUN-MATCH-FINALPHASE-WARNING")
	if warning <= 0:
		return 0.0
	var to_final := ticks_remaining - Tuning.ticks(&"TUN-MATCH-FINALPHASE-DURATION")
	return clampf(float(warning - to_final) / float(warning), 0.0, 1.0)


## `2` for 2.0 and `1.5` for 1.5 — the marker names the number scoring pays, and
## a trailing `.0` on the shipped value would read as a decimal that matters.
func multiplier_label() -> String:
	var text := String.num(multiplier, 1)
	return text.trim_suffix(".0")

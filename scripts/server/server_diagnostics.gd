## **WHAT THIS PROCESS SAYS ABOUT ITSELF WHILE IT RUNS.** SERVER ONLY.
##
## Split out of `server_root.gd` on 2026-09-08, when US-0079's phase wiring took that
## file to 424 against never-do #6's 400 — the sixth time the length guard has asked
## a question worth answering. **The seam is that none of this is topology**:
## `ServerRoot` answers *what is joined to what*, and nothing here is joined to
## anything. Both readings below are diagnostics whose output is a level-data or a
## network finding reporting itself, and neither changes a single thing about the
## match if it is never read.
##
## **AND THE TWO DOCSTRINGS HAD MERGED INTO ONE, WHICH IS TRAP 11's SHAPE IN
## PROSE.** Before the move, the paragraph about input starvation sat above the
## function about the fallen crowd, and `_log_starvation` carried none at all — so
## the file explained each reading over the wrong body. The guard measures `func` to
## `func` and charges a function for its neighbour's comment; a reader does the same
## thing, and here it had already happened.
class_name ServerDiagnostics
extends RefCounted

## How often the two lines may repeat, in net ticks. Ten seconds at 30 Hz.
const EVERY := 300

var _director: MatchDirector
var _crowd: CrowdDirector

## The last count reported, so a steady number is silent. Logged once per rise.
var _fallen_reported: int = 0


func _init(director: MatchDirector, crowd: CrowdDirector) -> void:
	_director = director
	_crowd = crowd


## Connected to `tick_completed`, so it never runs outside a match.
func report(_ctx: MatchContext, _dt: float) -> void:
	_log_the_fallen()
	_log_starvation()


## **A CROWD THAT FALLS OUT OF THE WORLD SAYS SO.** `CrowdRescue` puts a fallen NPC
## back rather than letting the district quietly drain, and the count must be zero
## on a map whose routes are walkable — so a line here is a level-data defect
## reporting itself.
func _log_the_fallen() -> void:
	var fallen := _crowd.rescued_from_the_void()
	if fallen == _fallen_reported:
		return
	_fallen_reported = fallen
	Log.warn(
		(
			(
				"crowd fell out of the world: %d put back so far — a route crosses ground "
				+ "that does not exist (test_circuit_separation.gd)"
			)
			% fallen
		),
		&"crowd"
	)


## **HOW OFTEN THE INPUT QUEUE RAN DRY**, once every ten seconds and only while it
## is happening. A starved tick repeats the peer's last command, which is a step the
## client never predicted — felt as a tug toward the previous input. US-0028's repeat
## is correct for a *lost* command; this line is how you find out whether it is
## firing for merely *late* ones.
func _log_starvation() -> void:
	var tick := _director.ctx.tick
	if tick % EVERY != 0 or _director.starved_ticks == 0:
		return
	Log.info(
		(
			"input starvation: %d repeats over %d ticks (%.1f %%)"
			% [_director.starved_ticks, tick, float(_director.starved_ticks) / float(tick) * 100.0]
		),
		&"net"
	)

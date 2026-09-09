## **WHICH PHASES THE DIRECTOR DESCRIBES, AND WHICH IT ONLY COUNTS.** US-0079.
##
## Split out of `test_match_director.gd` on 2026-09-09, when three more assertions took
## that file past `.gdlintrc`'s twenty-method cap — the same push that produced
## US-0065's window files, and the seam is honest either way: above is *the clock and
## its order*, here is *what happens in the phases where the order does not run*.
##
## **`is_simulating` AND `is_watched` ARE DIFFERENT QUESTIONS, AND CONFLATING THEM COST
## THE RESULTS SCREEN ITS CLOCK.** Until 2026-09-09 the director emitted
## `tick_completed` only while simulating, so the instant a match reached `RESULTS` the
## snapshots stopped: every client's last one said `FINAL`, `ticks_remaining` froze on
## whatever the final tick carried, and the unanimous skip had **no channel at all** to
## end the screen through. Found by the second agent, against a claim of mine from the
## day before. `test_the_results_screen_is_still_described` is that defect.
extends GutTest

const PEER := 5

var _director: MatchDirector
var _substeps: Array = []
var _completions: Array = []


func before_each() -> void:
	_substeps = []
	_completions = []
	_director = MatchDirector.new()
	add_child_autofree(_director)
	_director.input_applied.connect(
		func(peer: int, command: InputCommand, dt: float) -> void:
			_substeps.append([peer, command.seq, dt])
	)
	_director.tick_completed.connect(
		func(_c: MatchContext, _d: float) -> void: _completions.append(true)
	)


## Drive the director's own clock directly. Waiting on real physics frames would make
## these assertions take minutes for nothing.
func _run_frames(count: int) -> void:
	for _i: int in count:
		_director._physics_process(1.0 / Tuning.net.client_input_rate)


func test_the_fixture_completes_a_tick_during_play() -> void:
	# **THE PREMISE.** Every assertion below counts completions; a fixture that never
	# produced one would make the two silence assertions vacuously true.
	_director.ctx.phase = MatchPhase.Phase.ACTIVE
	_run_frames(20)
	assert_gt(_completions.size(), 0, "the director completed no tick during play at all")


## **THE ASSERTION THE DEFECT WOULD HAVE FAILED.** A results screen is a phase in which
## nothing may change and everything must still be visible.
func test_the_results_screen_is_still_described() -> void:
	_director.ctx.phase = MatchPhase.Phase.RESULTS
	_run_frames(20)
	assert_gt(_completions.size(), 0, "a match in its results phase sent no snapshot at all")


## And no stage runs there, which is the half `is_simulating` was right about.
func test_nothing_simulates_in_the_results() -> void:
	_director.ctx.phase = MatchPhase.Phase.RESULTS
	_director.enqueue_input(PEER, InputCommand.empty(1))
	_run_frames(20)
	assert_eq(_substeps.size(), 0, "input was applied over the results screen")


func test_nothing_simulates_in_the_lobby() -> void:
	_director.ctx.phase = MatchPhase.Phase.LOBBY
	_director.enqueue_input(PEER, InputCommand.empty(1))
	_run_frames(20)
	assert_eq(_substeps.size(), 0, "input was applied in the lobby")


## **THE LOBBY IS DELIBERATELY STILL SILENT**, and saying which of the two
## non-simulating phases changed is the whole precision of the fix. There is no world
## to describe before a match — no pawns, no crowd placed, nothing — and what a lobby
## screen needs is a roster, which is US-0078's message rather than this format.
func test_the_lobby_is_still_silent() -> void:
	_director.ctx.phase = MatchPhase.Phase.LOBBY
	_run_frames(20)
	assert_eq(_completions.size(), 0, "the lobby began sending snapshots of a match not started")

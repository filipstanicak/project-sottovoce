## `SYS-MATCH` — THE PHASE, AND NOTHING ELSE. TDD-10 §6, US-0079. SERVER ONLY.
##
## Lobby, countdown, play, the Final Contract, results. Every transition is a tick
## count compared against `MatchClock`; nothing here reads a wall clock, and nothing
## here decides a gameplay rule. What the Final Contract changes is one number the
## scoring already derives — GDD-07's own note, that the last thirty seconds must be
## decisive without being a different game.
##
## **IT IS NOT A `GameSystem`, AND THIS IS THE FIFTH SUCH CALL AND THE STRONGEST
## REASON.** `SYS-SCORE`, `SYS-STUN` and `SYS-SPAWN` each declined the interface
## because their stage was the wrong moment. This one cannot take a stage at all:
## `MatchDirector._net_tick` runs the stages only when `MatchPhase.is_simulating`,
## so a system that lived in the stage loop **could never leave `LOBBY`** — it would
## be waiting to be run by the gate it exists to open. It rides `net_ticked`, which
## the director emits before that gate and which had no listener at all.
##
## **AND TDD-10 §6's SKETCH SAYS `extends GameSystem`, WHICH IS NOW A DOCUMENTED
## DIVERGENCE RATHER THAN A DRIFT** — see §6.2. Two of its other lines are sketch
## rather than code as well: `ctx.ticks_remaining` is not a field of `MatchContext`
## (the count lives here, and the wire carries it), and `MatchPhase.PLAYING` is not
## an enum member — play is `ACTIVE` and `FINAL`.
##
## **THE PLAYER COUNT IS REPORTED IN RATHER THAN READ.** `Net.player_count()` is an
## autoload, and a system that reached for it could not be asked a question in a
## test without one standing up — the reason `ScoreFold` takes events and
## `ContractCycle` takes peers. `server_root` reports it on every join and part.
class_name MatchSystem
extends RefCounted

## The phase has changed. `to` is already on `ctx` when this fires.
signal phase_changed(from: int, to: int, ctx: MatchContext)

## The countdown has begun. **This is where the contract cycle is built** — US-0079
## asks for it "at countdown", and `ContractSystem.open` has had no caller under
## `scripts/` since US-0050: contracts today are grown one `report_join` at a time,
## which is a cycle in join order rather than the uniformly random permutation the
## story asks for.
signal countdown_opened(peers: PackedInt32Array, ctx: MatchContext)

## `TUN-MATCH-FINALPHASE-WARNING` before the Final Contract opens.
##
## **IT CHANGES NO RULE, WHICH IS THE CRITERION AND NOT AN OVERSIGHT.** It exists so
## the phase is anticipated rather than sprung; anything that acted on it would make
## the warning itself a mechanic.
signal final_warning_announced(ctx: MatchContext)

## The match ended because the lobby fell below `min_players`, rather than on its
## clock. Emitted with the transition into `RESULTS`, never instead of it: US-0079
## requires the results to be **shown**, so an abandoned match still ends the way a
## finished one does.
signal abandoned(players: int, ctx: MatchContext)

## Ticks spent in `LOBBY` before saying so, and then how often to repeat it.
##
## **A SERVER WAITING FOR PLAYERS LOOKS EXACTLY LIKE A SERVER THAT IS BROKEN**, and
## it did until this line: `MatchDirector` runs no stage outside a match, so a lobby
## that never fills is a process that accepts connections, prints its banner and does
## nothing else. Every silent-failure finding in this corpus has the same fix, which
## is to make the silence speak.
const LOBBY_REPORT_EVERY := 150

## Ticks since the current phase began. Zero on the first tick of a phase.
var phase_elapsed: int = 0

## How many players are connected, reported by `server_root`.
var players: int = 0

## The countdown trigger and the abandon floor, one number for both.
##
## **`TUN-LOBBY-MIN-PLAYERS` 4 IS THE DEFAULT AND `--min-players` OVERRIDES IT**, so
## the bench stays usable: `sandbox.bat` runs one hunter and you, and a server that
## refused to leave `LOBBY` under four peers would simulate nothing at all on every
## debug tool this project has.
var min_players: int = 4

var _rules: MatchTuning = null

## **WHETHER THIS SYSTEM STARTED THE MATCH IT IS LOOKING AT.** Armed by entering
## `WARMUP`, and it is what the abandon floor is gated on.
##
## **A PHASE SOMEBODY ELSE ASSIGNED IS A FIXTURE, NOT A MATCH IN PROGRESS.** Half
## the probes in `tools/` and several tests set `ctx.phase = ACTIVE` by hand with one
## or two synthetic peers, which is the whole point of a probe; ending "their match"
## for want of players would leave every one of them in `RESULTS` simulating nothing,
## with no error — trap 3's shape. In a live server the only route to `ACTIVE` is
## through `_enter`, so this is not a hole: it is the difference between a match and
## a fixture, said once.
var _started: bool = false


func setup(ctx: MatchContext, rules: MatchTuning) -> void:
	_rules = rules
	min_players = rules.min_players
	phase_elapsed = 0
	_started = false
	ctx.active_started_at = MatchContext.NO_MATCH


## One net tick of the phase, before any stage has run.
##
## **THE ELAPSED COUNT ADVANCES FIRST AND THE TRANSITION IS TESTED AFTER**, so a
## phase of N ticks lasts N ticks. Testing first would give every phase one free tick
## and put the Final Contract boundary one tick past where `ScoreEvent` pays double.
func advance(ctx: MatchContext, _dt: float = 0.0) -> void:
	if _rules == null:
		return
	var previous := phase_elapsed
	phase_elapsed += 1
	if _ended_for_want_of_players(ctx):
		return
	match ctx.phase:
		MatchPhase.Phase.LOBBY:
			if players >= min_players:
				_enter(MatchPhase.Phase.WARMUP, ctx)
			else:
				_say_what_it_is_waiting_for()
		MatchPhase.Phase.ACTIVE:
			_announce_the_warning(previous, ctx)
			_end_the_phase_on_its_clock(ctx)
		_:
			_end_the_phase_on_its_clock(ctx)


## **BELOW THE FLOOR THE MATCH ENDS WITH RESULTS SHOWN, NEVER BY STOPPING.** A
## server that simply stopped simulating would leave the last players standing in a
## world that no longer answers, which is indistinguishable from a crash.
##
## `LOBBY` and `RESULTS` are exempt: neither is a match in progress, and applying it
## to `LOBBY` would end a match that has not started.
func _ended_for_want_of_players(ctx: MatchContext) -> bool:
	if not _started:
		return false
	if ctx.phase == MatchPhase.Phase.LOBBY or ctx.phase == MatchPhase.Phase.RESULTS:
		return false
	if players >= min_players:
		return false
	abandoned.emit(players, ctx)
	_enter(MatchPhase.Phase.RESULTS, ctx)
	return true


func _say_what_it_is_waiting_for() -> void:
	if phase_elapsed % LOBBY_REPORT_EVERY != 0:
		return
	Log.info(
		"lobby: %d of %d players — nothing simulates until the countdown" % [players, min_players],
		&"net"
	)


## **A CROSSING, NEVER AN EQUALITY** — `MatchClock.crossed` carries the argument.
func _announce_the_warning(previous: int, ctx: MatchContext) -> void:
	if MatchClock.crossed(previous, phase_elapsed, MatchClock.warning_at(_rules)):
		final_warning_announced.emit(ctx)


func _end_the_phase_on_its_clock(ctx: MatchContext) -> void:
	var total := MatchClock.duration_ticks(ctx.phase, _rules)
	if total == MatchClock.NO_CLOCK or phase_elapsed < total:
		return
	var next := MatchClock.next_phase(ctx.phase)
	if next != ctx.phase:
		_enter(next, ctx)


## Ticks left on the clock the players are watching. The wire's `ticks_remaining`.
func remaining(ctx: MatchContext) -> int:
	if _rules == null:
		return 0
	return maxi(MatchClock.remaining(ctx.phase, phase_elapsed, _rules), 0)


## The score multiplier in force right now — 1.0 outside the Final Contract.
##
## **READ FROM `ScoreEvent`, NEVER DERIVED HERE.** The corpus's instruction for this
## story was that the phase must *read* the boundary scoring already owns rather than
## decide it again, "or the phase the HUD announces and the phase the points are paid
## at will drift". This is the announcement half asking the paying half.
func multiplier(ctx: MatchContext) -> float:
	if _rules == null:
		return 1.0
	return ScoreEvent.multiplier_at(ctx.match_tick(), _rules)


func _enter(phase: int, ctx: MatchContext) -> void:
	var from := ctx.phase
	ctx.phase = phase
	phase_elapsed = 0
	if phase == MatchPhase.Phase.WARMUP:
		_started = true
		countdown_opened.emit(PackedInt32Array(ctx.pawns.keys()), ctx)
	if phase == MatchPhase.Phase.ACTIVE:
		# **THE ORIGIN OF EVERY SCORE EVENT.** See `MatchContext.match_tick`.
		ctx.active_started_at = ctx.tick
	phase_changed.emit(from, phase, ctx)

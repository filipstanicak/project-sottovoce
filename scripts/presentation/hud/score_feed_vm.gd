## **THE GAME'S TEACHER.** GDD-06 Part 3, UI_UX_SPEC §5, TDD-11 §2.3, US-0074.
## CLIENT ONLY.
##
## Without a kill-cam, a player who dies learns nothing about what gave them away
## and a player who succeeds learns nothing about why — GDD-01 §3.2 calls that the
## "Tobias" failure, and this is the primary countermeasure. **It names good play,
## out loud, at the instant it happens.**
##
## **THE STAGGER IS THE WHOLE DESIGN AND IT LIVES HERE RATHER THAN IN THE WIDGET.**
## Four bonuses arriving together is *one* event; arriving
## `TUN-UI-SCOREFEED-STAGGER` 0.12 s apart they are *four*, each individually
## readable. That is a claim about time, and time is the view model's — a widget
## that dealt its own delays would be a second clock, and the audio (US-0075) has
## to pitch up on exactly these instants.
##
## **IT COUNTS ITS OWN CLOCK RATHER THAN READING ONE.** `Time.*` is banned from
## anything replayed and merely wrong here: the feed advances at display rate,
## which is what `update(delta)` is handed, and a wall clock would make the stagger
## drift against the frame the line is drawn on.
class_name ScoreFeedVm
extends RefCounted


## One line, from the moment it was told to the moment it stops being drawn.
## **A plain inner record, not a resource** — nothing outside this file constructs
## one and the widget only ever reads it.
class Line:
	extends RefCounted

	var key: StringName = &""
	var points: int = 0
	var penalty: bool = false
	var show_at: float = 0.0
	var dies_at: float = 0.0

	func age(now: float) -> float:
		return now - show_at


signal changed

var lines: Array[Line] = []

var _now: float = 0.0
var _pending: Array[Line] = []

## The group each pending line belongs to, and how many are already queued for it.
## **Reset by nothing** — a group id is monotonic per match, so the count for a
## group that has finished arriving is simply never asked for again.
var _in_group: Dictionary = {}


## **THE ONE ENTRY POINT, AND IT TAKES A REPORT RATHER THAN AN EVENT.** A
## `ScoreEvent` is server-side and immutable and this client never holds one; what
## arrives is `ScoreWire`'s decoding of what the server said it paid.
func report(entry: ScoreReport) -> void:
	if entry == null or entry.kind == &"":
		return
	var key := ScoreKinds.string_key(entry.kind)
	if key == &"" or not Strings.has(key):
		# **A KIND WITH NO NAME IS DROPPED, NOT DRAWN AS ITS ID.** `Strings.get_text`
		# returns the key on a miss so a missing string is visible in a screenshot —
		# right everywhere else, and wrong here: `bonus.closecall` in the feed reads
		# as a bonus called that, and this element exists to teach vocabulary.
		Log.error("no bonus name for %s" % entry.kind, &"hud")
		return
	var count := int(_in_group.get(entry.group, 0))
	_in_group[entry.group] = count + 1
	var line := Line.new()
	line.key = key
	line.points = entry.points
	line.penalty = entry.is_penalty()
	line.show_at = _now + float(count) * Tuning.ui_audio.scorefeed_stagger
	line.dies_at = line.show_at + Tuning.ui_audio.scorefeed_duration
	_pending.append(line)


## Advance at display rate. **Promote, then expire, then cap** — in that order,
## because a line promoted into a full feed must push the oldest out on the same
## frame rather than being dropped before anybody sees it.
func update(delta: float) -> void:
	_now += maxf(delta, 0.0)
	var before := lines.size()
	_promote()
	var kept: Array[Line] = []
	for line: Line in lines:
		if _now < line.dies_at:
			kept.append(line)
	lines = kept
	_cap()
	if lines.size() != before or not _pending.is_empty():
		changed.emit()


func now() -> float:
	return _now


## Everything whose stagger has elapsed, oldest first.
func _promote() -> void:
	var still: Array[Line] = []
	for line: Line in _pending:
		if line.show_at <= _now:
			lines.append(line)
		else:
			still.append(line)
	_pending = still


## **THE OLDEST GOES, NEVER THE NEWEST.** `TUN-UI-SCOREFEED-MAX-LINES` 4 exists
## because GDD-01 §5 names "the subtle break": a player receiving a prey warning, a
## Compass acceleration and three feed lines at once is receiving nothing. Dropping
## the *newest* would be cheaper and would silently delete the bonus the player
## just earned, which is the one they are looking for.
func _cap() -> void:
	var most := maxi(Tuning.ui_audio.scorefeed_max_lines, 1)
	if lines.size() <= most:
		return
	lines = lines.slice(lines.size() - most)

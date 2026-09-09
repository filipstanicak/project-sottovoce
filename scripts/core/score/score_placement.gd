## **WHO CAME WHERE, AND WHAT A TIE MEANS.** US-0077. PURE Core.
##
## `ScoreFold` answers *how much*; this answers *what place*, and it is a separate
## class for the reason `ScoreAward` is separate from `ScoreEvent`: folding is
## arithmetic over events and placing is a rule about players, including players the
## log never mentions.
##
## **IT IS NOT ON THE WIRE, AND THAT IS THE STRONGER CHOICE — THE SAME ONE THE
## MULTIPLIER GOT.** `NET-S2C-MATCH-END` already carries every event and every slot,
## so both peers can derive the standings from identical inputs with identical code.
## Sending a computed placement would be a second source of truth for something two
## fields already imply, and the first time the two disagreed the screen would show a
## rank the totals beside it contradict.
##
## **A PLAYER WHO SCORED NOTHING IS STILL IN THE MATCH**, which is why `slots` is an
## argument rather than being read off the events. `ScoreFold.fold` only knows about
## actors who earned something; a player who died six times and scored zero has no
## event at all and must still appear, last, on nought.
class_name ScorePlacement
extends RefCounted


## `[{slot, points, place}]`, best first. Standard competition ranking.
##
## **EQUAL TOTALS SHARE THE HIGHER PLACE AND THE NEXT DISTINCT TOTAL SKIPS: 1, 1, 3.**
## The alternative is a tie-break, and a tie-break is **a scoring rule invented at the
## results screen**. This game is *"decided by score, not kills"* — its own thesis —
## so breaking a tie on deaths would make the match partly decided by deaths, and
## breaking it on time spent Anonymous would decide it on a number that is displayed
## beside the placement as a separate fact. TDD-10 §3.1 already refused the two
## obvious tie-breaks for the kill contest on the same grounds: join order hands one
## player every tie for the whole match, and a coin makes a decision random. **Here
## there is a third answer neither of those had: say that the game did not separate
## them.** If two players tie, that is the true outcome and the screen should show it.
##
## **THE ORDER WITHIN A TIE GROUP IS BY SLOT, AND IT IS PRESENTATION ONLY.** Two rows
## have to be drawn in some order; the *place* is what is equal, and both sides sort
## the same way so the two screens list the same names in the same order. Slot order
## decides nothing, because nothing above reads it.
static func standings(events: Array[ScoreEvent], slots: Array) -> Array:
	var totals := ScoreFold.fold(events)
	var rows: Array = []
	for slot: int in slots:
		rows.append({"slot": slot, "points": int(totals.get(slot, 0)), "place": 0})
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return (
				int(a["points"]) > int(b["points"])
				if int(a["points"]) != int(b["points"])
				else int(a["slot"]) < int(b["slot"])
			)
	)
	_number_the_rows(rows)
	return rows


## **THE PLACE IS THE COUNT OF PLAYERS STRICTLY AHEAD, PLUS ONE.** Written that way
## rather than as "increment unless equal to the previous", because the second form
## is where an off-by-one lives: after two players share first, the third's place is
## **3** and an incrementing counter would say 2 unless it also remembered how many
## rows the tie held.
static func _number_the_rows(rows: Array) -> void:
	var ahead := 0
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		if i > 0 and int(row["points"]) != int((rows[i - 1] as Dictionary)["points"]):
			ahead = i
		row["place"] = ahead + 1


## What place this slot finished in, or **0 for a slot that was not in the match** —
## never 1, which is what a lookup with a zero default would answer for a stranger.
static func place_for(events: Array[ScoreEvent], slots: Array, slot: int) -> int:
	for row: Dictionary in standings(events, slots):
		if int(row["slot"]) == slot:
			return int(row["place"])
	return 0


## True when nobody finished alone at the top. **The results screen has to know**:
## a winner's treatment applied to two players reads as a bug, and applied to neither
## reads as a screen that forgot to say who won.
static func is_shared_win(events: Array[ScoreEvent], slots: Array) -> bool:
	var rows := standings(events, slots)
	if rows.size() < 2:
		return false
	return int((rows[1] as Dictionary)["place"]) == 1

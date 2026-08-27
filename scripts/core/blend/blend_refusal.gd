## **WHY AN `INPUT-BLEND` PRESS DID NOT TAKE.** GDD-03 §4.1.4, US-0054. PURE Core.
##
## **"REFUSED WITH DISTINCT FEEDBACK, NOT SILENCE"** is US-0054's third criterion,
## and it exists because of a specific moment: you run for the hay cart with a
## hunter behind you, press blend, and nothing happens. Without a reason the game
## has told you *the button is broken*; with one it has told you *somebody is
## already in there*, which is a fact about the world you can act on.
##
## **THIS IS `KillVerdict`'s SHAPE AND NOT ITS RULE.** A rejected kill must be
## indistinguishable from every other rejected kill, because the answer would
## otherwise be an identity probe (`StunVerdict`). A rejected blend has no such
## problem: the prop is level geometry, its occupancy is not a secret, and a
## player standing in front of a full hay cart can see there is no room. Telling
## them costs nothing and withholding it costs a moment of confusion at the worst
## possible time.
class_name BlendRefusal
extends RefCounted

enum Why {
	## The press took. Not a refusal; present so a caller can return one value.
	TAKEN,
	## Nothing blendable within reach — no pocket, no group, no prop.
	NOTHING_HERE,
	## `TUN-BLEND-PROP-CAPACITY`. **Somebody else is already inside**, and this is
	## the one the criterion is really about: it is the only refusal caused by
	## another player rather than by where you are standing.
	PROP_OCCUPIED,
	## `TUN-BLEND-PROP-EXIT-VULN`. You left this prop less than half a second ago.
	## Door-flickering to dodge a kill is what the window exists to stop.
	PROP_TOO_SOON,
	## You are dead, respawning, stunned or mid-animation.
	BUSY,
}


static func is_refusal(why: Why) -> bool:
	return why != Why.TAKEN


## Does the player get told *something specific*? Everything but `TAKEN`.
##
## **`NOTHING_HERE` IS IN THE LIST DELIBERATELY.** It is the commonest press in the
## game — a player mashing blend while crossing a street — and answering it with
## silence is what teaches them the button is unreliable.
static func has_feedback(why: Why) -> bool:
	return why != Why.TAKEN


## For `TEL-BLEND-REFUSED` and for test failure messages.
static func name_of(why: Why) -> StringName:
	return Why.keys()[why] as StringName

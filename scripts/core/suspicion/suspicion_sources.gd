## **WHY A PLAYER IS VISIBLE, AS FIVE BITS.** NETWORK_PROTOCOL §4, UI_UX_SPEC
## §4.1, US-0052. PURE.
##
## `active_sources` drives the HUD's source list — the two words under the tier
## that answer *"why am I visible?"* before the player has to ask. GDD-03 §13's
## failure mode 3 is **suspicion is opaque**: a player who cannot attribute their
## suspicion cannot learn from it, and the total alone is not attributable.
##
## **THE LIST AND THE NUMBER ARE ONE DECISION, NOT TWO.**
## `SuspicionMath.gain_rate()` sums the rates of exactly the bits `of()` sets, so
## a HUD reading "sprinting · alone" beside a value that rose for some other
## reason is not a defect this project can have. Two functions applying the same
## conditions independently is how a source list drifts from the number it
## explains — silently, with no error, and only ever in the direction of a player
## learning not to trust the channel.
##
## **THE BIT ORDER IS THE WIRE.** §4 lists them `SPRINT ROOF CLIMB OPEN RUN`, and
## that is bit 0 upward. Reordering is not a refactor: a peer on a different build
## during a rolling restart would print the wrong words, and every misread bit is
## a plausible one.
class_name SuspicionSources
extends RefCounted

const NONE := 0
const SPRINT := 1 << 0
const ROOF := 1 << 1
const CLIMB := 1 << 2
const OPEN := 1 << 3
const RUN := 1 << 4

## Every bit, in wire order. The *words* are `data/strings/en.csv`'s job — never
## this file's, and never a widget's.
const ALL: Array[int] = [SPRINT, ROOF, CLIMB, OPEN, RUN]


## Which sources are contributing this tick.
##
## **ZERO WHILE BLENDING**, because the crush overrides gain outright: a source
## list naming reasons the value is *not* rising would be the opposite of an
## explanation. `SuspicionMath.integrate()` early-returns on the same flag, so the
## two agree by construction rather than by both remembering to check.
##
## **RUN, SPRINT AND CLIMB ARE MUTUALLY EXCLUSIVE** because they are states and a
## pawn is in one state. Roof and open are *conditions*, and either can accompany
## any of them — which is ASM-0018's compounding, expressed as bits.
static func of(s: SuspicionState, t: SuspicionTuning) -> int:
	if s.blending:
		return NONE
	var bits := NONE
	if s.speed_state == PawnStateId.RUN:
		bits |= RUN
	elif s.speed_state == PawnStateId.SPRINT:
		bits |= SPRINT
	elif s.speed_state == PawnStateId.CLIMB:
		bits |= CLIMB
	if s.on_roof:
		bits |= ROOF
	if s.nearest_npc_distance > t.open_radius:
		bits |= OPEN
	return bits


## Points per second for one bit. Unknown bits are worth nothing rather than
## erroring: the wire is a byte and three of its eight values are undeclared.
static func rate_of(bit: int, t: SuspicionTuning) -> float:
	match bit:
		SPRINT:
			return t.gain_sprint
		ROOF:
			return t.gain_roof
		CLIMB:
			return t.gain_climb
		OPEN:
			return t.gain_open
		RUN:
			return t.gain_run
	return 0.0


## **ADDITIVE, NOT MAX-OF-SOURCES** (ASM-0018). A sprinting player on a roof with
## nobody nearby pays 25 + 18 + 6 = 49/s and is Exposed in 1.4 s. Taking the
## maximum would make the second bad choice free, and compounding bad choices is
## exactly what should compound.
static func rate(bits: int, t: SuspicionTuning) -> float:
	var total := 0.0
	for bit: int in ALL:
		if (bits & bit) != 0:
			total += rate_of(bit, t)
	return total

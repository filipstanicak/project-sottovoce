## **THE `SCORE-` IDS IN WIRE ORDER, AND THE STRING KEY EACH ONE DISPLAYS UNDER.**
## `NET-S2C-SCORE-EVENT`, US-0074. PURE.
##
## `NETWORK_PROTOCOL.md` §4 declares the score event's `kind` as a **`u8`**, so
## something has to turn a `SCORE-` id into a byte and back. That mapping is a
## **protocol ordering**: a client decodes byte 3 as whatever byte 3 meant when it
## was built, so `ALL` may be appended to and may never be reordered. Moving one
## row renames every bonus in the feed at once, and nothing errors — the feed just
## says `Patient` where the server paid `Focus`.
##
## **THE DISPLAY KEY IS DERIVED RATHER THAN TABULATED**, which is the half worth
## knowing. A second hand-written list mapping seventeen ids to seventeen string
## keys is seventeen chances to mistype one, and the symptom is a feed line reading
## `bonus.fromabove` in front of a player. `SCORE-FROMABOVE` becomes
## `bonus.fromabove` by construction, so the only way to break it is to add an id
## with no row in the string table — which `test_bonus_names_exist.gd` refuses.
class_name ScoreKinds
extends RefCounted

## **APPEND ONLY. NEVER REORDER.** Index is the wire byte.
##
## Every `SCORE-` id in `Ids`, including the two ADR-0014 dormants and the death
## marker — a kind that exists but is not yet paid still needs a stable byte, or
## the day it is paid every byte after it shifts.
const ALL: Array[StringName] = [
	Ids.SCORE_CONTRACT,
	Ids.SCORE_SILENT,
	Ids.SCORE_PATIENT,
	Ids.SCORE_MASKED,
	Ids.SCORE_FOCUS,
	Ids.SCORE_FROMABOVE,
	Ids.SCORE_BLENDED,
	Ids.SCORE_LONGHUNT,
	Ids.SCORE_VENDETTA,
	Ids.SCORE_POISONED,
	Ids.SCORE_VARIETY,
	Ids.SCORE_HALFSEEN,
	Ids.SCORE_RECKLESS,
	Ids.SCORE_STUN,
	Ids.SCORE_ESCAPE,
	Ids.SCORE_CLOSECALL,
	Ids.SCORE_DEATH,
]

## An id nothing in `ALL` matches. **255 rather than 0**, because 0 is
## `SCORE-CONTRACT` — the commonest event in the game and the worst thing for an
## unknown byte to decode as.
const UNKNOWN := 255

const PREFIX := "SCORE-"
const NAMESPACE := "bonus."


static func to_byte(kind: StringName) -> int:
	var at := ALL.find(kind)
	return UNKNOWN if at < 0 else at


## **AN UNKNOWN BYTE IS `&""`, NOT A GUESS.** A client built against an older
## `ALL` receiving a newer kind must draw nothing rather than the wrong name; a
## feed that invents a bonus teaches the player something false, which is worse
## than a feed that misses a line.
static func from_byte(value: int) -> StringName:
	if value < 0 or value >= ALL.size():
		return &""
	return ALL[value]


## The string-table key this kind displays under, e.g. `bonus.fromabove`.
## `Strings.NAMESPACES` reserves `bonus` for exactly this.
static func string_key(kind: StringName) -> StringName:
	var id := String(kind)
	if not id.begins_with(PREFIX):
		return &""
	return StringName(NAMESPACE + id.substr(PREFIX.length()).to_lower())

## **EVERY `ABIL-` ID AS A WIRE BYTE.** `ScoreKinds`' shape, for the same reason and
## with the same hazard. PURE Core.
##
## A loadout has to reach a client at the end of a match — US-0077 asks the results
## screen for *retrospective kit-reading*, which is the one moment this game hands
## out a kit for free, deliberately: GDD-04 §5.1 makes reading a kit **during** play
## a skill, and the results screen is where the answer is finally allowed.
##
## **APPEND ONLY. NEVER REORDER.** The index is the byte, so inserting a name in the
## middle silently retells every client which ability somebody carried — the same
## hazard as `PawnStateId.ALL`, `MatchPhase.Phase` and `ContractSystem.Reason`, in a
## fourth place.
##
## **ALL FIVE ARE LISTED, INCLUDING THE TWO THAT ARE NOT BUILT.**
## `ABIL-WHISPERBOLT` was deferred by ADR-0013 and `ABIL-NIGHTSHADE` is post-MVP; a
## kind that exists and is not yet carried still needs a stable byte, or the day it
## is carried every byte after it shifts. `ScoreKinds` says the same thing about its
## two dormant bonuses.
class_name AbilityKinds
extends RefCounted

const ALL: Array[StringName] = [
	Ids.ABIL_CINDERFALL,
	Ids.ABIL_LUNGE,
	Ids.ABIL_NIGHTSHADE,
	Ids.ABIL_SECONDFACE,
	Ids.ABIL_WHISPERBOLT,
]

## An id nothing in `ALL` matches. **255 rather than 0**, because 0 is
## `ABIL-CINDERFALL` — the ability every player carries today, and the worst thing
## for an unknown byte to decode as.
const UNKNOWN := 255


static func to_byte(id: StringName) -> int:
	var at := ALL.find(id)
	return UNKNOWN if at < 0 else at


static func from_byte(byte: int) -> StringName:
	return ALL[byte] if byte >= 0 and byte < ALL.size() else &""

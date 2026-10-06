## **WHICH GROUP A CIVILIAN BELONGS TO, AS THE WIRE'S `u8`.** US-0107,
## `NET-S2C-CROWD-GROUPS`. PURE.
##
## The reference draws a faint white net on the ground under every group a player
## can blend with and under every bench, and greys the blended player's own group
## on their screen alone (the owner's reading of the reference, 2026-10-06). A
## client can draw neither from positions: which civilians form a walking group,
## which stand together closely enough to hide among, and who holds which seat are
## decided on the server. So the server tags each NPC and the client draws from the
## tags.
##
## **MEMBERSHIP, NEVER PROXIMITY** (review of #252). The first version told the
## client only which civilians could each anchor a pocket, and the client guessed
## the rest from distances: a pocket the server granted greyed one of its four
## civilians, and a passer-by at a counter was greyed as a sitter. Every value here
## now says what the civilian *is*.
##
## **THE VALUES ARE THE PROTOCOL.** `NONE` is zero for `BlendKind`'s reason — an
## unwritten byte must read as *no group*.
class_name BlendGroupTag
extends RefCounted

## Walking, startled, gawking: in no group, and supporting no blend a client draws.
const NONE := 0
## Standing in a knot a pocket can be taken in: within `TUN-BLEND-POCKET-RADIUS` of
## a standing civilian who has `TUN-BLEND-POCKET-MIN-NPC` standing civilians round
## it. The net lies under these.
const STANDING := 1
## Standing, in no such knot. No net; still one of the people a pocket rests on.
const STILL := 2
## Walking group `g` is `FORMATION_BASE + g`.
const FORMATION_BASE := 3
## Holding static prop `p` — a bench seat or a stall counter — is `PROP_BASE + p`.
const PROP_BASE := 64


static func formation(group: int) -> int:
	return FORMATION_BASE + group if group >= 0 and group < PROP_BASE - FORMATION_BASE else NONE


static func is_formation(tag: int) -> bool:
	return tag >= FORMATION_BASE and tag < PROP_BASE


static func prop(spot: int) -> int:
	return PROP_BASE + spot if spot >= 0 and spot <= 255 - PROP_BASE else NONE


static func is_prop(tag: int) -> bool:
	return tag >= PROP_BASE


## The static prop a `prop()` tag holds, or -1.
static func prop_of(tag: int) -> int:
	return tag - PROP_BASE if is_prop(tag) else -1


## Standing still in the world: in a knot, alone, or holding a seat or counter.
static func is_standing(tag: int) -> bool:
	return tag == STANDING or tag == STILL or is_prop(tag)

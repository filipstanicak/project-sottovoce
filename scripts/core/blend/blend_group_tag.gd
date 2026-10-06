## **WHICH GROUP A CIVILIAN BELONGS TO, AS THE WIRE'S `u8`.** US-0107,
## `NET-S2C-CROWD-GROUPS`. PURE.
##
## The reference draws a faint white net on the ground under every group a player
## can blend with and under every bench, and greys the blended player's own group
## on their screen alone (the owner's reading of the reference, 2026-10-06). A
## client can draw neither from positions: which civilians form a walking group,
## and which stand together closely enough to hide among, is decided on the server.
## So the server tags each NPC and the client draws from the tags.
##
## **THE VALUES ARE THE PROTOCOL.** `NONE` is zero for `BlendKind`'s reason — an
## unwritten byte must read as *no group* — and walking groups are numbered from
## `FORMATION_BASE`, so a map with more circuits needs no new value.
class_name BlendGroupTag
extends RefCounted

## In no group.
const NONE := 0
## Standing among enough other standing civilians to be a crowd pocket.
const STANDING := 1
## Walking group `g` is `FORMATION_BASE + g`.
const FORMATION_BASE := 2


static func formation(group: int) -> int:
	return FORMATION_BASE + group


static func is_formation(tag: int) -> bool:
	return tag >= FORMATION_BASE

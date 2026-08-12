## The `InputCommand.buttons` bitfield. TDD-03 §5, NETWORK_PROTOCOL §2 `NET-C2S-INPUT`.
##
## **THE ORDER IS THE WIRE FORMAT.** These bit positions are serialised into a
## `u16` and read by a peer that may be running a different build during a
## rolling restart. Reordering them is not a refactor; it silently remaps every
## button — a client's SLOW would arrive as the server's RUN — and nothing
## crashes, because every value is a valid bitfield.
##
## Append only, and only up to bit 15.
##
## The bit names are the `INPUT-` IDs with the prefix dropped. `Ids` holds the
## IDs themselves; `InputActions` maps one to the other and is where the
## correspondence is asserted, so this file stays a list of numbers.
class_name InputBits
extends RefCounted

const NONE: int = 0

const SLOW: int = 1 << 0
const RUN: int = 1 << 1
const SPRINT: int = 1 << 2
const TRAVERSE: int = 1 << 3
const KILL: int = 1 << 4
const STUN: int = 1 << 5
const BLEND: int = 1 << 6
const ABILITY_1: int = 1 << 7
const ABILITY_2: int = 1 << 8
const SCAN: int = 1 << 9

## `INPUT-RUN` pulled PAST `TUN-SPEED-TRIGGER-RUN`, not merely pressed.
##
## Appended after the ten in TDD-03 §5, because GDD-02 §1.3 requires something
## those ten cannot express: *"partial pull = jog, full pull = run"*. The ladder
## escalates Jog → Run on a sustained `RUN`, so a pad player holding a half-pulled
## trigger would be dragged to Run against their intent — losing exactly the fine
## speed control §1.3 calls the analogue advantage.
##
## A keyboard press has strength 1.0, so KBM sets this whenever it sets `RUN` and
## behaves precisely as before. Appending is safe by construction; reordering is
## not (see above).
## **DEPRECATED 2026-08-12, and the bit is retired rather than reused.** It
## qualified `RUN` as a full trigger pull, which is what escalated Jog to Run.
## With the Jog rung gone `TUN-SPEED-TRIGGER-RUN` decides whether the trigger is
## held at all, and there is no second grade of held. Absent from `ALL`, so it
## reaches no wire and no state.
const RUN_FULL: int = 1 << 10

## The highest bit the wire format can carry. `buttons` is a `u16`.
const MAX_BIT: int = 15

## Every declared bit, in wire order. Used by the guards; nothing on the hot path
## reads this.
##
## FIFTEEN ACTIONS EXIST AND TEN ARE HERE. `INPUT-SHOULDER`, `INPUT-SCORE` and
## `INPUT-MENU` are bound and rebindable like the rest, but they change the
## camera, the scoreboard and the pause menu — nothing the server simulates;
## `INPUT-MOVE` and `INPUT-LOOK` are axes and travel in their own fields. An
## action reaches the wire only if it changes `step()`, because every bit here is
## bandwidth spent 60 times a second per client, forever.
const ALL: Array[int] = [SLOW, RUN, SPRINT, TRAVERSE, KILL, STUN, BLEND, ABILITY_1, ABILITY_2, SCAN]


## Bits set in `buttons` that are not held in `previous` — the presses that began
## this tick. Edge detection belongs here rather than in the sampler because the
## server needs it too: it receives held state, not events.
static func newly_pressed(buttons: int, previous: int) -> int:
	return buttons & ~previous


static func is_set(buttons: int, bit: int) -> bool:
	return (buttons & bit) != 0


## Set or clear `bit`, returning the new field. Pure; `buttons` is not mutated.
static func with(buttons: int, bit: int, on: bool) -> int:
	return (buttons | bit) if on else (buttons & ~bit)

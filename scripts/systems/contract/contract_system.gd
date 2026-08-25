## **`SYS-CONTRACT`. THE SERVER SYSTEM AROUND `ContractCycle`.** TDD-10 §5,
## GDD-03 §7.3, US-0050. SERVER ONLY.
##
## Registered at the `contract` stage, which `SystemOrder` puts **after** `combat`
## for one reason: the cycle must be repaired in the same tick the death resolves,
## so the invariant never lapses at a tick boundary.
##
## **A REMOVAL IS NOT A REBUILD, AND THAT IS WHAT MAKES BOTH RULES TRUE AT ONCE.**
## US-0050 asks for repair in the *same tick* and for events inside
## `TUN-CONTRACT-REPAIR-DEBOUNCE` to be batched into *one pass*, which sounds like a
## contradiction and is not. Deleting a node from a cycle leaves a cycle — the
## pursuer inherits by construction — so removals apply **immediately** and cannot
## conflict with each other. What the debounce governs is the **announcement** and
## the insertions, which are the operations that choose something.
##
## **THE KILLER AND THE INHERITING PURSUER ARE THE SAME PLAYER, BY CONSTRUCTION.**
## A contract can only be killed by its holder (TDD-10 §1), so the player who
## inherits the victim's contract is the one who just earned a breath —
## `TUN-CONTRACT-REASSIGN-DELAY`, which "converts a kill from a link in a chain into
## a moment". The graph is repaired instantly and the **telling** waits.
##
## **NOTHING KILLS ANYBODY YET.** `SYS-KILL` is US-0060's, so `report_death` has no
## caller in the shipped server — the same shape as `CrowdAlarm`, which had an entry
## point for violence through all of M3. Join and disconnect are wired and live.
class_name ContractSystem
extends GameSystem

## One player has been told who they are hunting. `contract` is a peer id;
## **mapping it to a wire slot is the sender's job**, because peer ids never reach
## the wire (US-0029).
signal contract_issued(peer: int, contract: int, reason: int)

## Why a contract was issued. **Appended, never inserted**: the ordinals travel on
## the wire as `NET-S2C-CONTRACT-ASSIGNED`'s `reason:u8`, and they are the same four
## `EVT-CONTRACT-ASSIGNED` declares.
enum Reason { START, KILL, RESPAWN, REPAIR }

var cycle: ContractCycle = null

## peer -> the contract that peer has actually been told about. The graph may be
## ahead of this for up to `TUN-CONTRACT-REASSIGN-DELAY`, which is the breath.
var _announced: Dictionary = {}

## peer -> the tick before which nothing may be announced to them.
var _held_until: Dictionary = {}

## peer -> why their next announcement happens, so a kill does not report itself as
## a repair.
var _reason: Dictionary = {}

## `[peer, killer, reason]` waiting for the debounce window to close.
var _pending: Array = []

## The tick the current debounce window closes on, or −1 when none is open.
var _window_closes: int = -1


func stage() -> StringName:
	return &"contract"


func setup(ctx: MatchContext) -> void:
	cycle = ContractCycle.new(ctx.rng)


## Match start. **The opening deal is announced immediately** — there is nothing to
## debounce against and no breath owed, and a player who reaches their first tick
## without a contract has no game to play.
func open(peers: PackedInt32Array, ctx: MatchContext) -> void:
	cycle.tick = ctx.tick
	cycle.open(peers)
	_announced.clear()
	_held_until.clear()
	_reason.clear()
	_pending.clear()
	_window_closes = -1
	for peer: int in peers:
		_reason[peer] = Reason.START
	_announce_what_changed(ctx)


## A death. **Applied to the graph now, in this tick**, which is the whole reason
## `combat` is ordered before `contract`.
##
## **AND ANYONE POINTED AT THE VICTIM IS CLEARED IN THE SAME BREATH.** The first
## version held the killer's *new* contract for `TUN-CONTRACT-REASSIGN-DELAY` and
## left their *old* one standing, so for three seconds a hunter's Compass pointed
## at the corpse they had just made. The delay is meant to be a moment of nothing —
## "it converts a kill from a link in a chain into a moment" — not a moment aimed
## at a dead player. Caught by the one assertion that swept every tick rather than
## the settled state.
func report_death(victim: int, killer: int, ctx: MatchContext) -> void:
	cycle.tick = ctx.tick
	if not cycle.remove(victim):
		return
	_announced.erase(victim)
	var why: int = Reason.KILL if killer != ContractCycle.NOBODY else Reason.REPAIR
	_forget_anyone_hunting(victim, why)
	if killer != ContractCycle.NOBODY and cycle.has(killer):
		_held_until[killer] = ctx.tick + Tuning.ticks(&"TUN-CONTRACT-REASSIGN-DELAY")
		_reason[killer] = Reason.KILL
	_open_window(ctx)


## **NOBODY IS EVER POINTED AT SOMEBODY WHO IS NOT LIVING.** Slot 0 is "nobody" on
## the wire, so a clear is an ordinary `NET-S2C-CONTRACT-ASSIGNED` rather than a
## second message kind — and the client's Compass has one rule instead of two.
func _forget_anyone_hunting(gone: int, why: int) -> void:
	for other: int in _announced.keys():
		if int(_announced[other]) != gone:
			continue
		_announced[other] = ContractCycle.NOBODY
		contract_issued.emit(other, ContractCycle.NOBODY, why)


## A disconnect is a death that does not respawn — GDD-03 §7.3. **The pursuer is
## not punished for their target quitting**: they inherit the next contract and are
## told at the debounce boundary, with no breath, because they did not earn one.
func report_disconnect(peer: int, ctx: MatchContext) -> void:
	report_death(peer, ContractCycle.NOBODY, ctx)


## A respawn. Queued rather than applied, because an insertion **chooses** a
## position and two choices made in the same window can conflict.
func report_respawn(peer: int, killer: int, ctx: MatchContext) -> void:
	_pending.append([peer, killer, Reason.RESPAWN])
	_open_window(ctx)


func report_join(peer: int, ctx: MatchContext) -> void:
	_pending.append([peer, ContractCycle.NOBODY, Reason.RESPAWN])
	_open_window(ctx)


## Close the debounce window if it is due, then tell whoever the graph has moved.
func tick(ctx: MatchContext, _dt: float) -> void:
	cycle.tick = ctx.tick
	if _window_closes >= 0 and ctx.tick >= _window_closes:
		_close_window(ctx)
	_announce_what_changed(ctx)


## Who `peer` is hunting **as the graph sees it**, which may be ahead of what they
## have been told.
func contract_of(peer: int) -> int:
	return cycle.contract_of(peer) if cycle != null else ContractCycle.NOBODY


## Who `peer` has actually been told they are hunting. **The Compass follows this
## one**, or `TUN-CONTRACT-REASSIGN-DELAY` would not exist as a felt thing.
func announced_contract_of(peer: int) -> int:
	return int(_announced.get(peer, ContractCycle.NOBODY))


## **ONE WINDOW, RE-ARMED BY NOTHING.** A second event inside an open window joins
## it rather than extending it, so a stream of deaths cannot postpone every
## announcement indefinitely.
func _open_window(ctx: MatchContext) -> void:
	if _window_closes >= 0:
		return
	_window_closes = ctx.tick + maxi(Tuning.ticks(&"TUN-CONTRACT-REPAIR-DEBOUNCE"), 1)


## Every queued insertion in one pass, which is what GDD-03 §7.3's debounce is for.
func _close_window(ctx: MatchContext) -> void:
	_window_closes = -1
	if _pending.is_empty():
		return
	var insertions: Array = []
	for entry: Array in _pending:
		insertions.append([entry[0], entry[1]])
		_reason[entry[0]] = entry[2]
	_pending.clear()
	cycle.tick = ctx.tick
	cycle.apply(PackedInt32Array(), insertions)


## Tell every player whose contract has moved since they were last told, unless
## they are inside a hold. **Nothing is announced twice**: `_announced` is the
## record of what was said, not of what is true.
func _announce_what_changed(ctx: MatchContext) -> void:
	if _window_closes >= 0:
		return
	for peer: int in cycle.living():
		if ctx.tick < int(_held_until.get(peer, 0)):
			continue
		var now := cycle.contract_of(peer)
		if now == ContractCycle.NOBODY or now == int(_announced.get(peer, ContractCycle.NOBODY)):
			continue
		_announced[peer] = now
		_held_until.erase(peer)
		var why: int = int(_reason.get(peer, Reason.REPAIR))
		_reason.erase(peer)
		contract_issued.emit(peer, now, why)

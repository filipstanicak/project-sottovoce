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
## **`ESCAPE` IS APPENDED AT INDEX 4** (US-0097). The wire field is already
## `reason:u8`, so nothing about `NET-S2C-CONTRACT-ASSIGNED`'s payload changes —
## and appending rather than inserting is what keeps every ordinal already on a
## client meaning what it meant.
## **APPEND-ONLY: THE ORDER IS THE WIRE.** `NET-S2C-CONTRACT-ASSIGNED` carries
## `reason:u8` as an index into this enum, so inserting a name in the middle
## silently retells every client a different story about why their contract moved.
## `STUNNED` was appended on 2026-09-04 by ADR-0019.
enum Reason { START, KILL, RESPAWN, REPAIR, ESCAPE, STUNNED }

var cycle: ContractCycle = null

## **`SYS-SPAWN`, OWNED AND TICKED HERE.** US-0062. TDD-01 §4's diagram has no
## spawn box at all and its stage 8 is *"Contract — repair cycle after deaths"*;
## a respawn is a repair after a death, so this is a plain object rather than a
## second `GameSystem` — `KillSystem`/`StunSystem`'s shape.
##
## **IT TICKS FIRST**, so a player whose timer expires is placed and reinserted in
## the same tick, and there is never a tick in which somebody stands on the map
## holding no contract.
var spawn := SpawnSystem.new()

## peer -> the tick before which nothing may be announced to them.
var _held_until: Dictionary = {}

## peer -> why their next announcement happens, so a kill does not report itself as
## a repair.
var _reason: Dictionary = {}

## peer -> the contract that peer has actually been told about. The graph may be
## ahead of this for up to `TUN-CONTRACT-REASSIGN-DELAY`, which is the breath.
##
## **IT IS `MatchContext.announced_contracts` ITSELF**, adopted in `setup()` rather
## than mirrored into. `SYS-DETECTION` renders from what players have been told,
## and two dictionaries holding the same thing drift the first time somebody adds
## a write to one of them.
var _published: Dictionary = {}

## Held for `_on_respawned`, which is a signal handler and therefore takes no
## context of its own. Nothing else in this system reads it — every other entry
## point is handed the context by its caller, which is what keeps the system
## askable in a test.
var _ctx: MatchContext = null

## `[peer, killer, reason]` waiting for the debounce window to close.
var _pending: Array = []

## The tick the current debounce window closes on, or −1 when none is open.
var _window_closes: int = -1


func stage() -> StringName:
	return &"contract"


func setup(ctx: MatchContext) -> void:
	spawn.setup(ctx)
	# **CONNECTED HERE RATHER THAN IN `server_root`**, because the insertion must
	# happen inside this system's own tick to land in the same tick as the
	# placement. A wiring in the root would run whenever the signal happened to be
	# emitted, which is the same tick today and would stop being so the first time
	# anything moved.
	if not spawn.respawned.is_connected(_on_respawned):
		spawn.respawned.connect(_on_respawned)
	_setup_rest(ctx)


func _on_respawned(peer: int, _at: Vector3, killer: int) -> void:
	if _ctx != null:
		report_respawn(peer, killer, _ctx)


func _setup_rest(ctx: MatchContext) -> void:
	_ctx = ctx
	cycle = ContractCycle.new(ctx.rng)
	# **THE ANNOUNCED VIEW GOES ON THE CONTEXT**, because `SYS-DETECTION` renders
	# from what players have been told rather than from what the graph holds, and a
	# system whose answers come from another system's field cannot be asked a
	# question in a test.
	_published = ctx.announced_contracts


## Match start. **The opening deal is announced immediately** — there is nothing to
## debounce against and no breath owed, and a player who reaches their first tick
## without a contract has no game to play.
func open(peers: PackedInt32Array, ctx: MatchContext) -> void:
	cycle.tick = ctx.tick
	cycle.open(peers)
	_published.clear()
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
	_published.erase(victim)
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
	for other: int in _published.keys():
		if int(_published[other]) != gone:
			continue
		_published[other] = ContractCycle.NOBODY
		contract_issued.emit(other, ContractCycle.NOBODY, why)


## A disconnect is a death that does not respawn — GDD-03 §7.3. **The pursuer is
## not punished for their target quitting**: they inherit the next contract and are
## told at the debounce boundary, with no breath, because they did not earn one.
func report_disconnect(peer: int, ctx: MatchContext) -> void:
	report_death(peer, ContractCycle.NOBODY, ctx)


## **THE PREY GOT AWAY. STRUCTURALLY THIS IS A RESPAWN WITHOUT A DEATH.** US-0097,
## ADR-0014. The hunter leaves the cycle and is queued for reinsertion through the
## same two calls a respawn uses, so the 10 000-event fuzz covers escapes too.
##
## **THE CLEAR IS IMMEDIATE AND THE NAME WAITS**, which is the shape a kill already
## has: `_announce_what_changed` walks `cycle.living()` and the hunter is not in it
## between the removal and the reinsertion, so their clear is emitted here or not
## at all — and a Compass still pointing at somebody who escaped is the defect this
## line exists to prevent.
##
## **NOTHING FORBIDS THE REPEAT EXPLICITLY, AND NOTHING NEEDS TO.** US-0097 says
## `_choose_index`'s `killer` constraint generalises; **it does not** — that one
## forbids a *predecessor*, and what an escape must forbid is the hunter's
## *successor* being the prey they just lost. What actually delivers it is the
## anti-repeat history: `_held_recently(peer, successor)` filters at the first
## relaxation stage, and the hunter's history already holds that prey from when the
## contract was issued. The right guarantee by a different mechanism than the story
## named.
func report_escape(hunter: int, ctx: MatchContext) -> void:
	_lose_the_prey(hunter, ctx, Reason.ESCAPE)


## **THE PREY FOUGHT BACK, AND THAT IS THE SAME EVENT.** ADR-0019. A stunned
## pursuer fails the contract and is dealt a new one, which is what the reference
## does — being stunned there costs you the target, not merely four seconds.
##
## **IT IS DELIBERATELY THE ESCAPE'S OWN CALL RATHER THAN A SECOND ROUTE.** The
## clear, the anti-repeat memory, the reassign breath and the reinsertion are one
## rule that has been fuzzed over 10 000 events; a stun-shaped copy of it would be
## the *rule implemented twice* this project keeps finding, and the half that would
## drift first is the memory — the line that stops the hunter being handed straight
## back the person who just put them on the ground.
##
## **THE EXILE STAYS AND IS NOT NOW REDUNDANT.** `TUN-STUN-LOCKOUT` 12 s blocks
## that pursuer from initiating on that specific player, which still binds if the
## cycle later deals them back together — and removing it to tidy up would be
## exactly the weakening never-do #13 forbids.
##
## **THE PREY IS PAID ONCE.** `TUN-SCORE-STUN` 200 already prices this read;
## paying `SCORE-ESCAPE` on top would pay the same act twice under two names.
func report_stun(pursuer: int, ctx: MatchContext) -> void:
	_lose_the_prey(pursuer, ctx, Reason.STUNNED)


func _lose_the_prey(hunter: int, ctx: MatchContext, why: Reason) -> void:
	cycle.tick = ctx.tick
	# **TELL THE HISTORY BEFORE THE REMOVAL, OR IT NEVER LEARNS.** `_remember` is
	# written by `insert` and `open` alone, so it records what was *dealt* rather
	# than what was *held* — and a hunter who lost their prey to a chase acquired
	# nothing by insertion. Without this line the reinsertion may legally hand the
	# same prey straight back, which is not a subtle failure: it deletes the escape.
	cycle.remember(hunter, cycle.contract_of(hunter))
	if not cycle.remove(hunter):
		return
	if int(_published.get(hunter, ContractCycle.NOBODY)) != ContractCycle.NOBODY:
		_published[hunter] = ContractCycle.NOBODY
		contract_issued.emit(hunter, ContractCycle.NOBODY, why)
	_pending.append([hunter, ContractCycle.NOBODY, why])
	_held_until[hunter] = ctx.tick + Tuning.ticks(&"TUN-CONTRACT-REASSIGN-DELAY")
	_open_window(ctx)


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
	spawn.tick(ctx)
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
	return int(_published.get(peer, ContractCycle.NOBODY))


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
## they are inside a hold. **Nothing is announced twice**: `_published` is the
## record of what was said, not of what is true.
func _announce_what_changed(ctx: MatchContext) -> void:
	if _window_closes >= 0:
		return
	for peer: int in cycle.living():
		if ctx.tick < int(_held_until.get(peer, 0)):
			continue
		var now := cycle.contract_of(peer)
		if now == ContractCycle.NOBODY or now == int(_published.get(peer, ContractCycle.NOBODY)):
			continue
		_published[peer] = now
		_held_until.erase(peer)
		# **THE HUNT CLOCK STARTS WHEN THE CONTRACT IS ANNOUNCED, NOT WHEN THE GRAPH
		# CHANGED** (US-0065). `TUN-CONTRACT-REASSIGN-DELAY` holds the announcement
		# for three seconds after a kill, and paying `SCORE-LONGHUNT` for a breath
		# the player spent not knowing who to look for would price the wrong thing.
		# `SYS-DETECTION` moves it later still on the first Compass lock.
		ctx.score_windows.begin_hunt(peer, ctx.tick)
		ctx.score_windows.break_focus(peer)
		var why: int = int(_reason.get(peer, Reason.REPAIR))
		_reason.erase(peer)
		contract_issued.emit(peer, now, why)

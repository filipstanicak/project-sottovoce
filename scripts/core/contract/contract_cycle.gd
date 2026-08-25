## **THE CONTRACT GRAPH, AS A SINGLE HAMILTONIAN CYCLE OVER LIVING PLAYERS.**
## GDD-03 §7, TDD-10, US-0049. PURE — no Node, no clock, no autoload but `Tuning`.
##
## `cycle = [p0, p1, ... pn-1]` and `contract(pi) = p(i+1 mod n)`. Every player has
## exactly one outgoing edge, their contract, and exactly one incoming edge, their
## pursuer. **The edges are implicit; the ordered list is the whole representation.**
##
## **THE REPAIR IS THE REMOVAL, AND THAT IS WHY A CYCLE WAS CHOSEN OVER A MATCHING.**
## Deleting a node from a cycle leaves a cycle: the victim's pursuer inherits the
## victim's contract by construction, so **no player is contractless at any
## instant** and there is no reassignment pass to get wrong. A random matching would
## need one, and would need it to run between the kill and the next tick.
##
## **A CONSTRAINT SYSTEM THAT CAN FAIL IS A CRASH WAITING FOR A PLAYTEST.**
## Insertion prefers a position that is not self, not a recent contract and not
## adjacent to the killer, and **relaxes in a fixed order** when no position
## satisfies all three. Self-assignment is the only constraint that never relaxes.
class_name ContractCycle
extends RefCounted

## The order the insertion constraints are dropped in, hardest to softest. Named
## rather than implied, because "it relaxes somehow" is how a constraint system
## acquires a failure nobody can reproduce.
enum Relaxation { ALL, WITHOUT_ANTI_REPEAT, SELF_ONLY }

## No contract. **Godot never issues peer id 0** and `SlotTable` already reserves
## zero for exactly this, so the two agree on what "nobody" looks like.
const NOBODY := 0

## **THE OWNER WRITES THIS; CORE MAY NOT READ A CLOCK.** Telemetry wants the tick a
## degeneracy happened on, and `TelemetrySink` is handed plain fields. A system with
## a `MatchContext` sets it, a test sets it, and nothing here reads `Time`.
var tick: int = 0

var _cycle: PackedInt32Array = PackedInt32Array()

## peer -> the last `TUN-CONTRACT-ANTI-REPEAT-DEPTH` contracts it has held.
var _recent: Dictionary = {}

var _rng: RandomNumberGenerator = null
var _telemetry: TelemetrySink = null

## Reported on the way down and cleared on the way back up, so a match that sits at
## two players does not emit one event per repair.
var _degenerate_reported: bool = false


func _init(rng: RandomNumberGenerator = null, telemetry: TelemetrySink = null) -> void:
	_rng = rng
	_telemetry = telemetry if telemetry != null else TelemetrySink.null_sink()


## Match start: a uniformly random permutation of the living players.
##
## **FISHER-YATES AGAINST THE SEEDED GENERATOR, NEVER `Array.shuffle()`.** That one
## draws from the global RNG, which is both never-do #8 and non-deterministic — two
## servers replaying one seed would deal different contracts and describe different
## matches.
func open(players: PackedInt32Array) -> void:
	_cycle = players.duplicate()
	_recent.clear()
	_degenerate_reported = false
	for index: int in range(_cycle.size() - 1, 0, -1):
		var swap := _rng.randi_range(0, index) if _rng != null else index
		var held := _cycle[index]
		_cycle[index] = _cycle[swap]
		_cycle[swap] = held
	# **THE OPENING DEAL IS A CONTRACT HELD, AND THE FIRST VERSION DID NOT RECORD
	# IT.** `_recent` was written only by `insert`, so at the first respawn of a
	# match the history was empty and `TUN-CONTRACT-ANTI-REPEAT-DEPTH` could only
	# avoid a repeat by luck — measured at 26 of 40, against 40 of 40 once the deal
	# is remembered. Every live-cycle assertion passed either way.
	for peer: int in _cycle:
		_remember(peer, contract_of(peer))
	_note_degeneracy()


func size() -> int:
	return _cycle.size()


## A copy, in cycle order. The caller may not hold the representation.
func living() -> PackedInt32Array:
	return _cycle.duplicate()


func has(peer: int) -> bool:
	return _cycle.has(peer)


## Who `peer` is hunting, or `NOBODY`.
##
## **`NOBODY` AT n < 2 IS NOT AN ERROR.** One living player has nobody to hunt, and
## the cyclic successor of a single-element list is itself — which would be a
## self-contract, the one thing this class must never produce.
func contract_of(peer: int) -> int:
	var index := _cycle.find(peer)
	if index < 0 or _cycle.size() < 2:
		return NOBODY
	return _cycle[(index + 1) % _cycle.size()]


## Who is hunting `peer`, or `NOBODY`.
func pursuer_of(peer: int) -> int:
	var index := _cycle.find(peer)
	if index < 0 or _cycle.size() < 2:
		return NOBODY
	return _cycle[(index - 1 + _cycle.size()) % _cycle.size()]


## Death, or a disconnect, which is a death that does not respawn.
##
## **NO REASSIGNMENT PASS.** GDD-03 §7.4: removing an element from a list whose
## successor function is cyclic successor leaves a list whose successor function is
## cyclic successor. The pursuer inherits, and that is the whole repair.
##
## **THE PEER'S CONTRACT HISTORY SURVIVES, AND THE FIRST VERSION ERASED IT.**
## `_recent` is a property of the *player*, not of the cycle, and the only reader is
## the insertion that happens when they **come back**. Clearing it on removal made
## `TUN-CONTRACT-ANTI-REPEAT-DEPTH` inert for the one case it exists for — a
## respawn — while every test of a live cycle still passed. It is cleared by `open`,
## which is where a match begins.
func remove(peer: int) -> bool:
	var index := _cycle.find(peer)
	if index < 0:
		return false
	_cycle.remove_at(index)
	_note_degeneracy()
	return true


## Respawn or mid-match join. `killer` is `NOBODY` for a join.
##
## **A JOIN IS THE SAME CALL WITH THE CONSTRAINTS VACUOUS**: a new peer has no
## recent contracts and no killer, so every position survives the filter and the
## choice is uniform — which is what GDD-03 §7.2's `on_join` does the long way
## round. One path, so a join cannot drift from a respawn.
func insert(peer: int, killer: int = NOBODY) -> bool:
	if peer == NOBODY or _cycle.has(peer):
		return false
	_cycle.insert(_choose_index(peer, killer), peer)
	_remember(peer, contract_of(peer))
	_note_degeneracy()
	return true


## **REMOVALS FIRST, THEN INSERTIONS, IN ONE PASS.** GDD-03 §7.3: several events
## inside `TUN-CONTRACT-REPAIR-DEBOUNCE` are repaired together, because a double
## kill applied as two passes produces two conflicting rebuilds. Doing every removal
## before any insertion also means a respawning player cannot be placed beside
## somebody who leaves the cycle in the same batch.
##
## `insertions` is an array of `[peer, killer]` pairs.
func apply(removals: PackedInt32Array, insertions: Array) -> void:
	for peer: int in removals:
		remove(peer)
	for pair: Array in insertions:
		insert(int(pair[0]), int(pair[1]) if pair.size() > 1 else NOBODY)


## Empty when the cycle is sound; otherwise what is wrong with it.
##
## **IT RETURNS RATHER THAN ASSERTS, AND THAT IS DELIBERATE.** GDScript strips
## `assert()` from release builds, so a validity check written as an assertion is a
## check that does not exist in the shipped game — which is exactly where a contract
## graph going wrong would cost the most and be seen the least.
func assert_valid() -> String:
	var seen: Dictionary = {}
	for peer: int in _cycle:
		if peer == NOBODY:
			return "the cycle contains NOBODY"
		if seen.has(peer):
			return "peer %d appears twice" % peer
		seen[peer] = true
	if _cycle.size() < 2:
		return ""
	for peer: int in _cycle:
		if contract_of(peer) == peer:
			return "peer %d holds a contract on itself" % peer
	return _one_cycle_only()


## **THE SUCCESSOR FUNCTION VISITS EVERYONE BEFORE RETURNING.** With a list
## representation this is true by construction, which is exactly why it is worth
## walking: the day the representation becomes a map of edges, "exactly one cycle"
## stops being free and nothing else here would notice.
func _one_cycle_only() -> String:
	var start := _cycle[0]
	var at := start
	var steps := 0
	while true:
		at = contract_of(at)
		steps += 1
		if at == start:
			break
		if steps > _cycle.size():
			return "the successor function never returns to its start"
	if steps != _cycle.size():
		return "the graph is not one cycle: %d of %d visited" % [steps, _cycle.size()]
	return ""


## Where to put `peer`, relaxing the constraints in a fixed order until something is
## legal. **The self filter is never dropped**, so the last stage cannot fail while
## there is anywhere at all to insert.
func _choose_index(peer: int, killer: int) -> int:
	var stages: Array[Relaxation] = [
		Relaxation.ALL, Relaxation.WITHOUT_ANTI_REPEAT, Relaxation.SELF_ONLY
	]
	for stage: Relaxation in stages:
		var candidates := _candidates(peer, killer, stage)
		if not candidates.is_empty():
			return candidates[_pick(candidates.size())]
	return _cycle.size()


## Every insertion index whose neighbours satisfy `stage`.
##
## Inserting at `i` makes `cycle[i-1]` the new pursuer and the old `cycle[i]` the
## new contract, so those two are the only players whose edges change.
##
## **THE KILLER MUST NOT IMMEDIATELY RE-HUNT.** Only the predecessor is checked, so
## a respawning player may be given a contract *on* their killer — GDD-03 §7.2
## forbids the killer hunting them, not the reverse, and being handed your killer is
## a revenge the design wants rather than a repeat it prevents.
func _candidates(peer: int, killer: int, stage: Relaxation) -> PackedInt32Array:
	var out := PackedInt32Array()
	var count := _cycle.size()
	if count == 0:
		return out
	for index: int in range(count + 1):
		var predecessor := _cycle[(index - 1 + count) % count]
		var successor := _cycle[index % count]
		# Never self. This filter survives every relaxation stage.
		if predecessor == peer or successor == peer:
			continue
		if stage == Relaxation.ALL and _held_recently(peer, successor):
			continue
		if stage != Relaxation.SELF_ONLY and killer != NOBODY and predecessor == killer:
			continue
		out.append(index)
	return out


func _held_recently(peer: int, candidate: int) -> bool:
	var history: PackedInt32Array = _recent.get(peer, PackedInt32Array())
	return history.has(candidate)


func _remember(peer: int, contract: int) -> void:
	if contract == NOBODY:
		return
	var history: PackedInt32Array = _recent.get(peer, PackedInt32Array())
	history.insert(0, contract)
	var depth := maxi(int(Tuning.contract.anti_repeat_depth), 1)
	while history.size() > depth:
		history.remove_at(history.size() - 1)
	_recent[peer] = history


func _pick(count: int) -> int:
	return _rng.randi_range(0, count - 1) if _rng != null else 0


## **BELOW `TUN-CONTRACT-MIN-CYCLE-LENGTH` THE CYCLE IS STILL VALID AND NO LONGER A
## GAME.** At two players the contracts are mutual: each hunts the other, the
## invariant holds, and the asymmetry the whole design rests on is gone. It is
## reported rather than prevented, because preventing it means refusing a death.
func _note_degeneracy() -> void:
	var count := _cycle.size()
	if count >= int(Tuning.contract.min_cycle_length):
		_degenerate_reported = false
		return
	if count < 2 or _degenerate_reported:
		return
	_degenerate_reported = true
	_telemetry.append(&"TEL-DEGENERATE-CYCLE", {"tick": tick, "cycle_length": count})

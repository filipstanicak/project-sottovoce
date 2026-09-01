## **TEN THOUSAND RANDOMISED EVENTS, WITH THE INVARIANT CHECKED AFTER EVERY ONE.**
## US-0049's test note, GDD-03 §7.4.
##
## The proof in §7.4 is an induction over a sequence of events, so the honest test
## is a sequence of events — kills, respawns, joins, disconnects and batches, in an
## order nobody chose, with `assert_valid()` between each pair.
##
## **THE COVERAGE IS ASSERTED BEFORE THE INVARIANT IS.** A fuzz run that happened to
## do nothing but joins would pass every assertion here and prove nothing about
## removal, and a run that never reached two players would never exercise the
## degenerate case at all. The counters are checked first and printed either way.
extends GutTest

const SEED := 20260821

## 200 sequences of 50 events. The story asks for 10 000; a single 10 000-event
## sequence would spend most of its time at whatever size it drifted to, where many
## short ones sweep the sizes a real match actually visits.
const SEQUENCES := 200
const EVENTS_PER_SEQUENCE := 50

## Six is `TUN-LOBBY-MAX-PLAYERS`; the pool is larger so respawns and joins have
## somebody to be.
const POOL := 12

var _rng: RandomNumberGenerator
var _cycle: ContractCycle
var _dead: PackedInt32Array
var _counts: Dictionary = {}
var _sizes: Dictionary = {}


func before_each() -> void:
	_counts = {&"remove": 0, &"insert": 0, &"escape": 0, &"batch": 0, &"refused": 0}
	_sizes = {}


func test_the_invariant_survives_ten_thousand_events() -> void:
	var events := 0
	for sequence: int in SEQUENCES:
		_rng = RandomNumberGenerator.new()
		_rng.seed = SEED + sequence
		_cycle = ContractCycle.new(_rng)
		_start_a_match()
		for step: int in EVENTS_PER_SEQUENCE:
			_one_event()
			events += 1
			_sizes[_cycle.size()] = int(_sizes.get(_cycle.size(), 0)) + 1
			var problem := _cycle.assert_valid()
			assert_eq(
				problem,
				"",
				"sequence %d step %d left the cycle invalid: %s" % [sequence, step, problem]
			)
			if problem != "":
				return
	_report(events)
	_assert_it_actually_fuzzed(events)


## **THE COVERAGE GUARD, AND IT RUNS ON THE SAME RUN IT DESCRIBES.** Asserted after
## the sweep rather than in a separate test, so the numbers cannot describe one run
## while the invariant was checked on another.
func _assert_it_actually_fuzzed(events: int) -> void:
	assert_gte(events, 10000, "fewer than ten thousand events were applied")
	assert_gt(int(_counts[&"remove"]), 500, "the fuzz barely removed anybody")
	assert_gt(int(_counts[&"insert"]), 500, "the fuzz barely inserted anybody")
	assert_gt(int(_counts[&"batch"]), 200, "the fuzz barely batched anything")
	assert_gt(int(_sizes.get(2, 0)), 0, "the fuzz never reached the degenerate two-player case")
	assert_gt(int(_sizes.get(1, 0)), 0, "the fuzz never reached a single survivor")
	assert_gt(int(_sizes.get(6, 0)), 0, "the fuzz never reached a full lobby")
	# **THE FUZZ MUST ASSERT IT GENERATED AN ESCAPE**, or the event simply never
	# ran and the invariant above says nothing about it — US-0097's own test note,
	# and the same coverage guard the three size assertions are.
	assert_gt(int(_counts.get(&"escape", 0)), 50, "the fuzz never generated an escape")


func _report(events: int) -> void:
	var spread: PackedStringArray = []
	for size: int in range(0, POOL + 1):
		if _sizes.has(size):
			spread.append("%d:%d" % [size, _sizes[size]])
	(
		gut
		. p(
			(
				"%d events over %d sequences — %d removals, %d insertions, %d escapes, %d batches, %d refused"
				% [
					events,
					SEQUENCES,
					_counts[&"remove"],
					_counts[&"insert"],
					_counts.get(&"escape", 0),
					_counts[&"batch"],
					_counts[&"refused"]
				]
			)
		)
	)
	gut.p("cycle sizes visited (size:ticks) — " + " ".join(spread))


func _start_a_match() -> void:
	var players := PackedInt32Array()
	for index: int in 6:
		players.append(100 + index)
	_cycle.open(players)
	_dead = PackedInt32Array()


## One randomly chosen event. The weights are not uniform on purpose: a match kills
## and respawns far more often than it takes a join or a disconnect.
func _one_event() -> void:
	var roll := _rng.randi_range(0, 99)
	if roll < 35:
		_kill()
	elif roll < 70:
		_respawn()
	elif roll < 80:
		_join()
	elif roll < 84:
		_disconnect()
	elif roll < 92:
		_escape()
	else:
		_batch()


func _kill() -> void:
	if _cycle.size() == 0:
		return
	var victim: int = _cycle.living()[_rng.randi_range(0, _cycle.size() - 1)]
	if _cycle.remove(victim):
		_counts[&"remove"] = int(_counts[&"remove"]) + 1
		_dead.append(victim)
	else:
		_counts[&"refused"] = int(_counts[&"refused"]) + 1


## **AN ESCAPE IS A REMOVAL AND AN INSERTION WITH NOBODY DEAD IN BETWEEN.**
## US-0097, ADR-0014. It is in the mix rather than in a test of its own precisely
## because it reaches `ContractCycle` through the same two calls a respawn does —
## so what proves it sound is the 10 000-event invariant, not a second proof.
##
## `remember` before `remove` is `ContractSystem.report_escape`'s own order, and
## putting it here means the fuzz exercises the anti-repeat path an escape takes
## rather than a simplified one.
func _escape() -> void:
	if _cycle.size() < 2:
		return
	var hunter: int = _cycle.living()[_rng.randi_range(0, _cycle.size() - 1)]
	_cycle.remember(hunter, _cycle.contract_of(hunter))
	if not _cycle.remove(hunter):
		_counts[&"refused"] = int(_counts[&"refused"]) + 1
		return
	_cycle.insert(hunter, ContractCycle.NOBODY)
	_counts[&"escape"] = int(_counts[&"escape"]) + 1


func _respawn() -> void:
	if _dead.is_empty():
		return
	var at := _rng.randi_range(0, _dead.size() - 1)
	var peer: int = _dead[at]
	_dead.remove_at(at)
	var killer: int = (
		ContractCycle.NOBODY
		if _cycle.size() == 0
		else int(_cycle.living()[_rng.randi_range(0, _cycle.size() - 1)])
	)
	if _cycle.insert(peer, killer):
		_counts[&"insert"] = int(_counts[&"insert"]) + 1
	else:
		_counts[&"refused"] = int(_counts[&"refused"]) + 1


func _join() -> void:
	var peer := 100 + _rng.randi_range(0, POOL - 1)
	if _cycle.has(peer) or _dead.has(peer):
		_counts[&"refused"] = int(_counts[&"refused"]) + 1
		return
	if _cycle.insert(peer):
		_counts[&"insert"] = int(_counts[&"insert"]) + 1


## A disconnect is a death that does not respawn — GDD-03 §7.3. The peer is simply
## not added to `_dead`, so nothing will bring it back.
func _disconnect() -> void:
	if _cycle.size() == 0:
		return
	var peer: int = _cycle.living()[_rng.randi_range(0, _cycle.size() - 1)]
	if _cycle.remove(peer):
		_counts[&"remove"] = int(_counts[&"remove"]) + 1


## **THE DEBOUNCED PASS, WHICH IS WHERE A DOUBLE KILL LIVES.** Several events inside
## `TUN-CONTRACT-REPAIR-DEBOUNCE` are applied together; applied as separate passes
## they produce two conflicting rebuilds.
func _batch() -> void:
	var removals := PackedInt32Array()
	var wanted := mini(_rng.randi_range(1, 3), _cycle.size())
	var order := _cycle.living()
	for index: int in wanted:
		removals.append(order[index])
	var insertions: Array = []
	for index: int in _rng.randi_range(0, 2):
		if _dead.is_empty():
			break
		var at := _rng.randi_range(0, _dead.size() - 1)
		insertions.append([_dead[at], ContractCycle.NOBODY])
		_dead.remove_at(at)
	_cycle.apply(removals, insertions)
	for gone: int in removals:
		_dead.append(gone)
	_counts[&"batch"] = int(_counts[&"batch"]) + 1
	_counts[&"remove"] = int(_counts[&"remove"]) + removals.size()
	_counts[&"insert"] = int(_counts[&"insert"]) + insertions.size()


func test_no_sequence_ever_produced_a_self_contract() -> void:
	# The invariant above covers this through `assert_valid()`, which is exactly why
	# it is worth asserting separately: a fixed point is the one failure whose
	# consequence is a player told to hunt themselves, and it must not be able to
	# hide behind a generic "the cycle is invalid" message that somebody later
	# loosens.
	for sequence: int in 40:
		_rng = RandomNumberGenerator.new()
		_rng.seed = SEED + 5000 + sequence
		_cycle = ContractCycle.new(_rng)
		_start_a_match()
		for step: int in EVENTS_PER_SEQUENCE:
			_one_event()
			for peer: int in _cycle.living():
				assert_ne(
					_cycle.contract_of(peer),
					peer,
					"sequence %d step %d: peer %d hunts itself" % [sequence, step, peer]
				)

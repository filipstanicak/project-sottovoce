## **THE DEBOUNCE, THE BREATH, AND THE FOUR REASONS.** US-0050, GDD-03 §7.3,
## TDD-10 §5.
##
## `test_contract_repair_same_tick.gd` holds the invariant; this file holds the
## timing, which is the half a player actually feels: a kill buys a breath before
## the next name arrives, and a flurry of deaths produces one announcement rather
## than a flicker of them.
extends GutTest

const SEED := 20260821

var _ctx: MatchContext
var _system: ContractSystem
var _issued: Array = []


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = SEED
	_ctx.tick = 0
	_issued = []
	_system = ContractSystem.new()
	add_child_autofree(_system)
	_system.setup(_ctx)
	_system.contract_issued.connect(_record)
	_system.open(PackedInt32Array([11, 12, 13, 14, 15, 16]), _ctx)


func _record(peer: int, contract: int, reason: int) -> void:
	_issued.append({"tick": _ctx.tick, "peer": peer, "contract": contract, "reason": reason})


func _issued_to(peer: int) -> Array:
	var out: Array = []
	for entry: Dictionary in _issued:
		if int(entry["peer"]) == peer:
			out.append(entry)
	return out


## **A KILL ANNOUNCES TWICE AND THE TWO BEATS ARE DIFFERENT THINGS.** The clear
## lands at once — nobody is ever pointed at a player who is not living — and the
## new name lands after the breath. `_named` is the second beat; `_cleared` is the
## first, and slot 0 is "nobody" on the wire, so both are one message kind.
func _named(peer: int) -> Array:
	var out: Array = []
	for entry: Dictionary in _issued_to(peer):
		if int(entry["contract"]) != ContractCycle.NOBODY:
			out.append(entry)
	return out


func _cleared(peer: int) -> Array:
	var out: Array = []
	for entry: Dictionary in _issued_to(peer):
		if int(entry["contract"]) == ContractCycle.NOBODY:
			out.append(entry)
	return out


func _run(ticks: int) -> void:
	for _step: int in ticks:
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


func test_the_opening_deal_is_announced_to_everybody_at_once() -> void:
	assert_eq(_issued.size(), 6, "six players did not each get an opening contract")
	for entry: Dictionary in _issued:
		assert_eq(int(entry["reason"]), ContractSystem.Reason.START, "the reason is not START")
		assert_eq(int(entry["tick"]), 0, "the opening deal was not announced at match start")
	# The vacuous guard: an `open` that announced everybody the same contract would
	# satisfy the count above perfectly.
	var targets: Dictionary = {}
	for entry: Dictionary in _issued:
		targets[entry["contract"]] = true
	assert_eq(targets.size(), 6, "the opening deal did not name six different contracts")


func test_a_killer_waits_the_reassign_delay_before_being_told() -> void:
	# `TUN-CONTRACT-REASSIGN-DELAY` — "a breath: it converts a kill from a link in a
	# chain into a moment". The graph is repaired at once; the telling waits.
	var victim: int = _system.cycle.living()[2]
	var killer := _system.cycle.pursuer_of(victim)
	var inherited := _system.contract_of(victim)
	_issued = []
	_system.report_death(victim, killer, _ctx)
	var delay := Tuning.ticks(&"TUN-CONTRACT-REASSIGN-DELAY")
	assert_gt(delay, 1, "the reassign delay is not a duration — this test proves nothing")
	# **BEAT ONE, AT ONCE**: the contract they just fulfilled is cleared, so the
	# Compass is not left pointing at the corpse for three seconds.
	assert_eq(_cleared(killer).size(), 1, "the killer was not cleared when their contract died")
	_run(delay - 2)
	assert_eq(_named(killer).size(), 0, "the killer was named a target before the breath was over")
	assert_eq(
		_system.contract_of(killer), inherited, "the graph did not repair while the telling waited"
	)
	# **BEAT TWO, AFTER THE BREATH.**
	_run(4)
	var told := _named(killer)
	assert_eq(told.size(), 1, "the killer was never told, or was told twice")
	assert_eq(int(told[0]["contract"]), inherited, "the killer was told the wrong contract")
	assert_eq(int(told[0]["reason"]), ContractSystem.Reason.KILL, "the reason is not KILL")


func test_two_deaths_inside_the_window_produce_one_announcement() -> void:
	# **GDD-03 §7.3's debounce, from the player's side.** Two repairs 0.1 s apart
	# would otherwise hand somebody a name and replace it before they could read it.
	var order := _system.cycle.living()
	var watcher: int = order[5]
	_issued = []
	# Two players ahead of `watcher` leave, with no killer, so no breath is owed and
	# the only thing between the repair and the announcement is the debounce.
	_system.report_disconnect(order[0], _ctx)
	_run(1)
	_system.report_disconnect(order[1], _ctx)
	_run(Tuning.ticks(&"TUN-CONTRACT-REPAIR-DEBOUNCE") + 4)
	var told := _named(watcher)
	assert_eq(told.size(), 1, "the watcher was named a target %d times, not once" % told.size())
	assert_eq(
		int(told[0]["contract"]),
		_system.contract_of(watcher),
		"the announcement does not match the settled graph"
	)


func test_a_second_event_joins_the_window_rather_than_extending_it() -> void:
	# A stream of deaths must not postpone every announcement indefinitely. The
	# window is opened once and closes on schedule.
	var debounce := Tuning.ticks(&"TUN-CONTRACT-REPAIR-DEBOUNCE")
	assert_gt(debounce, 2, "the debounce is not a duration — this test proves nothing")
	_issued = []
	_system.report_disconnect(_system.cycle.living()[0], _ctx)
	for _step: int in debounce - 1:
		_ctx.tick += 1
		if _system.cycle.size() > 3:
			_system.report_disconnect(_system.cycle.living()[0], _ctx)
		_system.tick(_ctx, MatchContext.net_dt())
	# Clears are immediate by design; what the window holds back is the naming.
	var named := 0
	for entry: Dictionary in _issued:
		if int(entry["contract"]) != ContractCycle.NOBODY:
			named += 1
	assert_eq(named, 0, "somebody was named a target inside the window")
	_run(3)
	assert_gt(_issued.size(), 0, "the window never closed — a stream of deaths silenced it")


func test_a_respawn_is_batched_and_announced_as_a_respawn() -> void:
	var victim: int = _system.cycle.living()[3]
	var killer := _system.cycle.pursuer_of(victim)
	_system.report_death(victim, killer, _ctx)
	_run(Tuning.ticks(&"TUN-CONTRACT-REPAIR-DEBOUNCE") + 2)
	_issued = []
	_system.report_respawn(victim, killer, _ctx)
	assert_false(_system.cycle.has(victim), "the respawn was applied before the window closed")
	_run(Tuning.ticks(&"TUN-CONTRACT-REPAIR-DEBOUNCE") + 2)
	assert_true(_system.cycle.has(victim), "the respawn never landed")
	var told := _named(victim)
	assert_eq(told.size(), 1, "the respawning player was named %d times" % told.size())
	assert_eq(int(told[0]["reason"]), ContractSystem.Reason.RESPAWN, "the reason is not RESPAWN")
	assert_ne(_system.cycle.pursuer_of(victim), killer, "the killer was handed them straight back")


func test_nothing_is_announced_twice_for_one_change() -> void:
	# `_announced` records what was **said**, not what is true, which is what keeps a
	# hundred quiet ticks from re-issuing the same contract a hundred times.
	_issued = []
	_run(120)
	assert_eq(_issued.size(), 0, "a quiet match announced %d contracts" % _issued.size())


func test_the_server_actually_registers_this_system() -> void:
	# **A CRITERION CAN BE TRUE OF A CLASS AND FALSE OF THE GAME**, which is what
	# happened to US-0039's pool: ninety bodies allocated in tests and none in a
	# scene, with the criterion ticked.
	var source := SourceScanner.read("res://scripts/server/server_root.gd")
	assert_gt(source.length(), 500, "server_root.gd is missing or tiny — the scan is vacuous")
	assert_true(
		source.contains("ContractSystem"),
		"server_root never mentions ContractSystem, so the shipped server has no contracts"
	)


func test_the_stage_is_the_one_system_order_declares() -> void:
	assert_eq(_system.stage(), &"contract", "the system is registered at the wrong stage")
	assert_true(
		SystemOrder.STAGES.has(_system.stage()), "the stage is not one SystemOrder declares"
	)
	assert_gt(
		SystemOrder.STAGES.find(&"contract"),
		SystemOrder.STAGES.find(&"combat"),
		"contract no longer runs after combat, so a death could outlive its repair"
	)

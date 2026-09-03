## **THE WHOLE EVENT CHANNEL ARRIVED AT THE CLIENT AND STOPPED AT THE BRIDGE.**
## ADR-0006, US-0072, and the reason it matters is `PortraitWidget`.
##
## `MatchAnnouncer` sends contract, kill, stun and prey-warning messages;
## `EventWire` re-emits every one of them as its own signal; and `HudBridge`
## connected to **one** — `score_reported`. Seven declared bus channels had no
## emitter at all, which is exactly the cost
## `test_eventbus_signals_documented.gd`'s docstring names: *"a widget author
## cannot tell what the payload means or when it fires, so they subscribe and
## guess, and the guess is wrong in the one case that matters."*
##
## **AND ONE WIDGET HAD ALREADY SUBSCRIBED.** `PortraitWidget._on_assigned`
## clears the reveal on a new contract, because — its own words — *"a portrait
## that persisted across a repair would be free identification of somebody you
## have never looked at."* Nothing emitted `contract_assigned`, so it never fired:
## once revealed, the portrait stayed revealed for the rest of the match across
## every reassignment. ASM-0030 defeated by an unwired signal.
extends GutTest

var _bridge: HudBridge
var _contracts: Array = []
var _kills: Array = []
var _stuns: Array = []
var _warnings: Array = []
var _started: Array = []
var _denials: Array = []
var _cooldowns: Array = []


func before_each() -> void:
	_contracts = []
	_kills = []
	_stuns = []
	_warnings = []
	_started = []
	_denials = []
	_cooldowns = []
	_bridge = HudBridge.new()
	add_child_autofree(_bridge)
	EventBus.contract_assigned.connect(_on_contract)
	EventBus.kill_resolved.connect(_on_kill)
	EventBus.stun_resolved.connect(_on_stun)
	EventBus.prey_warning_triggered.connect(_on_warning)
	EventBus.ability_started.connect(_on_started)
	EventBus.ability_denied.connect(_on_denied)
	EventBus.ability_cooldown_changed.connect(_on_cooldown)


func after_each() -> void:
	# The bus is an autoload and outlives this test — US-0037's lesson, one layer up.
	EventBus.contract_assigned.disconnect(_on_contract)
	EventBus.kill_resolved.disconnect(_on_kill)
	EventBus.stun_resolved.disconnect(_on_stun)
	EventBus.prey_warning_triggered.disconnect(_on_warning)
	EventBus.ability_started.disconnect(_on_started)
	EventBus.ability_denied.disconnect(_on_denied)
	EventBus.ability_cooldown_changed.disconnect(_on_cooldown)


func _on_contract(reason: int) -> void:
	_contracts.append(reason)


func _on_kill(killer_slot: int, victim_slot: int) -> void:
	_kills.append([killer_slot, victim_slot])


func _on_stun(stunner_slot: int, target_slot: int, valid: bool) -> void:
	_stuns.append([stunner_slot, target_slot, valid])


func _on_warning(bearing: float, bucket: int) -> void:
	_warnings.append([bearing, bucket])


func _on_started(caster_slot: int, ability: StringName, origin: Vector3, at: Vector3) -> void:
	_started.append([caster_slot, ability, origin, at])


func _on_denied(slot: int, reason: int) -> void:
	_denials.append([slot, reason])


func _on_cooldown(slot: int, remaining_ticks: int) -> void:
	_cooldowns.append([slot, remaining_ticks])


func _snapshot(a: int = 0, b: int = 0) -> Snapshot:
	var s := Snapshot.new()
	s.cooldown_a_tick = a
	s.cooldown_b_tick = b
	return s


# --- the seven that arrive and used to stop -------------------------------


## **THE ONE THAT COST SOMETHING.** Everything else here is a channel nobody had
## subscribed to yet; this one had a subscriber and a documented reason.
func test_a_new_contract_reaches_the_bus() -> void:
	Net.events.contract_assigned.emit(3, ContractSystem.Reason.KILL)
	assert_eq(_contracts.size(), 1, "a new contract was announced and the HUD was not told")
	assert_eq(int(_contracts[0]), ContractSystem.Reason.KILL, "the reason was not forwarded")


## **THE SLOT IS DROPPED AND THAT IS THE RULE, NOT AN OVERSIGHT.** `EventWire`
## carries a contract slot; `EVT-CONTRACT-ASSIGNED`'s payload is the **reason
## alone**, because GDD-03 §8.5 forbids the client learning anything about its
## contract it has not earned by looking. The bridge is where that is enforced.
func test_the_contract_slot_never_reaches_the_bus() -> void:
	Net.events.contract_assigned.emit(5, ContractSystem.Reason.REPAIR)
	assert_eq(_contracts, [ContractSystem.Reason.REPAIR], "the bus carried an identity hint")


func test_a_kill_reaches_the_bus_as_slots() -> void:
	Net.events.kill_resolved.emit(2, 4, 900, 0)
	assert_eq(_kills.size(), 1, "a kill result was delivered and the HUD was not told")
	assert_eq(_kills[0], [2, 4], "the killer and victim slots did not survive the hop")


func test_a_stun_reaches_the_bus_with_its_validity() -> void:
	Net.events.stun_resolved.emit(3, 1, false, 0)
	assert_eq(_stuns.size(), 1, "a stun result was delivered and the HUD was not told")
	assert_eq(_stuns[0], [3, 1, false], "the stun's validity did not survive the hop")


## US-0059's prey warning has reached the client since M4 and stopped here. Its
## own story lists the client half as blocked on `CompassVm`; **the bus hop is not
## `CompassVm`'s and was simply missing.**
func test_a_prey_warning_reaches_the_bus() -> void:
	Net.events.prey_warned.emit(1.25, 7)
	assert_eq(_warnings.size(), 1, "the prey's only warning was delivered and dropped")
	assert_almost_eq(float(_warnings[0][0]), 1.25, 0.001, "the bearing did not survive")
	assert_eq(int(_warnings[0][1]), 7, "the bucket did not survive")


## **WHERE IT LANDED SURVIVES; WHO IT WAS AIMED AT IS NOT IN THE PAYLOAD AT ALL.**
##
## US-0090 dropped the aim outright and this narrows that, deliberately. The old
## rule — *a tell says something happened there* — was written when nothing drew
## anything, and it made `ABIL-CINDERFALL` **undrawable**: the cloud lands up to
## `TUN-CINDERFALL-THROW-RANGE` 8 m away, so a client given only the thrower's feet
## would put cover where there is none. A player standing in an invisible cloud,
## unable to initiate a kill and told nothing about why, is a worse information
## failure than the one the old rule prevented.
##
## The replacement is a property rather than an omission, and it is the one
## never-do #12 is actually about: **the payload names nobody.** Asserted
## structurally below, so a later author cannot add a target slot to it quietly.
func test_an_ability_tell_reaches_the_bus_with_where_it_landed() -> void:
	Net.events.ability_started.emit(2, Ids.ABIL_CINDERFALL, Vector3(1, 0, 2), Vector3(0, 0, 6))
	assert_eq(_started.size(), 1, "the one broadcast in this game was dropped at the bridge")
	assert_eq(_started[0][0], 2, "the caster slot did not survive")
	assert_eq(_started[0][1], Ids.ABIL_CINDERFALL, "the ability did not survive")
	assert_eq(_started[0][2], Vector3(1, 0, 2), "the origin did not survive")
	assert_eq(_started[0][3], Vector3(1, 0, 8), "the landing point was not origin + aim")


## **THE STRUCTURAL HALF.** Two points and no people: a target's slot, peer,
## persona or tier must never appear here, and the way to keep that true is to
## assert the shape rather than to remember the rule.
func test_the_tell_payload_names_nobody_but_its_caster() -> void:
	var found := {}
	for entry: Dictionary in EventBus.get_signal_list():
		if entry["name"] == "ability_started":
			found = entry
	assert_false(found.is_empty(), "EVT-ABILITY-STARTED is gone from the bus")
	var names: Array = []
	for argument: Dictionary in found["args"]:
		names.append(String(argument["name"]))
	assert_eq(
		names,
		["caster_slot", "ability", "origin", "at"],
		"EVT-ABILITY-STARTED grew or lost a field — a target's identity must not be one"
	)


func test_an_ability_denial_reaches_the_bus() -> void:
	Net.events.ability_denied.emit(1, AbilityDenial.Why.ON_COOLDOWN)
	assert_eq(_denials, [[1, AbilityDenial.Why.ON_COOLDOWN]], "a denial was dropped")


# --- the one derived from the snapshot ------------------------------------


## `cooldown_a_tick` and `cooldown_b_tick` are in the own-gameplay block the
## bridge already reads. **On change, never on arrival**, like everything else
## here — a cooldown ticks down every snapshot and emitting each one would make a
## widget's redraw condition *"a packet arrived"*.
func test_a_cooldown_reaches_the_bus_on_change_only() -> void:
	_bridge._on_snapshot(_snapshot(0, 0))
	var baseline := _cooldowns.size()
	_bridge._on_snapshot(_snapshot(900, 0))
	assert_eq(_cooldowns.size(), baseline + 1, "a cooldown started and no widget was told")
	assert_eq(_cooldowns[baseline], [0, 900], "the slot or the remaining ticks were wrong")
	_bridge._on_snapshot(_snapshot(900, 0))
	assert_eq(_cooldowns.size(), baseline + 1, "an unchanged cooldown was republished")


func test_both_slots_are_published_independently() -> void:
	_bridge._on_snapshot(_snapshot(0, 0))
	_cooldowns = []
	_bridge._on_snapshot(_snapshot(0, 450))
	assert_eq(_cooldowns, [[1, 450]], "slot 1's cooldown did not reach the bus on its own")


# --- the portrait, which is what any of this was for ----------------------


## **A NEW CONTRACT IS A NEW UNKNOWN**, and until now nothing said so.
## `PortraitWidget` has cleared its reveal on `contract_assigned` since US-0073
## and the signal had no emitter, so a portrait earned against one player stayed
## lit against the next — free identification of somebody you have never looked
## at, which is the thing ASM-0030 and the 1.6 s lock exist to charge for.
func test_a_reassignment_clears_an_earned_portrait() -> void:
	var portrait := PortraitWidget.new()
	add_child_autofree(portrait)
	EventBus.contract_portrait_revealed.emit(&"")
	assert_true(portrait.is_revealed(), "the fixture could not reveal the portrait")
	Net.events.contract_assigned.emit(6, ContractSystem.Reason.REPAIR)
	assert_false(
		portrait.is_revealed(), "a portrait earned against one contract stayed lit against the next"
	)

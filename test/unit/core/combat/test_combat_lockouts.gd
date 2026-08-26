## **THE EXILE AND THE STAGGER.** GDD-03 §10.2, TDD-10 §4, US-0060 and US-0061.
##
## `TUN-STUN-LOCKOUT` is what makes a stun counterplay rather than a four-second
## delay: without it the hunter is frozen, stands up, and walks back. The two
## shapes in this class are deliberately different and the difference is the
## whole rule — **a stagger stops you doing anything, an exile stops you doing one
## thing to one person.**
extends GutTest

const HUNTER := 71
const PREY := 72
const OTHER := 73

var _l: CombatLockouts


func before_each() -> void:
	_l = CombatLockouts.new()


func test_an_exile_binds_one_pair_and_leaves_every_other_hunt_alone() -> void:
	# **THE PROPERTY THAT MAKES IT A LOCKOUT AND NOT A BAN.** A stunned hunter is
	# exiled from the player who stunned them; the cycle may hand them somebody
	# else in the same second, and that hunt must start immediately.
	_l.exile(HUNTER, PREY, 100)
	assert_true(_l.is_exiled(HUNTER, PREY, 50), "the exile did not bind the pair it was set for")
	assert_false(_l.is_exiled(HUNTER, OTHER, 50), "the exile spread to an unrelated contract")
	assert_false(_l.is_exiled(PREY, HUNTER, 50), "the exile bound the wrong direction")


func test_it_expires_on_the_tick_it_names() -> void:
	_l.exile(HUNTER, PREY, 100)
	assert_true(_l.is_exiled(HUNTER, PREY, 99), "the exile ended a tick early")
	assert_false(_l.is_exiled(HUNTER, PREY, 100), "the exile outlived its own deadline")
	assert_eq(_l.remaining(HUNTER, PREY, 90), 10, "the remaining count disagrees with the deadline")
	assert_eq(_l.remaining(HUNTER, PREY, 200), 0, "an expired exile reports time left")


func test_a_second_stun_extends_and_never_shortens() -> void:
	# The prey who stuns the same hunter twice must not accidentally *free* them.
	# A plain assignment would do exactly that, and the symptom would be a hunter
	# who returns early after being punished twice — which reads as a design
	# problem rather than as arithmetic.
	_l.exile(HUNTER, PREY, 100)
	_l.exile(HUNTER, PREY, 60)
	assert_eq(_l.remaining(HUNTER, PREY, 50), 50, "the shorter exile overwrote the longer one")
	_l.exile(HUNTER, PREY, 140)
	assert_eq(_l.remaining(HUNTER, PREY, 50), 90, "the longer exile did not extend")


func test_a_stagger_stops_everything_and_belongs_to_one_player() -> void:
	_l.stagger(HUNTER, 100)
	assert_true(_l.is_staggered(HUNTER, 99), "the stagger ended a tick early")
	assert_false(_l.is_staggered(PREY, 99), "the stagger spread to another player")
	assert_eq(_l.stagger_remaining(HUNTER, 90), 10)


func test_a_stagger_also_extends_rather_than_shortening() -> void:
	# Two flails in quick succession must compound, not reset. `TUN-STUN-COOLDOWN`
	# makes this hard to reach in the shipped game and it is asserted anyway,
	# because "hard to reach" is how the anti-repeat rule in `ContractCycle` stayed
	# inert for two milestones.
	_l.stagger(HUNTER, 100)
	_l.stagger(HUNTER, 70)
	assert_eq(_l.stagger_remaining(HUNTER, 50), 50, "the shorter stagger won")


func test_a_departing_peer_leaves_nothing_behind_in_either_direction() -> void:
	# **ENet REUSES PEER IDS** (US-0037). The half everybody forgets is the second
	# one: the joiner who inherits the id would inherit every *other* hunter's
	# exile from them, and would be unkillable by half the lobby for twelve
	# seconds with nothing anywhere reporting it.
	_l.exile(HUNTER, PREY, 100)
	_l.exile(OTHER, PREY, 100)
	_l.stagger(PREY, 100)
	_l.forget(PREY)
	assert_false(_l.is_staggered(PREY, 50), "the departed peer's own stagger survived them")
	assert_false(_l.is_exiled(HUNTER, PREY, 50), "an exile ABOUT the departed peer survived")
	assert_false(_l.is_exiled(OTHER, PREY, 50), "a second hunter's exile about them survived")
	assert_eq(_l.exiles_live(50), 0, "%d exiles still name a peer that left" % _l.exiles_live(50))


func test_an_empty_table_answers_free() -> void:
	# The state at the first tick of every match. A default that answered "locked"
	# would make the opening ten seconds of a match silently unplayable.
	assert_false(_l.is_exiled(HUNTER, PREY, 0), "a fresh table exiles somebody")
	assert_false(_l.is_staggered(HUNTER, 0), "a fresh table staggers somebody")
	assert_eq(_l.remaining(HUNTER, PREY, 0), 0)
	assert_eq(_l.exiles_live(0), 0)

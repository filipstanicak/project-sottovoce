## **THE TIER INDICATOR, THE PORTRAIT, THE CROSSHAIR AND THE VIGNETTE.** US-0073,
## UI_UX_SPEC §4 and §6.
##
## Each is a pure renderer fed by the event bus, so each is testable by emitting
## the signal the server would have caused and asking what the widget now believes.
## **Nothing here draws** — a screenshot test would assert against a font this
## project does not ship.
extends GutTest

var _tier: TierWidget
var _crosshair: CrosshairWidget
var _portrait: PortraitWidget
var _vignette: VignetteWidget


func before_each() -> void:
	_tier = TierWidget.new()
	_crosshair = CrosshairWidget.new()
	_portrait = PortraitWidget.new()
	_vignette = VignetteWidget.new()
	for widget: Control in [_tier, _crosshair, _portrait, _vignette]:
		add_child_autofree(widget)


# ------------------------------------------------------- the tier indicator ---


func test_the_tier_is_a_shape_and_a_word_as_well_as_a_colour() -> void:
	# **THREE CHANNELS CARRYING ONE FACT** (§4), which is what lets the indicator
	# survive the monochrome palette with nothing added. The test that matters is
	# that the three *disagree* across tiers — a widget returning the same word or
	# the same glyph for two tiers has silently collapsed to one channel.
	var seen_words: Array[String] = []
	var seen_colours: Array[Color] = []
	for tier: int in [
		SuspicionMath.Tier.ANONYMOUS, SuspicionMath.Tier.NOTICED, SuspicionMath.Tier.EXPOSED
	]:
		EventBus.suspicion_tier_changed.emit(tier, SuspicionSources.NONE)
		seen_words.append(_tier._word())
		seen_colours.append(_tier.palette.for_tier(tier))
	assert_eq(seen_words.size(), 3)
	for i: int in 3:
		for j: int in range(i + 1, 3):
			assert_ne(seen_words[i], seen_words[j], "two tiers share a word")
			assert_ne(seen_colours[i], seen_colours[j], "two tiers share a colour")


func test_the_words_come_from_the_string_table() -> void:
	# Never-do #10. A literal here would also be untranslatable, and
	# `test_no_literal_strings.gd` guards the general case — this asserts the
	# specific keys resolve rather than falling back to the key itself.
	EventBus.suspicion_tier_changed.emit(SuspicionMath.Tier.EXPOSED, SuspicionSources.NONE)
	assert_eq(_tier._word(), Strings.get_text(&"ui.tier.exposed").to_upper())
	assert_ne(_tier._word(), "UI.TIER.EXPOSED", "the string table has no key for this tier")


func test_the_source_list_names_every_contributing_source() -> void:
	# **§4.1 EXISTS TO ANSWER "WHY AM I VISIBLE?"** A player who cannot attribute
	# their suspicion cannot learn from it, and the total alone is not
	# attributable — GDD-06 Part 3's failure mode 3.
	EventBus.suspicion_tier_changed.emit(
		SuspicionMath.Tier.NOTICED, SuspicionSources.SPRINT | SuspicionSources.OPEN
	)
	var line := _tier._source_line()
	assert_string_contains(line, Strings.get_text(&"ui.source.sprinting"))
	assert_string_contains(line, Strings.get_text(&"ui.source.alone"))
	assert_false(
		line.contains(Strings.get_text(&"ui.source.climbing")), "a source nobody set was listed"
	)


func test_every_source_bit_has_a_word() -> void:
	# **A BIT WITH NO STRING IS A REASON THE PLAYER IS NEVER TOLD**, and it would
	# be invisible: the line would simply be one item shorter. `SuspicionSources`
	# is the source of truth for how many there are.
	for bit: int in SuspicionSources.ALL:
		EventBus.suspicion_tier_changed.emit(SuspicionMath.Tier.NOTICED, bit)
		assert_false(_tier._source_line().is_empty(), "source bit %d lists nothing" % bit)


func test_nothing_contributing_lists_nothing() -> void:
	EventBus.suspicion_tier_changed.emit(SuspicionMath.Tier.ANONYMOUS, SuspicionSources.NONE)
	assert_eq(_tier._source_line(), "", "an empty bitfield produced a line")


# ------------------------------------------------------------ the crosshair ---


func test_the_ring_appears_if_and_only_if_the_server_says_so() -> void:
	# **THE ONE HARD CORRECTNESS REQUIREMENT** (§6). The widget cannot lie because
	# it cannot compute: it holds two booleans it was handed. This asserts the
	# absence of any other route — a range check, a distance, a pawn.
	for kill: bool in [true, false]:
		for stun: bool in [true, false]:
			EventBus.kill_ready_changed.emit(kill, stun)
			assert_eq(_crosshair._kill, kill, "the crosshair disagrees with the server on kill")
			assert_eq(_crosshair._stun, stun, "the crosshair disagrees with the server on stun")


func test_the_crosshair_can_never_compute_readiness() -> void:
	var source := "res://scripts/presentation/hud/crosshair_widget.gd"
	for term: String in ["distance", "KillRules", "position", "range", "Tuning.combat"]:
		assert_false(
			SourceScanner.code_contains(source, term),
			"the crosshair mentions `%s` — a lying crosshair is worse than no crosshair" % term
		)


# ------------------------------------------------------------- the portrait ---


func test_the_portrait_is_unknown_until_a_lock_completes() -> void:
	assert_false(_portrait.is_revealed(), "the portrait opens revealed")
	EventBus.contract_portrait_revealed.emit(&"")
	assert_true(_portrait.is_revealed(), "a completed lock revealed nothing")


func test_a_new_contract_is_a_new_unknown() -> void:
	# **`CompassLock` RESETS ITS PORTRAIT ON REASSIGNMENT** (US-0058), and the
	# widget must follow: a reveal earned against one person says nothing about the
	# next, and a portrait that persisted across a repair would be free
	# identification of somebody you have never looked at.
	EventBus.contract_portrait_revealed.emit(&"")
	assert_true(_portrait.is_revealed())
	EventBus.contract_assigned.emit(0)
	assert_false(_portrait.is_revealed(), "the portrait survived a reassignment")


# ------------------------------------------------------------- the vignette ---


func test_the_vignette_belongs_to_exposed_alone() -> void:
	# §4.2: the only full-screen effect in the game, reserved entirely for Exposed.
	for tier: int in [SuspicionMath.Tier.ANONYMOUS, SuspicionMath.Tier.NOTICED]:
		EventBus.suspicion_tier_changed.emit(tier, SuspicionSources.NONE)
		_vignette._process(10.0)
		assert_eq(_vignette.alpha(), 0.0, "the vignette showed below Exposed")
	EventBus.suspicion_tier_changed.emit(SuspicionMath.Tier.EXPOSED, SuspicionSources.NONE)
	_vignette._process(10.0)
	assert_eq(_vignette.alpha(), 1.0, "Exposed did not raise the vignette")


func test_it_fades_over_the_tunable_rather_than_snapping() -> void:
	# Instant would read as a rendering fault. The rate is
	# `TUN-UI-DAMAGE-VIGNETTE-TIME`, read rather than written as 0.8.
	var seconds := Tuning.ui_audio.damage_vignette_time
	EventBus.suspicion_tier_changed.emit(SuspicionMath.Tier.EXPOSED, SuspicionSources.NONE)
	_vignette._process(seconds * 0.5)
	assert_almost_eq(_vignette.alpha(), 0.5, 0.02, "the vignette does not fade over the tunable")
	assert_gt(seconds, 0.0, "the tunable is zero, so this test cannot tell a fade from a snap")

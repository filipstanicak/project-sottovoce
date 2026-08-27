## **HOW MUCH OF THE TELEMETRY PLAN EXISTS?** US-0063, the M4 gate.
##
## GDD-07 §8 is a 29-event catalogue, and `TelemetrySink` has been the fixed
## interface since M0 precisely so that *"call sites written between now and
## US-0080 do not have to change"* — its own docstring adds **"a sink that appears
## late is a sink whose call sites were never written."**
##
## **NOTHING HAD EVER COUNTED THE CALL SITES.** This test does. It is the M4
## gate's equivalent of `test_crowd_bandwidth.gd` at M3: an instrument the gate
## depends on, which nobody had checked was there.
##
## **IT REPORTS RATHER THAN FAILS**, the choice `test_snapshot_size.gd` made. The
## gap is a story (US-0080), not a defect — but two of US-0063's own acceptance
## criteria are scored against events in this catalogue, so a gate run that did
## not know the number would have discovered it with six humans in the room.
##
## **AN EMITTER IS A CALL, NOT A MENTION.** Most `TEL-` strings under `scripts/`
## are in docstrings explaining what a value will one day be used for. Matching
## those would report a telemetry system that does not exist as complete, which is
## trap 3's shape in an audit.
extends GutTest

const DOC := "res://docs/10_gdd/07_balance.md"

## The catalogue is §8 of that document. Fewer than this and the parser has
## silently matched nothing, and every number below would be about nothing.
const MINIMUM_CATALOGUE := 25

## The two call forms that actually reach `TelemetrySink.append`.
const CALL_FORMS := ['telemetry(&"TEL-', '.append(&"TEL-']

var _documented: PackedStringArray
var _emitted: PackedStringArray


func before_all() -> void:
	_documented = _catalogue()
	_emitted = _emitters()


## Every `TEL-` id in GDD-07 §8's tables.
func _catalogue() -> PackedStringArray:
	var text := SourceScanner.read(DOC)
	var section := text.substr(text.find("## 8. Telemetry plan"))
	section = section.substr(0, maxi(section.find("\n## 9."), 1))
	var out: PackedStringArray = []
	for chunk: String in section.split("`TEL-"):
		var end := chunk.find("`")
		if end <= 0:
			continue
		var id := "TEL-" + chunk.substr(0, end)
		if not out.has(id):
			out.append(id)
	out.sort()
	return out


## Every id passed to a call that reaches the sink. Raw source rather than
## `SourceScanner.code_lines`, because that blanks string literals — and the
## literal is the thing being looked for.
func _emitters() -> PackedStringArray:
	var out: PackedStringArray = []
	for path: String in SourceScanner.gd_files("res://scripts"):
		for line: String in SourceScanner.read(path).split("\n"):
			for form: String in CALL_FORMS:
				var at := line.find(form)
				if at < 0:
					continue
				var rest := line.substr(at + form.length() - 4)
				var end := rest.find('"')
				if end > 0 and not out.has(rest.substr(0, end)):
					out.append(rest.substr(0, end))
	out.sort()
	return out


func test_the_catalogue_parsed() -> void:
	# **THE VACUOUS-SUCCESS GUARD.** Every count below is satisfied by a parser
	# that found nothing at all, which would report perfect coverage of an empty
	# catalogue.
	assert_gte(
		_documented.size(),
		MINIMUM_CATALOGUE,
		"GDD-07 §8 parsed to %d events; the parser is matching nothing" % _documented.size()
	)


func test_an_emitter_is_a_call_and_not_a_mention() -> void:
	# The counterfactual for the scan. `TEL-MEAN-SPEED` appears in three
	# docstrings under `scripts/` and is emitted from nowhere; a scan that counted
	# mentions would report it as live.
	assert_true(
		SourceScanner.read("res://scripts/pawn/states/vault_state.gd").contains("TEL-MEAN-SPEED"),
		"the fixture's example mention is gone; pick another before trusting this"
	)
	assert_false(
		_emitted.has("TEL-MEAN-SPEED"),
		"TEL-MEAN-SPEED now has a real emitter — update the gate's reading of US-0063"
	)


func test_the_gap_between_the_plan_and_the_code_is_reported() -> void:
	var missing: PackedStringArray = []
	for id: String in _documented:
		if not _emitted.has(id):
			missing.append(id)
	gut.p(
		(
			"telemetry: %d documented, %d emitted, %d with no call site"
			% [_documented.size(), _emitted.size(), missing.size()]
		)
	)
	gut.p("emitted: %s" % ", ".join(_emitted))
	assert_gt(_emitted.size(), 0, "no telemetry is emitted anywhere at all")
	if missing.is_empty():
		return
	pending(
		(
			(
				"%d of %d GDD-07 §8 events have no emitter (US-0080). "
				% [missing.size(), _documented.size()]
			)
			+ "US-0063's THE TURN reads TEL-MEAN-SPEED and its identification "
			+ "criterion reads TEL-FIRST-CONTACT-OUTCOME; neither can be scored."
		)
	)


func test_the_record_flag_still_has_no_reader() -> void:
	# **`--record` IS PARSED INTO `LaunchConfig.record_path` AND NOTHING READS IT.**
	# `docs/40_backlog/playtests/README.md` tells a facilitator to *"attach the
	# telemetry export (`--record`)"*, so the playtest procedure documents a flag
	# that does nothing — trap 14, in a runbook rather than in a test table.
	#
	# Asserted in the direction that is true today, so it **goes red the day
	# US-0080 wires a sink** and somebody re-reads this file rather than leaving a
	# stale note behind.
	var readers := 0
	for path: String in SourceScanner.gd_files("res://scripts"):
		if path.ends_with("launch_config.gd"):
			continue
		if SourceScanner.code_contains(path, "record_path"):
			readers += 1
	assert_eq(readers, 0, "record_path has a reader now; US-0080 has started — re-read US-0063")

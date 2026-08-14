## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **THE TWO PROTOCOL DOCUMENTS DECLARE THE SAME MESSAGES.** TDD-04 §6 owns the
## reasoning; NETWORK_PROTOCOL is a deliberate duplicate of it, kept because a
## lookup that requires reading a chapter is a lookup nobody does.
##
## **NETWORK_PROTOCOL's header has claimed since M0 that this file asserts they
## match. It did not exist.** Two documents duplicated on purpose, drifting
## unguarded, under a note telling every reader they were guarded — which is
## worse than no guard at all, because the note is exactly what stops somebody
## checking by hand. Found while checkpointing M2 (2026-08-15). No drift had
## accumulated; that was luck, not process.
##
## Only the message IDs are compared, not the payload columns. The two tables
## carry different columns on purpose — the TDD's validation column is a
## paragraph where the bible's is a phrase — so an equality test over rows would
## fail on formatting and be deleted within a week. What actually drifts is a
## message added to one document and not the other, and that is what this sees.
extends GutTest

const BIBLE := "res://docs/30_bible/NETWORK_PROTOCOL.md"
const TDD := "res://docs/20_tdd/04_networking.md"

## `NET-C2S-SCORE` and its kin are named by §2.1 **while explaining that they do
## not exist**. The bible lists them as forbidden; the TDD does not repeat the
## list. They are not drift and are excluded by name rather than by pattern.
const NOT_MESSAGES: Array[String] = ["NET-C2S-SCORE"]


func _ids_in(path: String) -> PackedStringArray:
	var text := FileAccess.get_file_as_string(path)
	var found: Dictionary = {}
	var re := RegEx.create_from_string("NET-[CS]2[CS]-[A-Z0-9]+(-[A-Z0-9]+)*")
	for m: RegExMatch in re.search_all(text):
		var id := m.get_string()
		if not NOT_MESSAGES.has(id):
			found[id] = true
	var out: PackedStringArray = found.keys()
	out.sort()
	return out


func test_both_documents_were_actually_read() -> void:
	# Guards the guard. A renamed document reads as an empty set, and two empty
	# sets match perfectly — trap 3's family, which this project has now hit
	# four times.
	assert_gt(_ids_in(BIBLE).size(), 20, "found almost no messages in NETWORK_PROTOCOL")
	assert_gt(_ids_in(TDD).size(), 20, "found almost no messages in TDD-04")


func test_the_two_catalogues_declare_the_same_messages() -> void:
	var bible := _ids_in(BIBLE)
	var tdd := _ids_in(TDD)

	var missing_from_tdd: PackedStringArray = []
	for id: String in bible:
		if not tdd.has(id):
			missing_from_tdd.append(id)
	var missing_from_bible: PackedStringArray = []
	for id: String in tdd:
		if not bible.has(id):
			missing_from_bible.append(id)

	assert_eq(
		missing_from_tdd.size() + missing_from_bible.size(),
		0,
		(
			"The two protocol documents disagree about which messages exist.\n"
			+ "NETWORK_PROTOCOL is a deliberate duplicate of TDD-04 §6; the TDD wins\n"
			+ "and the bible is the bug.\n"
			+ "In NETWORK_PROTOCOL but not TDD-04: %s\n" % ", ".join(missing_from_tdd)
			+ "In TDD-04 but not NETWORK_PROTOCOL: %s" % ", ".join(missing_from_bible)
		)
	)


func test_the_check_can_actually_fail() -> void:
	# Falsification. The comparison above is only worth having if the extractor
	# sees a message that is present in one text and absent from the other.
	var re := RegEx.create_from_string("NET-[CS]2[CS]-[A-Z0-9]+(-[A-Z0-9]+)*")
	var planted := "| `NET-S2C-INVENTED` | X | Rel | once | `peer_id:u8` |"
	var hits := re.search_all(planted)
	assert_eq(hits.size(), 1, "the extractor did not find a planted message id")
	assert_eq(hits[0].get_string(), "NET-S2C-INVENTED", "the extractor mangled the id")
	assert_false(
		_ids_in(TDD).has("NET-S2C-INVENTED"), "a message invented for this test is in the corpus"
	)

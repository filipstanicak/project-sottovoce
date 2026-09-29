## **A NEW PAWN STATE IS A PROTOCOL CHANGE.** US-0104, the review of #239.
##
## `state_id` travels as an index into `PawnStateId.ALL`, in the own pawn record and
## in every remote pawn record. A client built before a state was appended cannot
## decode its index, and the handshake would still let it in unless
## `Messages.PROTOCOL_VERSION` moved: `build_hash()` covers neither the list nor its
## length. `Choking` was appended at index 16 without the bump and only the review
## caught it, so the pairing is written down here and asserted.
##
## **When a state is appended, add its row below in the same commit as the bump.**
## The table is the history and rows are never removed. The second review of #239
## found the first version of this guard passable by adding `18: 5` — a new count
## at the version already in force — so the rule is now that **every new count
## carries a strictly newer version**, and that rule is falsified below with that
## exact row.
extends GutTest

## `{number of states on the wire: the protocol version in force when that count first shipped}`.
## The versions between are other changes (see `Messages.PROTOCOL_VERSION`'s history).
const STATES_AT_VERSION := {
	16: 1,
	17: 5,
}


## Every way `table` fails to pair `count` states with protocol `version`, as
## readable lines. **PURE**, so the planted tables below go through the same code.
static func problems(table: Dictionary, count: int, version: int) -> PackedStringArray:
	var out := PackedStringArray()
	if not table.has(count):
		out.append("%d states go on the wire and no row records a version for that count" % count)
	elif version < int(table[count]):
		out.append(
			"the wire carries %d states but PROTOCOL_VERSION %d predates them" % [count, version]
		)
	var counts: Array = table.keys()
	counts.sort()
	if not counts.is_empty() and int(counts[-1]) != count:
		out.append("the newest row is for %d states and the wire carries %d" % [counts[-1], count])
	for i: int in range(1, counts.size()):
		if int(table[counts[i]]) <= int(table[counts[i - 1]]):
			out.append(
				(
					"%d states at version %d is not newer than %d states at version %d"
					% [counts[i], table[counts[i]], counts[i - 1], table[counts[i - 1]]]
				)
			)
	return out


func test_todays_state_list_is_paired_with_the_protocol() -> void:
	var found := problems(STATES_AT_VERSION, PawnStateId.ALL.size(), Messages.PROTOCOL_VERSION)
	assert_eq(
		found.size(),
		0,
		"an appended state needs a PROTOCOL_VERSION bump and a row here:\n" + "\n".join(found)
	)


func test_the_shipped_rows_stay() -> void:
	# The history cannot be rewritten to make room: dropping `17: 5` and writing
	# `18: 5` would satisfy the ordering with no bump at all.
	assert_eq(STATES_AT_VERSION.get(16), 1, "the row for sixteen states was changed or removed")
	assert_eq(STATES_AT_VERSION.get(17), 5, "the row for seventeen states was changed or removed")


func test_a_new_state_at_the_version_already_in_force_is_refused() -> void:
	# **THE REVIEW'S COUNTEREXAMPLE**, which the first version of this guard passed.
	var found := problems({16: 1, 17: 5, 18: 5}, 18, 5)
	assert_true(
		"\n".join(found).contains("18 states at version 5 is not newer"),
		"a state appended without a bump went unreported: %s" % [found]
	)


func test_each_other_way_to_forget_the_bump_is_refused() -> void:
	var cases := {
		"no row records a version": problems({16: 1, 17: 5}, 18, 5),
		"PROTOCOL_VERSION 5 predates them": problems({16: 1, 17: 5, 18: 6}, 18, 5),
		"the newest row is for 18 states": problems({16: 1, 17: 5, 18: 6}, 17, 6),
	}
	for expected: String in cases:
		var text := "\n".join(cases[expected])
		assert_true(text.contains(expected), "'%s' was not reported:\n%s" % [expected, text])
	assert_eq(problems({16: 1, 17: 5, 18: 6}, 18, 7).size(), 0, "a correct bump was refused")

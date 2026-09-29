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
## The table is the history; the assertion is that the latest row is today.
extends GutTest

## `{number of states on the wire: the protocol version in force when that count first shipped}`.
## The versions between are other changes (see `Messages.PROTOCOL_VERSION`'s history).
const STATES_AT_VERSION := {
	16: 1,
	17: 5,
}


func test_the_state_count_has_a_protocol_version() -> void:
	var count := PawnStateId.ALL.size()
	assert_true(
		STATES_AT_VERSION.has(count),
		(
			(
				"%d pawn states go on the wire and no protocol version is recorded for that count: "
				+ "an appended state needs a PROTOCOL_VERSION bump and a row here"
			)
			% count
		)
	)


func test_the_protocol_is_at_least_the_version_that_introduced_this_count() -> void:
	var count := PawnStateId.ALL.size()
	assert_gte(
		Messages.PROTOCOL_VERSION,
		int(STATES_AT_VERSION.get(count, 1 << 30)),
		"the wire carries %d states but PROTOCOL_VERSION predates them" % count
	)


func test_the_newest_count_is_todays() -> void:
	# A row added for a state that was then removed again would let a later
	# appended state reuse its count without a new bump.
	var newest := -1
	for count: int in STATES_AT_VERSION:
		newest = maxi(newest, count)
	assert_eq(newest, PawnStateId.ALL.size(), "the table's newest state count is not today's")

## Who is admitted, who is refused, and who is corrected. US-0025.
##
## The distinction this file exists for: **two disagreements, two different
## answers.** A wire-format disagreement is a rejection; a tuning disagreement is
## a correction. Collapsing them — kicking on a tuning mismatch — would be a
## single line's change and would read as consistency.
extends GutTest


func test_a_matching_peer_is_admitted() -> void:
	assert_eq(
		Handshake.check(Messages.PROTOCOL_VERSION, Messages.build_hash()), Messages.Reject.NONE
	)


func test_a_wrong_protocol_version_is_refused() -> void:
	assert_eq(
		Handshake.check(Messages.PROTOCOL_VERSION + 1, Messages.build_hash()),
		Messages.Reject.PROTOCOL_VERSION
	)


func test_a_wrong_build_hash_is_refused() -> void:
	assert_eq(
		Handshake.check(Messages.PROTOCOL_VERSION, Messages.build_hash() + 1),
		Messages.Reject.BUILD_HASH
	)


func test_the_version_is_checked_before_the_build() -> void:
	# Not cosmetic. A version bump changes the surface the build hash is computed
	# over, so both differ at once — and "build hash mismatch" would send someone
	# looking for a corrupt install when the real answer is that they are running
	# last week's client.
	assert_eq(
		Handshake.check(Messages.PROTOCOL_VERSION + 1, Messages.build_hash() + 1),
		Messages.Reject.PROTOCOL_VERSION
	)


func test_a_tuning_mismatch_is_never_a_rejection() -> void:
	# **THE POINT OF THE WHOLE FILE.** `check()` does not take a tuning hash at
	# all, which is the strongest available statement that tuning cannot refuse a
	# peer: there is no argument to pass it through.
	assert_true(Handshake.needs_tuning_sync(1, 2), "a mismatch did not ask for a sync")
	assert_false(Handshake.needs_tuning_sync(7, 7), "matching profiles asked for a sync anyway")


func test_every_reason_says_something_different() -> void:
	# A reason that renders as the same sentence as another is a reason nobody can
	# act on, which is most of what a rejection is for.
	var seen: Dictionary = {}
	for reason: int in [Messages.Reject.PROTOCOL_VERSION, Messages.Reject.BUILD_HASH]:
		var text := Handshake.reason_text(reason as Messages.Reject)
		assert_false(text.is_empty(), "reason %d renders as nothing" % reason)
		assert_false(seen.has(text), "two reasons render identically: %s" % text)
		seen[text] = true

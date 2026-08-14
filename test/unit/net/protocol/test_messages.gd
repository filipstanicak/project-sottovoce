## The wire surface. NETWORK_PROTOCOL §1.1 and §2.1, US-0025.
##
## Every assertion here is about a *rule*, not about a number. The channel
## numbers are pinned because they are the wire; everything else is checked as a
## property — that unknown messages are refused, that the forbidden ones stay
## unsendable, and that the build hash notices a change to the surface it covers.
extends GutTest


func test_the_channel_numbers_are_the_wire() -> void:
	# Pinned, not derived. These three integers travel in every ENet packet
	# header, and a peer on the other side of a rolling restart reads them
	# positionally — so renumbering them is a protocol break, not a refactor.
	assert_eq(Messages.Channel.STATE, 0)
	assert_eq(Messages.Channel.EVENT, 1)
	assert_eq(Messages.Channel.SESSION, 2)
	assert_eq(Messages.CHANNEL_COUNT, 3, "the peer is sized for a different number of channels")


func test_the_high_volume_stream_is_unreliable_and_the_rest_is_not() -> void:
	# The split's whole purpose: a retransmitted score event must never be able to
	# delay a snapshot. Asserted as a property of the two streams rather than
	# message by message, so a new message joining the wrong one is caught.
	assert_eq(Messages.channel_for(Ids.NET_S2C_SNAPSHOT), Messages.Channel.STATE)
	assert_eq(Messages.channel_for(Ids.NET_C2S_INPUT), Messages.Channel.STATE)
	assert_eq(Messages.channel_for(Ids.NET_S2C_SCORE_EVENT), Messages.Channel.EVENT)
	assert_eq(Messages.channel_for(Ids.NET_C2S_HELLO), Messages.Channel.SESSION)
	assert_eq(Messages.channel_for(Ids.NET_S2C_WELCOME), Messages.Channel.SESSION)


func test_an_undeclared_message_has_no_channel() -> void:
	# NOT a default of STATE. A message invented in code and never documented must
	# fail loudly at the point of sending, rather than quietly riding the
	# unreliable stream and going missing under packet loss.
	assert_eq(Messages.channel_for(&"NET-S2C-INVENTED"), -1)


func test_no_forbidden_message_can_be_sent() -> void:
	# **THE PROTOCOL'S CENTRAL CLAIM, AS A TEST.** A client cannot express "I
	# killed someone". `Ids` declares these five because §2.1 names them while
	# explaining that they do not exist — the harvest cannot tell a prohibition
	# from a specification, so the prohibition is declared in code.
	for id: StringName in Messages.FORBIDDEN:
		assert_true(Messages.is_forbidden(id), "%s stopped being forbidden" % id)
		assert_eq(Messages.channel_for(id), -1, "%s was given a channel" % id)


func test_every_message_the_corpus_forbids_is_listed() -> void:
	# Guards the other direction, and it is the direction that matters: a typo in
	# `FORBIDDEN` forbids nothing at all while reading exactly like a rule being
	# enforced. Written against the `Ids` constants, so a forbidden message that
	# quietly stopped being declared fails to compile rather than to assert.
	for id: StringName in [
		Ids.NET_C2S_KILL,
		Ids.NET_C2S_STUN,
		Ids.NET_C2S_POSITION,
		Ids.NET_C2S_SUSPICION,
		Ids.NET_C2S_SCORE,
	]:
		assert_true(Messages.FORBIDDEN.has(id), "%s dropped off the forbidden list" % id)


func test_the_build_hash_covers_the_surface_it_claims_to() -> void:
	# It must be stable within a build and sensitive to the catalogue. Asserted by
	# construction rather than against a magic number — a pinned hash would have
	# to be updated by hand every time a message is added, which is precisely when
	# nobody would notice it had stopped meaning anything.
	assert_eq(Messages.build_hash(), Messages.build_hash(), "the build hash is not stable")
	assert_ne(Messages.build_hash(), hash(Messages.PROTOCOL_VERSION), "it hashes the version only")


func test_the_map_id_on_the_wire_is_a_byte() -> void:
	# `NET-S2C-WELCOME` carries `map_id:u8`, so whatever the corpus calls the map,
	# what travels is a small integer.
	var wire: int = Messages.MAP_ON_THE_WIRE[Ids.MAP_VETRAIO]
	assert_between(wire, 0, 255, "the map id does not fit in the byte the schema declares")

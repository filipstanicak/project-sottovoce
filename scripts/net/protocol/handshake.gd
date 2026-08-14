## `NET-C2S-HELLO` and what the server does with it. NETWORK_PROTOCOL §2–3.
##
## PURE and static. The decision to admit a peer is arithmetic on four numbers,
## and it is written here — with no peer, no socket and no autoload — so that
## every branch is a unit test rather than something only a two-process
## integration run can reach.
##
## **TWO KINDS OF DISAGREEMENT, TWO DIFFERENT ANSWERS**, and the difference is
## the whole design:
##
## A **protocol version or build hash** disagreement is a rejection with a
## reason: the two peers cannot read each other's packets at all, and continuing
## produces garbage that looks like line corruption.
##
## A **tuning hash** disagreement is not. The client can read everything; it
## merely holds different numbers, and the server can simply send it the right
## ones. Kicking someone over a stale balance patch is a hostile answer to a
## problem that has a polite one.
class_name Handshake
extends RefCounted


## Whether this hello may be admitted, and why not if it may not.
##
## `Messages.Reject.NONE` means admit. The tuning hash is **not** consulted here:
## it can never refuse a peer, so letting it into the reject path at all would be
## an invitation to return it from here one day.
static func check(protocol_version: int, build_hash: int) -> Messages.Reject:
	if protocol_version != Messages.PROTOCOL_VERSION:
		return Messages.Reject.PROTOCOL_VERSION
	if build_hash != Messages.build_hash():
		return Messages.Reject.BUILD_HASH
	return Messages.Reject.NONE


## Whether the server must follow `NET-S2C-WELCOME` with `NET-S2C-TUNING-SYNC`.
##
## The client's hash travels in the hello for exactly this: the catalogue says
## the sync is sent *on mismatch*, and a server that never learns the client's
## hash could only ever send it always or never. Six kilobytes on every join
## would work and would hide a real disagreement inside a routine transfer.
static func needs_tuning_sync(client_hash: int, server_hash: int) -> bool:
	return client_hash != server_hash


## A reason a human can read, for the log and for the client's disconnect notice.
##
## Not a user-facing string — `data/strings/en.csv` owns anything a player sees.
## This is diagnostic text, and it names the two hashes because "rejected" with
## no numbers is the least useful log line in networking.
static func reason_text(reason: Messages.Reject) -> String:
	match reason:
		Messages.Reject.PROTOCOL_VERSION:
			return "protocol version mismatch"
		Messages.Reject.BUILD_HASH:
			return "build hash mismatch — the two peers disagree about the wire format"
		Messages.Reject.LOBBY_FULL:
			return "the lobby is full — no wire slot is free"
		_:
			return "accepted"

## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **A SCORE EVENT REACHES THE PLAYER WHO EARNED IT AND NOBODY ELSE.** Never-do
## #12, GDD-06 §2.3, `NETWORK_PROTOCOL.md` §4, US-0074.
##
## *"X killed Y" broadcast to everyone would tell every player how the contract
## cycle has shifted, for free. The cycle's opacity is load-bearing.* The score
## feed is the closest thing this game has to a kill feed, so it is the surface
## where that law is easiest to break by accident — one `rpc()` instead of one
## `rpc_id()` and every player learns every kill, with nothing failing.
##
## **THE ENFORCEMENT IS STRUCTURAL RATHER THAN A FILTER.**
## `MatchAnnouncer.flush_score` sends to `ScoreEvent.actor_id`, which is a field of
## the event; there is no recipient list to widen. This refuses the two shapes that
## would undo that.
extends GutTest

const COURIER := "res://scripts/server/match_announcer.gd"
const WIRE := "res://scripts/net/event_wire.gd"

## Client layers, which may not decide who is told anything.
const CLIENT: Array[String] = [
	"res://scripts/presentation",
	"res://scripts/mirrors",
	"res://scripts/pawn",
]


func test_the_scan_reaches_the_files_at_all() -> void:
	# The vacuous-success guard. `ip-guard` reported clean over zero of 739 files
	# for two milestones, and every assertion below passes over an unreadable file.
	assert_gt(SourceScanner.read(COURIER).length(), 500, "the courier could not be read")
	assert_gt(SourceScanner.read(WIRE).length(), 500, "the wire could not be read")


func test_the_score_message_is_addressed_and_never_broadcast() -> void:
	# `rpc_id` names one peer; `rpc` reaches everybody. The tell
	# (`NET-S2C-ABILITY-STARTED`) is the only message in this game that may reach a
	# room, and it does so by calling `rpc_id` once per recipient rather than by
	# broadcasting — so a bare `rpc(` anywhere in this file is a defect whichever
	# message wrote it.
	for row: Array in SourceScanner.code_lines(WIRE):
		var line := str(row[1]).strip_edges()
		assert_false(
			line.contains(".rpc(") or line.begins_with("rpc("),
			"event_wire.gd:%d broadcasts: %s" % [int(row[0]), line]
		)


func test_the_courier_addresses_the_actor() -> void:
	# The counterfactual for the guard above: a file with no send at all satisfies
	# "nothing broadcasts" perfectly.
	var source := SourceScanner.read(COURIER)
	assert_true(source.contains("send_score("), "the courier no longer sends anything")
	assert_true(
		source.contains("event.actor_id"),
		"the courier no longer addresses the event's own actor, so the recipient is a list again"
	)


func test_the_death_marker_is_withheld() -> void:
	# `ScoreLog.mark_death` records the victim as actor and the **killer** as
	# subject, so this is the one score event whose subject names somebody the
	# recipient has not earned. `NET-S2C-KILL-RESULT` is the message designed to
	# tell a victim who killed them; a second channel for it is one nobody audits.
	assert_true(
		SourceScanner.code_contains(COURIER, "Ids.SCORE_DEATH"),
		"the courier stopped withholding SCORE-DEATH"
	)


func test_no_client_layer_names_the_courier_or_another_players_score() -> void:
	# A client that could ask for somebody else's events is a client with a
	# scoreboard the design does not have. `INPUT-SCORE` shows standings on demand
	# and that is `SYS-RESULTS`' fold at match end, not a live feed.
	for folder: String in CLIENT:
		for path: String in SourceScanner.gd_files(folder):
			for term: String in ["MatchAnnouncer", "ScoreLog", "actor_id"]:
				assert_false(
					SourceScanner.code_contains(path, term),
					"%s names `%s`; scoring recipients are the server's" % [path.get_file(), term]
				)

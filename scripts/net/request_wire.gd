## **THE `EVENT`-CHANNEL CLIENT-TO-SERVER DOORWAY, ON ITS OWN NODE.**
## `NETWORK_PROTOCOL.md` §2, TDD-04 §4, US-0077. A child of the `Net` autoload.
##
## **THIS IS THE SPLIT `net.gd` HAS PREDICTED SINCE M4**, in its own words: *"the C2S
## doorway below could move the same way if this file grows again."* It grew — 398 of
## its 400 lines — and `NET-C2S-SKIP-RESULTS` is the message that would not fit.
## `EventWire` made the same move for the S2C direction and its docstring says why the
## move is legal at all: **a child of an autoload is at the same path on every peer**,
## which is the whole reason an RPC surface can live outside `net.gd`.
##
## **`NET-C2S-INPUT` DELIBERATELY DID NOT MOVE.** It is the one C2S message on the
## `STATE` channel, it runs at 60 Hz where everything here is a keypress, and the
## reason to touch it is a bandwidth argument rather than a line count. Moving it
## would also make this class's name a lie: it is the doorway for *requests*, and an
## input is not a request — it is the simulation's clock.
##
## **THE DOORWAY IS HERE; THE DECISION IS STILL THE ROUTER'S.** Every handler calls
## `authorise()` first — `Authority`'s table already carries all three rows, including
## `NET-C2S-SKIP-RESULTS`'s `[player, RESULTS, no pawn]` from M0 — and
## `test_no_client_authority.gd` refuses a handler that does not.
class_name RequestWire
extends Node

## The chokepoint, handed over by `Net.bind_router` rather than fetched per call.
##
## **A CACHED REFERENCE RATHER THAN A GETTER, AND THE ARCH GUARD IS WHY.**
## `test_authorisation_happens_before_the_work` permits **only** the sender lookup
## before `authorise()`, and it is right to: a handler that fetches anything first is
## a handler that has started acting. `var router := Net.router()` is one line of
## nothing and it still reddened the guard — correctly, because the rule is *first*,
## not *early*. This is `net.gd`'s own shape, in a second file.
var _router: RpcRouter = null


## Called by `Net.bind_router`, so the two doorways can never disagree about which
## router is live.
func bind(router: RpcRouter) -> void:
	_router = router


## `NET-C2S-ABILITY-REQUEST`. Aim is clamped by `SYS-ABILITY`, not here.
@rpc("any_peer", "call_remote", "reliable", Messages.Channel.EVENT)
func c2s_ability_request(slot: int, origin: Vector3, direction: Vector3) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if _router == null or not _router.authorise(peer, Ids.NET_C2S_ABILITY_REQUEST):
		return
	_router.receive_ability_request(peer, slot, origin, direction)


## `NET-C2S-BLEND-REQUEST`. Range and capacity belong to `SYS-BLEND`.
##
## **STILL WIRED TO NOTHING IN `server_root`, AND REPORTED RATHER THAN DELETED.** It
## is a second doorway for a verb that already works through `InputBits.BLEND`; a
## `NET-` id is merged and removing a protocol message is the owner's call.
@rpc("any_peer", "call_remote", "reliable", Messages.Channel.EVENT)
func c2s_blend_request(target_id: int) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if _router == null or not _router.authorise(peer, Ids.NET_C2S_BLEND_REQUEST):
		return
	_router.receive_blend_request(peer, target_id)


## `NET-C2S-SKIP-RESULTS`. **A vote, not a command** — US-0077 asks for the results to
## be skippable *only* by unanimous input, so that one impatient player cannot deny
## another the teaching moment. `MatchSystem` counts; this only carries the press.
##
## **IT CARRIES NOTHING AT ALL, AND THAT IS THE PAYLOAD.** There is no "yes or no" to
## send: pressing is the yes, and a vote that could be withdrawn would give the last
## player to change their mind a veto over a screen everybody else has finished
## reading. `Authority` refuses it outside `RESULTS`, so a client cannot bank one.
@rpc("any_peer", "call_remote", "reliable", Messages.Channel.EVENT)
func c2s_skip_results() -> void:
	var peer := multiplayer.get_remote_sender_id()
	if _router == null or not _router.authorise(peer, Ids.NET_C2S_SKIP_RESULTS):
		return
	_router.receive_skip_results(peer)


## Ask the server to end the results screen. CLIENT SIDE, called by the HUD.
##
## **EVERYTHING THAT SENDS ASKS FIRST**, `net.gd`'s own rule: with no peer at all
## Godot's caller id is 1, so addressing the server addresses the sender and fails —
## which is every test in this repo, none of which stands up a transport.
func send_skip_results() -> void:
	if not Net.is_client_connected():
		return
	c2s_skip_results.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


## Cast an ability. CLIENT SIDE, called by `InputSender` on the press edge.
func send_ability_request(slot: int, origin: Vector3, direction: Vector3) -> void:
	if not Net.is_client_connected():
		return
	c2s_ability_request.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, slot, origin, direction)

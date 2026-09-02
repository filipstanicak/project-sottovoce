## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **A CLIENT-TO-SERVER RPC WITH NO CALLER IS A BUTTON THAT DOES NOTHING.**
##
## Why review misses this: every piece looks finished. `NET-C2S-ABILITY-REQUEST`
## had its RPC on `Net`, its row in `Authority`, its channel in `Messages`, its hop
## in `RpcRouter`, its `server_root` wiring into `SYS-ABILITY`, and behind that a
## whole pipeline with five validations, a cooldown, a tell broadcast, two shipped
## effects and a pawn state. **Nothing on the client ever called it**, so pressing
## Q or F did literally nothing — through US-0066, US-0067 and US-0070, three
## stories that each declared their ability working.
##
## **AND NO TEST COULD HAVE SEEN IT.** The unit suites drive `AbilitySystem`
## directly, and `tools/ability_probe.tscn` calls `report_request` on the server
## in-process — deliberately, because that is the only way to test a system
## without a wire. The missing hop is between the two. **It was found by the owner
## pressing F and reporting that nothing happened**, which is where every defect
## that has mattered in this project has come from.
##
## The rule is narrow and mechanical: an `@rpc` named `c2s_*` exists to be sent, so
## something under `scripts/` must send it.
extends GutTest

const CLIENT_ROOTS: Array[String] = ["res://scripts"]

## **A DECLARED DOORWAY NOTHING WALKS THROUGH, KEPT WITH ITS REASON RATHER THAN
## SILENTLY ALLOWED.** `NET-C2S-BLEND-REQUEST` is a **second** path for a verb that
## already works: a blend press rides `InputBits.BLEND`, `PawnInputBuffer` sets
## `PawnContext.blend_requested`, and `SuspicionSystem` — which owns `SYS-BLEND` —
## reads it at the `suspicion` stage. The RPC and `RpcRouter.blend_requested` are
## wired to nothing in `server_root`.
##
## **It is REPORTED rather than deleted**: `NET-` ids are merged and immutable, and
## removing a protocol message is the owner's call. Listed here so it is visible
## every time this guard runs instead of being forgotten.
const VESTIGIAL: Dictionary = {
	"c2s_blend_request":
	(
		"NET-C2S-BLEND-REQUEST — a blend press rides InputBits.BLEND into "
		+ "PawnContext.blend_requested, which SuspicionSystem reads. This RPC is a "
		+ "second doorway that server_root never connects. Owner's call to remove."
	),
}


func _rpcs() -> PackedStringArray:
	var out: PackedStringArray = []
	for root: String in CLIENT_ROOTS:
		for path: String in SourceScanner.gd_files(root):
			for row: Array in SourceScanner.code_lines(path):
				var line := String(row[1]).strip_edges()
				if not line.begins_with("func c2s_"):
					continue
				out.append(line.substr(5).split("(")[0].strip_edges())
	return out


func test_the_scan_finds_the_rpcs_it_is_about() -> void:
	# **THE VACUOUS-SUCCESS GUARD.** A scan that matched no RPC would report every
	# one of them correctly sent.
	assert_gt(_rpcs().size(), 2, "the C2S scan found almost nothing — the paths are stale")


## **SENT, NOT MERELY DECLARED.** `.rpc_id(` or `.rpc(` somewhere under
## `scripts/`; a wrapper counts, because the wrapper is what a caller reaches for.
func test_every_c2s_rpc_is_actually_sent_by_something() -> void:
	var silent: PackedStringArray = []
	for name: String in _rpcs():
		if VESTIGIAL.has(name):
			continue
		var senders := 0
		for root: String in CLIENT_ROOTS:
			for path: String in SourceScanner.gd_files(root):
				for row: Array in SourceScanner.code_lines(path):
					var line := String(row[1])
					if line.contains(name + ".rpc"):
						senders += 1
		if senders == 0:
			silent.append(name)
	silent.sort()
	assert_eq(
		silent.size(),
		0,
		(
			"A client-to-server RPC is declared and never sent, so the button behind it\n"
			+ "does nothing however complete the server side looks. This is exactly how\n"
			+ "NET-C2S-ABILITY-REQUEST survived three stories:\n"
			+ "\n".join(silent)
		)
	)


## The exemption list must name things that exist, or it is a place for a real
## break to hide behind a stale name.
func test_the_vestigial_list_names_real_rpcs() -> void:
	var declared := _rpcs()
	var stale: PackedStringArray = []
	for name: String in VESTIGIAL:
		if not declared.has(name):
			stale.append(name)
	assert_eq(stale.size(), 0, "VESTIGIAL names an RPC that no longer exists: " + ", ".join(stale))

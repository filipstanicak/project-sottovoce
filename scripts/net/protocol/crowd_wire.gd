## **HOW THE CROWD BLOCK SAYS AN NPC HAS GONE.** TDD-04 §7.1.2, §7.1.3.
## PURE — a position, an observer, and a rule. No node, no socket, either end.
##
## Absence in the crowd block means "no update": culling (US-0030), rate LOD
## (US-0031) and `NpcDelta` all omit NPCs a client must keep drawing, which is why
## the block needed no `present_slots` and no protocol change where the remote-pawn
## block did. **So departure cannot be silence, and is carried by a value instead**
## — the server sends one final record at the NPC's real, now-out-of-range
## position, and it sends an out-of-range record for no other reason. That is what
## the cull is.
##
## **IT IS A CLASS OF ITS OWN BECAUSE TWO INDEPENDENT READERS MUST AGREE ON IT.**
## `SnapshotAssembler` has to stop carrying a departed NPC forward and `NpcView`
## has to free its body. When only the second knew the rule, the first replayed
## that one farewell in **every later snapshot** and the view obediently created
## and freed a body from it — measured on a running server at a constant
## **70.0231 m on 199 consecutive ticks**, and on six spawn points at **485 drops
## for 5 real departures.** Neither class was wrong about its own job.
class_name CrowdWire


## **ONE QUANTUM OF SLACK, BECAUSE THE SERVER CULLS ON FLOATS AND THE WIRE CARRIES
## CENTIMETRES.** An NPC at 69.997 m is inside the radius and sent normally;
## quantised to `TUN-NET-QUANT-POS` it can arrive measuring 70.004 and be read as a
## goodbye. Quantising x and z each to `q` bounds the distance error at
## `q / sqrt(2)`, so one whole quantum is provably enough. It leaves a band one
## centimetre wide in which an NPC that stops dead is held rather than dropped; any
## NPC that is walking leaves it inside a single tick.
##
## Horizontal and squared, like every other radius in this project.
##
## **ONLY EVER APPLIED TO A RECORD THIS SNAPSHOT ACTUALLY CARRIED.** A *stale*
## position beyond the radius is the observer having walked away, which is a
## different question with a different margin — and answering it with this rule
## would drop NPCs on a boundary the server has not agreed to.
static func is_farewell(at: Vector3, observer: Vector3) -> bool:
	var reach: float = Tuning.net.npc_cull_radius + Tuning.net.quant_pos
	var dx := at.x - observer.x
	var dz := at.z - observer.z
	return dx * dx + dz * dz > reach * reach

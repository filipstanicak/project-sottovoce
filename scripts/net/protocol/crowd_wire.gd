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


## **HOW MUCH DEEPER IN THE PAST THE CROWD IS DRAWN THAN A PLAYER.** ADR-0007.
##
## `TUN-NET-INTERP-BUFFER` is 100 ms and an NPC beyond `TUN-NET-NPC-RATE-LOD-RADIUS`
## is sent at `TUN-NET-NPC-RATE-LOD-HZ` — **one record every 100 ms**. So the render
## clock lands exactly on that NPC's newest sample with nothing in hand, and
## `SnapshotInterpolator` refuses to extrapolate past it, by design and rightly. Any
## late arrival is therefore drawn as a hold and then a catch-up, which is what the
## owner reported as far NPCs stuttering while near ones walk smoothly.
##
## **ONE SEND INTERVAL, DERIVED RATHER THAN CHOSEN**, so retuning the rate carries
## the margin with it. ADR-0007 asked for exactly this in writing — "10 Hz far-NPC
## updates require the interpolation buffer to stretch for those entities" — and
## only the timestamp half was ever built.
##
## **APPLIED TO THE WHOLE CROWD, NOT ONLY THE FAR BAND, AND THAT IS THE DECISION.**
## Banding it would put a discontinuity at `TUN-NET-NPC-RATE-LOD-RADIUS`: an NPC
## crossing it would have its whole time base shift by one interval and jump. A
## delay that varies with distance is also a delay that *drifts as the player
## walks*, which is an adaptive buffer by accident and ASM-0021 refuses those. The
## price is that the near crowd is drawn 100 ms staler than before, and it is
## affordable because **nothing reads a drawn NPC's position**: pawn and NPC share
## no collision layer, and every gameplay radius is resolved server-side against
## server positions. It buys the near band margin under loss as well.
static func crowd_extra_delay() -> float:
	return 1.0 / Tuning.net.npc_rate_lod_hz


## The whole distance into the past this client draws the crowd, in seconds.
##
## **THE CULL MARGIN IS DERIVED FROM THIS, NOT FROM `TUN-NET-INTERP-BUFFER`.** A
## view that lags further has drifted further from the observer it measures
## against, so a margin computed from the buffer alone would start dropping NPCs
## the server still believes this client holds — the exact failure `NpcView`'s
## margin exists to prevent, reintroduced by making the view deeper.
static func crowd_render_lag() -> float:
	return Tuning.net.interp_buffer / 1000.0 + crowd_extra_delay()

## Peer lifecycle, role and RTT statistics.
##
## STUB — full implementation in US-0025 through US-0028.
extends Node

## True on the dedicated headless server. Every GameSystem checks this before
## instantiating: systems exist ONLY server-side.
var is_server: bool = false


func rtt_ms(_peer: int) -> float:
	return 0.0

---
id: ADR-0010
title: Lag compensation scope and clamping
version: 1.0.0
status: accepted
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0002, ADR-0007, TUN-INDEX]
supersedes: none
---

# ADR-0010 — Lag compensation scope and clamping

## Context

The two decisive actions in this game happen at conversational distance and are resolved in
sub-second windows:

| Action | Range | Window |
|---|---|---|
| Kill | `TUN-KILL-RANGE` 2.5 m, cone `TUN-KILL-FACING-CONE` 60° | `TUN-KILL-CONTEST-WINDOW` 0.4 s |
| Stun | `TUN-STUN-RANGE` 3.0 m, cone `TUN-STUN-FACING-CONE` 120° | `TUN-STUN-FREEZE` 4.0 s consequence |

Under ADR-0002, a client renders remote players `TUN-NET-INTERP-BUFFER` = 100 ms in the past,
plus half its round-trip time. At 60 ms RTT that is 130 ms of staleness. A target walking at
`TUN-SPEED-STROLL` (2.2 m/s) has moved 29 cm in that time; at `TUN-SPEED-SPRINT` (6.2 m/s),
81 cm. Against a 2.5 m kill radius, sprinting targets alone produce a ~32 % positional error.

Without compensation, the experience is: *you walk up behind someone, press kill at
conversational distance, and nothing happens.* In a game whose entire emotional payload is
the patient approach, having the payoff moment fail arbitrarily is the worst possible bug.

The counter-force is well known: compensation means the server sometimes rewinds the world
to a state where the victim was somewhere they no longer are. From the victim's side this is
"I was killed after I got behind cover." Someone always pays for latency. The decision is
*who*, and *how much*.

## Options considered

| Option | Who pays | Verdict |
|---|---|---|
| **Rewind for kill/stun validation only, clamped to `TUN-NET-LAGCOMP-MAX` = 200 ms** | The victim pays, but bounded; and the high-ping *attacker* pays too, because the clamp caps their reach | **Chosen** |
| No lag compensation | The attacker pays entirely — kills fail arbitrarily | Rejected: destroys the game's payoff moment |
| Rewind everything (movement collision, LOS, blend membership) | Consistency, at high cost | Rejected — see below |
| Unclamped rewind | Nobody notices at low ping; at high ping the victim pays without limit | Rejected: a 600 ms player killing someone half a second in their past is indistinguishable from cheating |
| Client-authoritative hit declaration with server sanity checks | Nobody pays; everyone can cheat | Rejected under ADR-0002 |

## Decision

**The server rewinds the world for kill and stun validation only, by a clamped, per-client
amount.**

### Rewind amount

```gdscript
## Time the world is rewound when validating an action from `peer`.
func rewind_ms(peer: int) -> float:
    var rtt_half: float = NetStats.rtt_ms(peer) * 0.5
    var raw: float = rtt_half + Tuning.net.interp_buffer_ms
    return clampf(raw, Tuning.net.lagcomp_min_ms, Tuning.net.lagcomp_max_ms)
```

`TUN-NET-LAGCOMP-MIN` = 100 ms, `TUN-NET-LAGCOMP-MAX` = 200 ms. The floor exists because the
interpolation buffer alone is 100 ms and is unavoidable; the ceiling is the important half.

### What is rewound

| Entity | Rewound? | Why |
|---|---|---|
| Player positions and yaw | **Yes** | The primary source of error. |
| Player suspicion tier | **No** | Tier is server-computed and changes slowly relative to the rewind window; rewinding it would let a player kill based on a tier the victim had already left. Current tier is used. |
| NPC positions | **Yes** | Because NPCs occlude line of sight and determine blend membership (ADR-0007). Validating a kill against a *current* crowd when the attacker acted against a *past* one reintroduces the error we are fixing. |
| `ABIL-CINDERFALL` cloud volumes | **Yes** | A cloud that had not yet appeared must not retroactively block a kill, and one that has expired must still have blocked it. |
| Blend membership | **Derived from rewound NPC positions** | Not stored historically; recomputed from the rewound crowd. |
| Contract assignment | **No** | Uses current state. A rewound contract could let a player kill someone who is no longer their contract, which would be incomprehensible. |
| Cooldowns and ability availability | **No** | Always current. Rewinding these permits double-spends. |

### History buffer

`TUN-NET-LAGCOMP-HISTORY` = 500 ms of positional snapshots at `TUN-NET-SERVER-TICK` (30 Hz)
= 15 entries per entity. At 6 players + 90 NPCs × 16 bytes × 15 ≈ 23 KB. Negligible.
2.5× the maximum rewind, so the buffer is never the binding constraint.

### Validation grace

After rewinding, `TUN-KILL-VALIDATION-GRACE` = 0.35 m is added to the range check. This
absorbs quantisation (1 cm), interpolation-endpoint error, and sub-tick timing. It is
deliberately small: it is error absorption, not a range extension.

### Contest resolution interacts with rewind

Two players initiating within `TUN-KILL-CONTEST-WINDOW` are resolved by **server receive
timestamp**, not by rewound client time. This is deliberate and is a real trade: it means a
low-ping player wins a genuine tie. The alternative — comparing client-claimed timestamps —
is trivially forgeable and would hand the contest window to whoever lies best. Server receive
order is the only ordering the server can actually trust.

## Consequences

### Positive
- The patient approach reliably pays off. Walking up behind someone and pressing kill works,
  which is the single most important interaction in the game.
- The 200 ms ceiling puts the cost of a bad connection on the player who has it: above
  ~200 ms RTT their kills begin failing, because the server will not reach as far back as
  their client rendered. This is the correct place for the pain.
- Rewinding NPCs and Cinderfall volumes means "I was hidden in the crowd" and "the cloud was
  up" are validated against the world as the acting player saw it — the crowd's gameplay role
  (ADR-0007) is preserved through compensation rather than undermined by it.
- Not rewinding tier, contracts or cooldowns removes the exploit surface where a rewind grants
  something that was never available.

### Negative — stated honestly
- **"Killed behind cover" will happen and cannot be eliminated.** It is bounded to 200 ms of
  the victim's past. Players will report it; the honest answer is that it is the price of the
  approach working at all, and the alternative is worse.
- The mixed rewind policy (positions yes, tier no, contract no) is a set of rules a developer
  must know. It is documented here and in the network protocol reference, and it is the kind
  of thing that gets quietly broken by someone adding a fourth validated action without
  reading this. The compliance check exists for that reason.
- Server receive-order for contests advantages low ping. Accepted as the least-bad option;
  logged in telemetry (`TEL-CONTEST-RESOLVED` records both peers' RTT) so its real-world
  frequency and skew are measurable rather than assumed.
- Rewinding 90 NPCs per validation costs CPU. Mitigated: only NPCs within
  `TUN-CINDERFALL-RADIUS + TUN-KILL-RANGE` of the action are rewound, typically fewer than 10.

### Neutral / follow-on
- A debug visualisation that draws the rewound world at validation time is required for
  diagnosing disputed kills. Specified in
  [`../../20_tdd/12_build_and_ci.md`](../../20_tdd/12_build_and_ci.md) §5.
- If `SCORE-FOCUS`'s line-of-sight window ever becomes contested, it will need a rewind
  policy too. Currently it is evaluated continuously server-side and needs none.

## Compliance

- [ ] Only two call sites invoke the rewind: `KillSystem.validate()` and
      `StunSystem.validate()`. A third requires an ADR amendment.
- [ ] `rewind_ms()` clamps to `[Tuning.net.lagcomp_min_ms, Tuning.net.lagcomp_max_ms]` with
      no path that bypasses the clamp.
- [ ] `TUN-NET-LAGCOMP-MAX <= TUN-NET-LAGCOMP-HISTORY / 2` asserted by
      `test_tuning_ranges.gd` (invariant §17.16).
- [ ] Contest resolution reads a server-assigned tick, never a client-supplied timestamp.
      No `InputCommand` field named `client_time` is read by `KillSystem`.
- [ ] `test_lagcomp_rewind.gd` covers: a kill valid at 150 ms rewind and invalid at 0;
      a kill invalid at 250 ms rewind (proving the clamp); an NPC-occluded LOS that was clear
      in the past; a Cinderfall cloud that had not yet spawned failing to block.
- [ ] `test_lagcomp_no_exploit.gd` asserts that a rewound validation cannot resolve against a
      stale contract, a stale tier, or a cooldown that has since been spent.

## Revisit trigger

Reopen if playtest telemetry shows disputed-kill reports above ~2 % of kills, or if
`TEL-CONTEST-RESOLVED` shows contest outcomes correlating with RTT beyond chance at a rate
players notice. The first lever is lowering `TUN-NET-LAGCOMP-MAX`, which shifts cost from
victims back to high-ping attackers.

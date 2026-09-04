# ADR-0018 — The prey has more than one tooth

- **Status:** accepted
- **Date:** 2026-09-03
- **Deciders:** owner
- **Supersedes:** design law 5's original wording; amends invariant 19
- **Related:** ADR-0013 (the reference wins), ADR-0014 (escape), US-0061, US-0070

## Context

Owner decision 9, taken at the controls: *"the Lunge should stun the pursuer, also
revamp design law 5 so that it is fitting to the original."*

Two things were wrong, and only one of them was a missing mechanic.

**`ABIL-LUNGE` did nothing at all if you arrived at the person hunting you.** The
reference's equivalent resolves against **whoever it connects with** — a kill on
the target it reaches, a stun on a pursuer it reaches — and one of its unlock
challenges is stunning your pursuer with it. Half the ability was absent here, and
it was the defensive half.

**And design law 5 was wrong in every clause when measured against the reference.**
It read: *"Stun hard-counters a reckless hunter and is worth as much as a kill.
Never weaken it."*

| The law said | The reference does |
|---|---|
| a stun is *worth as much as a kill* | **200** for a stun, **100** for a base assassination |
| — and implicitly no more | a well-made kill is 100 + up to **400** of stealth bonuses, so it still beats a stun |
| the prey's teeth are **the stun** | a read stun, a smoke-bomb flush, a charge into a pursuer — and escape |
| *never weaken it* | already excepted once, by ADR-0013's uninterruptible kill |

The pricing error is the one that mattered: `TUN-SCORE-STUN` shipped at **100** with
invariant 19 pinning it equal to `TUN-SCORE-CONTRACT`, so the rule that existed to
*be* design law 5 was under-paying the prey by half while looking like fidelity.

## Decision

**1. A Lunge arrival resolves against a pursuer it passed.** `SYS-KILL` asks for
the kill first and the stun second — the reference's own ordering, *a kill is
always prioritised over a stun* — and a dash that stuns pays **no whiff stagger**,
because GDD-04 §3.4 prices that stagger for arriving at *nothing*.

Every other gate stays. The target is the lunger's own **announced** pursuer by
reverse lookup, exactly as a pressed stun's is; `TUN-STUN-MIN-TIER` still applies,
so an Anonymous hunter is unstunnable by this route as by every other; and it uses
the **stun's** reach (3.35 m) rather than the kill's (2.85), so the range advantage
is not quietly narrowed for one ability.

**2. `TUN-SCORE-STUN` 100 → 200**, the reference's number, and invariant 19 becomes
`TUN-SCORE-STUN > TUN-SCORE-CONTRACT` — a **floor rather than a ratio**, because a
stun must still lose to a well-made kill and `== 2 x` would pin a number no source
gives.

**3. Design law 5 is revamped**, to state a principle with several instruments
rather than one mechanic with a wrong price:

> **The prey must have teeth, and more than one.** Being hunted is the more
> frightening role and must not be the weaker one. A stun outscores a base kill and
> loses to a well-made one; the prey reaches that outcome by more than one route —
> a read stun, an escape, a Lunge into a pursuer — and none of them may be traded
> away to make hunting feel better.

## Consequences

**Never-do #13 generalises from the stun to the set.** A law that protects one
mechanic can be satisfied while the prey is disarmed of the other two, which is
precisely what had happened: escape shipped at ADR-0014 and the law never mentioned
it.

**The balance model moves and is not re-derived here.** BALANCE_MODEL §4's
kills-per-match figures were already stale — they model a 45 % stun-per-attempt
rate measured before ADR-0013 removed the last-instant save — and doubling the stun
payout moves the expected ratio again. `TEL-STUN-RATE` settles both; guessing a
rate and then three numbers that depend on it is what §4 already warns against.

**What was rejected: giving this route its own reach, cone or score.** A second set
of stun numbers is a second thing to retune and the first to drift. It calls
`StunSystem._land`, so the exile, the freeze, the score and the wire message are the
same ones a pressed stun produces — there is one stun in this game, reached three
ways.

**And what was rejected earlier stands: Cinderfall does not stun.** The reference's
smoke does, and 2026-09-03's analysis ruled for the divergence — its cloud can be
1.6 m only because it stuns *instead of* blocking kills, and our kill-block leaves a
protected core of `radius - reach` = 2.15 m that a 1.6 m cloud could not have. Three
teeth, not four.

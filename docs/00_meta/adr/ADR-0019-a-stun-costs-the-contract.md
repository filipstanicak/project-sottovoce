# ADR-0019 — A stun costs the pursuer the contract

- **Status:** accepted
- **Date:** 2026-09-04
- **Deciders:** owner
- **Supersedes:** nothing. **Amends:** GDD-03 §10.1's consequence table; appends
  `Reason.STUNNED` to `NET-S2C-CONTRACT-ASSIGNED`'s reason enum
- **Related:** ADR-0013 (the reference wins), ADR-0014 and US-0097 (escape),
  ADR-0018 (design law 5), US-0061 (`SYS-STUN`)

## Context

Reported from the controls on 2026-09-04, as a statement of the reference's rule
rather than as a defect: *"if a pursuer gets stunned or the prey escapes, his
contract is failed and he gets a new prey."*

**Half of it was already true and half of it was missing.** An escape has removed
the hunter from the cycle and reinserted them since US-0097 — that is the whole of
ADR-0014. A stun did nothing to the contract at all: `StunSystem._land` froze the
pursuer for `TUN-STUN-FREEZE` 4 s, held them at `TUN-SUSPICION-MAX`, and exiled
them from that one target for `TUN-STUN-LOCKOUT` 12 s. **After twelve seconds they
walked back to the same person.**

**The reference does not work that way**, and the sources say so plainly: stunning
your pursuer makes them lose their contract, and a player who loses a contract is
dealt another. The sources are deliberately not reproduced here — every one of them
names the franchise and `ip-guard` fails hard on that (never-do #5). They live in
the chat log and the owner's design notes, which is already where ADR-0013's audit
table lives for the same reason.

## Decision

**A stunned pursuer fails the contract and is dealt a new one**, through exactly
the call an escape already uses.

`ContractSystem.report_stun(pursuer, ctx)` is `report_escape`'s own body with a
different reason on it: the announcement is cleared immediately, the anti-repeat
history is told *before* the removal, the pursuer leaves the cycle, and the
reinsertion is queued behind `TUN-CONTRACT-REASSIGN-DELAY`.

`MatchConsequences.stunned` is the hop, wired to `StunSystem.stunned` in
`server_root`. `SYS-STUN` is judged inside `SYS-KILL` at the `combat` stage and
`SYS-CONTRACT` repairs at `contract`, so **the freeze and the reassignment land in
the same tick** — the ordering a kill has relied on since US-0060.

## Why it is the escape's own call and not a second route

The clear, the memory, the breath and the reinsertion are one rule that
`test_contract_cycle_fuzz.gd` drives over 10 000 events. A stun-shaped copy would
be the *rule implemented twice* this project keeps finding, and **the half that
would drift first is the memory** — `cycle.remember` before the removal is the one
line that stops the pursuer being handed straight back the person who just put them
on the ground. It is not obvious, it is one line, and it has no local reason to
exist. That is precisely the line a second implementation omits.

## What does not change, and why each was considered

**`TUN-STUN-LOCKOUT` 12 s stays, and it is not now redundant.** GDD-03 §10.2's
rationale for it — *"without the lockout, a stun costs the hunter 4 seconds and
they walk back"* — is superseded by this decision, which is a stronger version of
the same argument. But the exile is a per-`(hunter, target)` pair rule and the
cycle may legitimately deal those two together again later; the exile still binds
then. **Removing it to tidy up would be a weakening, which never-do #13 forbids
outright.** §10.2's reasoning is amended rather than the value.

**The prey is paid once.** `TUN-SCORE-STUN` 200 already prices this read.
`SCORE-ESCAPE` is not also awarded — that would pay one act twice under two names,
and it would make a stun worth 300 against a well-made kill's ceiling, which is the
ordering ADR-0018 spent its whole argument establishing.

**The tier floor is untouched.** `TUN-STUN-MIN-TIER` is what makes *"an Anonymous
hunter cannot be stunned — patience is genuinely safe"* true. This decision makes
the punishment for being careless larger; it does not widen who can be punished.

**`Reason.STUNNED` is appended, never inserted.** `NET-S2C-CONTRACT-ASSIGNED`
carries `reason:u8` as an index into `ContractSystem.Reason`, so a name inserted in
the middle silently retells every client a different story about why its contract
moved — the hazard `PawnStateId.ALL` carries and is guarded for. `STUNNED` is 5 and
`test_the_stun_costs_the_contract.gd` asserts both indices.

## Consequences

**A stun is now the strongest thing the prey can do, which is the point.** The
pursuer loses four seconds, their anonymity, the exile, the contract they had
spent the approach earning, and the identification that went with it — and the
prey keeps their own hunt. Design law 5 needs no further amendment: ADR-0018 wrote
it as *the prey reaches that outcome by more than one route*, and this makes two of
those routes cost the hunter the same thing.

**The balance model moves again and is deliberately not re-derived.** §4.3 already
models a 45 % stun rate measured before ADR-0013 removed the last-instant save, and
ADR-0018 doubled the payout. Contract churn per stun is a third change on top.
`TEL-STUN-RATE` settles all three; guessing a rate and then three numbers that
depend on it is what §4 already warns against.

**What is not modelled: how often a hunt now ends without a death.** A match has an
escape route and a stun route out of every contract, and nothing measures what
fraction of contracts end in either. That is a telemetry gap rather than a design
one, and it is named here so the first playtest knows to look.

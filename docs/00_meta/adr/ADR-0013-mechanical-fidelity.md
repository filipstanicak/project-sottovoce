---
id: ADR-0013
title: Mechanical fidelity to the reference title
version: 1.0.0
status: accepted
owner: Lead Game Designer
last_updated: 2026-08-26
depends_on: [DOC-IP-GUARDRAILS, DOC-SCOPE-FENCE]
supersedes: none
---

# ADR-0013 — Mechanical fidelity to the reference title

## Context

This project is a homage to one specific multiplayer mode: the 2010 social-stealth
"hunt your contract in a crowd" mode that defined the genre. **The reference title cannot be
named in this repository** — `docs/00_meta/IP_GUARDRAILS.md` §2 hard-bans it and CI enforces
that mechanically — so it is called *the reference* throughout the corpus. It is named in the
owner's external design notes.

Until 2026-08-26 the corpus treated that game as an influence. Many rules were invented here,
several of them explicitly to *improve on* it, and each was argued for at length. The owner
has now set the direction plainly: **all mechanics — climbing, killing, perks — should be as
close as possible to the reference.**

That is a legitimate instruction and the guardrails already say so. §1 of `IP_GUARDRAILS.md`:

> Game mechanics, rules, systems — generally **not** copyrightable. […] We may design a
> social-stealth game with contracts, blending, suspicion and a proximity compass. This is a
> **mechanical homage** and it is legitimate.

What remains protected, and therefore banned, is unchanged: names, art, audio, characters,
story, and trade dress.

## Decision

**Where a rule in this corpus diverges from the reference, the reference wins.** A divergence
is kept only when the owner has ruled specifically for it, and the ruling is recorded here.

Three consequences that are not obvious:

1. **A design law is not exempt.** Several of the project's own laws exist *because* they
   diverge. They are amendable like anything else, and three were amended on the strength of
   this ADR — see §Consequences.
2. **A claim about the reference is a specification, not trivia.** It must be researched and
   sourced before it becomes a `TUN-` value or a protocol shape. Recall is not evidence: two
   load-bearing claims were wrong on first telling during the audit that produced this ADR —
   that a stun could win a contested kill (it cannot), and that the reference has no
   carelessness gate on the pursuer reveal (it has one).
3. **The scope fence still binds.** Fidelity is not authority to add anything the reference
   has. Progression, unlocks and additional maps stay OUT for the reasons already recorded;
   what changes is that those reasons are now *acknowledged divergences* rather than
   silently-better choices.

## Options considered

| Option | Verdict |
|---|---|
| **Track the reference; record every remaining divergence as a ruling** | **Chosen.** It makes fidelity checkable — there is a list, and each item is either matched or has a name against it |
| Keep treating the reference as an influence, decide case by case | Rejected. This is what produced four divergences nobody had noticed until they were audited |
| Clone it exactly, including progression and unlocks | Rejected. Persistence needs accounts and a backend, and `SCOPE_FENCE.md` OUT #2 already prices that |

## Consequences

### Positive

- The design has an external referent, so "is this right?" has an answer that is not taste.
- The audit that produced this ADR found one whole missing verb — **escaping a pursuer** —
  which nobody had noticed was absent because there was nothing to notice it against.

### Amended by this ADR

| Rule | Was | Now |
|---|---|---|
| never-do #12 | No hit-direction indicator | The prey warning is **directional**. The nameplate ban survives, narrowed: no *names*, but a **relationship marker** on your own contract or your revealed pursuer is permitted |
| never-do #13 / design law 5 | Never weaken stun | Stun keeps its range advantage, tier gate, freeze and lockout. It **no longer interrupts a committed kill** |
| GDD-02 §3.2 rule 1 | A kill can be stopped before the contact frame | A kill in progress completes. Only a FATAL-priority event — a third party killing the killer — ends it |

### Negative — stated honestly

- **The project's thesis moves from mechanics into scoring.** "Patience beats speed" was
  enforced by the stun hard-countering a reckless hunter. In the reference it is enforced by
  a stealthy kill paying several times a careless one. **Those two changes have to move
  together**; adopting the combat rule without the scoring weights leaves speed neither
  punished nor discouraged. The re-pricing is owed and is not in this ADR.
- **Some of the amended arguments were good.** GDD-03 §10.4 spends a page defending stun as a
  mechanical refusal of the sprint approach, and it is not wrong — it is simply not what the
  reference does. It is preserved rather than deleted, so a future reversal has something to
  read.

### Neutral / follow-on

- The remaining divergences are inventoried in the owner's external audit, not here, because
  the table names the reference in every row.
- Four are large enough to need their own stories: the escape verb, line-of-sight-gated
  suspicion accrual, chase breakers, and the ability pool.

## Compliance

- [ ] A new mechanic cites what the reference does, with a source, before a `TUN-` value or a
      `NET-` payload is chosen for it.
- [ ] A deliberate divergence is recorded as a ruling — in this ADR's table, or in an ADR of
      its own — never left as an unremarked difference.
- [x] No franchise term enters the repository. `ip-guard` enforces it and this ADR does not
      weaken it.

## Revisit trigger

Playtesting shows the reference's rule is worse *for this game* — which is a real
possibility, since this game has a crowd of clones and an authored suspicion scalar the
reference did not. A reversal needs its own ADR naming the rule and the evidence.

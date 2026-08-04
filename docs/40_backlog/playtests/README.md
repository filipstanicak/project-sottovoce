# Playtest logs

One file per session: `YYYY-MM-DD.md`.

Every session records **all twelve questions** from
[`../../30_bible/TEST_PLAN.md`](../../30_bible/TEST_PLAN.md) §6.2, asked **individually and in
writing** — never aloud in the group, because the first answer spoken shapes every answer after
it.

Attach the telemetry export (`--record`) alongside. It carries the tuning profile hash, so the
session stays interpretable after values change.

## Template

```markdown
# Playtest YYYY-MM-DD

| | |
|---|---|
| Build / tag | |
| Tuning profile hash | |
| Players | n (external / team) |
| Matches | |
| Facilitator | |

## Observations
- The turn (mean speed, minute 1 vs minute 4):
- Anything the facilitator had to explain beyond the 60-second brief:

## Question responses
| # | Question | Responses |
|---|---|---|
| 1 | Walked past your target without recognising them? | |
| … | | |

## Reading
- Q5 vs Q4 (must be lower):
- Q7 (≥ 4/5):
- Q12 (≥ 70 % yes):

## Actions
| Finding | Story / ADR raised |
```

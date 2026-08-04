---
id: US-0009
title: EventBus autoload
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0006, BIBLE-EVENT-BUS]
---

# US-0009 — EventBus autoload

| | |
|---|---|
| **Milestone** | M0 |
| **Epic** | `EPIC-DATA` |
| **Systems** | `SYS-EVENTBUS` |
| **Estimate** | S |
| **Depends on** | US-0006 |

## Description

The one-way systems-to-presentation channel. Signal declarations and documentation comments only.

## Acceptance criteria

- [ ] `event_bus.gd` contains only signal declarations, comments and blank lines — no var, no func.
- [ ] Every signal from SIGNAL_AND_EVENT_BUS.md section 3 declared with matching arity.
- [ ] Every signal has a docstring.
- [ ] Names are past-tense facts — no on_ prefix, no _signal suffix.
- [ ] `prey_warning_triggered` takes ZERO parameters.
- [ ] Registered as an autoload.

## Test notes

`test_eventbus_is_stateless.gd`, `test_eventbus_signals_documented.gd`,
`test_prey_warning_signal_arity.gd`, `test_signal_naming.gd`.

## Notes

A stateful event bus is a global variable in disguise.

The zero-arity prey warning is the third of three layers enforcing directionlessness — no
protocol field, no signal parameter, nothing for a widget to render.

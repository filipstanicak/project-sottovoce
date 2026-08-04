---
id: US-0011
title: String table and Strings autoload
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-04
depends_on: [TDD-02-STRUCTURE]
---

# US-0011 — String table and Strings autoload

| | |
|---|---|
| **Milestone** | M0 |
| **Epic** | `EPIC-DATA` |
| **Systems** | — |
| **Estimate** | S |
| **Depends on** | US-0010 |

## Description

`data/strings/en.csv` and the Strings autoload. Localisation is out of scope; the table is not
(ASM-0023).

Retrofitting a string table across a finished UI is a multi-day refactor with a long tail of
missed strings. Doing it from commit one costs approximately nothing and makes the deferred work
a data task.

## Acceptance criteria

- [x] `data/strings/en.csv` exists in Godot translation CSV format.
- [x] `Strings.get_text(key)` resolves; a missing key logs push_error and returns the key. *(Not `get`: `Object.get(property)` already exists and shadowing it on an autoload breaks every engine call that reaches for a property by name.)*
- [x] Namespaces reserved: ui, bonus, **passive**, ability, persona, caption, credits, menu. *(`passive` added: `PassiveData` needs display keys and the original list omitted it.)*
- [x] `test_no_literal_strings.gd` finds no user-facing literal outside `data/strings/`.

## Test notes

The test scans for quoted strings assigned to Label.text, Button.text and similar.

## Notes

Every bonus name and every audio caption lives here, which also gives the IP guardrails one place
to review user-visible vocabulary.

> **Done 2026-08-04.** 56 keys covering every ability, passive, persona and score
> bonus that already exists in data, plus a minimal ui/menu/caption set. The unit
> test asserts every `display_key` on the generated `.tres` resources resolves —
> a resource pointing at a missing key would render the raw key in the ability bar
> and nothing else would complain.
>
> `test_no_literal_strings` scans **scenes as well as scripts**. A Label with its
> text typed into the editor never appears in any script, so a script-only scan
> would have reported success on the exact case most likely to happen.

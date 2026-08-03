---
id: DOC-IP-GUARDRAILS
title: IP Guardrails — Original Naming and Asset Rules
version: 0.1.0
status: draft
owner: Documentation Architect
last_updated: 2026-08-03
depends_on: [DOC-GLOSSARY]
---

# IP Guardrails — Original Naming and Asset Rules

**Status: non-negotiable.** These rules override convenience, override "it's just a
placeholder", and override "we'll rename it later". Renaming later does not work: names
leak into commit history, asset filenames, class names, string tables, screenshots, build
artefacts and playtester vocabulary. The cost of a rename grows superlinearly. Get it right
in the first commit.

---

## 1. The legal position, stated plainly

This section is a working summary for the team's day-to-day decisions. It is not legal
advice, and it is not a substitute for a lawyer's review before any public release.

| What | Protected? | Consequence for us |
|---|---|---|
| **Game mechanics, rules, systems** | Generally **not** copyrightable. Ideas, procedures, methods of operation and systems are excluded from copyright protection. | We may design a social-stealth game with contracts, blending, suspicion and a proximity compass. This is a **mechanical homage** and it is legitimate. |
| **Names and titles** | Protected as **trademarks** where used as source identifiers. | Never use another company's product, character, faction, or ability names. |
| **Characters** | Protected by copyright where sufficiently delineated; often also trademarked. | Invent our own. No named character may resemble an existing one in name, silhouette, costume or catchphrase. |
| **Art, models, textures, UI, logos** | Copyright. | Zero third-party game assets. Ever. Original or CC0-with-attribution only. |
| **Music and audio** | Copyright (composition and recording separately). | Original or CC0. Record every source. |
| **Story, dialogue, setting-specific lore** | Copyright. | Our fiction is original and deliberately thin. |
| **Trade dress / overall look and feel** | Protectable where distinctive and non-functional. | Our UI, colour language, HUD layout and menu presentation must not evoke another product's presentation. This is the rule people forget. |

**The two-sentence version:** we may build the same *kind* of game. We may not use anyone
else's *words, pictures, sounds or characters*, and we may not dress ours up to look like
theirs.

---

## 2. Banned terms

The following terms must never appear in this repository — not in documentation, not in
code, not in identifiers, not in comments, not in commit messages, not in asset filenames,
not in branch names, not in playtest scripts, not in the string table, not in issue titles.

### 2.1 Hard-banned (Ubisoft / Assassin's Creed franchise)

```
Assassin's Creed        Assassin's            AC (as an abbreviation for the franchise)
Abstergo               Animus                Templar
Brotherhood            Ezio                  Altair / Altaïr
Desmond                Eagle Vision          Eagle Sense
Leap of Faith          Hidden Blade          Apple of Eden
Piece of Eden          Isu                   Precursor (in the franchise sense)
Creed                  Bureau (in the franchise sense)
Ubisoft                Ubi                   Anvil / AnvilNext
Wanted (as the mode name)                    Deathmatch (as the franchise mode name)
```

### 2.2 Also banned — franchise-adjacent phrasings

These are not trademarks, but they are the specific vocabulary of the franchise and using
them signals imitation rather than homage.

```
"Nothing is true"          "Everything is permitted"
"Requiescat in pace"       "Stay your blade"
"Master Assassin"          "Novice / Mercenary / Guardian" (as rank names)
"Social link" (as the blend mechanic name)
"Notoriety" (as the suspicion mechanic name)
"Blend group" is acceptable; "blending group of monks/scholars" is not
```

### 2.3 Also banned — other franchises

Because this project sits adjacent to several, and the same rules apply:

```
Hitman        Agent 47       ICA        Providence       "Silent Assassin"
Spy Party     Deceit         Among Us   "Impostor" (as a role name)
Payday        Dishonored     Thief      "The Dark Project"
```

### 2.4 Discouraged generic terms

Not illegal, but ambiguous or franchise-flavoured. Use the listed replacement so that the
vocabulary in this project is consistent and defensibly ours.

| Do not write | Write |
|---|---|
| smoke bomb | **Cinderfall** (`ABIL-CINDERFALL`) |
| throwing knife / throwing blade | **Whisperbolt** (`ABIL-WHISPERBOLT`) |
| disguise (as the ability's proper name) | **Second Face** (`ABIL-SECONDFACE`) |
| charge / tackle / sprint-attack | **Lunge** (`ABIL-LUNGE`) |
| notoriety / awareness / detection meter | **suspicion** (`SYS-SUSPICION`) |
| target | **contract** (`SYS-CONTRACT`) |
| stealth kill | **Silent kill** (`SCORE-SILENT`) |
| hay bale / haystack | **hay cart** (a concealment prop, `PROP-HAYCART`) |
| viewpoint / synchronisation point | **bell-tower vantage** (`LOC-CAMPANILE`) |
| guard | *(there are no guards in MVP — do not introduce the concept)* |

---

## 3. Original naming rules

### 3.1 The functional-original rule

Every ability, persona, faction, location and UI element gets an **original name** that is
**functionally descriptive** rather than borrowed. The test: a player who has never seen the
name should be able to guess roughly what it does, and a lawyer should not be able to find
it in another company's trademark register.

| Good | Why |
|---|---|
| **Cinderfall** | Original compound. "Cinder" tells you it is fire/ash; "fall" tells you it drops. Not in use elsewhere in this space. |
| **Whisperbolt** | Original compound. "Whisper" = quiet, "bolt" = thrown projectile. |
| **Second Face** | Original. Plainly means "you look like someone else". |
| **Cold Read** | Original in this usage. Names the skill it rewards: reading a person from little information. |

| Bad | Why |
|---|---|
| "Smoke Bomb" | Generic-descriptive, evokes the franchise vocabulary, unmemorable, unprotectable. |
| "Shadow Strike" | Fantasy-generic. Tells the player nothing. Almost certainly in use. |
| "Eagle Sight" | Franchise-adjacent by construction. Hard no. |

### 3.2 The original-name-first rule

**Every document lists the original name first**, with any functional description second and
subordinate:

> ✅ **Cinderfall** — an area-denial ability that blocks line of sight for 4 s.
>
> ❌ The smoke ability, which we're calling Cinderfall.

This is not pedantry. It is how a name becomes the team's actual vocabulary. If the internal
shorthand stays "the smoke bomb", it will reach a screenshot eventually.

### 3.3 The naming registry

Every original name in the project is registered in
[`GLOSSARY.md`](GLOSSARY.md) with its ID. A name that is not in the glossary is not a name
yet — it is a placeholder, and placeholders may not be committed.

Current registry summary:

| Category | Names |
|---|---|
| **City** | Vessalia |
| **Map** | Rione Vetraio (the Glassmakers' Quarter), `MAP-VETRAIO` |
| **Personas** | Vetraio (Glasswright), Cantatrice (Street Singer), Lucerna (Lamp-Tender), Pesatore (Weighmaster) |
| **Abilities** | Cinderfall, Whisperbolt, Second Face, Lunge |
| **Passives** | Stillness, Cold Read, Second Wind |
| **Score bonuses** | Contract Fulfilled, Silent, Patient, Masked, Focus, From Above, Blended, Poisoned, Long Hunt, Vendetta, Variety, Reckless |
| **Mode** | Contract (free-for-all) |
| **Phase** | Final Contract |
| **Instrument** | the Compass |

Note on Italian vocabulary: common Italian nouns (*vetraio*, *cantatrice*, *lucerna*,
*pesatore*, *rione*, *piazza*, *loggia*, *campanile*) are ordinary language and generic
architectural terms. Using them is equivalent to naming an English character "the Glazier".
This is safe and is the intended flavour source. What is *not* safe is any proper noun
invented by another company.

---

## 4. Art and audio asset rules

1. **Placeholder art must be primitives or procedural.** Capsules, boxes, cylinders,
   procedurally-generated buildings. Silhouette differentiation is achieved with scale and
   attached primitives, not with downloaded models. See
   [`../30_bible/ART_BIBLE.md`](../30_bible/ART_BIBLE.md) §6.
2. **Third-party assets must be CC0**, or a licence with equivalent freedom, and must be
   recorded in [`ASSET_LICENSES.md`](ASSET_LICENSES.md) **in the same commit that adds the
   asset**. An asset without a licence row is a build-breaking condition.
3. **No asset ripped, extracted, or derived from a commercial game.** Ever. Including
   "just for reference", including in a scratch folder, including in a branch.
4. **Reference images are not assets.** Looking at photographs of Renaissance Italian
   architecture is research. Importing anything into the repo is an asset and needs a row.
5. **Fonts are assets.** Same rules. Godot's bundled fonts and OFL fonts are fine, recorded.
6. **Audio recorded by the team is original** and gets a row saying so, with the recordist
   named.
7. **No AI-generated assets in shipping builds without an ADR** recording the tool, the
   prompt, and the licence position of its output. Placeholder use during greybox is
   permitted if recorded.

---

## 5. The pre-commit review question

Before any commit that adds or renames a user-visible name, asset, UI element or sound, ask:

> ### **"Would a reasonable person mistake this asset for Ubisoft's?"**

If the answer is *yes*, *maybe*, or *I'd have to think about it*, the commit does not go in.
Rework it and ask again.

Two supporting questions for the harder cases:

> **"If I showed this to someone with no context, what would they name?"**
> If the answer is another company's product, stop.

> **"Is this resemblance doing design work, or is it just resemblance?"**
> A hood is functional: it makes a silhouette readable at 40 m and reads as period-plausible.
> A specific hood shape copied from a specific character is just resemblance. Keep the
> function, discard the copy.

---

## 6. Enforcement

### 6.1 Automated

A banned-terms grep runs in CI over the whole repository, including documentation. It is a
**hard failure**, not a warning.

```bash
# .github/workflows/ci.yml — ip-guard job
# Fails the build if any banned term appears anywhere in the repo.
grep -rIn --exclude-dir=.git -i -f .ci/banned_terms.txt . && exit 1 || exit 0
```

`.ci/banned_terms.txt` contains the terms from §2.1–§2.3, one per line. This file is
maintained alongside this document; **the two must not diverge**, and a mismatch is caught by
the docs-sync check in [`../30_bible/DEFINITION_OF_DONE.md`](../30_bible/DEFINITION_OF_DONE.md).

Known exception handling: this document itself necessarily contains the banned terms. It is
the sole file on the grep's exclusion list, alongside `.ci/banned_terms.txt`:

```
# .ci/ip_guard_exclude.txt
docs/00_meta/IP_GUARDRAILS.md
.ci/banned_terms.txt
```

Adding any other file to that exclusion list requires an ADR.

### 6.2 Human

- The pre-commit review question in §5 is part of the
  [Definition of Done](../30_bible/DEFINITION_OF_DONE.md) checklist.
- Any new user-visible name must be added to [`GLOSSARY.md`](GLOSSARY.md) in the same
  commit that introduces it.
- Playtest facilitators use only original names when explaining the game. If a facilitator
  says "it's like the smoke bomb in—", that is a vocabulary bug: file it.

### 6.3 What to do if a banned term is found in history

Do not rewrite published history reflexively. Instead: fix forward, note it in
[`DECISION_LOG.md`](DECISION_LOG.md), and — before any public release of the repository —
run a history scrub as a single planned operation with an ADR.

---

## 7. The homage boundary, in concrete cases

Recorded so the team does not have to re-derive these judgements.

| Case | Verdict | Reasoning |
|---|---|---|
| A proximity indicator that pulses faster as you approach your target | **Allowed** | Pure mechanic. Our visual design, colour language and audio are original. |
| A "blend into a group of civilians" verb | **Allowed** | Pure mechanic. Our groups are walking merchants, our activation is original, our name is original. |
| Renaissance Italian setting | **Allowed** | A historical period and a real place-type. Nobody owns the Italian Renaissance. |
| A hooded figure in a white robe with a red sash and a beaked hood | **Banned** | That is a specific character design. Trade dress and character copyright. |
| Calling the roof stratum "viewpoints" | **Banned** | Franchise vocabulary. Use **bell-tower vantage**. |
| A UI that fades to a grid-white loading screen with glitch text | **Banned** | Trade dress. Our loading screen is a plain plate with our own type. |
| Naming a persona "Ezio the Glasswright" | **Banned** | Character name. |
| Naming a persona "Vetraio" | **Allowed** | Italian for glassmaker. Ordinary language. |
| A kill animation where the killer walks past the victim and the victim slumps | **Allowed** | Mechanic and staging convention, widely used, functionally motivated (the killer must remain anonymous, so the animation cannot be theatrical). |
| Using a period-accurate Florentine building photographed by a team member | **Allowed**, record it | Original photography of a public building; record in [`ASSET_LICENSES.md`](ASSET_LICENSES.md). |

---

## 8. Acceptance criteria for this document

- [ ] `.ci/banned_terms.txt` exists and contains every term from §2.1–§2.3.
- [ ] The `ip-guard` CI job exists and is a required check on `main`.
- [ ] Every original name in §3.3 appears in [`GLOSSARY.md`](GLOSSARY.md) with an ID.
- [ ] The §5 review question appears in [`../30_bible/DEFINITION_OF_DONE.md`](../30_bible/DEFINITION_OF_DONE.md).
- [ ] [`ASSET_LICENSES.md`](ASSET_LICENSES.md) has a row for every file under `assets/`
      that the team did not author, verified by a CI asset-inventory check.

## 9. Open questions

| # | Question | Owner | Needed by |
|---|---|---|---|
| 1 | Is "Project Sottovoce" the shipping title or a codename? *Sottovoce* is an ordinary Italian/musical term (a real musical direction meaning "in an undertone") and is therefore weakly distinctive as a trademark. If it ships, a trademark search is required. | Stakeholder | Before any public announcement |
| 2 | Do we want a legal review before the first external playtest, or before first public build? External playtests with NDA-less participants create screenshot risk. | Stakeholder | Before M6 |
| 3 | Position on AI-generated placeholder art — permitted with recording, or banned outright? Currently permitted for greybox only, per §4.7. | Stakeholder | M3 |

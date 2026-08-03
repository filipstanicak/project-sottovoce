---
id: DOC-ASSET-LICENSES
title: Third-Party Asset Register
version: 0.1.0
status: draft
owner: Documentation Architect
last_updated: 2026-08-03
depends_on: [DOC-IP-GUARDRAILS]
---

# Third-Party Asset Register

Every file in this repository that the team did not author has a row in this document.
No exceptions, no "temporary" imports, no untracked scratch folders.

**The rule:** the licence row is added in **the same commit that adds the asset**. An asset
without a row is a build-breaking condition, checked by the `asset-inventory` CI job
described in §5.

**Why this is strict:** licence provenance is trivially cheap to record at import time and
extremely expensive to reconstruct later. An unattributable asset discovered at release
means deleting it and redoing the work that depended on it.

---

## 1. Acceptable licences

| Licence | Accepted? | Attribution required in-build? | Notes |
|---|---|---|---|
| **CC0 1.0 / Public Domain** | ✅ Preferred | No (but we record it here anyway) | The default choice. |
| **CC-BY 4.0** | ✅ | **Yes** — must appear in the in-game credits screen | Requires the credits screen to exist before M6. |
| **OFL (fonts)** | ✅ | Per licence terms | Fonts only. Do not rename the font files. |
| **MIT / BSD / Apache-2.0** | ✅ | Notice file in build | Normal for code/tooling, unusual for art. |
| **CC-BY-SA** | ⚠️ ADR required | Yes | Share-alike may impose obligations on derived assets. Do not use without an ADR. |
| **CC-BY-NC** | ❌ | — | Non-commercial. Incompatible with any future commercial release. |
| **CC-BY-ND** | ❌ | — | No-derivatives. We always derive. |
| **"Free for personal use"** | ❌ | — | Not a licence. |
| **Unlicensed / unknown** | ❌ | — | Delete it. |
| **Anything extracted from a commercial game** | ❌❌ | — | See [`IP_GUARDRAILS.md`](IP_GUARDRAILS.md) §4.3. This is a fireable-level mistake, not a style preference. |

---

## 2. Register — art

*No third-party art assets are present. All placeholder geometry is engine primitives
authored in-repo, per [`ASSUMPTIONS.md`](ASSUMPTIONS.md) ASM-0029.*

| ID | File path | Description | Source | Author | Licence | Attribution string | Added in | Verified by |
|---|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — | — |

---

## 3. Register — audio

*No third-party audio assets are present. MVP audio events are placeholder tones generated
procedurally in-engine, per [`../30_bible/AUDIO_BIBLE.md`](../30_bible/AUDIO_BIBLE.md) §7.*

| ID | File path | Description | Source | Author | Licence | Attribution string | Added in | Verified by |
|---|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — | — |

---

## 4. Register — fonts, tooling and code dependencies

| ID | Name | Version | Used for | Licence | In shipped build? | Added in |
|---|---|---|---|---|---|---|
| `DEP-GODOT` | Godot Engine | 4.5 stable | Engine | MIT | Yes (runtime) | M0 |
| `DEP-GUT` | GUT (Godot Unit Test) | pinned at M0 | Unit + integration tests | MIT | **No** — dev-only, excluded from export | M0 |
| `DEP-GDLINT` | gdtoolkit (`gdlint`, `gdformat`) | pinned at M0 | Lint and format in CI | MIT | **No** — CI-only | M0 |
| `DEP-FONT-UI` | Godot's bundled default font | bundled | All UI text at MVP | MIT (bundled with engine) | Yes | M0 |

**Note on `DEP-GUT` and `DEP-GDLINT`:** both must be excluded from export presets. A test
framework shipped inside a game build is both a size cost and an attack surface. The export
exclusion is asserted by a CI check listed in
[`../20_tdd/12_build_and_ci.md`](../20_tdd/12_build_and_ci.md) §6.

---

## 5. Enforcement — the `asset-inventory` CI job

The job walks every file under `assets/`, `data/fonts/` and `addons/`, and fails if any
path is absent from this register.

```bash
# .ci/check_asset_inventory.sh (invoked by the asset-inventory CI job)
# 1. Enumerate every non-authored asset path in the repo.
# 2. Extract every `File path` cell from this document.
# 3. Fail on any path present in (1) and absent from (2).
# 4. Fail on any path present in (2) and absent from (1)  -> stale row, delete it.
```

Both directions are checked. A stale row is as much a defect as a missing one: it means
somebody deleted an asset and left a claim about it in the register, which makes the whole
register untrustworthy.

**Exempt paths** (authored in-repo, never third-party):

```
assets/greybox/**       # engine primitives, authored in-editor
assets/procedural/**    # generated at import time by our own tool scripts
```

Adding a path to the exemption list requires an ADR.

---

## 6. Import procedure

When adding any third-party asset:

1. **Confirm the licence at the source.** Screenshot or archive the licence statement — not
   the download page, the licence statement. Store it under `docs/00_meta/licenses/`.
2. **Check it against §1.** If it is not in the ✅ list, stop.
3. **Add the file** under the correct `assets/` subfolder.
4. **Add a row** to §2 or §3 in the same commit, including the exact attribution string the
   author requires, character for character.
5. **If attribution is required in-build**, add the string to `data/strings/en.csv` under the
   `credits.*` namespace in the same commit.
6. **Answer the [IP guardrails](IP_GUARDRAILS.md) §5 review question** before pushing.

---

## 7. Attribution rendering

Where a licence requires in-build attribution, the string appears in the credits screen,
grouped by licence, in the exact form the author specifies. The credits screen is a
milestone-M6 deliverable and is a hard blocker for any CC-BY asset: **do not import a CC-BY
asset before the credits screen exists**, because the build will be non-compliant from the
moment it is exported.

Current status: **no CC-BY assets, credits screen not yet required.** If this changes, the
credits screen story is promoted into the milestone that adds the asset.

---

## 8. Acceptance criteria for this document

- [ ] The `asset-inventory` CI job exists and is a required check on `main`.
- [ ] Both directions of the check (missing row, stale row) are implemented.
- [ ] Every row has a non-empty `Licence` and `Source` cell.
- [ ] No row uses a licence marked ❌ or ⚠️-without-ADR in §1.
- [ ] Export presets exclude `addons/gut/` and any lint tooling, asserted by CI.

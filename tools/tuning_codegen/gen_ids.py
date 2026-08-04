"""Generate scripts/core/ids.gd from the IDs harvested out of the docs corpus."""
import io, json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "scripts", "core", "ids.gd")

ids = json.load(io.open(os.path.join(HERE, "ids.json"), encoding="utf-8"))

# Declared in the corpus, but not a member of its namespace's runtime set.
# Mirrored by IdScanner.NOT_A_MEMBER, which is the committed source of truth.
NOT_A_MEMBER = {"SCORE-EVENT"}
for ns in ids:
    ids[ns] = [i for i in ids[ns] if i not in NOT_A_MEMBER]

# The namespaces code refers to at runtime. SYS-, RISK-, US-, ADR-, ASM- are
# documentation-only. TUN- has its own mechanism (US-0007). LOC-, MAT-, PROP-
# and TEL- are runtime-bound but arrive with the systems that use them.
NAMESPACES = [
    ("SCORE",   "Score event kinds. The ScoreEvent log is keyed on these."),
    ("ABIL",    "Abilities."),
    ("PASV",    "Passives."),
    ("PERSONA", "Playable personas. A persona is also a clone roster."),
    ("ARCH",    "NPC filler archetypes."),
    ("MAP",     "Maps."),
    ("EVT",     "Event-bus signals. Presentation only — systems call directly."),
    ("NET",     "Network messages. C2S is a request; S2C is a fact."),
    ("SFX",     "Sound effects."),
    ("MUS",     "Music stems."),
    ("ANIM",    "Animation clips."),
]

HEADER = '''## Every ID the code refers to by name, as `StringName`.
##
## `StringName` rather than `String` because these are compared on the hot path —
## every score append, every ability lookup, every state transition — and
## `StringName` comparison is pointer-equal and allocation-free.
##
## GENERATED FROM THE CORPUS, then committed. `test_ids_match_glossary.gd`
## asserts the two still agree in both directions: an ID here but not in the
## docs is undocumented, and one in the docs but not here is a name nobody
## implemented. Neither is allowed to persist.
##
## IDs ARE IMMUTABLE ONCE MERGED (`docs/30_bible/NAMING_AND_IDS.md` §2). A wrong
## name is deprecated with a note and a new one added. It is never renamed and
## never reused — a rename fails silently in archived telemetry, in `.tres`
## files and in test names that keep passing while testing the wrong thing.
class_name Ids
extends RefCounted
'''

lines = [HEADER]
total = 0
for ns, blurb in NAMESPACES:
    vals = ids[ns]
    total += len(vals)
    lines.append("\n# --- %s %s\n## %s\n" % (ns, "-" * (68 - len(ns)), blurb))
    for v in vals:
        name = v.replace("-", "_")
        lines.append('const %s := &"%s"\n' % (name, v))

body = "".join(lines)
io.open(OUT, "w", encoding="utf-8", newline="\n").write(body)

n_lines = body.count("\n")
print("constants: %d   file lines: %d   (limit 400)" % (total, n_lines))
over = [l for l in body.split("\n") if len(l) > 100]
print("lines over 100 chars: %d" % len(over))
bad = [v.replace("-", "_") for ns, _ in NAMESPACES for v in ids[ns]
       if not re.match(r"^_?[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$", v.replace("-", "_"))]
print("constant-name violations: %d %s" % (len(bad), bad[:5]))

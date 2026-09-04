"""Generate the *Tuning resource classes from TUNABLES.md."""
import io, json, os, re, textwrap, collections

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(ROOT, "scripts", "core", "tuning")

tun = {r["id"]: r for r in json.load(io.open(os.path.join(HERE, "tunables.json"), encoding="utf-8"))}
fm = json.load(io.open(os.path.join(HERE, "fieldmap.json"), encoding="utf-8"))
assigned = {k: tuple(v) for k, v in fm["assigned"].items()}

# Documented in the corpus with a TUN- ID, but not a value. Excluded, with the
# reason recorded here and mirrored by the docs-sync test.
NOT_A_VALUE = {
    "TUN-SUSPICION-GAIN-WHISPERBOLT-WINDUP":
        "a pointer row: ABIL-WHISPERBOLT forces Exposed instead of gaining suspicion",
}

CLASS_DOC = {
    "MovementTuning": "Speed states, traversal and the feel budget. TUNABLES §2.",
    "SuspicionTuning": "Suspicion gain, decay, tiers and blending. TUNABLES §3.",
    "CompassTuning": "The Compass: pulse curve, lock, warning. TUNABLES §4.",
    "CombatTuning": "The kill and the stun. TUNABLES §5–6.",
    "ContractTuning": "The contract cycle, respawn and spawn points. TUNABLES §7.",
    "CrowdTuning": "Crowd density, NPC speeds and reactions. TUNABLES §9.",
    "MatchTuning": "Match length, phases and lobby size. TUNABLES §10.",
    "ScoringTuning": "Score event values and multipliers. TUNABLES §11.",
    "CameraTuning": "Camera framing, damping and shake. TUNABLES §12.",
    "NetTuning": "Tick rates, interpolation, lag compensation, culling. TUNABLES §13.",
    "PerfTuning": "Per-frame CPU budgets. TUNABLES §14. Invariant 20 sums these.",
    "UiAudioTuning": "HUD and audio timing. TUNABLES §15.",
    "FeatureFlags": "Temporary flags. Every one names the story that removes it.",
}

DASH = "\u2014"
MINUS = "\u2212"


def parse_range(s):
    s = s.strip().replace(MINUS, "-")
    if s in ("", DASH, "-"):
        return None
    m = re.match(r"^([+-]?\d+(?:\.\d+)?)\s*[\u2013-]\s*([+-]?\d+(?:\.\d+)?)$", s)
    if not m:
        return None
    return float(m.group(1)), float(m.group(2))


def parse_value(row):
    v = row["value"].strip().replace(MINUS, "-")
    if v in ("true", "false"):
        return v == "true", "bool"
    if row["unit"] == "enum":
        return v, "StringName"
    m = re.match(r"^([+-]?\d+(?:\.\d+)?)", v)
    if not m:
        return None, None
    num = float(m.group(1))
    is_int = row["unit"] == "count" and "." not in m.group(1)
    return (int(num) if is_int else num), ("int" if is_int else "float")


def step_for(lo, hi, default):
    span = abs(hi - lo)
    dec = max(len(str(x).split(".")[1]) if "." in str(x) else 0 for x in (lo, hi, default))
    if dec >= 2:
        return 0.01
    if dec == 1 or span <= 5:
        return 0.1 if isinstance(default, float) else 1
    return 1.0 if isinstance(default, float) else 1


def fmt(v, t):
    if t == "bool":
        return "true" if v else "false"
    if t == "StringName":
        return '&"%s"' % v
    if t == "int":
        return str(v)
    return ("%.4f" % v).rstrip("0").rstrip(".") + ("" if "." in ("%.4f" % v).rstrip("0").rstrip(".") else ".0")


def doc_lines(rationale, tid):
    txt = re.sub(r"\[`([^`]+)`\]\([^)]+\)", r"\1", rationale)      # strip md links
    txt = re.sub(r"\*\*|\*|`", "", txt).strip()
    out = textwrap.wrap(txt, width=94) or [tid]
    return ["## " + l for l in out] + ["## " + tid]


by_class = collections.defaultdict(list)
skipped = []
for tid, (cls, field) in assigned.items():
    if tid in NOT_A_VALUE:
        skipped.append(tid)
        continue
    by_class[cls].append((tid, field))
for cls in by_class:                                   # document order == TUNABLES order
    by_class[cls].sort(key=lambda p: list(tun).index(p[0]))

# **EVERY VALUE IS READ BEFORE ANY FILE IS WRITTEN.** A generator that discovers a
# bad row halfway through has already replaced half the tree, so the check has to
# come first for the refusal to mean anything.
unparseable = [
    (tid, cls, field, tun[tid]["value"])
    for tid, (cls, field) in assigned.items()
    if tid not in NOT_A_VALUE and parse_value(tun[tid])[0] is None
]
# **A VALUE THIS CANNOT READ IS A FAILURE, NOT A LINE OF OUTPUT.** It used to append
# to `skipped` beside the deliberate `NOT_A_VALUE` exclusions and exit 0 — so
# `TUN-STUN-SCORE` and `TUN-SCORE-STUN` were dropped from `CombatTuning` and
# `ScoringTuning` on 2026-09-03 and nothing said anything. `scoring.stun` is read by
# invariant 19, so the next person to follow the README's own instruction would have
# regenerated a tree that does not compile, from a run that printed success.
#
# **THE TWO LISTS ARE SEPARATE ON PURPOSE.** `NOT_A_VALUE` is a decision recorded
# with its reason; this is the absence of one. Folding them together is what let a
# defect wear an exemption's clothes.
if unparseable:
    print("REFUSING TO WRITE: %d documented value(s) could not be read." % len(unparseable))
    for tid, cls, field, raw in unparseable:
        print("  %-42s -> %s.%s   value cell was %r" % (tid, cls, field, raw))
    print("Either the cell in TUNABLES.md is malformed, or the row genuinely carries no")
    print("value -- in which case add it to NOT_A_VALUE with the reason, so the exclusion")
    print("is a decision somebody made rather than a parse that quietly failed.")
    raise SystemExit(1)

os.makedirs(OUTDIR, exist_ok=True)
total = 0
for cls, items in sorted(by_class.items()):
    snake = re.sub(r"(?<!^)(?=[A-Z])", "_", cls).lower()
    lines = ["## " + CLASS_DOC.get(cls, cls) + "\n##",
             "## GENERATED FROM TUNABLES.md. Every field's docstring ends with its TUN- ID,",
             "## which is what test_tuning_docs_sync greps for. Never reorder these: the order",
             "## is the .tres property order, and reordering rewrites every file unreviewably.",
             "class_name %s" % cls, "extends Resource", ""]
    for tid, field in items:
        row = tun[tid]
        default, gdtype = parse_value(row)
        if default is None:
            continue  # unreachable: the pass above refused the run
        lines += doc_lines(row["rationale"], tid)
        rng = parse_range(row["range"]) if gdtype in ("int", "float") else None
        if rng and rng[0] < rng[1]:
            st = step_for(rng[0], rng[1], default)
            lo = ("%g" % rng[0]) if gdtype == "int" else ("%.2f" % rng[0]).rstrip("0").rstrip(".")
            hi = ("%g" % rng[1]) if gdtype == "int" else ("%.2f" % rng[1]).rstrip("0").rstrip(".")
            if gdtype == "float":
                lo = lo if "." in lo else lo + ".0"
                hi = hi if "." in hi else hi + ".0"
            lines.append("@export_range(%s, %s, %s) var %s: %s = %s"
                         % (lo, hi, st, field, gdtype, fmt(default, gdtype)))
        else:
            lines.append("@export var %s: %s = %s" % (field, gdtype, fmt(default, gdtype)))
        lines.append("")
        total += 1
    io.open(os.path.join(OUTDIR, snake + ".gd"), "w", encoding="utf-8",
            newline="\n").write("\n".join(lines).rstrip("\n") + "\n")
    print("%-18s %3d fields  %3d lines" % (cls, len(items), len(lines)))

print("\nfields emitted: %d   excluded by name: %d %s" % (total, len(skipped), skipped))

"""Extract every ID in the docs corpus and validate it against NAMING_AND_IDS.md section 1."""
import io, os, os, re, json, sys, collections

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOCS = os.path.join(ROOT, "docs")

GRAMMAR = {
    "SYS":     r"^SYS-[A-Z][A-Z0-9]*(-[A-Z0-9]+)*$",
    "SCORE":   r"^SCORE-[A-Z]+$",
    "ABIL":    r"^ABIL-[A-Z]+$",
    "PASV":    r"^PASV-[A-Z]+$",
    "PERSONA": r"^PERSONA-[A-Z]+$",
    "ARCH":    r"^ARCH-[A-Z]+$",
    "MAP":     r"^MAP-[A-Z]+$",
    "LOC":     r"^LOC-[A-Z]+$",
    "NET":     r"^NET-(C2S|S2C)-[A-Z]+(-[A-Z]+)*$",
    "EVT":     r"^EVT-[A-Z]+(-[A-Z]+)*$",
    "SFX":     r"^SFX-[A-Z]+(-[A-Z]+)*$",
    "MUS":     r"^MUS-[A-Z]+(-[A-Z]+)*$",
    "ANIM":    r"^ANIM-[A-Z]+(-[A-Z]+)*$",
    "MAT":     r"^MAT-[A-Z]+$",
    "PROP":    r"^PROP-[A-Z]+$",
    "TEL":     r"^TEL-[A-Z]+(-[A-Z]+)*$",
    "RISK":    r"^RISK-[A-Z]+(-[A-Z]+)*$",
}

# Not preceded by an ID character or hyphen, so TUN-PASV-STILLNESS-MULT does not
# yield a bogus PASV-STILLNESS-MULT. Trailing hyphens trimmed.
found = collections.defaultdict(lambda: collections.defaultdict(set))  # ns -> id -> files

for dirpath, dirnames, filenames in os.walk(DOCS):
    for fn in filenames:
        if not fn.endswith(".md"):
            continue
        p = os.path.join(dirpath, fn)
        rel = os.path.relpath(p, ROOT).replace("\\", "/")
        text = io.open(p, encoding="utf-8").read()
        for ns in GRAMMAR:
            for m in re.finditer(r"(?<![A-Z0-9\-])" + ns + r"-[A-Z0-9\-]+", text):
                # `NET-S2C-*` in a diagram is a glob over a namespace, not an ID.
                if text[m.end():m.end() + 1] == "*":
                    continue
                tok = m.group(0).rstrip("-")
                found[ns][tok].add(rel)

report = {}
for ns in sorted(GRAMMAR):
    rx = re.compile(GRAMMAR[ns])
    ok, bad = [], []
    for tok in sorted(found[ns]):
        (ok if rx.match(tok) else bad).append(tok)
    report[ns] = {"valid": ok, "invalid": bad,
                  "files": {t: sorted(found[ns][t]) for t in bad}}

total_ok = sum(len(report[n]["valid"]) for n in report)
total_bad = sum(len(report[n]["invalid"]) for n in report)
print("VALID IDs: %d   GRAMMAR VIOLATIONS: %d\n" % (total_ok, total_bad))
for ns in sorted(report):
    v, b = report[ns]["valid"], report[ns]["invalid"]
    print("%-8s valid=%-4d invalid=%d" % (ns, len(v), len(b)))
    for t in b:
        print("        !! %-40s %s" % (t, ", ".join(report[ns]["files"][t][:3])))

io.open(os.path.join(os.path.dirname(__file__), "ids.json"), "w",
        encoding="utf-8").write(json.dumps(
            {n: report[n]["valid"] for n in report}, indent=1))
print("\nwrote ids.json")

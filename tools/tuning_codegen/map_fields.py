"""Resolve every TUN- ID to a (class, field) pair.

DATA_SCHEMA's 132 explicit field rows are anchors: each is matched to an ID
across ALL sections, because §8's passive tunables are distributed into the
domain classes they affect rather than living in an abilities class. The
remaining IDs are assigned by section and named mechanically.
"""
import io, json, os, re, collections

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.dirname(os.path.abspath(__file__))
tun = json.load(io.open(os.path.join(HERE, "tunables.json"), encoding="utf-8"))
sch = io.open(os.path.join(ROOT, "docs", "30_bible", "DATA_SCHEMA.md"), encoding="utf-8").read()
# §3 only. Without this cut the last §3 chunk runs into §4 and swallows
# AbilityData's field table, whose names then match unrelated TUN- IDs.
sch = sch.split("## 4. Content resources")[0]

# FeatureFlags holds no TUN- values; it is hand-written.
SECTION_CLASS = {
    2: "MovementTuning", 3: "SuspicionTuning", 4: "CompassTuning",
    5: "CombatTuning", 6: "CombatTuning", 7: "ContractTuning",
    9: "CrowdTuning", 10: "MatchTuning", 11: "ScoringTuning",
    12: "CameraTuning", 13: "NetTuning", 14: "PerfTuning", 15: "UiAudioTuning",
}
ABILITY_SECTION = 8

# Agreed exception table: mechanical transform overridden, with a reason.
EXCEPTIONS = {
    "TUN-SPEED-BLENDWALK": ("blend_walk", "compound word; blendwalk is unreadable"),
    "TUN-SUSPICION-MAX": ("max_value", "a member named `max` shadows GDScript's built-in max()"),
    "TUN-PASV-COLDREAD-MULT": ("cold_read_mult", "compound word"),
    "TUN-PASV-SECONDWIND-REDUCTION": ("second_wind_reduction", "compound word"),
}


def mech(tid, strip):
    """ID minus TUN-, minus a leading domain segment if `strip`, lowercased."""
    parts = tid.split("-")[1:]
    if strip and len(parts) > 1:
        parts = parts[1:]
    return "_".join(parts).lower()


# Explicit field names per class, in document order.
explicit = {}
for chunk in re.split(r"### 3\.\d+ ", sch)[1:]:
    n = re.match(r"`(\w+)`", chunk)
    if n:
        explicit[n.group(1)] = re.findall(r"^\| `(\w+)` \|", chunk, re.M)

by_id = {r["id"]: r for r in tun}
assigned = {}          # id -> (cls, field)
used = collections.defaultdict(set)
unmatched_fields = []

# Search the class's OWN sections first. Scanning all IDs in document order made
# MatchTuning's `duration` match TUN-CINDERFALL-DURATION (§8) instead of
# TUN-MATCH-DURATION (§10), because §8 comes first — a cloud lifetime of 4 s
# shipped as the match length.
for cls, names in explicit.items():
    own = {t for s in SECTION_CLASS if SECTION_CLASS[s] == cls for t in
           [r["id"] for r in tun if r["section"] == s]}
    for f in names:
        hit = None
        for tid in list(own) + [t for t in by_id if t not in own]:
            if tid in EXCEPTIONS and EXCEPTIONS[tid][0] == f:
                hit = tid
                break
            if mech(tid, True) == f or mech(tid, False) == f:
                if tid not in assigned:
                    hit = tid
                    break
        if hit:
            assigned[hit] = (cls, f)
            used[cls].add(f)
        else:
            unmatched_fields.append((cls, f))

# Everything else: assign by section, name mechanically (strip the domain when
# it does not collide with a name already taken in that class).
leftover = []
for r in tun:
    if r["id"] in assigned:
        continue
    sec = r["section"]
    if sec == ABILITY_SECTION:
        leftover.append(r["id"])
        continue
    cls = SECTION_CLASS.get(sec)
    if cls is None:
        leftover.append(r["id"])
        continue
    if r["id"] in EXCEPTIONS:
        f = EXCEPTIONS[r["id"]][0]
    else:
        f = mech(r["id"], True)
        if f in used[cls] or not re.match(r"^[a-z]", f):
            f = mech(r["id"], False)
    assigned[r["id"]] = (cls, f)
    used[cls].add(f)

print("assigned: %d / %d" % (len(assigned), len(tun)))
print("schema field rows with no matching ID: %d %s" % (len(unmatched_fields), unmatched_fields[:6]))
print("left for AbilityData/PassiveData (§8): %d" % len(leftover))

dupes = []
for cls in used:
    seen = collections.Counter(f for i, (c, f) in assigned.items() if c == cls)
    dupes += [(cls, f) for f, n in seen.items() if n > 1]
print("field-name collisions within a class: %d %s" % (len(dupes), dupes[:6]))

print("\nper class:")
cnt = collections.Counter(c for c, f in assigned.values())
for c in sorted(cnt):
    print("  %-18s %d" % (c, cnt[c]))

io.open(os.path.join(HERE, "fieldmap.json"), "w", encoding="utf-8").write(json.dumps(
    {"assigned": {k: list(v) for k, v in assigned.items()}, "abilities": leftover},
    indent=1))
print("\nwrote fieldmap.json")

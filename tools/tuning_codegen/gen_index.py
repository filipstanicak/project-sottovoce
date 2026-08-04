"""Generate scripts/core/tuning/tuning_index.gd — the runtime TUN-ID -> field map."""
import io, json, os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
tun = {r["id"]: r for r in json.load(io.open("tunables.json", encoding="utf-8"))}
fm = json.load(io.open("fieldmap.json", encoding="utf-8"))
am = json.load(io.open("abilitymap.json", encoding="utf-8"))
CLS2SEC = {"MovementTuning": "movement", "SuspicionTuning": "suspicion", "CompassTuning": "compass",
 "CombatTuning": "combat", "ContractTuning": "contract", "CrowdTuning": "crowd",
 "MatchTuning": "match_rules", "ScoringTuning": "scoring", "CameraTuning": "camera",
 "NetTuning": "net", "PerfTuning": "perf", "UiAudioTuning": "ui_audio"}
NOT_A_VALUE = {"TUN-SUSPICION-GAIN-WHISPERBOLT-WINDUP"}
rows = []
for tid, (cls, field) in sorted(fm["assigned"].items(), key=lambda kv: list(tun).index(kv[0])):
    if tid in NOT_A_VALUE or cls not in CLS2SEC:
        continue
    rows.append((tid, CLS2SEC[cls], field, tun[tid]["unit"]))
for ab, fields in am.items():
    for field, tid in sorted(fields.items(), key=lambda kv: list(tun).index(kv[1])):
        rows.append((tid, "ABIL-" + ab, field, tun[tid]["unit"]))
for tid in tun:
    if tid.startswith("TUN-ABILITY-"):
        rows.append((tid, "ability", "_".join(tid.split("-")[2:]).lower(), tun[tid]["unit"]))
seen = set()
for t, *_ in rows:
    assert t not in seen, "duplicate key %s" % t
    seen.add(t)
hdr = '''## TUN- ID -> where its value lives, at runtime.
##
## GDScript docstrings are not readable at runtime, so the TUN- ID a field carries
## in its comment cannot be recovered from the loaded resource. This table is the
## runtime half of that link, generated from the same parse of TUNABLES.md that
## generated the classes.
##
## `holder` is a TuningProfile section name, or an `ABIL-*` key into
## `profile.abilities` for a per-ability value.
class_name TuningIndex
extends RefCounted

## StringName(TUN-*) -> [holder, field, unit].
const FIELD := {
'''
body = "".join('\t&"%s": ["%s", "%s", "%s"],\n' % r for r in rows)
tail = '''}

## Units denoting a duration, and therefore convertible to server ticks.
const DURATION_UNITS: Array[String] = ["s", "ms"]
'''
io.open(os.path.join(ROOT, "scripts", "core", "tuning", "tuning_index.gd"), "w",
        encoding="utf-8", newline="\n").write(hdr + body + tail)
print("index: %d entries, %d durations, no duplicates" %
      (len(rows), sum(1 for r in rows if r[3] in ("s", "ms"))))

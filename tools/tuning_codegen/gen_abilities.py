"""Generate AbilityTuning and AbilityData from TUNABLES.md §8."""
import io, json, os, re, textwrap, collections

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "scripts", "core", "tuning")
tun = {r["id"]: r for r in json.load(io.open(os.path.join(HERE, "tunables.json"), encoding="utf-8"))}

ABILITIES = ["CINDERFALL", "LUNGE", "SECONDFACE", "WHISPERBOLT"]

# DATA_SCHEMA §4.1 names these differently from the mechanical transform.
FIELD_EXCEPTIONS = {"suspicion": "suspicion_cost", "stunnable": "stunnable_during"}


def strip(tid, prefix):
    parts = tid.split("-")
    assert parts[1] == prefix, tid
    f = "_".join(parts[2:]).lower()
    return FIELD_EXCEPTIONS.get(f, f)


def gdtype_and_default(row):
    v = row["value"].strip().replace("\u2212", "-")
    if v in ("true", "false"):
        return "bool", ("true" if v == "true" else "false")
    if row["unit"] == "enum":
        return "StringName", '&"%s"' % v
    n = float(re.match(r"^([+-]?\d+(?:\.\d+)?)", v).group(1))
    if row["unit"] == "count":
        return "int", str(int(n))
    return "float", (("%.4f" % n).rstrip("0").rstrip(".") or "0") + ("" if "." in ("%.4f" % n).rstrip("0").rstrip(".") else ".0")


def rng(row):
    s = row["range"].strip().replace("\u2212", "-")
    m = re.match(r"^([+-]?\d+(?:\.\d+)?)\s*[\u2013-]\s*([+-]?\d+(?:\.\d+)?)$", s)
    return (float(m.group(1)), float(m.group(2))) if m else None


def doc(row, tid):
    t = re.sub(r"\[`([^`]+)`\]\([^)]+\)", r"\1", row["rationale"])
    t = re.sub(r"\*\*|\*|`", "", t).strip()
    return ["## " + l for l in (textwrap.wrap(t, 94) or [tid])] + ["## " + tid]


def export_line(row, field, gdtype, default):
    r = rng(row)
    if r and r[0] < r[1] and gdtype in ("int", "float"):
        step = 0.01 if (r[1] - r[0]) <= 1.5 else (0.1 if gdtype == "float" else 1)
        fm = (lambda x: "%g" % x) if gdtype == "int" else (
            lambda x: ("%.2f" % x).rstrip("0").rstrip(".") + ("" if "." in ("%.2f" % x).rstrip("0").rstrip(".") else ".0"))
        return "@export_range(%s, %s, %s) var %s: %s = %s" % (fm(r[0]), fm(r[1]), step, field, gdtype, default)
    return "@export var %s: %s = %s" % (field, gdtype, default)


# ---------------------------------------------------------------- AbilityTuning
globals_ = [t for t in tun if t.startswith("TUN-ABILITY-")]
lines = ["## Ability-system settings that are not per-ability. TUNABLES §8.1.",
         "##",
         "## GENERATED FROM TUNABLES.md. Never reorder: the order is the .tres property",
         "## order, and reordering rewrites every file unreviewably.",
         "class_name AbilityTuning", "extends Resource", ""]
for tid in globals_:
    row = tun[tid]
    gt, d = gdtype_and_default(row)
    lines += doc(row, tid) + [export_line(row, strip(tid, "ABILITY"), gt, d), ""]
io.open(os.path.join(OUT, "ability_tuning.gd"), "w", encoding="utf-8",
        newline="\n").write("\n".join(lines).rstrip("\n") + "\n")
print("AbilityTuning: %d fields" % len(globals_))

# ------------------------------------------------------------------ AbilityData
# One class holding the union of every ability's fields, as DATA_SCHEMA §4.1
# specifies with its "Whisperbolt only" / "Second Face" annotations. Abilities
# leave the fields they do not use at zero.
fields = collections.OrderedDict()   # field -> (row, tid, owners)
for ab in ABILITIES:
    for tid in tun:
        if not tid.startswith("TUN-%s-" % ab):
            continue
        f = strip(tid, ab)
        if f in fields:
            fields[f][2].append(ab)
        else:
            fields[f] = (tun[tid], tid, [ab])

head = '''## One ability's authored data. DATA_SCHEMA §4.1.
##
## A SINGLE class holding the union of every ability's fields, as the schema
## specifies with its "Whisperbolt only" / "Second Face" annotations. An ability
## leaves the fields it does not use at zero — four subclasses would make the
## `abilities` dictionary untypeable for the sake of a few unused floats.
##
## THE TELL FIELDS ARE NOT DECORATION. Design law 3: no ability resolves without
## the victim having had a perceivable chance to read it, and two tell channels
## are the minimum with at least one environmental or audio. That is asserted by
## test_ability_has_tell.gd against this resource, not left to review.
class_name AbilityData
extends Resource

## ABIL-*. Immutable once merged.
@export var id: StringName = &""

## Key into data/strings/en.csv. Never a user-facing literal.
@export var display_key: StringName = &""

## SFX-* played on cast. Tell channel 1 of 3.
@export var tell_sfx: StringName = &""

## extends AbilityEffect. The only per-ability code there is.
@export var effect_script: Script = null

## Tell channel 3. Arrives with the VFX pass.
@export var tell_vfx: PackedScene = null
'''
lines = [head]
for f, (row, tid, owners) in fields.items():
    gt, d = gdtype_and_default(row)
    zero = {"float": "0.0", "int": "0", "bool": "false", "StringName": '&""'}[gt]
    note = "Used by: " + ", ".join(o.capitalize() for o in owners) + "."
    lines.append("")
    lines += doc(row, tid)[:-1] + ["## " + note, "## " + tid]
    # Defaults are per-ability and live in the .tres files; the class default is
    # the inert value, so an ability that does not use a field cannot inherit a
    # number that means something for a different ability.
    lines.append(export_line(row, f, gt, zero) if gt in ("int", "float")
                 else "@export var %s: %s = %s" % (f, gt, zero))
io.open(os.path.join(OUT, "ability_data.gd"), "w", encoding="utf-8",
        newline="\n").write("\n".join(lines).rstrip("\n") + "\n")
print("AbilityData: %d tunable-backed fields + 5 content fields" % len(fields))

io.open(os.path.join(HERE, "abilitymap.json"), "w", encoding="utf-8").write(json.dumps(
    {ab: {strip(t, ab): t for t in tun if t.startswith("TUN-%s-" % ab)} for ab in ABILITIES}, indent=1))
print("wrote abilitymap.json")

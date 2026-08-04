"""Run the whole tuning code-generation pipeline, in order.

    python tools/tuning_codegen/run_all.py

Then `gdformat scripts/`, then regenerate the .tres files in the engine:

    godot --headless -s res://tools/generate_default_tuning.gd

See README.md. The order matters: later steps read the .json intermediates that
earlier steps write.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

STEPS = [
    ("parse_tunables.py", "parse TUNABLES.md into tunables.json"),
    ("extract_ids.py", "harvest every ID in docs/ into ids.json"),
    ("map_fields.py", "resolve TUN- ID -> class.field into fieldmap.json"),
    ("gen_ids.py", "write scripts/core/ids.gd"),
    ("gen_tuning.py", "write the twelve section classes"),
    ("gen_abilities.py", "write ability_tuning.gd and ability_data.gd"),
    ("gen_index.py", "write tuning_index.gd"),
]


def main() -> int:
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    for script, what in STEPS:
        print("=== %-22s %s" % (script, what))
        result = subprocess.run([sys.executable, os.path.join(HERE, script)],
                                cwd=HERE, env=env)
        if result.returncode != 0:
            print("FAILED at %s — stopping. Nothing after this ran." % script)
            return result.returncode
    print()
    print("Generated. Now run:  gdformat scripts/")
    print("The committed files are POST-format; skipping it leaves a whitespace diff.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

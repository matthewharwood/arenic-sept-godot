#!/usr/bin/env python3
"""Build the versioned Hunter fixture using an isolated, real Godot simulation."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    parser.add_argument("--output", type=Path, default=REPO / "tests/fixtures/hunter-full-arena-v1")
    args = parser.parse_args()
    work_root = REPO / ".tmp/hunter-full-arena-seed"
    work_root.mkdir(parents=True, exist_ok=True)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    previous_manifest = output / "manifest.json"
    previous_save_sha = None
    if previous_manifest.exists():
        previous = json.loads(previous_manifest.read_text())
        previous_save_sha = previous.get("save_sha256")
        for relative, expected in previous.get("source_sha256", {}).items():
            if hashlib.sha256((REPO / relative).read_bytes()).hexdigest() != expected:
                raise SystemExit(f"Version 1 input changed: {relative}. Create a new fixture version instead of rewriting this one.")
    spec = importlib.util.spec_from_file_location("arenic_ci", REPO / "scripts/ci/test-godot.py")
    ci = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(ci)
    with tempfile.TemporaryDirectory(prefix="project-", dir=work_root) as directory:
        work = Path(directory)
        project = ci.isolated_project(work, enable_doctor=False)
        target = project / "tools/fixtures/hunter_full_arena_v1.gd"
        target.parent.mkdir(parents=True)
        shutil.copy2(REPO / "scripts/fixtures/hunter_full_arena_v1.gd", target)
        env = os.environ.copy()
        env["NO_COLOR"] = "1"
        for key, leaf in [("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
            env[key] = str(work / leaf)
        base = [args.godot, "--path", str(project), "--headless", "--audio-driver", "Dummy", "--disable-file-logging"]
        results = [ci.run(base + ["--editor", "--import", "--quit", "--rendering-method", "gl_compatibility"], "import", work_root, env, 180)]
        if results[-1]["passed"]:
            results.append(ci.run(base + ["--script", "res://tools/fixtures/hunter_full_arena_v1.gd", "--", str(output), str(work_root)], "generate-and-replay", work_root, env, 300))
        (work_root / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    if len(results) != 2 or not all(result["passed"] for result in results):
        return 1
    manifest_path = output / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    if previous_save_sha is not None and manifest["save_sha256"] != previous_save_sha:
        raise SystemExit("Version 1 output changed with unchanged inputs; investigate reproducibility before publishing.")
    sources = [
        "scripts/fixtures/hunter_full_arena_v1.gd",
        "arenic-game/data/encounters/labyrinth_normal.tres",
        "arenic-game/scripts/combat/combat_state.gd",
        "arenic-game/scripts/encounters/encounter_state.gd",
        "arenic-game/scripts/encounters/arena_timeline.gd",
        "arenic-game/scripts/encounters/recording.gd",
        "arenic-game/scripts/encounters/timeline_event.gd",
        "arenic-game/scripts/encounters/encounter_score.gd",
        "arenic-game/scripts/encounters/encounter_beat.gd",
        "arenic-game/scripts/encounters/cycle_clock.gd",
        "arenic-game/scripts/encounters/acid_field.gd",
        "arenic-game/scripts/encounters/dig_field.gd",
        "arenic-game/scripts/heroes/hero_state.gd",
        "arenic-game/scripts/heroes/hero_contact.gd",
        "arenic-game/scripts/heroes/hero_names.gd",
        "arenic-game/scripts/character_creation/class_ability.gd",
        "arenic-game/scripts/character_creation/run_setup.gd",
        "arenic-game/scripts/persistence/save_codec.gd",
        "arenic-game/scripts/persistence/save_document.gd",
        "arenic-game/scripts/persistence/save_migrations.gd",
        "arenic-game/scripts/world/grid_math.gd",
        "arenic-game/scripts/world/arena_definition.gd",
        "arenic-game/data/world/arenia.tres",
        "arenic-game/data/world/labyrinth.tres",
    ]
    for class_id in ["hunter", "cardinal", "warrior", "thief", "bard", "merchant", "alchemist", "forager"]:
        sources.extend([f"arenic-game/data/classes/{class_id}.tres", f"arenic-game/data/classes/{class_id}_primary.tres"])
    manifest["source_sha256"] = {relative: hashlib.sha256((REPO / relative).read_bytes()).hexdigest() for relative in sources}
    manifest["godot_version"] = subprocess.check_output([args.godot, "--version"], text=True).strip()
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

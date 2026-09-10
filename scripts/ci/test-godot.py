#!/usr/bin/env python3
"""Run Godot checks in a disposable project/editor copy; never import the checkout.

Local: python3 scripts/ci/test-godot.py --godot /Applications/Godot.app/Contents/MacOS/Godot
Linux rendering: LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s '-screen 0 4096x2304x24' \
    python3 scripts/ci/test-godot.py --godot /path/to/godot --suite renderer --display-driver x11
"""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

REPOSITORY = Path(__file__).resolve().parents[2]
HEADLESS = (
    "world/grid_checks", "world/camera_checks", "world/flow_checks",
    "heroes/hero_checks", "heroes/hero_flow_checks", "bosses/catalog_checks",
    "themes/theme_checks", "themes/region_checks", "world/transition_checks",
    "audio/clock_checks", "audio/music_checks",
)
RENDERER = (
    "world/arena_tiles_checks", "themes/presentation_checks", "themes/overworld_checks",
    "display/display_checks", "world/transition_render_checks",
)
MANUAL = {"audio/render_checks": "Requires a working non-Dummy audio mixer; retain separate native audio validation."}
ERROR = re.compile(r"SCRIPT ERROR|SHADER ERROR|(?:^|\n)\s*ERROR:|Assertion failed|Parse Error|Failed to compile", re.IGNORECASE)


def isolated_project(destination: Path) -> Path:
    project = destination / "arenic-game"
    ignore = shutil.ignore_patterns(".godot", ".git", ".mcp.json", ".DS_Store", "__pycache__")
    shutil.copytree(REPOSITORY / "arenic-game", project, ignore=ignore)
    # The boss catalog validates original authoring sources outside res://.
    shutil.copytree(REPOSITORY / "assets", destination / "assets", ignore=ignore)
    settings = project / "project.godot"
    text = settings.read_text(encoding="utf-8")
    text = re.sub(r'^MCPRuntimeServer=.*\n', '', text, flags=re.MULTILINE)
    text = text.replace('"res://addons/godot_mcp_toolkit/plugin.cfg"', '')
    text = re.sub(r'^config/name=.*$', f'config/name="arenic-ci-{destination.name}"', text, flags=re.MULTILINE)
    settings.write_text(text, encoding="utf-8")
    return project


def run(command: list[str], label: str, logs: Path, environment: dict[str, str], timeout: float) -> dict:
    started = time.monotonic()
    log = logs / f"{label.replace('/', '-')}.log"
    timed_out = False
    with log.open("w", encoding="utf-8") as output:
        output.write("Command: " + json.dumps(command) + "\n")
        output.flush()
        try:
            completed = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT,
                                       env=environment, timeout=timeout, check=False)
            code = completed.returncode
        except subprocess.TimeoutExpired:
            code = 124
            timed_out = True
            output.write(f"\nTimeout after {timeout:g} seconds.\n")
    content = log.read_text(encoding="utf-8", errors="replace")
    result = {"test": label, "passed": code == 0 and not ERROR.search(content),
              "exit": code, "timed_out": timed_out, "seconds": round(time.monotonic() - started, 2), "log": str(log)}
    print(json.dumps(result), flush=True)
    if not result["passed"]:
        print(content[-12000:], flush=True)
    else:
        for line in content.splitlines():
            if "passed" in line.lower():
                print(line, flush=True)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--suite", choices=("headless", "renderer", "all"), default="all")
    parser.add_argument("--logs-dir", type=Path, default=REPOSITORY / ".tmp/ci-logs")
    parser.add_argument("--display-driver", help="For example x11 under Xvfb; omitted for local macOS.")
    parser.add_argument("--timeout", type=float, default=90.0, help="Outer timeout per test; in-script watchdogs still apply.")
    args = parser.parse_args()
    if not (0 < args.timeout < float("inf")):
        parser.error("--timeout must be finite and positive")
    binary = shutil.which(args.godot)
    if binary is None:
        parser.error(f"Godot binary not found: {args.godot}")
    known = set(HEADLESS) | set(RENDERER) | set(MANUAL)
    discovered = {str(path.relative_to(REPOSITORY / "arenic-game/tests").with_suffix(""))
                  for path in (REPOSITORY / "arenic-game/tests").rglob("*checks.gd")}
    if discovered != known:
        parser.error(f"Update explicit test classification: unclassified={sorted(discovered - known)}, missing={sorted(known - discovered)}")
    logs = args.logs_dir.expanduser().resolve() / args.suite
    logs.mkdir(parents=True, exist_ok=True)
    results = []
    summary = {"suite": args.suite, "manual_checks": MANUAL, "results": results}
    try:
        with tempfile.TemporaryDirectory(prefix="arenic-ci-") as temporary:
            work = Path(temporary)
            project = isolated_project(work)
            # macOS requires the installed, signed app binary. Never move it out
            # of its bundle; the project copy and distinct app name isolate tests.
            engine = Path(binary)
            if sys.platform != "darwin":
                engine_dir = work / "engine"
                engine_dir.mkdir()
                engine = engine_dir / Path(binary).name
                shutil.copy2(binary, engine)
                (engine_dir / "_sc_").touch()
            environment = os.environ.copy()
            for name in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
                directory = work / name.lower()
                directory.mkdir()
                environment[name] = str(directory)
            environment["NO_COLOR"] = "1"
            version = subprocess.run([str(engine), "--version"], capture_output=True, text=True,
                                     env=environment, timeout=15, check=True).stdout.strip()
            (logs / "version.log").write_text(version + "\n", encoding="utf-8")
            if not version.startswith("4.7.2.stable."):
                raise RuntimeError(f"Expected Godot 4.7.2 stable; got {version}")
            summary["engine_version"] = version
            base = [str(engine), "--path", str(project), "--audio-driver", "Dummy", "--disable-file-logging", "--verbose"]
            results.append(run(base + ["--headless", "--editor", "--import", "--quit", "--rendering-method", "gl_compatibility"],
                               "import", logs, environment, 180))
            if results[-1]["passed"]:
                selected = (HEADLESS if args.suite != "renderer" else ()) + (RENDERER if args.suite != "headless" else ())
                for test in selected:
                    flags = ["--headless"] if test in HEADLESS else ["--rendering-method", "gl_compatibility"]
                    if test in RENDERER and args.display_driver:
                        flags += ["--display-driver", args.display_driver]
                    results.append(run(base + flags + ["--script", f"res://tests/{test}.gd"],
                                       test, logs, environment, args.timeout))
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        summary["error"] = str(error)
        (logs / "runner-error.log").write_text(str(error) + "\n", encoding="utf-8")
        print(f"Validation failed: {error}", file=sys.stderr)
    summary["passed"] = bool(results) and all(item["passed"] for item in results) and "error" not in summary
    (logs / "results.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(f"Logs: {logs}")
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

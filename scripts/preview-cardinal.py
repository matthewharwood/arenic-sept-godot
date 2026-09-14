#!/usr/bin/env python3
"""Launch an isolated Cardinal practice run: F6 next cue, F7 reset, F8 pause.

The real game and authored resources are copied; player saves and the open
editor cache remain untouched. Re-run after editing a draft score to audition it.
"""
import argparse
import importlib.util
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot')
    parser.add_argument('--hero', choices=['hunter', 'warrior', 'thief', 'alchemist', 'cardinal', 'bard', 'forager', 'merchant'], default='hunter')
    parser.add_argument('--tick', type=int, default=0)
    parser.add_argument('--capture', type=Path, help='Capture five warning/window frames at 720p logical layout, then exit.')
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('arenic_ci', ROOT / 'scripts/ci/test-godot.py')
    ci = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(ci)
    with tempfile.TemporaryDirectory(prefix='arenic-cardinal-practice-') as tmp:
        project = ci.isolated_project(Path(tmp), enable_doctor=False)
        settings = project / 'project.godot'
        text = settings.read_text().replace('[autoload]', '[autoload]\n\nCardinalPractice="*res://tests/encounters/cardinal_preview.gd"')
        settings.write_text(text)
        base = [args.godot, '--path', str(project), '--rendering-method', 'gl_compatibility']
        result = subprocess.run(base + ['--headless', '--editor', '--import', '--quit'], capture_output=True, text=True, timeout=180)
        output = result.stdout + result.stderr
        if result.returncode or re.search(r'SCRIPT ERROR|Parse Error|^ERROR:', output, re.M):
            raise RuntimeError(output[-12000:])
        user = [f'--cardinal-class={args.hero}', f'--cardinal-tick={args.tick}']
        if args.capture:
            args.capture.resolve().mkdir(parents=True, exist_ok=True)
            user.append(f'--cardinal-capture={args.capture.resolve()}')
        print('Cardinal practice: F6 next cue · F7 restart · F8 pause. Player saves are untouched.', flush=True)
        subprocess.run(base + ['--resolution', '1280x720', '--', *user], check=True)


if __name__ == '__main__':
    main()

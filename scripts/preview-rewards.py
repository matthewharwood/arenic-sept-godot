#!/usr/bin/env python3
"""Launch isolated reward practice: F6 heroes, F7 loot, F8 arena theme.

Copies the real game into a disposable project with its own application identity.
The preview has no active save slot and never loads or writes the player's guild.
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
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('arenic_ci', ROOT / 'scripts/ci/test-godot.py')
    ci = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(ci)
    with tempfile.TemporaryDirectory(prefix='arenic-reward-practice-') as temporary:
        project = ci.isolated_project(Path(temporary), enable_doctor=False)
        settings = project / 'project.godot'
        text = settings.read_text().replace('[autoload]', '[autoload]\n\nRewardPractice="*res://tests/loot/reward_preview.gd"')
        settings.write_text(text)
        base = [args.godot, '--path', str(project), '--rendering-method', 'gl_compatibility']
        imported = subprocess.run(base + ['--headless', '--editor', '--import', '--quit'],
                                  capture_output=True, text=True, timeout=180)
        output = imported.stdout + imported.stderr
        if imported.returncode or re.search(r'SCRIPT ERROR|Parse Error|^ERROR:', output, re.M):
            raise RuntimeError(output[-12000:])
        print('Reward practice: F6 Heroes · F7 Loot · F8 Arena theme. Player saves are untouched.', flush=True)
        subprocess.run(base + ['--resolution', '1280x720'], check=True)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Export a clean Web release from a disposable copy, never the live editor project."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ERRORS = re.compile(r'SCRIPT ERROR|SHADER ERROR|(?:^|\n)ERROR:|Parse Error|Assertion failed')
EDITOR_PLUGINS = re.compile(r'(?m)^(\[editor_plugins\]\n\n)enabled=PackedStringArray\([^\n]*\)$')


def run(command, log):
    result = subprocess.run(command, capture_output=True, text=True, timeout=300)
    output = result.stdout + result.stderr
    log.write_text(output)
    if result.returncode or ERRORS.search(output):
        raise RuntimeError(f'{log.name} failed ({result.returncode}):\n{output[-10000:]}')


def export(repo, godot, output, probe=None):
    source = repo / 'arenic-game'
    if output.is_relative_to(source) or source.is_relative_to(output):
        raise ValueError('Export output must be outside the source project and its ancestors.')
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise ValueError('Export output must be empty; use a new build directory.')
    reports = repo / '.tmp/web-export-logs' / ('probe' if probe else 'production')
    reports.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='arenic-web-') as tmp:
        project = Path(tmp) / 'project'
        shutil.copytree(repo / 'arenic-game', project,
                        ignore=shutil.ignore_patterns('.godot', '.mcp.json', '.DS_Store', 'addons', 'tests'))
        # The validation suite references the editor-only Godot Doctor script.
        # It is never loaded by the game, and must not survive into a clean export
        # after the add-on directory has been intentionally stripped.
        validation_suite = project / 'data' / 'validation' / 'arenic_authored_content.tres'
        if validation_suite.exists():
            validation_suite.unlink()
        config = project / 'project.godot'
        text = config.read_text()
        text, removed = re.subn(r'^MCPRuntimeServer=.*\n', '', text, flags=re.M)
        if removed != 1:
            raise ValueError('Expected exactly one development MCP autoload to strip.')
        text, plugins = EDITOR_PLUGINS.subn(r'\1enabled=PackedStringArray()', text, count=1)
        if plugins != 1:
            raise ValueError('Editor plugin configuration changed; review export isolation.')
        config.write_text(text)
        if probe:
            # Probe prepares only this disposable project. It never changes
            # shipping source or the production export.
            probe_project = Path(tmp) / 'probe'
            subprocess.run(['node', str(probe), '--source', str(project), '--destination', str(probe_project)], check=True)
            project = probe_project
        run([godot, '--headless', '--path', str(project), '--editor', '--import', '--quit'], reports / 'import.log')
        run([godot, '--headless', '--path', str(project), '--export-release', 'Web', str(output / 'index.html')], reports / 'export.log')
        if not (output / 'index.wasm').is_file() or not (output / 'index.pck').is_file():
            raise RuntimeError('Godot did not produce the game payload.')
        # PCK resource paths remain plain in our unencrypted export. The audit
        # rejects any accidentally shipped editor, test, or probe resources.
        if not probe:
            pack = (output / 'index.pck').read_bytes()
            for forbidden in (b'addons/', b'tests/', b'data/validation/arenic_authored_content.tres', b'web_probe', b'WebCIProbe', b'__ci__', b'.mcp.json'):
                if forbidden in pack:
                    raise ValueError(f'Development resource in production pack: {forbidden!r}')
    print(f'Exported {"probe" if probe else "production"} Web release: {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=ROOT)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--probe', type=Path, help='Test-only prepare-probe.mjs')
    args = parser.parse_args()
    export(args.repo.resolve(), args.godot, args.output.resolve(), args.probe.resolve() if args.probe else None)

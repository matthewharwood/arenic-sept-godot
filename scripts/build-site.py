#!/usr/bin/env python3
"""Assemble the static Pages site from existing game and art outputs."""
import argparse
from collections import defaultdict
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def build(repo, output, game):
    if not (game / 'index.wasm').is_file() or not (game / 'index.pck').is_file():
        raise ValueError('A complete production Web export is required.')
    site_source = repo / 'site'
    if output == repo or output in repo.parents or output == game or output in game.parents or output.is_relative_to(game) or output.is_relative_to(site_source) or site_source.is_relative_to(output):
        raise ValueError('Output must be a dedicated build directory, separate from source and game.')
    if output.exists() and not (output / 'build-info.json').is_file():
        raise ValueError('Refusing to replace a directory without an Arenic build manifest.')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='arenic-site-', dir=output.parent) as temporary:
        stage = Path(temporary) / 'site'
        shutil.copytree(repo / 'site', stage)
        shutil.copytree(game, stage / 'play')
        media = stage / 'media'
        media.mkdir(exist_ok=True)
        for name in ('hunter',):
            shutil.copy2(repo / f'arenic-game/assets/portraits/{name}.png', media / f'{name}.png')
        for name in ('PPMigra-Extrabold.ttf', 'Barlow-Regular.ttf', 'barlow-OFL.txt'):
            shutil.copy2(repo / 'arenic-game/assets/fonts' / name, media / name)
        shutil.copy2(repo / 'arenic-game/icon.svg', media / 'icon.svg')
        report_path = repo / '.tmp/gallery-report.json'
        subprocess.run(['python3', str(repo / 'scripts/ci/publish-gallery.py'), '--repo', str(repo), '--output', str(stage / 'docs'), '--report', str(report_path)], check=True, stdout=subprocess.DEVNULL)
        report = json.loads(report_path.read_text())
        grouped = defaultdict(list)
        for ability in report['ability_links']:
            grouped[ability['hero']].append(ability)
        entries = []
        for hero, abilities in grouped.items():
            links = ''.join(f'<li><a href="{html.escape(a["href"])}">{html.escape(a["name"])} <span aria-hidden="true">↗</span></a></li>' for a in abilities)
            entries.append(f'<section><h2>{html.escape(hero.title())}</h2><ul>{links}</ul></section>')
        attacks = '''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Arenic · Attacks & abilities</title><style>body{background:oklch(.15 .018 150);color:oklch(.93 .016 110);font:16px/1.5 system-ui;margin:32px auto;padding:24px;max-width:1200px}a{color:inherit;text-underline-offset:4px}h1{font-size:clamp(32px,5vw,56px);line-height:1.1}p{max-width:700px;color:oklch(.77 .02 150)}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:32px}section{border-top:1px solid oklch(.45 .03 150)}h2{font-size:25px}ul{list-style:none;padding:0}li{border-top:1px solid oklch(.3 .02 150)}li a{padding:12px 0;display:flex;justify-content:space-between;text-decoration:none}li a:hover{text-decoration:underline}</style></head><body><h1>Attacks & abilities</h1><p>32 designs across eight classes. Open an ability to see its animation, effect layers, timing, and arena preview. These are design studies; ability combat and sound cues are not yet part of the playable build.</p><main>'''+''.join(entries)+'</main></body></html>'
        (stage / 'docs/attacks.html').write_text(attacks)
        for page in (stage / 'docs').rglob('*.html'):
            prefix = os.path.relpath(stage, page.parent).replace(os.sep, '/') + '/'
            nav = f'<nav class="site-nav" aria-label="Arenic site"><a href="{prefix}">Arenic</a><a href="{prefix}play/">Play ↗</a><a href="{prefix}docs/">Heroes</a><a href="{prefix}docs/bosses/">Bosses</a><a href="{prefix}docs/attacks.html">Attacks</a></nav>'
            style = '<style>.site-nav{display:flex;flex-wrap:wrap;gap:12px 24px;align-items:center;border-bottom:1px solid oklch(.45 .03 150);padding:0 0 20px;margin:0 0 24px}.site-nav a{font:16px/1.5 system-ui;text-decoration:none;border:0!important;padding:0!important;background:transparent!important}.site-nav a:first-child{font-weight:800;margin-right:auto}.site-nav a:hover{text-decoration:underline}a:focus-visible,button:focus-visible,select:focus-visible,input:focus-visible{outline:3px solid oklch(.8 .12 150);outline-offset:4px}*{border-radius:0!important}</style>'
            content = page.read_text()
            body = re.search(r'<body\b[^>]*>', content)
            if body:
                content = content[:body.end()] + style + nav + content[body.end():]
            else:
                content = content.replace('<nav ', style + nav + '<nav ', 1)
            page.write_text(content)
        revision = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
        (stage / 'build-info.json').write_text(json.dumps({'commit': revision, 'godot': '4.7.2', 'heroes': 8, 'bosses': 8, 'abilities': 32, 'music_version': 3}, indent=2)+'\n')
        (stage / '.nojekyll').touch()
        if output.exists():
            shutil.rmtree(output)
        stage.rename(output)
    print(f'Built Pages site: {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=ROOT)
    parser.add_argument('--output', type=Path, default=ROOT / '.tmp/site')
    parser.add_argument('--game', type=Path, required=True)
    args = parser.parse_args()
    build(args.repo.resolve(), args.output.resolve(), args.game.resolve())

#!/usr/bin/env python3
"""Package saved Arenic review galleries; no native art rebuild or source export.

Usage: python3 publish-gallery.py --repo PATH --output PATH [--report PATH]
Only the 16 studies, two indexes, necessary boss JSON and content-hashed PNGs
are published. Output must be a dedicated generated directory outside assets/.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import tempfile
from html.parser import HTMLParser
from urllib.parse import unquote, urlsplit

ROSTER = ('hunter', 'warrior', 'thief', 'alchemist', 'cardinal', 'bard', 'forager', 'merchant')
PAGE = re.compile(r'(<script>const PAGE=)(.*?)(;</script>)', re.S)
DATA_PNG = re.compile(r'data:image/png;base64,([A-Za-z0-9+/=]+)')
ATTR_IMAGE = re.compile(r'(?P<prefix>\bsrc=["\'])(?P<url>[^"\']+)(?P<quote>["\'])')
MARKERS = ('/Users/', 'file://', 'localhost', '127.0.0.1', 'api_key', 'Authorization', '../arenic_bevy/', 'res://')


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.urls = []

    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key in ('src', 'href') and value:
                self.urls.append(value)


def relative(target, page):
    return os.path.relpath(target, page.parent).replace(os.sep, '/')


def strip_unused_provenance(data):
    """Leave render keys (actor and FX source IDs) intact; omit disk references."""
    if 'hero' in data and 'abilities' in data['hero']:
        data['hero'].pop('portrait', None)
        for ability in data['hero']['abilities']:
            ability.pop('source_doc', None)
            for cue in ability.get('sounds', {}).values():
                cue.pop('file', None)
        for sprite in data['sprites'].values():
            sprite.pop('source', None)
    if 'boss' in data:
        data['boss'].pop('source', None)
        data['boss'].pop('portrait', None)


def image_values(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key in ('image', 'portrait_image', 'url') and isinstance(child, str):
                yield child
            else:
                yield from image_values(child)
    elif isinstance(value, list):
        for child in value:
            yield from image_values(child)


def package(repo, output, report_path):
    source = repo / 'assets/previews'
    if output == repo or output == source or source in output.parents or output in source.parents:
        raise ValueError('Output must be a separate generated directory, not a source ancestor.')
    output.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='gallery-package-', dir=output.parent))
    media = stage / '_media'
    media.mkdir()
    image_hashes = set()
    edges = set()
    pages = [PurePosixPath('index.html'), PurePosixPath('bosses/index.html')]
    pages += [PurePosixPath(identifier, 'attacks.html') for identifier in ROSTER]
    pages += [PurePosixPath('bosses', identifier, 'attacks.html') for identifier in ROSTER]
    payloads = {}
    source_html_bytes = sum((source / page).stat().st_size for page in pages)

    def save_image(raw, page):
        if raw[:8] != b'\x89PNG\r\n\x1a\n':
            raise ValueError('Expected a PNG export.')
        digest = hashlib.sha256(raw).hexdigest()
        target = media / (digest + '.png')
        if digest not in image_hashes:
            target.write_bytes(raw)
            image_hashes.add(digest)
        return relative(target, page)

    def edge(page, url):
        parsed = urlsplit(url)
        if parsed.scheme or parsed.netloc or parsed.path.startswith('/'):
            raise ValueError(f'Non-relative public dependency in {page}: {url[:100]}')
        if not parsed.path:
            return
        target = (page.parent / unquote(parsed.path)).resolve()
        if target.is_dir():
            target /= 'index.html'
        if stage.resolve() not in target.parents or not target.is_file():
            raise ValueError(f'Missing or escaped dependency: {page.relative_to(stage)} -> {url}')
        edges.add((page.relative_to(stage).as_posix(), target.relative_to(stage).as_posix()))

    try:
        for name in pages:
            original = source / name
            destination = stage / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            content = original.read_text()
            match = PAGE.search(content)
            if match:
                data = json.loads(match[2])
                strip_unused_provenance(data)
                content = content[:match.start(2)] + json.dumps(data, separators=(',', ':')).replace('</', '<\\/') + content[match.end(2):]
            content = DATA_PNG.sub(lambda m: save_image(base64.b64decode(m[1], validate=True), destination), content)

            def external_image(match):
                url = match['url']
                if '_media/' in url:
                    return match[0]
                raw = (original.parent / url).read_bytes()
                return match['prefix'] + save_image(raw, destination) + match['quote']

            content = ATTR_IMAGE.sub(external_image, content)
            if name.parts[0] == 'bosses' and len(name.parts) == 3:
                portrait = save_image((original.parent / 'portrait.png').read_bytes(), destination)
                content = content.replace('href="portrait.png"', f'href="{portrait}"')
                content = content.replace("$('portrait-link').href='portrait.png';", f"$('portrait-link').href='{portrait}';")
                content = content.replace("$('source').textContent='Source: '+boss.source;", "$('source').textContent='Native overhead sprite · appearance study';")
            if len(name.parts) == 2 and name.parts[0] in ROSTER:
                old = "img.src=base+id+'.png';"
                new = "img.src=new URL(content.image,new URL(base,document.baseURI)).href;"
                if content.count(old) != 1:
                    raise ValueError(f'Boss image fetch contract changed: {name}')
                content = content.replace(old, new)
                content = content.replace('Sounds pending · ElevenLabs connection needs a valid key', 'Ability sounds are not available yet')
                article = "article.className='panel';article.innerHTML="
                if content.count(article) != 1:
                    raise ValueError(f'Ability article contract changed: {name}')
                content = content.replace(article, "article.className='panel';article.id='ability-'+s.id;article.innerHTML=")
                linked_ability = """function selectLinkedAbility(){const id=location.hash.slice(1);if(!id.startsWith('ability-'))return;const target=document.getElementById(id);if(!target)return;$('ability').value=id.slice(8);stopSounds();now=0;render();target.scrollIntoView({block:'start'});}window.addEventListener('hashchange',selectLinkedAbility);"""
                content = content.replace('Promise.all(Object.values(sprites)', linked_ability + '\nPromise.all(Object.values(sprites)')
                content = content.replace('ready=true;ctx.imageSmoothingEnabled=false;resize();arenaResize();', 'ready=true;ctx.imageSmoothingEnabled=false;resize();arenaResize();if(location.hash)requestAnimationFrame(selectLinkedAbility);')
            if name == PurePosixPath('index.html'):
                content = content.replace('all four animations and their sound cues.', 'all four animations. Ability sounds are not available yet.')
            content = content.replace('</style>', '*{border-radius:0!important}article[id]{scroll-margin-top:24px}</style>', 1)
            if any(marker in content for marker in MARKERS) or ';base64,' in content:
                raise ValueError(f'Unexpected private path, setup detail or embedded media: {name}')
            destination.write_text(content)
            final_match = PAGE.search(content)
            if final_match:
                payloads[name.as_posix()] = json.loads(final_match[2])

        gallery = json.loads((source / 'bosses/gallery.json').read_text())
        if [entry['id'] for entry in gallery] != list(ROSTER):
            raise ValueError('Expected the complete eight-boss roster.')
        (stage / 'bosses/gallery.json').write_text(json.dumps([{'id': b['id'], 'name': b['name']} for b in gallery], separators=(',', ':')) + '\n')
        for identifier in ROSTER:
            folder = stage / 'bosses' / identifier
            original = source / 'bosses' / identifier
            metadata = json.loads((original / f'{identifier}.json').read_text())
            public = {
                'frames': metadata['frames'],
                'meta': {'frameTags': metadata['meta']['frameTags']},
                'image': save_image((original / f'{identifier}.png').read_bytes(), folder / f'{identifier}.json'),
            }
            (folder / f'{identifier}.json').write_text(json.dumps(public, separators=(',', ':')) + '\n')

        # Validate actual HTML and embedded media, then enumerate dynamic JS
        # navigation/fetch contracts. This includes all 8x8 boss selections.
        for name in pages:
            page = stage / name
            parser = Links()
            parser.feed(page.read_text())
            for url in parser.urls:
                edge(page, url)
            for url in image_values(payloads.get(name.as_posix(), {})):
                edge(page, url)
        for identifier in ROSTER:
            hero_page = stage / identifier / 'attacks.html'
            hero = payloads[f'{identifier}/attacks.html']
            assert hero['hero']['id'] == identifier and len(hero['hero']['abilities']) == 4
            assert hero['sprites'] and all(sprite['frames'] and sprite['tags'] for sprite in hero['sprites'].values())
            assert len({ability['id'] for ability in hero['hero']['abilities']}) == 4
            assert "article.id='ability-'+s.id" in hero_page.read_text()
            edge(hero_page, '../index.html')
            edge(hero_page, '../bosses/index.html')
            edge(hero_page, '../bosses/gallery.json')
            for other in ROSTER:
                edge(hero_page, f'../{other}/attacks.html')
                edge(hero_page, f'../bosses/{other}/{other}.json')
            boss_page = stage / 'bosses' / identifier / 'attacks.html'
            boss = payloads[f'bosses/{identifier}/attacks.html']
            assert boss['boss']['id'] == identifier and boss['sprite']['frames']
            for other in ROSTER:
                edge(boss_page, f'../{other}/attacks.html')
            metadata_path = stage / 'bosses' / identifier / f'{identifier}.json'
            metadata = json.loads(metadata_path.read_text())
            assert metadata['frames'] == boss['sprite']['frames']
            assert metadata['meta']['frameTags'] == boss['sprite']['tags']
            edge(metadata_path, metadata['image'])

        files = sorted(path for path in stage.rglob('*') if path.is_file())
        incoming = {target for _, target in edges}
        orphaned = {path.relative_to(stage).as_posix() for path in files} - incoming - {'index.html'}
        if orphaned:
            raise ValueError(f'Unexpected unreferenced output: {sorted(orphaned)}')
        if any(path.suffix not in ('.html', '.json', '.png') for path in files):
            raise ValueError('Unexpected public file type.')
        report = {
            'heroes': 8, 'hero_abilities': 32, 'bosses': 8,
            'html_pages': len(pages), 'json_files': 9, 'unique_pngs': len(image_hashes),
            'file_count': len(files), 'total_bytes': sum(path.stat().st_size for path in files),
            'html_bytes': sum((stage / page).stat().st_size for page in pages),
            'source_html_bytes': source_html_bytes,
            'verified_dependency_edges': len(edges),
            'pending_ability_audio_cues': sum(len(a['sounds']) for key, value in payloads.items() if not key.startswith('bosses/') for a in value['hero']['abilities']),
            'ability_links': [{'hero': identifier, 'id': a['id'], 'name': a['name'], 'href': f'{identifier}/attacks.html#ability-{a["id"]}'} for identifier in ROSTER for a in payloads[f'{identifier}/attacks.html']['hero']['abilities']],
            'files': [{'path': p.relative_to(stage).as_posix(), 'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files],
            'dependencies': [{'from': a, 'to': b} for a, b in sorted(edges)],
        }
        # The selected sources are finite and checked above. Only replace the
        # explicitly requested generated directory, never unrelated siblings.
        if output.exists():
            shutil.rmtree(output)
        stage.rename(output)
        if report_path:
            report_path.parent.mkdir(parents=True, exist_ok=True)
            report_path.write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps({key: value for key, value in report.items() if key not in ('files', 'dependencies')}, indent=2))
    except BaseException:
        if stage.exists():
            shutil.rmtree(stage)
        raise


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    package(args.repo.resolve(), args.output.resolve(), args.report.resolve() if args.report else None)

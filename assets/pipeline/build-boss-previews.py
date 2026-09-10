"""Render saved boss masters, build their gallery, and optionally export Godot assets."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROSTER = ['hunter', 'warrior', 'thief', 'alchemist', 'cardinal', 'bard', 'forager', 'merchant']


def uri(path):
    return 'data:image/png;base64,' + base64.b64encode(path.read_bytes()).decode()


def spriteframes(boss, content):
    """Aseprite durations are milliseconds; speed 1000 preserves each duration verbatim."""
    identifier = boss['id']
    frames = content['frames']
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(frames)+2} format=3]', '',
             f'[ext_resource type="Texture2D" path="res://assets/bosses/{identifier}/{identifier}.png" id="1"]', '']
    for index, frame in enumerate(frames):
        r = frame['frame']
        lines.extend([f'[sub_resource type="AtlasTexture" id="Frame_{index}"]',
                      'atlas = ExtResource("1")',
                      f'region = Rect2({r["x"]}, {r["y"]}, 114, 114)',
                      'filter_clip = true', ''])
    animations = []
    for tag in content['meta']['frameTags']:
        sequence = ', '.join('{"duration": %s.0, "texture": SubResource("Frame_%s")}' %
                             (frames[i]['duration'], i) for i in range(tag['from'], tag['to']+1))
        animations.append('{"frames": [%s], "loop": true, "name": &"%s", "speed": 1000.0}' %
                          (sequence, tag['name']))
    lines.extend(['[resource]', 'animations = [' + ',\n'.join(animations) + ']', ''])
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--aseprite', default='aseprite')
    parser.add_argument('--boss', choices=ROSTER, action='append')
    parser.add_argument('--export-game', action='store_true', help='Write authorized boss runtime assets.')
    args = parser.parse_args()
    assets = Path(__file__).resolve().parents[1]
    root = assets.parent
    preview = assets/'previews'
    template = (assets/'pipeline/boss-preview.html').read_text()
    javascript = (assets/'pipeline/boss-preview.js').read_text()
    roster = []
    for identifier in ROSTER:
        manifest = assets/'bosses'/identifier/'boss.json'
        if not manifest.exists():
            continue
        boss = json.loads(manifest.read_text())
        roster.append({'id': identifier, 'name': boss['name']})
        if args.boss and identifier not in args.boss:
            continue
        source = root/boss['source']
        assert source.is_file(), source
        assert boss['canvas'] == [114, 114] and boss['pivot'] == [57, 57]
        dest = preview/'bosses'/identifier
        dest.mkdir(parents=True, exist_ok=True)
        texture, metadata = dest/f'{identifier}.png', dest/f'{identifier}.json'
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        stamp = dest/'source.sha256'
        if not all(p.exists() for p in (texture, metadata, stamp)) or stamp.read_text() != digest:
            result = subprocess.run([args.aseprite, '--batch', str(source), '--sheet-columns', '16',
                '--sheet-type', 'rows', '--format', 'json-array', '--list-tags', '--list-layers',
                '--list-slices', '--sheet', str(texture), '--data', str(metadata)],
                capture_output=True, text=True, check=True)
            assert texture.exists() and metadata.exists(), result.stdout + result.stderr
            stamp.write_text(digest)
        content = json.loads(metadata.read_text())
        frames, tags = content['frames'], content['meta']['frameTags']
        assert frames and all(not f['trimmed'] and f['frame']['w'] == 114 and
                              f['frame']['h'] == 114 and f['duration'] > 0 for f in frames)
        assert content['meta']['size']['w'] <= 1824
        anchor = next(s for s in content['meta']['slices'] if s['name'] == 'frame')['keys'][0]['pivot']
        assert anchor == {'x': 57, 'y': 57}, anchor
        for state in boss['visual_states']:
            for direction in 'nesw':
                tag = next(t for t in tags if t['name'] == state['tag']+'_'+direction)
                assert 0 <= tag['from'] <= tag['to'] < len(frames)
        hero = json.loads((assets/'characters'/identifier/'hero.json').read_text())
        hero_meta = json.loads((preview/identifier/'sheets'/f'{identifier}.json').read_text())
        hero_sprite = {'frames': hero_meta['frames'], 'tags': hero_meta['meta']['frameTags'],
                       'pivot': [9, 9], 'image': uri(preview/identifier/'sheets'/f'{identifier}.png')}
        sprite = {'frames': frames, 'tags': tags, 'pivot': [57, 57], 'image': uri(texture)}
        boss['portrait_image'] = uri(root/boss['portrait'])
        payload = {'boss': boss, 'sprite': sprite, 'hero': hero_sprite, 'roster': ROSTER}
        page = template.replace('__PAGE_DATA__', json.dumps(payload).replace('</', '<\\/')).replace('__PREVIEW_JS__', javascript)
        (dest/'attacks.html').write_text(page)
        for alias in ['index.html', 'attacks.htm']:
            (dest/alias).write_text('<!doctype html><meta http-equiv="refresh" content="0;url=attacks.html"><a href="attacks.html">Open boss study</a>')
        shutil.copy2(root/boss['portrait'], dest/'portrait.png')
        if args.export_game:
            runtime = root/'arenic-game/assets/bosses'/identifier
            runtime.mkdir(parents=True, exist_ok=True)
            shutil.copy2(texture, runtime/texture.name)
            shutil.copy2(metadata, runtime/metadata.name)
            (runtime/f'{identifier}_frames.tres').write_text(spriteframes(boss, content))
        print(f'{identifier}: {len(frames)} frames, {len(tags)} tags, {len(boss["visual_states"])} appearance states')
    (preview/'bosses').mkdir(exist_ok=True)
    available = [boss for boss in roster if (preview/'bosses'/boss['id']/f'{boss["id"]}.json').exists()]
    (preview/'bosses/gallery.json').write_text(json.dumps(available, indent=2)+'\n')
    subprocess.run(['python3', str(assets/'pipeline/build-gallery-index.py')], check=True)


if __name__ == '__main__':
    main()

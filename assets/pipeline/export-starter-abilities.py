"""Export only eight authorized starter abilities and their native FX, without saving masters.

python3 assets/pipeline/export-starter-abilities.py --aseprite /path/to/aseprite
Optional --ability limits rebuilding; the catalog always describes all eight.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
STARTERS = {"auto_shot": "hunter", "bash": "warrior", "backstab": "thief", "acid_flask": "alchemist",
            "heal": "cardinal", "cleanse": "bard", "dig": "forager", "fortune": "merchant"}
spec = importlib.util.spec_from_file_location("base_export", Path(__file__).with_name("export-base-heroes.py"))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)


def validate(texture, content, actor):
    frames, meta = content["frames"], content["meta"]
    base.require(isinstance(frames, list) and frames, "Expected JSON Array frames")
    base.require(texture[:8] == b"\x89PNG\r\n\x1a\n", "Expected native PNG")
    width, height = struct.unpack(">II", texture[16:24])
    canvas = frames[0]["sourceSize"]
    w, h = canvas["w"], canvas["h"]
    base.require((width, height) == (w * len(frames), h), "Expected untrimmed horizontal sheet")
    base.require(meta["size"] == {"w": width, "h": height} and meta["scale"] == "1", "Native dimensions changed")
    base.require(not actor or (w, h) == (19, 19), "Actors must remain 19x19")
    for index, frame in enumerate(frames):
        base.require(frame["frame"] == {"x": index * w, "y": 0, "w": w, "h": h}, "Unexpected atlas region")
        base.require(frame["sourceSize"] == canvas and frame["spriteSourceSize"] == {"x": 0, "y": 0, "w": w, "h": h}, "Trimmed canvas")
        base.require(not frame["trimmed"] and not frame["rotated"] and frame["duration"] > 0, "Invalid frame/timing")
    slices = [item for item in meta["slices"] if item["name"] == "frame"]
    base.require(len(slices) == 1 and slices[0]["keys"], "Missing native frame pivot")
    pivot = slices[0]["keys"][0]["pivot"]
    for key in slices[0]["keys"]:
        base.require(key["bounds"] == {"x": 0, "y": 0, "w": w, "h": h} and key["pivot"] == pivot, "Animated pivots require explicit support")
    base.require(not actor or pivot == {"x": 9, "y": 9}, "Actor pivot must remain 9,9")
    base.require(meta.get("layers") and meta.get("frameTags"), "Missing layer/tag metadata")
    for tag in meta["frameTags"]:
        base.require(tag["direction"] == "forward" and 0 <= tag["from"] <= tag["to"] < len(frames), "Unsupported tag playback")
    return [w, h], [pivot["x"], pivot["y"]]


def spriteframes(texture_path, content, loops):
    frames = content["frames"]
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(frames) + 2} format=3]', "",
             f'[ext_resource type="Texture2D" path="{texture_path}" id="1"]', ""]
    for index, frame in enumerate(frames):
        r = frame["frame"]
        lines += [f'[sub_resource type="AtlasTexture" id="Frame_{index}"]', 'atlas = ExtResource("1")',
                  f'region = Rect2({r["x"]}, {r["y"]}, {r["w"]}, {r["h"]})', 'filter_clip = true', ""]
    animations = []
    for tag in content["meta"]["frameTags"]:
        sequence = ', '.join('{"duration": %s.0, "texture": SubResource("Frame_%s")}' %
                             (frames[index]["duration"], index) for index in range(tag["from"], tag["to"] + 1))
        animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": 1000.0}' %
                          (sequence, str(tag["name"] in loops).lower(), tag["name"]))
    return ('\n'.join(lines + ['[resource]', 'animations = [' + ',\n'.join(animations) + ']', ""])).encode()


def export(aseprite, version, ability_id, hero, ability):
    folder = ROOT / 'assets/characters' / hero
    destination = ROOT / 'arenic-game/assets/abilities' / ability_id
    source_rows = [(ability['actor'], 'actor', [])]
    for path in dict.fromkeys(fx['source'] for fx in ability['fx']):
        source_rows.append((path, Path(path).stem, [fx for fx in ability['fx'] if fx['source'] == path]))
    rows = {}
    for relative, stem, fx_rows in source_rows:
        source = folder / relative
        source_hash = base.digest(source.read_bytes())
        with tempfile.TemporaryDirectory(prefix='arenic-starter-') as temporary:
            png, metadata = Path(temporary) / (stem + '.png'), Path(temporary) / (stem + '.json')
            subprocess.run([aseprite, '--batch', str(source), '--sheet-type', 'horizontal', '--format', 'json-array',
                            '--list-tags', '--list-layers', '--list-slices', '--sheet', str(png), '--data', str(metadata)],
                           capture_output=True, text=True, check=True)
            texture, raw_json = png.read_bytes(), metadata.read_bytes()
            content = json.loads(raw_json)
            canvas, pivot = validate(texture, content, stem == 'actor')
            base.require(base.digest(source.read_bytes()) == source_hash, 'Export modified a saved master')
        tags = content['meta']['frameTags']
        loops = {fx['tag'] for fx in fx_rows if fx['loop']}
        if stem == 'actor' and ability_id == 'heal':
            loops.update(tag['name'] for tag in tags if 'channel' in tag['name'] or 'hold' in tag['name'])
        res_prefix = f'res://assets/abilities/{ability_id}/{stem}'
        resource = spriteframes(res_prefix + '.png', content, loops)
        base.write_changed(destination / (stem + '.png.import'), base.import_settings(destination / (stem + '.png.import'), stem + '.png').encode())
        for name, data in [(stem + '.png', texture), (stem + '.json', raw_json), (stem + '_frames.tres', resource)]:
            base.write_changed(destination / name, data)
        rows[stem] = {'source': source.relative_to(ROOT).as_posix(), 'source_sha256': source_hash,
                      'sprite_frames': res_prefix + '_frames.tres', 'canvas': canvas, 'pivot': pivot,
                      'sha256': {'png': base.digest(texture), 'json': base.digest(raw_json), 'sprite_frames': base.digest(resource)},
                      'tags': {tag['name']: {'duration_ms': sum(f['duration'] for f in content['frames'][tag['from']:tag['to'] + 1]),
                                           'frame_count': tag['to'] - tag['from'] + 1, 'loop': tag['name'] in loops} for tag in tags}}
        print(f'{ability_id}/{stem}: {canvas}, pivot {pivot}, {len(content["frames"])} frames, {len(tags)} tags; master unchanged')
    record = {'id': ability_id, 'hero': hero, 'display_name': 'Sacrifice' if ability_id == 'heal' else ability['name'],
              'generator': 'assets/pipeline/export-starter-abilities.py', 'aseprite_version': version,
              'release_seconds': ability['release_ms'] / 1000, 'preview_impact_seconds': ability['preview']['impact_ms'] / 1000,
              'saved_layer_visibility': True, 'required_filter': 'BaseMaterial3D.TEXTURE_FILTER_NEAREST',
              'import_options': base.IMPORT_OPTIONS, 'actor': rows.pop('actor'),
              'effects': [{**fx, 'asset': Path(fx['source']).stem} for fx in ability['fx']], 'assets': rows,
              'authority': 'Presentation timing and native pixels only; gameplay owns impacts, status lifetimes and ranges.'}
    base.write_changed(destination / 'export.json', (json.dumps(record, indent=2) + '\n').encode())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--aseprite', default='aseprite')
    parser.add_argument('--ability', choices=STARTERS, action='append')
    args = parser.parse_args()
    version = subprocess.run([args.aseprite, '--version'], capture_output=True, text=True, check=True).stdout.strip()
    for ability_id, hero in STARTERS.items():
        if args.ability and ability_id not in args.ability:
            continue
        brief = json.loads((ROOT / 'assets/characters' / hero / 'hero.json').read_text())
        ability = next(item for item in brief['abilities'] if item['id'] == ability_id)
        export(args.aseprite, version, ability_id, hero, ability)
    catalog = {key: json.loads((ROOT / 'arenic-game/assets/abilities' / key / 'export.json').read_text()) for key in STARTERS}
    base.write_changed(ROOT / 'arenic-game/assets/abilities/starter_manifest.json', (json.dumps(catalog, indent=2) + '\n').encode())
    runtime = {key: {'release_seconds': row['release_seconds'], 'assets': {stem: {field: asset[field] for field in ('sprite_frames', 'canvas', 'pivot')} for stem, asset in row['assets'].items()}} for key, row in catalog.items()}
    resource = '[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/abilities = ' + json.dumps(runtime, indent=2) + '\n'
    base.write_changed(ROOT / 'arenic-game/assets/abilities/starter_catalog.tres', resource.encode())


if __name__ == '__main__':
    main()

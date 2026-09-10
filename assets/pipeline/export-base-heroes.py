"""Export authorized base hero idles to Godot; never save masters or export abilities.

Run: python3 assets/pipeline/export-base-heroes.py --aseprite /path/to/aseprite
Optional repeated --hero limits the roster. Saved layer visibility is respected.
SpriteFrames cannot own filtering: the consuming Sprite3D must select NEAREST.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import tempfile

ROSTER = ("hunter", "warrior", "thief", "alchemist", "cardinal", "bard", "forager", "merchant")
TAGS = tuple("idle_" + direction for direction in "nesw")
IMPORT_OPTIONS = {
    "compress/mode": "0",
    "mipmaps/generate": "false",
    "detect_3d/compress_to": "0",
    "process/fix_alpha_border": "false",
    "process/premult_alpha": "false",
    "process/size_limit": "0",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def write_changed(path, data):
    """Avoid reimporting unchanged outputs; replace complete files atomically."""
    if path.exists() and path.read_bytes() == data:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".", suffix=".tmp", delete=False) as temporary:
        temporary.write(data)
        temporary_path = Path(temporary.name)
    try:
        temporary_path.replace(path)
    finally:
        temporary_path.unlink(missing_ok=True)


def validate(texture, content):
    frames = content["frames"]
    meta = content["meta"]
    require(frames and isinstance(frames, list), "Expected JSON Array frames")
    require(texture[:8] == b"\x89PNG\r\n\x1a\n" and texture[12:16] == b"IHDR", "Expected PNG output")
    width, height = struct.unpack(">II", texture[16:24])
    require((width, height) == (19 * len(frames), 19), "Expected an unpadded horizontal 19px sheet")
    require(meta["size"] == {"w": width, "h": height}, "PNG and JSON dimensions differ")
    require(meta.get("scale") == "1", "Source scale must remain native 1x")
    for index, frame in enumerate(frames):
        require(frame["frame"] == {"x": index * 19, "y": 0, "w": 19, "h": 19}, "Unexpected frame region")
        require(frame["sourceSize"] == {"w": 19, "h": 19}, "Source canvas must be 19x19")
        require(frame["spriteSourceSize"] == {"x": 0, "y": 0, "w": 19, "h": 19}, "Unexpected trimmed bounds")
        require(not frame["trimmed"] and not frame["rotated"], "Trimming/atlas rotation is forbidden")
        require(isinstance(frame["duration"], int) and frame["duration"] > 0, "Invalid native frame timing")
    tags = meta["frameTags"]
    require(len(tags) == 4 and {tag["name"] for tag in tags} == set(TAGS), "Only four base idle tags are supported")
    coverage = []
    for tag in tags:
        require(tag["direction"] == "forward", "Unexpected tag playback direction; update the exporter deliberately")
        require(0 <= tag["from"] <= tag["to"] < len(frames), "Invalid idle tag range")
        coverage.extend(range(tag["from"], tag["to"] + 1))
    require(sorted(coverage) == list(range(len(frames))), "Idle tags must cover each source frame exactly once")
    slices = [item for item in meta["slices"] if item["name"] == "frame"]
    require(len(slices) == 1 and slices[0]["keys"], "Missing authoritative frame slice")
    for key in slices[0]["keys"]:
        require(key["bounds"] == {"x": 0, "y": 0, "w": 19, "h": 19}, "Unexpected frame slice bounds")
        require(key["pivot"] == {"x": 9, "y": 9}, "Source pivot must remain (9,9)")
    require(meta.get("layers"), "Layer metadata was not exported")


def spriteframes(identifier, content):
    """Speed 1000 with millisecond frame weights preserves Aseprite timing."""
    frames = content["frames"]
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(frames) + 2} format=3]', "",
             f'[ext_resource type="Texture2D" path="res://assets/characters/{identifier}/{identifier}.png" id="1"]', ""]
    for index, frame in enumerate(frames):
        region = frame["frame"]
        lines += [f'[sub_resource type="AtlasTexture" id="Frame_{index}"]', 'atlas = ExtResource("1")',
                  f'region = Rect2({region["x"]}, {region["y"]}, 19, 19)', 'filter_clip = true', ""]
    animations = []
    tags = {tag["name"]: tag for tag in content["meta"]["frameTags"]}
    for name in TAGS:
        tag = tags[name]
        sequence = ', '.join('{"duration": %s.0, "texture": SubResource("Frame_%s")}' %
                             (frames[index]["duration"], index) for index in range(tag["from"], tag["to"] + 1))
        animations.append('{"frames": [%s], "loop": true, "name": &"%s", "speed": 1000.0}' % (sequence, name))
    return '\n'.join(lines + ['[resource]', 'animations = [' + ',\n'.join(animations) + ']', ""])


def import_settings(path, source_file):
    """Preserve engine-generated remap/UID metadata while pinning pixel-art options."""
    if path.exists():
        text = path.read_text()
    else:
        text = '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'
    require('[params]' in text, f"Missing import params in {source_file}")
    for key, value in IMPORT_OPTIONS.items():
        pattern = re.compile(r'^' + re.escape(key) + r'=.*$', re.MULTILINE)
        if pattern.search(text):
            text = pattern.sub(key + '=' + value, text)
        else:
            text = text.rstrip() + '\n' + key + '=' + value + '\n'
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--aseprite', default='aseprite')
    parser.add_argument('--hero', choices=ROSTER, action='append')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    version = subprocess.run([args.aseprite, '--version'], capture_output=True, text=True, check=True).stdout.strip()
    for identifier in ROSTER:
        if args.hero and identifier not in args.hero:
            continue
        source = root / 'assets/characters' / identifier / (identifier + '.aseprite')
        manifest = json.loads(source.with_name('hero.json').read_text())
        require(manifest['id'] == identifier, 'Source manifest identity mismatch')
        # Older briefs omit dimensions or call the canvas "frame"; the actual
        # exported regions and native frame slice remain mandatory below.
        for key, expected in [('canvas', [19, 19]), ('frame', [19, 19]), ('pivot', [9, 9])]:
            if key in manifest:
                require(manifest[key] == expected, f'Unexpected {identifier} {key}')
        source_hash = digest(source.read_bytes())
        with tempfile.TemporaryDirectory(prefix='arenic-base-hero-') as temporary:
            staged = Path(temporary)
            png, metadata = staged / (identifier + '.png'), staged / (identifier + '.json')
            subprocess.run([args.aseprite, '--batch', str(source), '--sheet-type', 'horizontal',
                            '--format', 'json-array', '--list-tags', '--list-layers', '--list-slices',
                            '--sheet', str(png), '--data', str(metadata)], capture_output=True, text=True, check=True)
            texture, json_bytes = png.read_bytes(), metadata.read_bytes()
            content = json.loads(json_bytes)
            validate(texture, content)
            require(digest(source.read_bytes()) == source_hash, 'Export modified the saved master')
        destination = root / 'arenic-game/assets/characters' / identifier
        resource = spriteframes(identifier, content).encode()
        import_path = destination / (identifier + '.png.import')
        # Install the import policy before the editor first sees the new PNG.
        settings = import_settings(import_path, png.name)
        write_changed(import_path, settings.encode())
        for name, data in [(identifier + '.png', texture), (identifier + '.json', json_bytes),
                           (identifier + '_frames.tres', resource)]:
            write_changed(destination / name, data)
        record = {
            'source': source.relative_to(root).as_posix(), 'source_sha256': source_hash,
            'generator': 'assets/pipeline/export-base-heroes.py', 'aseprite_version': version,
            'canvas': [19, 19], 'pivot': [9, 9], 'saved_layer_visibility': True,
            'sprite_frames': 'res://assets/characters/%s/%s_frames.tres' % (identifier, identifier),
            'required_sprite_filter': 'BaseMaterial3D.TEXTURE_FILTER_NEAREST',
            'import_options': IMPORT_OPTIONS,
            'sha256': {'png': digest(texture), 'json': digest(json_bytes), 'sprite_frames': digest(resource)},
            'idle_durations_ms': {tag['name']: [frame['duration'] for frame in content['frames'][tag['from']:tag['to'] + 1]]
                                  for tag in content['meta']['frameTags']},
        }
        write_changed(destination / (identifier + '_export.json'), (json.dumps(record, indent=2) + '\n').encode())
        print(f'{identifier}: {len(content["frames"])} native frames; four idle tags; source unchanged')


if __name__ == '__main__':
    main()

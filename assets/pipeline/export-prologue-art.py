"""Export the authorized Keeper and gate from saved Aseprite masters.

Usage: python3 assets/pipeline/export-prologue-art.py --aseprite /path/to/aseprite
Native artwork remains authoritative. Godot consumers must use nearest filtering.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('base_export', ROOT / 'assets/pipeline/export-base-heroes.py')
BASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BASE)
ASSETS = (
    ('keeper', 'npcs/keeper', (19, 19), (9, 9)),
    ('guild_gate', 'environment/guild_gate', (57, 38), (28, 28)),
)


def run(executable, args):
    result = subprocess.run([executable, *args], check=True, text=True, capture_output=True)
    if 'error' in result.stdout.lower() or 'error' in result.stderr.lower():
        raise ValueError(result.stdout + result.stderr)
    return result.stdout.strip()


def resource(identifier, folder, content):
    frames = content['frames']
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(frames)+2} format=3]', '',
             f'[ext_resource type="Texture2D" path="res://assets/{folder}/{identifier}.png" id="1"]', '']
    for index, frame in enumerate(frames):
        r = frame['frame']
        lines.extend([f'[sub_resource type="AtlasTexture" id="Frame_{index}"]', 'atlas = ExtResource("1")',
                      f'region = Rect2({r["x"]}, {r["y"]}, {r["w"]}, {r["h"]})', 'filter_clip = true', ''])
    animations = []
    for tag in content['meta']['frameTags']:
        sequence = ', '.join('{"duration": %d.0, "texture": SubResource("Frame_%d")}' %
                             (frames[i]['duration'], i) for i in range(tag['from'], tag['to']+1))
        loop = str(not (tag['name'].startswith('beckon_') or tag['name']=='opening')).lower()
        animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": 1000.0}' % (sequence, loop, tag['name']))
    return '\n'.join(lines + ['[resource]', 'animations = ['+',\n'.join(animations)+']', '']).encode()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--aseprite', default='aseprite')
    args=parser.parse_args()
    verification=run(args.aseprite, ['--batch', '--script-param', f'root={ROOT}', '--script',
                                    str(ROOT/'assets/pipeline/validate-prologue-art.lua')])
    if 'PROLOGUE_ART_VALIDATION_OK' not in verification:
        raise ValueError('Native readback did not finish: '+verification)
    print(verification)
    version=run(args.aseprite, ['--version'])
    for identifier, folder, canvas, pivot in ASSETS:
        source=ROOT/'assets'/folder/(identifier+'.aseprite')
        source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
        preview=source.parent/'previews'; preview.mkdir(parents=True, exist_ok=True)
        destination=ROOT/'arenic-game/assets'/folder
        with tempfile.TemporaryDirectory(prefix='arenic-prologue-art-') as temporary:
            png=Path(temporary)/(identifier+'.png'); metadata=png.with_suffix('.json')
            run(args.aseprite, ['--batch', str(source), '--sheet-columns', '8', '--sheet-type', 'rows',
                '--format', 'json-array', '--list-tags', '--list-layers', '--list-slices', '--sheet', str(png), '--data', str(metadata)])
            texture=png.read_bytes(); content=json.loads(metadata.read_text())
            width,height=struct.unpack('>II',texture[16:24])
            if content['meta']['size'] != {'w':width,'h':height}:
                raise ValueError('Atlas metadata/PNG size mismatch')
            for index, frame in enumerate(content['frames']):
                if frame['trimmed'] or frame['rotated'] or frame['sourceSize'] != {'w':canvas[0],'h':canvas[1]}:
                    raise ValueError('Native frame was transformed')
                if frame['frame'] != {'x':index%8*canvas[0], 'y':index//8*canvas[1], 'w':canvas[0], 'h':canvas[1]}:
                    raise ValueError('Unexpected untrimmed atlas region')
            # Aseprite embeds temporary atlas paths; stable metadata makes reruns reproducible.
            content['meta']['image']=identifier+'.png'
            data=(json.dumps(content, indent=2)+'\n').encode()
            frames=resource(identifier,folder,content)
            BASE.write_changed(destination/(identifier+'.png.import'), BASE.import_settings(destination/(identifier+'.png.import'), png.name).encode())
            for target in (preview,destination):
                BASE.write_changed(target/(identifier+'.png'),texture)
                BASE.write_changed(target/(identifier+'.json'),data)
            BASE.write_changed(destination/(identifier+'_frames.tres'),frames)
            for tag in content['meta']['frameTags']:
                run(args.aseprite, ['--batch', str(source), '--tag', tag['name'], '--scale', '8', '--save-as', str(preview/(tag['name']+'.gif'))])
            record={'source':source.relative_to(ROOT).as_posix(),'source_sha256':source_hash,
                'generator':'assets/pipeline/export-prologue-art.py','aseprite_version':version,
                'canvas':canvas,'pivot':pivot,'native_scale':1,'atlas_columns':8,
                'required_sprite_filter':'NEAREST','saved_layer_visibility':True,
                'sprite_frames':f'res://assets/{folder}/{identifier}_frames.tres',
                'import_options':BASE.IMPORT_OPTIONS,
                'animations':{tag['name']:{'durations_ms':[content['frames'][i]['duration'] for i in range(tag['from'],tag['to']+1)],
                    'loop':not(tag['name'].startswith('beckon_') or tag['name']=='opening')} for tag in content['meta']['frameTags']},
                'sha256':{'png':BASE.digest(texture),'json':BASE.digest(data),'sprite_frames':BASE.digest(frames)}}
            BASE.write_changed(destination/(identifier+'_export.json'),(json.dumps(record,indent=2)+'\n').encode())
        if hashlib.sha256(source.read_bytes()).hexdigest()!=source_hash:
            raise ValueError('Export changed native master')
        print(f'{identifier}: {len(content["frames"])} untrimmed frames exported; saved source unchanged')
    review=['<!doctype html><meta charset="utf-8"><title>Keeper and guild gate motion review</title>',
        '<style>body{background:oklch(.19 .025 295);color:oklch(.91 .02 85);font:16px system-ui;padding:28px}',
        'section{display:grid;grid-template-columns:repeat(4,180px);gap:16px}figure{margin:0;padding:12px;background:oklch(.3 .025 295)}',
        'img{image-rendering:pixelated;display:block}figcaption{margin:8px 0}.native{width:19px;height:19px}.gate{width:456px;height:304px}</style>',
        '<h1>The Keeper · native Aseprite motion</h1><p>Top row: 1.2s idle loops. Bottom row: 1.4s beckons replayed for review. Large 8× and native 1×.</p>']
    for action in ('idle','beckon'):
        review.append('<section>')
        for direction in 'nesw':
            name=action+'_'+direction
            review.append(f'<figure><img src="{name}.gif" width="152" height="152"><figcaption>{name}</figcaption><img class="native" src="{name}.gif"></figure>')
        review.append('</section>')
    review.extend(['<h2>Guild gate · locked / 1.4s opening / open</h2>', '<p>The source animation loops here only for review; Godot opening is a one-shot.</p>'])
    for name in ('locked','opening','open'):
        review.append(f'<figure style="display:inline-block"><img class="gate" src="../../../environment/guild_gate/previews/{name}.gif"><figcaption>{name}</figcaption></figure>')
    BASE.write_changed(ROOT/'assets/npcs/keeper/previews/motion-review.html', '\n'.join(review).encode())


if __name__=='__main__':
    main()

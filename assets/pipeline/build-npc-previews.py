"""Build NPC portrait/dialogue booklets from saved art; never mutate native masters."""
import base64
import html
import json
from pathlib import Path
import shutil
import subprocess
import sys

ASSETS = Path(__file__).resolve().parents[1]
ROOT = ASSETS.parent


def uri(path):
    return 'data:image/png;base64,' + base64.b64encode(path.read_bytes()).decode()


def main():
    template = (ASSETS / 'pipeline/npc-preview.html').read_text()
    catalog = []
    for manifest in sorted((ASSETS / 'npcs').glob('*/npc.json')):
        npc = json.loads(manifest.read_text())
        identifier = npc['id']
        if identifier != manifest.parent.name or not identifier.replace('_', '').isalnum():
            raise ValueError(f'Invalid NPC identity: {manifest}')
        if npc['schema_version'] != 1 or npc['kind'] != 'npc' or npc['canvas'] != [19, 19] or npc['pivot'] != [9, 9]:
            raise ValueError(f'Unsupported NPC manifest: {manifest}')
        portrait = ROOT / npc['portrait']
        dialogue_portrait = ROOT / npc.get('dialogue_portrait', npc['portrait'])
        sheet = ROOT / npc['sprite_preview']['sheet']
        content = json.loads((ROOT / npc['sprite_preview']['metadata']).read_text())
        frames, tags = content['frames'], content['meta']['frameTags']
        if not frames or any(frame.get('trimmed', False) or frame['frame']['w'] != 19 or frame['frame']['h'] != 19 or frame['duration'] <= 0 for frame in frames):
            raise ValueError(f'NPC frames must retain their native 19px canvas: {identifier}')
        for state in npc['visual_states']:
            for direction in 'nesw':
                tag = next((tag for tag in tags if tag['name'] == state['id'] + '_' + direction), None)
                if tag is None or not 0 <= tag['from'] <= tag['to'] < len(frames):
                    raise ValueError(f'Missing or invalid {identifier} {state["id"]}_{direction} tag')
        public_npc = {key: npc[key] for key in ('id', 'name', 'visual_states')}
        payload = {'npc': public_npc, 'sprite': {'frames': frames, 'tags': tags, 'pivot': npc['pivot'], 'image': uri(sheet)}}
        dialogue = ''.join(f'<li><span class="line-number">{index + 1:02}</span><p>{html.escape(line["text"])}</p></li>' for index, line in enumerate(npc['opening']['dialogue']))
        appearance = ''.join(f'<li>{html.escape(note)}</li>' for note in npc['appearance'])
        spoilers = ''.join(f'<li>{html.escape(note)}</li>' for note in npc['design_spoilers'])
        substitutions = {
            '__NAME__': html.escape(npc['name']), '__ROLE__': html.escape(npc['role']),
            '__DESCRIPTION__': html.escape(npc['description']), '__DIALOGUE__': dialogue,
            '__APPEARANCE__': appearance, '__SPOILERS__': spoilers,
            '__PACING__': html.escape(npc['opening']['pacing']),
            '__PAGE_DATA__': json.dumps(payload, separators=(',', ':')).replace('</', '<\\/'),
        }
        page = template
        for key, value in substitutions.items():
            page = page.replace(key, value)
        destination = ASSETS / 'previews/npcs' / identifier
        destination.mkdir(parents=True, exist_ok=True)
        shutil.copy2(portrait, destination / 'portrait.png')
        shutil.copy2(dialogue_portrait, destination / 'dialogue-portrait.png')
        (destination / 'index.html').write_text(page)
        catalog.append({'id': identifier, 'name': npc['name'], 'description': npc['description']})
        print(f'{identifier}: dialogue portrait and original reference, {len(frames)} frames, {len(tags)} tags, {len(npc["opening"]["dialogue"])} opening lines')
    folder = ASSETS / 'previews/npcs'
    folder.mkdir(parents=True, exist_ok=True)
    (folder / 'gallery.json').write_text(json.dumps(catalog, indent=2) + '\n')
    subprocess.run([sys.executable, str(ASSETS / 'pipeline/build-gallery-index.py')], check=True)


if __name__ == '__main__':
    main()

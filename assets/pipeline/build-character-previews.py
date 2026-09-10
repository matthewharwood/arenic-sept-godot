"""Render the eight saved hero sources into source-side galleries. No game exports."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import subprocess

ROSTER = ['hunter','warrior','thief','alchemist','cardinal','bard','forager','merchant']

def uri(path, mime):
    return f'data:{mime};base64,' + base64.b64encode(path.read_bytes()).decode()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--aseprite',default='aseprite')
    parser.add_argument('--hero',choices=ROSTER,action='append')
    args=parser.parse_args()
    assets=Path(__file__).resolve().parents[1]
    review=assets/'previews'; review.mkdir(exist_ok=True)
    audio=json.loads((assets/'audio/events.json').read_text())
    template=(assets/'pipeline/character-preview.html').read_text()
    javascript=(assets/'pipeline/character-preview.js').read_text()
    roster=[json.loads((assets/'characters'/h/'hero.json').read_text()) for h in ROSTER]
    count=0
    for hero in roster:
        if args.hero and hero['id'] not in args.hero: continue
        source_dir=assets/'characters'/hero['id']; dest=review/hero['id']; sheets=dest/'sheets'
        sheets.mkdir(parents=True,exist_ok=True)
        data={}
        for source in sorted(source_dir.rglob('*.aseprite')):
            relative=source.relative_to(source_dir)
            if 'previews' in relative.parts:continue
            key=relative.with_suffix('').as_posix(); stem=key.replace('/','__')
            texture,metadata=sheets/f'{stem}.png',sheets/f'{stem}.json'
            digest=hashlib.sha256(source.read_bytes()).hexdigest(); stamp=sheets/f'{stem}.sha256'
            if not(texture.exists() and metadata.exists() and stamp.exists() and stamp.read_text()==digest):
                result=subprocess.run([args.aseprite,'--batch',str(source),'--sheet-type','horizontal',
                    '--format','json-array','--list-tags','--list-layers','--list-slices',
                    '--sheet',str(texture),'--data',str(metadata)],check=True,capture_output=True,text=True)
                if not texture.exists() or not metadata.exists():raise RuntimeError(result.stdout+result.stderr)
                stamp.write_text(digest)
            content=json.loads(metadata.read_text()); frames=content['frames']; assert frames
            assert all(not f['trimmed'] for f in frames),source
            anchor=next(s for s in content['meta']['slices'] if s['name']=='frame')['keys'][0]['pivot']
            data[key]=dict(source=relative.as_posix(),frames=frames,tags=content['meta']['frameTags'],
                pivot=[anchor['x'],anchor['y']],image=uri(texture,'image/png'))
        for ability in hero['abilities']:
            actor=data[ability['actor'].removesuffix('.aseprite')]
            assert len(actor['frames'])==4*ability['frames_per_direction'],ability['actor']
            for direction in ['n','e','s','w']:
                tag=next(t for t in actor['tags'] if t['name']==ability['id']+'_'+direction)
                assert [f['duration'] for f in actor['frames'][tag['from']:tag['to']+1]]==ability['durations_ms'],ability['actor']
            for fx in ability['fx']:
                s=data[fx['source'].removesuffix('.aseprite')]
                assert any(t['name']==fx['tag'] for t in s['tags']),(hero['id'],fx)
            ability['sounds']={}
            for phase,cue in audio['events'][hero['id']+'.'+ability['id']]['phases'].items():
                ability['sounds'][phase]={**cue,'url':uri(assets/'audio'/cue['file'],'audio/mpeg') if cue['status']=='ready' else None}
        hero['portrait_image']=uri(assets.parent/hero['portrait'],'image/png')
        payload=dict(hero=hero,sprites=data,roster=[dict(id=h['id'],name=h['name']) for h in roster])
        page=template.replace('__PAGE_DATA__',json.dumps(payload).replace('</','<\\/')).replace('__PREVIEW_JS__',javascript)
        (dest/'attacks.html').write_text(page)
        (dest/'attacks.htm').write_text('<!doctype html><meta http-equiv="refresh" content="0;url=attacks.html"><a href="attacks.html">Open ability preview</a>')
        (dest/'source-manifest.json').write_text(json.dumps({k:{p:v for p,v in s.items() if p!='image'} for k,s in data.items()},indent=2)+'\n')
        count+=len(data)
        print(f"{hero['id']}: {len(data)} native sources / four ability scenes")
    subprocess.run([args.aseprite,'--batch','--script',str(assets/'pipeline/build-roster-preview.lua')],cwd=assets.parent,check=True,capture_output=True,text=True)
    nav=''.join(f'<a href="{h["id"]}/attacks.html"><div class="visual"><img src="{uri(assets.parent/h["portrait"],"image/png")}" alt=""><img class="sprite" src="{uri(review/h["id"]/"idle.png","image/png")}" alt="19 pixel overhead sprite"></div><strong>{h["name"]}</strong><span>'+ ' · '.join(a['name'] for a in h['abilities'])+'</span></a>' for h in roster)
    (review/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Arenic · Hero ability studies</title><style>body{font:16px/1.5 system-ui;background:oklch(.15 .018 150);color:oklch(.93 .016 110);max-width:1100px;margin:40px auto;padding:24px}h1{font-size:36px;margin:0}p{color:oklch(.73 .025 150)}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:16px}a{color:inherit;text-decoration:none;background:oklch(.22 .025 150);padding:20px;border:1px solid oklch(.34 .025 150);border-radius:10px;display:flex;flex-direction:column;gap:9px}a:hover{border-color:oklch(.75 .1 145)}img{width:100%;height:170px;object-fit:contain}.visual{display:flex;align-items:center;gap:12px}.visual>img{width:65%}.visual>.sprite{width:76px;height:76px;image-rendering:pixelated}strong{font-size:21px}span{font-size:13px;color:oklch(.76 .025 150)}</style><h1>Eight heroes. One grid.</h1><p>32 base abilities · 19×19 overhead characters · 720p arena previews<br>Choose a hero to inspect all four animations and their sound cues.</p><main>'''+nav+'</main></html>')
    (review/'attacks.html').write_text('<!doctype html><meta http-equiv="refresh" content="0;url=hunter/attacks.html"><a href="hunter/attacks.html">Hunter ability preview</a>')
    # Preserve the previously shared file path with navigation relative to its older location.
    hunter_page=review/'hunter/attacks.html'
    if hunter_page.exists():
        legacy=assets/'characters/hunter/previews/attacks.html'
        legacy.write_text(hunter_page.read_text().replace('data-prefix=".."','data-prefix="../../../previews"'))
    print(f'{count} source previews rendered. Gallery: {review / "index.html"}')
    subprocess.run(['python3',str(assets/'pipeline/build-gallery-index.py')],check=True)

if __name__=='__main__':main()

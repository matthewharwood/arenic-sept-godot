"""Build the shared Heroes / Bosses entry points from saved manifests and previews."""
import base64
import html
import json
from pathlib import Path

ASSETS = Path(__file__).resolve().parents[1]
ROSTER = ['hunter', 'warrior', 'thief', 'alchemist', 'cardinal', 'bard', 'forager', 'merchant']
STYLE = '''body{font:16px/1.5 system-ui;background:oklch(.15 .018 150);color:oklch(.93 .016 110);max-width:1200px;margin:32px auto;padding:24px}h1{font-size:36px;line-height:1.2;margin:18px 0 8px}p{color:oklch(.73 .025 150)}nav{display:flex;gap:10px;margin-bottom:25px}a{color:inherit;text-decoration:none}nav a{padding:8px 20px;border:1px solid oklch(.35 .03 150);border-radius:7px}nav a[aria-current]{background:oklch(.36 .06 150)}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:16px}.card{background:oklch(.22 .025 150);padding:20px;border:1px solid oklch(.34 .025 150);border-radius:10px;display:flex;flex-direction:column;gap:9px}.card:hover{border-color:oklch(.75 .1 145)}.visual{display:flex;align-items:center;gap:10px;min-height:210px}.portrait{width:65%;height:210px;object-fit:contain;background:oklch(1 0 0);border-radius:6px}.sprite{width:76px;height:76px;image-rendering:pixelated}.boss-portrait{width:100%;height:290px;object-fit:contain;background:oklch(1 0 0);border-radius:6px}strong{font-size:21px}span{font-size:13px;color:oklch(.76 .025 150)}.eyebrow{font-size:11px;letter-spacing:.15em;text-transform:uppercase;color:oklch(.78 .095 135)}'''


def uri(path):
    return 'data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode()


def page(kind):
    is_boss = kind == 'bosses'
    prefix = '../' if is_boss else ''
    cards = []
    for identifier in ROSTER:
        manifest = ASSETS/('bosses' if is_boss else 'characters')/identifier/('boss.json' if is_boss else 'hero.json')
        if not manifest.exists():
            continue
        spec = json.loads(manifest.read_text())
        if is_boss:
            if not (ASSETS/'previews/bosses'/identifier/'attacks.html').exists():
                continue
            visual = f'<img class="boss-portrait" src="{identifier}/portrait.png" alt="{html.escape(spec["name"])} boss portrait">'
            description = spec['description']
        else:
            visual = f'<div class="visual"><img class="portrait" src="{uri(ASSETS.parent/spec["portrait"])}" alt=""><img class="sprite" src="{identifier}/idle.png" alt="19 pixel overhead sprite"></div>'
            description = ' · '.join(a['name'] for a in spec['abilities'])
        cards.append(f'<a class="card" href="{identifier}/attacks.html">{visual}<strong>{html.escape(spec["name"])}</strong><span>{html.escape(description)}</span></a>')
    title = 'Eight bosses. One arena.' if is_boss else 'Eight heroes. One grid.'
    sub = 'Portraits and overhead idle studies · 114 × 114 pixels · six-tile footprint<br>Choose a boss to inspect its forms, four directions, and size beside a hero.' if is_boss else '32 base abilities · 19 × 19 overhead characters · 720p arena previews<br>Choose a hero to inspect all four animations and their sound cues.'
    current_hero = '' if is_boss else ' aria-current="page"'
    current_boss = ' aria-current="page"' if is_boss else ''
    return f'<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Arenic · {kind.title()}</title><style>{STYLE}</style><nav aria-label="Character type"><a href="{prefix}index.html"{current_hero}>Heroes</a><a href="{prefix}bosses/index.html"{current_boss}>Bosses</a></nav><div class="eyebrow">Arenic / Character studies</div><h1>{title}</h1><p>{sub}</p><main>'+''.join(cards)+'</main></html>'


if __name__ == '__main__':
    (ASSETS/'previews/index.html').write_text(page('heroes'))
    (ASSETS/'previews/bosses').mkdir(exist_ok=True)
    (ASSETS/'previews/bosses/index.html').write_text(page('bosses'))
    print('Built Heroes / Bosses gallery entry points.')

"""Classify documented ability composition. This does not simulate combat."""
import json
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
ABILITIES = {a['id'] for a in json.loads((ROOT / 'data/abilities.json').read_text())}
GROUPS = [
    ('P01', {'shadow_step', 'poison_shot'}),
    ('P02', {'acid_flask'}),
    ('P03', {'dig', 'bolder', 'border', 'mushroom', 'transmute', 'coin_toss', 'pickpocket'}),
    ('P04', {'cleanse', 'barrier', 'beam', 'resurrect', 'mushroom', 'siphon', 'helix'}),
    ('P05', {'block', 'bulwark', 'taunt', 'ironskin_draft', 'border', 'smoke_screen'}),
    ('P06', {'mimic'}),
    ('P07', {'dice', 'vault', 'helix'}),
    ('P08', {'poison_shot', 'acid_flask', 'heal', 'cleanse', 'mushroom', 'helix', 'dig', 'fortune'}),
]
def classify(first, second, arena):
    if first not in ABILITIES or second not in ABILITIES:
        raise ValueError('Unknown ability ID')
    arenas = {s['arena'] for s in json.loads((ROOT / 'data/scores.json').read_text())}
    if arena not in arenas:
        raise ValueError('Unknown arena ID')
    pair = {first, second}
    return [rule for rule, group in GROUPS if pair & group] + ['P09', 'P10']
if __name__ == '__main__':
    if len(sys.argv) != 4:
        raise SystemExit('Usage: python3 pair_rules.py ABILITY ABILITY ARENA')
    print(json.dumps({'rules': classify(*sys.argv[1:]), 'meaning': 'See INTERACTIONS.md; structural classification only.'}, indent=2))

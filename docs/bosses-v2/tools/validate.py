"""Validate the design corpus and conservative solo walking witnesses.

This is a documentation/data validator, not the Godot combat implementation.
"""
import hashlib
import itertools
import json
import sys
from collections import Counter
from pathlib import Path
sys.dont_write_bytecode = True
from pair_rules import classify
ROOT = Path(__file__).resolve().parents[1]
scores = json.loads((ROOT / 'data/scores.json').read_text())
abilities = json.loads((ROOT / 'data/abilities.json').read_text())
coverage = json.loads((ROOT / 'data/ability-coverage.json').read_text())

def cells(rect):
    x, y, w, h = rect
    return {(xx, yy) for xx in range(x, x+w) for yy in range(y, y+h)}

def rear(pose):
    x, y = pose['origin']
    return {'n': (x, y-1), 's': (x, y+6), 'e': (x-1, y), 'w': (x+6, y)}[pose['facing']]

def route(score):
    # Conservative: all impact-duration masks are unsafe, including between pulses.
    # Ignore portals, attunement, protection and free cover; ordinary cardinal steps only.
    # One tile each 15 ticks is a planning pace, not a runtime movement-cap claim.
    obstacles = [(e['at_tick'], e['end_tick'], set().union(*(cells(r) for r in e['masks'])))
                 for e in score['events'] if e['kind'] != 'window']
    poses = score['pose_track']
    for i, p in enumerate(poses):
        obstacles.append((p['tick'], poses[i+1]['tick'] if i+1 < len(poses) else 7200,
                          cells([*p['origin'], 6, 6])))
    checkpoints = {p['tick']+90: rear(p) for p in poses[1:]}
    required = {}
    for tick, cell in checkpoints.items():
        for t in range(tick, tick+75, 15): required[t] = cell
    start = (29, 2)
    required[7185] = start
    reachable = {start}
    parents = []
    for t in range(0, 7200, 15):
        blocked = set()
        for begin, end, occupied in obstacles:
            if begin < t+15 and end > t:
                blocked.update(occupied)
        new = {}
        for old in sorted(reachable):
            x, y = old
            for cell in [old, (x-1,y), (x+1,y), (x,y-1), (x,y+1)]:
                xx, yy = cell
                if 0 <= xx < 66 and 0 <= yy < 31 and cell not in blocked:
                    if t not in required or cell == required[t]:
                        new.setdefault(cell, old)
        assert new, f"No conservative walking path: {score['id']} at {t}"
        parents.append(new)
        reachable = set(new)
    cell = start
    path = []
    for k in range(len(parents)-1, -1, -1):
        path.append({'tick': k*15, 'cell': list(cell)})
        cell = parents[k][cell]
    path.reverse()
    compressed = [p for i,p in enumerate(path) if i == 0 or p['cell'] != path[i-1]['cell']]
    # Independent readback of the chosen path against event geometry.
    for point in path:
        t = point['tick']; cell = tuple(point['cell'])
        for begin, end, occupied in obstacles:
            assert not (begin < t+15 and end > t and cell in occupied)
        if t in required: assert cell == required[t]
    return {'arena':score['arena'], 'start':list(start), 'planning_step_ticks':15,
            'checked_intervals':len(path), 'checkpoint_rears':[
                {'tick':t,'cell':list(c)} for t,c in checkpoints.items()],
            'movement_witness':compressed,
            'scope':'Zero-hazard solo cardinal route with 75-tick rear dwells. No casts, bonuses, friendly fields, portals or other heroes simulated.'}

def validate():
    assert len(scores) == 8 and len(abilities) == 32
    ids = {a['id'] for a in abilities}
    assert len(ids) == 32
    assert len(coverage) == 256
    assert {(r['boss'],r['ability']) for r in coverage} == {(s['id'],a) for s in scores for a in ids}
    assert all(r['rating'] in ['+','=','-'] and len(r['interaction']) > 40 for r in coverage)
    witnesses=[]
    perimeter = {(x,y) for x in range(66) for y in range(31) if x < 2 or x > 63 or y < 2 or y > 28}
    slots = {(3+3*i,y) for i in range(20) for y in [2,28]}
    assert len(slots) == 40
    for s in scores:
        assert s['cycle_ticks'] == 7200 and len(s['actions']) >= 4
        action_ids = {a['id'] for a in s['actions']}
        assert len(action_ids) == len(s['actions']) == 6
        assert len({e['event_id'] for e in s['events']}) == len(s['events']) == 25
        assert s['events'] == sorted(s['events'], key=lambda e:(e['at_tick'],e['event_id']))
        assert s['pose_track'][0]['origin'] == s['pose_track'][-1]['origin']
        assert s['pose_track'][0]['facing'] == s['pose_track'][-1]['facing']
        for p in s['pose_track']:
            x,y=p['origin'];assert 0<=x<=60 and 0<=y<=25
            assert not (cells([x,y,6,6]) & slots)
        for e in s['events']:
            assert e['action'] in action_ids
            assert 0 <= e['cue_tick'] < e['at_tick'] < e['end_tick'] <= 7200
            assert e['at_tick']-e['cue_tick'] >= (180 if e['kind']=='terrain' or e['damage']==4 or 'boss_origin' in e else 120)
            assert all(isinstance(e[k],int) for k in ['cue_tick','at_tick','end_tick','damage'])
            if e['kind']!='window':assert e['at_tick']>=360 and e['end_tick']<=6840
            for rect in e['masks']:
                x,y,w,h=rect;assert w>0 and h>0 and 0<=x<x+w<=66 and 0<=y<y+h<=31
                assert not cells(rect)&perimeter
                assert not cells(rect)&slots
        for e in s['events']:
            if 'boss_origin' in e:
                pose = next(p for p in s['pose_track'] if p['tick'] == e['at_tick'])
                assert pose['origin'] == e['boss_origin'] and pose['facing'] == e['boss_facing']
            if 'mask_elements' in e:
                assert len(e['mask_elements']) == len(e['masks'])
                assert set(e['mask_elements']) <= {'sun', 'moon'}
            if 'pulse_offsets' in e:
                assert all(0 <= t < e['end_tick']-e['at_tick'] for t in e['pulse_offsets'])
            if e['kind'] == 'window':
                assert e['window_condition'] in {
                    'first_direct_hit', 'clean_phrase_direct_hit', 'portal_interval',
                    'portal_success_direct_hit', 'prepared_periodic_hit',
                    'matched_attunement_direct_hit', 'three_floor_steps_direct_hit',
                    'prepared_ground_tick', 'dividend_pad_direct_hit'}
            for key in ['active_pad', 'dividend_pad']:
                if key in e:
                    x,y,w,h=e[key]
                    assert w>0 and h>0 and 0<=x<x+w<=66 and 0<=y<y+h<=31
        for cell in s.get('font_cells', {}).values():
            assert all(tuple(cell) not in cells(rect) for e in s['events'] for rect in e['masks'])
        witnesses.append(route(s))
    rule_counts=Counter()
    for s,a,b in itertools.product(scores,sorted(ids),sorted(ids)):
        found=classify(a,b,s['arena']); assert len(found)==len(set(found)) and 'P10' in found
        rule_counts.update(found)
    classes=sorted({a['hero'] for a in abilities}); assert len(classes)==8
    starters={a['hero']:a['id'] for a in abilities if a['status']=='live'}
    subsets=0
    for s in scores:
        for mask in range(1,256):
            group=[classes[i] for i in range(8) if mask & (1<<i)]
            assert all(c in starters for c in group)
            assert all(any(r['boss']==s['id'] and r['ability']==starters[c] for r in coverage) for c in group)
            subsets+=1
    weights=[2,2,2,2,2,1,2,2]
    unions={s['id']:set().union(*(cells(r) for e in s['events'] if e['kind']!='window' for r in e['masks'])) for s in scores}
    ratings={s['id']:{r['ability']:{'-':-1,'=':0,'+':1}[r['rating']] for r in coverage if r['boss']==s['id']} for s in scores}
    distances=[]
    for a,b in itertools.combinations(scores,2):
        behavior=sum(w*abs(x-y) for w,x,y in zip(weights,a['features'],b['features']))/(4*sum(weights))
        ua,ub=unions[a['id']],unions[b['id']]
        spatial=1-len(ua&ub)/len(ua|ub)
        role=sum(abs(ratings[a['id']][k]-ratings[b['id']][k]) for k in ids)/(2*len(ids))
        total=.55*behavior+.25*spatial+.20*role
        distances.append(dict(first=a['id'],second=b['id'],behavior=round(behavior,4),spatial=round(spatial,4),ability_fit=round(role,4),distance=round(total,4)))
    corpus=json.loads((ROOT/'data/research-corpus.json').read_text())
    report=dict(status='PASS',scope='Static documentation/data validation and conservative solo navigation only; not Godot gameplay or balance validation.',
                encounters=8,unique_moves=48,events=sum(len(s['events']) for s in scores),ability_boss_cells=256,
                ordered_pair_classifications=8192,class_subset_checks=subsets,
                pair_rule_counts=dict(rule_counts),walking_intervals=sum(w['checked_intervals'] for w in witnesses),
                research_module_count=len(corpus['encounters']),distance_pairs=distances,
                minimum_distance=min(d['distance'] for d in distances),
                input_sha256={name:hashlib.sha256((ROOT/'data'/name).read_bytes()).hexdigest() for name in ['scores.json','abilities.json','ability-coverage.json','research-corpus.json']})
    (ROOT/'data/validation.json').write_text(json.dumps(report,indent=2)+'\n')
    (ROOT/'data/walking-witnesses.json').write_text(json.dumps(witnesses,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ['input_sha256','distance_pairs','pair_rule_counts']},indent=2))
if __name__=='__main__':validate()

"""Prepare stable audio events and the resumable ElevenLabs request queue; never generates audio."""
import json
from pathlib import Path

ASSETS = Path(__file__).resolve().parents[1]
ROSTER = ['hunter','warrior','thief','alchemist','cardinal','bard','forager','merchant']
STYLE = ('Compact fantasy tactical game sound, dry close recording, clear at low volume, '
         'controlled transients and soft high frequencies, centered mono-compatible, '
         'no speech, no background music, no environmental ambience, no long reverb. '
         'Keep instrument gestures brief when musically themed. ')

# These are staged gallery contacts, not changes to ability cast or hit rules.
PREVIEW_START_OVERRIDES = {
    'bard.dance': {'cast': 0},
    'forager.dig': {'cast': 0},
    'forager.border': {'impact': 2500},
    'merchant.dice': {'impact': 500},
    'merchant.vault': {'impact': 1200},
    'thief.smoke_screen': {'impact': 700},
    'warrior.bulwark': {'impact': 500},
}

# The authored lower/release phases occupy the final two actor frames. Reserve
# their actual manifest duration, matching the gallery's channel exit timing.
HELD_RELEASE_FRAMES = {'warrior.block': 2, 'alchemist.siphon': 2, 'cardinal.heal': 2}

# Each existing sustain brief was reviewed for what is actually sounding.
# A travel, performance, or held-channel loop must not default to impact time.
SUSTAIN_MEANINGS = {
    'hunter.poison_shot': 'Venom status after the arrow hits; shortened preview of the game-owned status.',
    'warrior.block': 'Shield holding from activation until the lowering gesture starts.',
    'warrior.bulwark': 'Protective wall resonance from immediate activation, including the staged absorbed hit.',
    'thief.smoke_screen': 'Active redirection vortex; the separate reversal sound marks a staged interaction.',
    'alchemist.acid_flask': 'Bubbling acid pool after the flask lands, not the flying glass flask.',
    'alchemist.ironskin_draft': 'Instant self-protection shimmer; drinking art adds no activation delay.',
    'alchemist.siphon': 'Ally-to-Alchemist life drain after setup, ending when the held channel releases.',
    'cardinal.heal': 'Current starter: outward sacrificial damage channel until release; no restoration or spoken prayer.',
    'cardinal.barrier': 'One selected ally\'s protective shell from instant application.',
    'cardinal.resurrect': 'Enhanced-vision harmony after revival resolves, not the two-second charge.',
    'bard.dance': 'The successful eight-beat performance itself, ending before the finale.',
    'bard.helix': 'This watery regeneration brief belongs only to regeneration mode, not haste.',
    'forager.bolder': 'Rolling stone travel; stop at collision before the impact/debris tail.',
    'forager.border': 'The living barrier after its cast completes, including a later staged deflection.',
    'forager.mushroom': 'Combined resource-absorption/healing sound during staged feeding of a grown node only.',
    'merchant.fortune': 'Current starter: active golden aura; impact is a real damage tick, never a currency payout.',
    'merchant.vault': 'Vault-zone resonance from immediate activation; opening art adds no buff delay.',
}


def preview_timing(ability_id, ability):
    """Return illustrative, end-exclusive gallery cue windows in milliseconds.

    Audio generation duration remains independent. A window can stop an asset
    early, particularly a charge at release or a rolling sound at collision.
    These windows never prescribe runtime cooldowns, state expiry, or hit timing.
    """
    preview = ability['preview']
    end = preview['duration_ms']
    release = ability['release_ms']
    impact = preview['impact_ms']
    starts = {'charge': 0, 'cast': release, 'impact': impact,
              'sustain': impact, 'end': end}
    starts.update(PREVIEW_START_OVERRIDES.get(ability_id, {}))
    sustain_end = end
    notes = []
    conditions = {}

    if 'sustain' in ability['audio']:
        notes.append(SUSTAIN_MEANINGS[ability_id])
    if ability_id in HELD_RELEASE_FRAMES:
        release_frames = HELD_RELEASE_FRAMES[ability_id]
        sustain_end = end - sum(ability['durations_ms'][-release_frames:])
        starts['sustain'] = release
    elif ability_id == 'forager.bolder':
        starts['sustain'], sustain_end = release, impact
    elif ability_id == 'bard.dance':
        starts['sustain'], sustain_end = 0, release
    elif ability_id in {'warrior.bulwark', 'thief.smoke_screen',
                        'merchant.vault'}:
        starts['sustain'] = release
    elif ability_id == 'forager.border':
        starts['sustain'] = release
    elif ability_id == 'forager.mushroom':
        # The gallery's feeding link lasts 1000 ms. The brief combines resource
        # intake and healing, so do not imply continued feeding after it ends.
        starts['sustain'] = release
        sustain_end = min(end, release + 1000)
        grown = {'control': 'growth', 'values': ['sprout', 'young', 'mature', 'ancient']}
        conditions.update(impact=grown, sustain=grown)
        notes.append('Seed mode plays only planting; growth/healing requires resource investment.')
    if ability_id == 'bard.helix':
        conditions['sustain'] = {'control': 'helix-state', 'values': ['regeneration']}
    if ability_id == 'bard.mimic':
        notes.append('The first 500 ms demonstrates passive copy latency after an ally action, not a player cast wind-up.')
    if ability_id in PREVIEW_START_OVERRIDES:
        notes.append('Cue starts follow the staged action represented by each sound, not phase names alone.')

    windows = {}
    for phase, cue in ability['audio'].items():
        start = starts[phase]
        if phase == 'charge':
            stop = release
        elif phase == 'sustain':
            stop = sustain_end
        else:
            stop = min(end, start + round(cue['duration_seconds'] * 1000))
        assert isinstance(start, int) and isinstance(stop, int)
        assert 0 <= start < stop <= end, f'Invalid preview window: {ability_id}.{phase}'
        windows[phase] = dict(start_ms=start, end_ms=stop)
        if phase in conditions:
            windows[phase]['condition'] = conditions[phase]
    return dict(illustrative=True, duration_ms=end, notes=notes), windows


def request_text(description):
    text = STYLE + description
    if len(text) > 450:
        text = ('Dry, compact fantasy tactical-game sound. Controlled transients, restrained highs, '
                'mono-compatible, no speech, music, ambience, or long reverb. ') + description
    assert len(text) <= 450, 'ElevenLabs sound effects prompts allow at most 450 characters'
    return text


def main():
    audio = ASSETS / 'audio'
    audio.mkdir(exist_ok=True)
    queue, events = [], {}
    for hero in ROSTER:
        manifest = json.loads((ASSETS / 'characters' / hero / 'hero.json').read_text())
        for ability in manifest['abilities']:
            assert set(ability['audio']).issubset({'charge','cast','impact','sustain','end'})
            assert {'cast','impact'} <= set(ability['audio'])
            ability_id = f"{hero}.{ability['id']}"
            preview, windows = preview_timing(ability_id, ability)
            phases = {}
            for phase, cue in ability['audio'].items():
                event = f'{ability_id}.{phase}'
                relative = f"abilities/{hero}/{ability['id']}/{phase}_01.mp3"
                provenance = audio / relative.replace('.mp3', '.generation.json')
                ready = (audio / relative).is_file() and provenance.is_file()
                item = dict(event=event, hero=hero, ability=ability['id'], slot=ability['slot'],
                            phase=phase, file=relative, status='ready' if ready else 'pending',
                            loop=bool(cue.get('loop')), duration_seconds=cue['duration_seconds'],
                            text=request_text(cue['description']), output_format='mp3_44100_128',
                            output_directory=str(audio / 'generation' / hero / ability['id'] / phase))
                assert .5 <= item['duration_seconds'] <= 5
                queue.append(item)
                phases[phase] = dict(event=event, file=relative, status=item['status'],
                                     loop=item['loop'], variant='01',
                                     preview_window=windows[phase])
            events[ability_id] = dict(slot=ability['slot'], name=ability['name'],
                                     phases=phases, preview=preview)
    (audio/'generation-queue.json').write_text(json.dumps(queue,indent=2)+'\n')
    (audio/'events.json').write_text(json.dumps(dict(version=1,provider='ElevenLabs',
        format='mp3_44100_128', preview_timing=dict(
            clock='milliseconds from the start of one illustrative gallery cycle',
            interval='start_ms inclusive; end_ms exclusive',
            playback='Automatic previews trigger at start_ms and stop at end_ms; conditions require the matching control value.',
            scope='Preview excerpts only, not runtime ability durations or cooldowns.'),
        events=events),indent=2)+'\n')
    counts={status:sum(c['status']==status for c in queue) for status in ['ready','pending']}
    print(json.dumps(dict(abilities=len(events),cues=len(queue),**counts)))

if __name__ == '__main__':
    main()

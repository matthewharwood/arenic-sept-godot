"""Decode authorized ElevenLabs originals to bounded mono runtime WAVs.

python3 assets/pipeline/export-starter-audio.py
Use --event shared.move for an incremental export. Source MP3s are never modified.
Requires ffmpeg; export is deterministic for the recorded decoder version.
"""
import argparse
import array
import hashlib
import json
import math
import re
from pathlib import Path
import struct
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / 'assets/audio'
RUNTIME = ROOT / 'arenic-game/assets/audio/sfx'
RATE = 44100
IMPORT_OPTIONS = {'force/8_bit': 'false', 'force/mono': 'false', 'force/max_rate': 'false',
                  'edit/trim': 'false', 'edit/normalize': 'false', 'edit/loop_mode': '0',
                  'edit/loop_begin': '0', 'edit/loop_end': '-1', 'compress/mode': '0'}


def preserve_import(path):
    text = path.read_text() if path.exists() else '[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\n'
    if '[params]' not in text: text += '\n[params]\n'
    for key, value in IMPORT_OPTIONS.items():
        pattern = r'^' + re.escape(key) + r'=.*$'
        if re.search(pattern, text, re.M): text = re.sub(pattern, key + '=' + value, text, flags=re.M)
        else: text += key + '=' + value + '\n'
    write_changed(path, text.encode())


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write_changed(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def export(row, decoder):
    source = AUDIO / row['file']
    provenance = source.with_suffix('.generation.json')
    if not source.is_file() or not provenance.is_file():
        raise RuntimeError('Missing generated audio/provenance: ' + row['event'])
    record = json.loads(provenance.read_text())
    if record['provider'] != 'ElevenLabs' or record['status'] != 'generated':
        raise RuntimeError('Unexpected audio provenance: ' + row['event'])
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(source), '-vn', '-ac', '1', '-ar', str(RATE), '-f', 'f32le', '-'], capture_output=True, check=True).stdout
    samples = array.array('f'); samples.frombytes(raw)
    if sys.byteorder != 'little': samples.byteswap()
    if not samples or not all(math.isfinite(x) for x in samples):
        raise RuntimeError('Invalid decoded PCM: ' + row['event'])
    decoded_frames = len(samples)
    required = round(row['duration_seconds'] * RATE)
    samples = list(samples[:required]) + [0.0] * max(0, required - len(samples))
    onset_trim_frames = 0
    if row['phase'] == 'charge':
        # A 260 ms gameplay charge must not spend most of its window in provider
        # preroll. Locate meaningful energy in 5 ms blocks, retain one block of
        # natural lead-in, and pad the tail to preserve the exact 500 ms asset.
        block = round(.005 * RATE)
        windows = [math.sqrt(sum(x*x for x in samples[i:i+block]) / len(samples[i:i+block])) for i in range(0, len(samples), block)]
        threshold = max(windows) * .1
        onset = next((i * block for i, value in enumerate(windows) if value >= threshold), 0)
        onset_trim_frames = max(0, onset - block)
        if onset_trim_frames < round(.02 * RATE): onset_trim_frames = 0
        if onset_trim_frames:
            samples = samples[onset_trim_frames:] + [0.0] * onset_trim_frames
    mean = sum(samples) / len(samples)
    samples = [x - mean for x in samples]
    peak = max(abs(x) for x in samples)
    if peak < 0.0001:
        raise RuntimeError('Silent generation: ' + row['event'])
    fade_in = round(.003 * RATE); fade_out = round(.02 * RATE)
    crossfade = round(.06 * RATE) if row['loop'] else 0
    if row['loop']:
        # Rotate the loop start past its first 60 ms and overlap that head with
        # the tail. The final boundary resumes adjacent source samples, without
        # fading to silence, padding a loop, or changing its playback pitch.
        if decoded_frames < required:
            raise RuntimeError('Loop source shorter than requested duration')
        blend = [samples[-crossfade + i] * (1.0 - i / (crossfade - 1)) + samples[i] * (i / (crossfade - 1)) for i in range(crossfade)]
        samples = samples[crossfade:-crossfade] + blend
    else:
        for i in range(fade_in): samples[i] *= i / (fade_in - 1)
        for i in range(fade_out): samples[-fade_out + i] *= 1.0 - i / (fade_out - 1)
    peak = max(abs(x) for x in samples)
    rms = math.sqrt(sum(x*x for x in samples) / len(samples))
    target_rms = .035 if row['loop'] or row['event'] == 'shared.move' else .05
    ceiling = .18 if row['loop'] or row['event'] == 'shared.move' else .25
    max_gain = 16.0 if row['phase'] == 'charge' else 4.0
    gain = min(ceiling / peak, target_rms / max(rms, 1e-9), max_gain)
    pcm = array.array('h', (round(max(-1.0, min(1.0, x * gain)) * 32767) for x in samples))
    floats = [x / 32768.0 for x in pcm]
    if sys.byteorder != 'little': pcm.byteswap()
    pcm_bytes = pcm.tobytes()
    fmt = struct.pack('<HHIIHH', 1, 1, RATE, RATE * 2, 2, 16)
    chunks = b'fmt ' + struct.pack('<I', len(fmt)) + fmt + b'data' + struct.pack('<I', len(pcm_bytes)) + pcm_bytes
    if row['loop']:
        # WAV sampler metadata: one forward loop, inclusive end frame.
        sampler = struct.pack('<9I', 0, 0, round(1e9 / RATE), 60, 0, 0, 0, 1, 0)
        sampler += struct.pack('<6I', 0, 0, 0, len(pcm) - 1, 0, 0)
        chunks += b'smpl' + struct.pack('<I', len(sampler)) + sampler
    wav = b'RIFF' + struct.pack('<I', len(chunks) + 4) + b'WAVE' + chunks
    relative = Path(row['ability']) / (row['phase'] + '.wav')
    destination = RUNTIME / relative
    preserve_import(destination.with_suffix(".wav.import"))
    write_changed(destination, wav)
    with wave.open(str(destination)) as check:
        assert check.getnchannels() == 1 and check.getsampwidth() == 2
        assert check.getframerate() == RATE and check.getnframes() == len(pcm)
    output = dict(event=row['event'], source=source.relative_to(ROOT).as_posix(), source_sha256=digest(source.read_bytes()), provenance=provenance.relative_to(ROOT).as_posix(), runtime='res://assets/audio/sfx/' + relative.as_posix(), runtime_sha256=digest(wav), sample_rate=RATE, channels=1, sample_format='signed PCM16 little endian', frames=len(pcm), duration_seconds=len(pcm)/RATE, loop=row['loop'], loop_begin_frame=0, loop_end_frame_exclusive=len(pcm) if row['loop'] else 0, processing=dict(decoder=decoder, decoded_frames=decoded_frames, requested_duration_seconds=row['duration_seconds'], dc_removed=mean, gain=gain, maximum_gain=max_gain, onset_trim_frames=onset_trim_frames, charge_onset_window_frames=round(.005 * RATE) if row['phase'] == 'charge' else 0, charge_onset_relative_rms_threshold=.1 if row['phase'] == 'charge' else 0.0, fade_in_frames=0 if row['loop'] else fade_in, fade_out_frames=0 if row['loop'] else fade_out, circular_crossfade_frames=crossfade), peak_dbfs=20*math.log10(max(abs(x) for x in floats)), rms_dbfs=20*math.log10(math.sqrt(sum(x*x for x in floats)/len(floats))), boundary_delta=abs(floats[-1]-floats[0]))
    assert output['peak_dbfs'] <= -12.0 and any(pcm)
    return output


def main():
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--event', action='append'); args=parser.parse_args()
    plan=json.loads((AUDIO/'starter-generation-plan.json').read_text())['clips']
    selected=[r for r in plan if not args.event or r['event'] in args.event]
    decoder=subprocess.run(['ffmpeg','-version'],capture_output=True,text=True,check=True).stdout.splitlines()[0]
    path=AUDIO/'starter-runtime-manifest.json'
    existing=json.loads(path.read_text()).get('clips',[]) if path.exists() else []
    records={r['event']:r for r in existing}
    for row in selected:
        records[row['event']]=export(row,decoder)
        r=records[row['event']]; print(f"{row['event']}: {r['duration_seconds']:.3f}s mono, peak {r['peak_dbfs']:.1f} dBFS, loop={r['loop']}")
    manifest=dict(version=1, provider='ElevenLabs', exporter='assets/pipeline/export-starter-audio.py', scope='Only 22 authorized starter/shared cues; generated MP3 originals preserved.', required_import_options=IMPORT_OPTIONS, clips=[records[r['event']] for r in plan if r['event'] in records])
    write_changed(path,(json.dumps(manifest,indent=2)+'\n').encode())


if __name__ == '__main__': main()

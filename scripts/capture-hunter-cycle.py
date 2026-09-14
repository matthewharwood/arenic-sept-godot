#!/usr/bin/env python3
"""Play the frozen Hunter seed v1 or film capture v2 in a disposable Godot project.

The native MovieWriter renders every frame at the simulation's 60 Hz. The MP4
contains only the requested cycle: startup loading/warmup frames are trimmed.
Neither the editor's import cache nor the player's save directories are used.
"""

import argparse
from fractions import Fraction
import hashlib
import importlib.util
from itertools import accumulate
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FPS = 60
MIX_RATE = 48000
CAPTURE_VERSION = 2
CAPTURE_ID = f"hunter-full-arena-v{CAPTURE_VERSION}"
SEED_ID = "hunter-full-arena-v1"
COUNTDOWN_SECONDS = 3
FORWARD_SECONDS = 120
REWIND_SECONDS = 5
PHASES = ("initial_countdown", "play", "rewind", "final_countdown", "complete")
PHASE_FRAMES = tuple(accumulate(
    (seconds * FPS for seconds in (COUNTDOWN_SECONDS, FORWARD_SECONDS, REWIND_SECONDS, COUNTDOWN_SECONDS)),
    initial=0,
))
CYCLE_FRAMES = PHASE_FRAMES[-1]
CYCLE_SECONDS = CYCLE_FRAMES // FPS
MOVIE = f"{CAPTURE_ID}.mp4"
SIZE = [1280, 720]


def execute(command, log, timeout=900):
    print(f"Running {log.name}", flush=True)
    with log.open("w") as output:
        result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT,
                                env={**os.environ, "NO_COLOR": "1"}, timeout=timeout)
    content = log.read_text(errors="replace")
    if result.returncode or re.search(r"SCRIPT ERROR|SHADER ERROR|(?:^|\n)\s*ERROR:", content):
        raise RuntimeError(f"{log}:\n{content[-9000:]}")


def probe(path, *, count_frames=False):
    return json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", *(["-count_frames"] if count_frames else []),
        "-show_streams", "-show_format", "-of", "json", str(path)
    ], text=True))


def media_streams(metadata):
    video = next(stream for stream in metadata["streams"] if stream["codec_type"] == "video")
    audio = next(stream for stream in metadata["streams"] if stream["codec_type"] == "audio")
    if ([video["width"], video["height"]] != SIZE
            or Fraction(video["r_frame_rate"]) != FPS
            or int(audio["sample_rate"]) != MIX_RATE or int(audio["channels"]) != 2):
        raise RuntimeError(f"Expected 1280x720 at60fps with 48kHz stereo: {metadata}")
    return video, audio


def trim_bounds(result, total_frames, smoke_seconds):
    start = int(result["start_frame"])
    end = int(result["end_frame"])
    frames = int(result["frames"])
    expected = max(1, math.floor(smoke_seconds * FPS + 0.5)) if result["reason"] == "smoke" else CYCLE_FRAMES
    if (int(result["fps"]) != FPS or start < 0 or end > total_frames
            or end - start != frames or frames != expected
            or result["reason"] not in ("smoke", "complete")
            or (result["reason"] == "smoke" and smoke_seconds <= 0)):
        raise RuntimeError(f"Invalid exclusive movie frame bounds: {result}")
    return start, end


def trim_filters(start, end):
    samples_per_frame = MIX_RATE // FPS
    return (f"[0:v]trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS[v];"
            f"[0:a]atrim=start_sample={start * samples_per_frame}:"
            f"end_sample={end * samples_per_frame},asetpts=PTS-STARTPTS[a]")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot" if sys.platform == "darwin" else "godot")
    parser.add_argument("--seed", type=Path, default=ROOT / "tests/fixtures" / SEED_ID / "save.arenic.json")
    parser.add_argument("--output", type=Path, required=True, help="New, empty capture directory.")
    parser.add_argument("--preview", action="store_true", help="Open the seeded game interactively without filming.")
    parser.add_argument("--smoke-seconds", type=float, default=0, help="Capture a short pipeline check instead of the complete cycle.")
    args = parser.parse_args()
    args.seed = args.seed.expanduser().resolve()
    engine = shutil.which(args.godot)
    if engine is None or not args.seed.is_file():
        parser.error("Godot and the versioned seed file must both exist.")
    if not 0 <= args.smoke_seconds <= 150:
        parser.error("Smoke duration must be from 0 to 150 seconds.")
    if args.preview and args.smoke_seconds:
        parser.error("Interactive preview and movie smoke capture are separate modes.")
    if not args.preview and (shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None):
        parser.error("Movie conversion requires ffmpeg and ffprobe.")
    output = args.output.expanduser().resolve()
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        parser.error("The output directory must be empty; captures never overwrite an existing store or video.")
    output.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([engine, "--version"], text=True).strip()
    if not version.startswith("4.7.2.stable."):
        parser.error(f"Expected Godot 4.7.2; received {version}.")

    spec = importlib.util.spec_from_file_location("arenic_ci", ROOT / "scripts/ci/test-godot.py")
    ci = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(ci)
    work = output / "work"
    project = ci.isolated_project(work, enable_doctor=False)
    capture_dir = project / "tools/capture"
    capture_dir.mkdir(parents=True)
    shutil.copy2(ROOT / "scripts/capture/hunter-cycle.gd", capture_dir / "hunter-cycle.gd")
    settings = project / "project.godot"
    # The CI helper normally names projects after destination.name ("work").
    # Give every capture its own bootstrap user:// before SaveGames is ready.
    capture_id = hashlib.sha256(str(output).encode()).hexdigest()[:16]
    text = re.sub(r'^config/name=.*$', f'config/name="arenic-capture-{capture_id}"',
                  settings.read_text(), flags=re.MULTILINE)
    settings.write_text(text + '\n[editor]\n\nmovie_writer/video_quality=0.85\n'
                        'movie_writer/mix_rate=48000\nmovie_writer/speaker_mode=0\n'
                        'movie_writer/audio_bit_depth=16\n')
    seed = output / "save.arenic.json"
    shutil.copy2(args.seed.resolve(), seed)
    base = [engine, "--path", str(project), "--disable-file-logging", "--rendering-method", "gl_compatibility"]
    execute(base + ["--headless", "--editor", "--import", "--quit"], output / "import.log", 180)
    command = base + ["--rendering-driver", "opengl3", "--render-thread", "safe",
                      "--windowed", "--resolution", "1280x720", "--position", "40,80",
                      "--script", "res://tools/capture/hunter-cycle.gd"]
    if sys.platform == "darwin":
        command += ["--display-driver", "macos"]
    if not args.preview:
        command += ["--write-movie", str(output / "source.avi"), "--fixed-fps", str(FPS), "--disable-vsync", "--quit-after", "9300"]
    command += ["--", "--capture-seed", str(seed), str(output)]
    if args.preview:
        command.append("--preview")
    elif args.smoke_seconds:
        command.append(f"--smoke={args.smoke_seconds}")
    (output / "command.json").write_text(json.dumps(command, indent=2) + "\n")
    if args.preview:
        # A preview belongs to the user; return its PID without a day-long
        # monitoring process or movie telemetry accumulating in the game.
        with (output / "godot.log").open("w") as log:
            child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                     env={**os.environ, "NO_COLOR": "1"}, start_new_session=True)
        preview = {"pid": child.pid, "log": str(output / "godot.log"), "command": command}
        (output / "preview.json").write_text(json.dumps(preview, indent=2) + "\n")
        print(json.dumps(preview), flush=True)
        return 0
    execute(command, output / "godot.log", 1200)
    result = json.loads((output / "capture.json").read_text())
    if not args.smoke_seconds and not result["passed"]:
        raise RuntimeError("The real cycle did not complete with its progress preserved.")
    raw = probe(output / "source.avi")
    video, _audio = media_streams(raw)
    total_frames = int(video["nb_frames"])
    start_frame, end_frame = trim_bounds(result, total_frames, args.smoke_seconds)
    clip_frames = int(result["frames"])
    length = clip_frames / FPS
    movie = output / MOVIE
    execute(["ffmpeg", "-hide_banner", "-nostdin", "-i", str(output / "source.avi"), "-filter_complex", trim_filters(start_frame, end_frame),
             "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-preset", "slow", "-crf", "17",
             "-pix_fmt", "yuv420p", "-fps_mode:v", "passthrough", "-c:a", "aac", "-b:a", "192k",
             "-movflags", "+faststart", str(movie)], output / "encode.log")
    metadata = probe(movie, count_frames=True)
    encoded_video, encoded_audio = media_streams(metadata)
    if (int(encoded_video["nb_read_frames"]) != clip_frames
            or abs(float(encoded_video["duration"]) - length) > 1 / FPS
            or abs(float(encoded_audio["duration"]) - length) > 1024 / MIX_RATE):
        raise RuntimeError(f"Encoded clip did not preserve its frame/sample interval: {metadata}")
    result.update(capture_id=CAPTURE_ID, capture_version=CAPTURE_VERSION,
                  engine=version, resolution=SIZE, raw_frames=total_frames,
                  trim_start_frame=start_frame, trim_end_frame=end_frame,
                  movie_sha256=hashlib.sha256(movie.read_bytes()).hexdigest(),
                  movie_bytes=movie.stat().st_size, media=metadata)
    (output / "capture.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"video": str(movie), "seconds": length, "frames": clip_frames,
                      "deaths": len(result["deaths"]), "passed": result["passed"]}), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

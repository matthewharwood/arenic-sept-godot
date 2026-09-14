#!/usr/bin/env python3
"""Validate and package Hunter capture v2 of frozen seed v1; never publish or edit Git.

Requires the capture's disposable work/arenic-game snapshot and the versioned
fixture in this checkout. The output is a new or empty artifact directory.
"""

import argparse
from fractions import Fraction
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
_timing_spec = importlib.util.spec_from_file_location("arenic_hunter_capture", ROOT / "scripts/capture-hunter-cycle.py")
_timing = importlib.util.module_from_spec(_timing_spec)
_timing_spec.loader.exec_module(_timing)
FPS = _timing.FPS
CYCLE_FRAMES = _timing.CYCLE_FRAMES
CYCLE_SECONDS = _timing.CYCLE_SECONDS
CAPTURE_VERSION = _timing.CAPTURE_VERSION
CAPTURE_ID = _timing.CAPTURE_ID
FIXTURE = Path("tests/fixtures") / _timing.SEED_ID
MOVIE = _timing.MOVIE
SEED = f"{_timing.SEED_ID}.arenic.json"
REPRO = f"hunter-full-arena-repro-v{CAPTURE_VERSION}.zip"
PROOF = f"capture-proof-v{CAPTURE_VERSION}.json"
SOURCE_GROUPS = ("scripts", "data", "scenes", "shaders")
HELPERS = (
    "scripts/capture-hunter-cycle.py",
    "scripts/capture/hunter-cycle.gd",
    "scripts/capture/package-hunter-capture.py",
    "scripts/fixtures/build-hunter-full-arena.py",
    "scripts/fixtures/hunter_full_arena_v1.gd",
    "scripts/fixtures/verify-hunter-browser.mjs",
)
MIB = 1024 * 1024
MAX_MOVIE_BYTES = 2 * 1024 * MIB - 1  # GitHub release assets must be under 2 GiB.
MAX_SEED_BYTES = 64 * MIB
MAX_JSON_BYTES = 8 * MIB
MAX_TEXT_BYTES = 2 * MIB
MAX_SOURCE_FILES = 4096
MAX_SOURCE_BYTES = 256 * MIB
IDENTIFIER = re.compile(r"[a-z][a-z0-9_]{0,63}")
PHASES = _timing.PHASES
PHASE_FRAMES = _timing.PHASE_FRAMES


def require(condition, message):
    if not condition:
        raise ValueError(message)


def regular_file(path, maximum, *, allow_empty=False):
    require(not path.is_symlink() and path.is_file(), f"Missing regular file: {path}")
    size = path.stat().st_size
    require((0 if allow_empty else 1) <= size <= maximum, f"File exceeds its byte bound or is empty: {path}")
    return size


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(MIB), b""):
            value.update(block)
    return value.hexdigest()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON object key.")
        result[key] = value
    return result


def read_json(path):
    regular_file(path, MAX_JSON_BYTES)
    value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_object,
                       parse_constant=lambda _: require(False, "Nonfinite JSON value."))
    require(isinstance(value, dict), f"Expected a JSON object: {path}")
    return value


def integer(value, minimum=0, maximum=(1 << 63) - 1):
    require(type(value) is int and minimum <= value <= maximum, "Expected a bounded whole integer.")
    return value


def counter(value):
    require(isinstance(value, str) and re.fullmatch(r"0|[1-9][0-9]{0,18}", value) is not None
            and int(value) <= (1 << 63) - 1, "Expected an exact nonnegative 64-bit counter string.")
    return value


def totals(value):
    require(isinstance(value, dict), "Missing capture totals.")
    return {key: counter(value.get(key)) for key in ("damage", "prospected", "wood", "gold")}


def limited_list(value, maximum):
    require(isinstance(value, list) and len(value) <= maximum, "Capture array exceeds its bound.")
    require(all(isinstance(item, dict) for item in value), "Expected capture records.")
    return value


def media_proof(value):
    """Select technical values only: never ffprobe filename, tags or side data."""
    require(isinstance(value, dict), "Missing encoded media metadata.")
    streams = limited_list(value.get("streams"), 2)
    video = [stream for stream in streams if stream.get("codec_type") == "video"]
    audio = [stream for stream in streams if stream.get("codec_type") == "audio"]
    require(len(video) == 1 and len(audio) == 1, "Expected exactly one video and one audio stream.")
    video, audio = video[0], audio[0]
    pixel_format = video.get("pix_fmt")
    color_range = video.get("color_range")
    require(video.get("codec_name") == "h264" and pixel_format in ("yuv420p", "yuvj420p"),
            "Expected an 8-bit 4:2:0 H.264 capture.")
    require(color_range in (None, "unknown", "tv", "pc"), "Invalid encoded color-range metadata.")
    require([video.get("width"), video.get("height")] == [1280, 720], "Expected 1280x720 encoded video.")
    require(str(video.get("nb_frames")) == str(CYCLE_FRAMES), f"Encoded video must contain exactly {CYCLE_FRAMES} frames.")
    for field in ("r_frame_rate", "avg_frame_rate"):
        require(isinstance(video.get(field), str) and len(video[field]) <= 32,
                "Missing encoded frame-rate metadata.")
        try:
            rate = Fraction(video[field])
        except (ValueError, ZeroDivisionError) as error:
            raise ValueError("Invalid encoded frame-rate metadata.") from error
        require(rate == FPS, f"Encoded video must be a constant {FPS} fps.")
    require(audio.get("codec_name") == "aac", "Expected AAC capture audio.")
    channels = integer(audio.get("channels"), 1, 8)
    sample_rate = str(audio.get("sample_rate", ""))
    require(re.fullmatch(r"[0-9]{4,6}", sample_rate) is not None and 8000 <= int(sample_rate) <= 192000,
            "Invalid capture audio sample rate.")
    container = value.get("format")
    require(isinstance(container, dict), "Missing encoded container metadata.")
    duration = float(container.get("duration", "nan"))
    require(math.isfinite(duration) and abs(duration - CYCLE_SECONDS) <= 1 / FPS,
            f"Encoded duration must be {CYCLE_SECONDS} seconds within one frame of container rounding.")
    require(str(container.get("size", "")).isdigit(), "Missing encoded container byte size.")
    size = integer(int(container["size"]), 1, MAX_MOVIE_BYTES)
    return {"video": {"codec": "h264", "pixel_format": pixel_format, "color_range": color_range, "width": 1280,
                      "height": 720, "frames": CYCLE_FRAMES, "fps": FPS},
            "audio": {"codec": "aac", "sample_rate": int(sample_rate), "channels": channels},
            "duration_seconds": duration, "bytes": size}


def capture_proof(capture, seed_sha, movie_sha, movie_size):
    require(capture.get("passed") is True and capture.get("reason") == "complete",
            "Only a passed complete capture can be packaged; smoke captures are excluded.")
    require(capture.get("capture_id") == CAPTURE_ID and capture.get("capture_version") == CAPTURE_VERSION,
            f"Expected capture {CAPTURE_ID}; seed v1 and capture v1 are separate identities.")
    require(capture.get("fps") == FPS and capture.get("frames") == CYCLE_FRAMES
            and capture.get("seconds") == CYCLE_SECONDS and capture.get("resolution") == [1280, 720],
            f"Expected {FPS} fps, {CYCLE_FRAMES} frames, {CYCLE_SECONDS} seconds and 1280x720 capture proof.")
    require(capture.get("seed_sha256") == seed_sha, "Capture used a different seed document.")
    require(capture.get("movie_sha256") == movie_sha and capture.get("movie_bytes") == movie_size,
            "Capture movie checksum or size differs from the finalized MP4.")
    engine = capture.get("engine", "")
    require(isinstance(engine, str) and re.fullmatch(r"4\.7\.2\.stable\.[A-Za-z0-9_.-]{1,96}", engine),
            "Expected Godot 4.7.2 stable capture provenance.")
    transitions = []
    supplied = limited_list(capture.get("transitions"), len(PHASES))
    require(len(supplied) == len(PHASES), "Capture must prove all five cycle boundaries.")
    for item, phase, frame in zip(supplied, PHASES, PHASE_FRAMES):
        require(item.get("phase") == phase and item.get("frame") == frame
                and item.get("seconds") == frame / FPS, "Unexpected cycle phase boundary.")
        transitions.append({"phase": phase, "frame": frame, "seconds": frame / FPS,
                            "tick": integer(item.get("tick"), 0, 7200)})
    deaths = []
    for item in limited_list(capture.get("deaths"), 320):
        actor = item.get("actor", "")
        require(isinstance(actor, str) and re.fullmatch(r"hero:[0-9]{1,3}", actor)
                and int(actor[5:]) < 320, "Invalid capture actor identity.")
        deaths.append({"actor": actor, "tick": integer(item.get("tick"), 0, 7199),
                       "frame": integer(item.get("frame"), 0, CYCLE_FRAMES)})
    damage = capture.get("damage_by_ability")
    require(isinstance(damage, dict) and len(damage) <= 32, "Invalid ability damage summary.")
    for key in damage:
        require(isinstance(key, str) and IDENTIFIER.fullmatch(key), "Invalid ability identity.")
    before, final = totals(capture.get("totals_before_rewind")), totals(capture.get("final_totals"))
    require(before == final, "Rewind changed preserved capture totals.")
    media = media_proof(capture.get("media"))
    require(media["bytes"] == movie_size, "Encoded metadata size does not match MP4 bytes.")
    # Per-second records are selected field by field; nested unknown dictionaries
    # (including future ffprobe/user-path metadata) never enter the public proof.
    samples = []
    for item in limited_list(capture.get("samples"), 150):
        phase = item.get("phase")
        require(phase in ("", "rewind", "countdown"), "Invalid sampled restart phase.")
        samples.append({"frame": integer(item.get("frame"), 0, CYCLE_FRAMES), "phase": phase,
                        "tick": integer(item.get("tick"), 0, 7200),
                        "alive": integer(item.get("alive"), 0, 40), "totals": totals(item.get("totals"))})
    return {"proof_version": 1, "capture_id": CAPTURE_ID, "capture_version": CAPTURE_VERSION,
            "seed_id": _timing.SEED_ID, "passed": True,
            "engine": engine, "fps": FPS, "frames": CYCLE_FRAMES, "seconds": CYCLE_SECONDS,
            "resolution": [1280, 720], "seed_sha256": seed_sha, "movie_sha256": movie_sha,
            "movie_bytes": movie_size, "media": media, "transitions": transitions,
            "samples": samples, "deaths": deaths,
            "damage_by_ability": {key: integer(damage[key]) for key in sorted(damage)},
            "totals_before_rewind": before, "final_totals": final}


def runtime_manifest(project, git_base):
    files, total = [], 0
    require(project.is_dir() and not project.is_symlink(), "Capture's disposable project snapshot is missing.")
    for group in SOURCE_GROUPS:
        directory = project / group
        require(directory.is_dir() and not directory.is_symlink(), f"Missing captured source group: {group}")
        for parent, directories, names in os.walk(directory, followlinks=False):
            require(not any((Path(parent) / name).is_symlink() for name in directories),
                    "Runtime snapshot must not contain directory symlinks.")
            for name in sorted(names):
                path = Path(parent) / name
                size = regular_file(path, 16 * MIB, allow_empty=True)
                total += size
                require(len(files) < MAX_SOURCE_FILES and total <= MAX_SOURCE_BYTES,
                        "Runtime snapshot exceeds file-count or byte bounds.")
                files.append({"path": "arenic-game/" + path.relative_to(project).as_posix(),
                              "bytes": size, "sha256": digest(path)})
    files.sort(key=lambda item: item["path"])
    source_sha = hashlib.sha256("".join(item["path"] + "\0" + item["sha256"] + "\n" for item in files).encode()).hexdigest()
    return {"manifest_version": 1, "source_kind": "captured_disposable_working_tree_snapshot",
            "git_base_head": git_base,
            "provenance_note": "Git HEAD is the packaging checkout's committed base. These hashes describe the captured working-tree snapshot, including uncommitted edits; the commit is not claimed to contain this source.",
            "source_groups": ["arenic-game/" + group for group in SOURCE_GROUPS],
            "source_sha256": source_sha, "source_sha256_recipe": "SHA256 of UTF-8 sorted path + NUL + lowercase file SHA256 + LF records",
            "file_count": len(files), "total_bytes": total, "files": files,
            "not_bundled": ["runtime source", "assets", "addons", "Godot imports", "raw AVI"]}


def json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False) + "\n").encode()


def checksums(files):
    return "".join(hashlib.sha256(data).hexdigest() + "  " + name + "\n" for name, data in sorted(files.items())).encode()


def write_zip(path, files):
    files = {**files, "SHA256SUMS": checksums(files)}
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)


def package(capture_dir, output):
    require(capture_dir.is_dir(), "Capture directory does not exist.")
    require(not output.is_symlink(), "Output cannot be a symlink.")
    require(not output.exists() or output.is_dir() and not any(output.iterdir()), "Output must be new or empty.")
    capture_dir, output = capture_dir.resolve(), output.resolve()
    require(output != capture_dir and capture_dir not in output.parents and output not in capture_dir.parents,
            "Output must be separate from the capture directory and its ancestors.")
    for protected in (ROOT / "arenic-game", ROOT / "assets", ROOT / "scripts", ROOT / "tests", ROOT / ".git", ROOT / "site"):
        require(output != protected and protected not in output.parents and output not in protected.parents,
                "Output must not replace or live inside repository source directories.")
    fixture = ROOT / FIXTURE
    seed_path = fixture / "save.arenic.json"
    regular_file(seed_path, MAX_SEED_BYTES)
    seed_sha = digest(seed_path)
    captured_seed = capture_dir / "save.arenic.json"
    regular_file(captured_seed, MAX_SEED_BYTES)
    require(digest(captured_seed) == seed_sha, "The captured seed differs from the versioned fixture.")
    manifest = read_json(fixture / "manifest.json")
    require(manifest.get("fixture_id") == "hunter-full-arena" and manifest.get("fixture_version") == 1
            and manifest.get("save_sha256") == seed_sha, "Fixture manifest identity or checksum mismatch.")
    require(manifest.get("payload_schema") == 7 and manifest.get("arena_id") == "labyrinth"
            and manifest.get("hero_count") == 40, "Expected the version-1 Hunter arena fixture.")
    regular_file(fixture / "README.md", MAX_TEXT_BYTES)
    movie_path = capture_dir / MOVIE
    movie_size = regular_file(movie_path, MAX_MOVIE_BYTES)
    movie_sha = digest(movie_path)
    proof = capture_proof(read_json(capture_dir / "capture.json"), seed_sha, movie_sha, movie_size)
    base = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
    require(re.fullmatch(r"[0-9a-f]{40}", base), "Expected an exact Git base commit.")
    runtime = runtime_manifest(capture_dir / "work/arenic-game", base)
    kit = {}
    for name in ("save.arenic.json", "manifest.json", "README.md"):
        kit[(FIXTURE / name).as_posix()] = (fixture / name).read_bytes()
    for name in HELPERS:
        regular_file(ROOT / name, MAX_TEXT_BYTES)
        kit[name] = (ROOT / name).read_bytes()
    kit["runtime-manifest.json"] = json_bytes(runtime)
    kit["README.md"] = (f"# Hunter full-arena capture reproduction kit v{CAPTURE_VERSION}\n\n"
        "Capture v2 uses the same frozen seed v1. Its full-history reverse lasts five seconds; the original hosted capture v1 remains a separate historical artifact.\n\n"
        "This kit requires a compatible full Arenic Godot checkout, including its runtime assets, addons and scripts/ci/test-godot.py. It is not a standalone game or a source release.\n\n"
        f"The packaging checkout's committed base is `{base}`. The capture uses a disposable working-tree snapshot, including uncommitted edits; this base commit alone does not reproduce it. `runtime-manifest.json` lists the exact captured scripts, data, scenes and shaders and their SHA256 values. Obtain that matching game checkout before reproducing.\n\n"
        "Extract this kit into a disposable copy of that matching checkout, preserving the kit's repository-relative paths. Verify SHA256SUMS within the kit first, and compare the runtime manifest against the checkout before running. The existing game assets and editor dependencies are deliberately not bundled.\n\n"
        "Use Godot 4.7.2 stable, Python 3, ffmpeg and ffprobe. From the checkout root:\n\n"
        "```sh\npython3 scripts/capture-hunter-cycle.py --godot /path/to/godot --seed tests/fixtures/hunter-full-arena-v1/save.arenic.json --output /new/empty/capture-directory\n```\n\n"
        f"The runner imports a disposable project, hydrates the supplied seed into a capture-owned save directory, captures at native 1280x720/{FPS}fps, and encodes the complete {CYCLE_SECONDS}-second clip ({CYCLE_FRAMES} frames): 3-second countdown, 120-second forward replay, 5-second reverse, then 3-second countdown. It does not use the player's save store. To inspect interactively, add `--preview`; the frozen seed does not need to be regenerated for this capture.\n\n"
        "The kit carries no raw AVI, video, full runtime source, assets, editor imports, credentials or live player saves. The accompanying seed is the deliberate versioned forty-hero fixture.\n").encode()
    require(sum(map(len, kit.values())) <= 96 * MIB, "Reproduction kit exceeds its uncompressed byte bound.")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".hunter-package-", dir=output.parent) as temporary:
        stage = Path(temporary) / "package"
        stage.mkdir()
        shutil.copyfile(movie_path, stage / MOVIE)
        (stage / SEED).write_bytes(kit[(FIXTURE / "save.arenic.json").as_posix()])
        (stage / "fixture-manifest.json").write_bytes(kit[(FIXTURE / "manifest.json").as_posix()])
        (stage / PROOF).write_bytes(json_bytes(proof))
        (stage / "runtime-manifest.json").write_bytes(json_bytes(runtime))
        write_zip(stage / REPRO, kit)
        require(digest(stage / MOVIE) == movie_sha and digest(stage / SEED) == seed_sha,
                "Capture or fixture changed while packaging; no output was published.")
        (stage / "SHA256SUMS").write_text("".join(digest(path) + "  " + path.name + "\n" for path in sorted(stage.iterdir())), encoding="utf-8")
        # rmdir can remove only an empty directory, including on Windows. A
        # concurrently populated output fails instead of replacing its files.
        if output.exists():
            output.rmdir()
        stage.rename(output)
    return {"output": str(output), "movie_bytes": movie_size, "seed_sha256": seed_sha,
            "movie_sha256": movie_sha, "source_sha256": runtime["source_sha256"], "published": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = package(args.capture_dir.expanduser(), args.output.expanduser())
    except (ValueError, OSError, subprocess.SubprocessError, TypeError, RecursionError) as error:
        parser.exit(1, f"Packaging failed: {error}\n")
    print(json.dumps(result, sort_keys=True), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Install the pinned official Linux editor; optionally install export templates.

Linux CI: python3 scripts/ci/install-godot.py [--templates]
Local macOS: use test-godot.py --godot /Applications/Godot.app/Contents/MacOS/Godot.
Checksums are from the official 4.7.2-stable release's SHA512-SUMS.txt:
https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import sys
import tempfile
import urllib.request
import zipfile

VERSION = "4.7.2"
RELEASE_URL = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable"
ENGINE_ARCHIVE = f"Godot_v{VERSION}-stable_linux.x86_64.zip"
TEMPLATE_ARCHIVE = f"Godot_v{VERSION}-stable_export_templates.tpz"
SHA512 = {
    ENGINE_ARCHIVE: "9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65",
    TEMPLATE_ARCHIVE: "ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079",
}


def checksum(path: Path) -> str:
    digest = hashlib.sha512()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def archive(name: str, cache: Path) -> Path:
    cache.mkdir(parents=True, exist_ok=True)
    destination = cache / name
    if destination.exists():
        if checksum(destination) == SHA512[name]:
            return destination
        raise RuntimeError(f"Cached checksum mismatch: {destination}; remove it and retry.")
    temporary = destination.with_suffix(destination.suffix + ".partial")
    try:
        request = urllib.request.Request(f"{RELEASE_URL}/{name}", headers={"User-Agent": "Arenic-CI"})
        with urllib.request.urlopen(request, timeout=120) as response, temporary.open("wb") as output:
            shutil.copyfileobj(response, output, length=1024 * 1024)
        if checksum(temporary) != SHA512[name]:
            raise RuntimeError(f"Official download checksum mismatch: {name}")
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)
    return destination


def install_templates(source: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(source) as bundle:
        for entry in bundle.infolist():
            relative = Path(entry.filename)
            if relative.is_absolute() or ".." in relative.parts or relative.parts[0] != "templates":
                raise RuntimeError(f"Unexpected template archive entry: {entry.filename}")
            # This repository exports Web only. Verify the whole official bundle,
            # then extract Web variants and version metadata, not unrelated SDKs.
            if relative.name != "version.txt" and not (relative.name.startswith("web") and relative.suffix == ".zip"):
                continue
            target = destination.joinpath(*relative.parts[1:])
            if entry.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with bundle.open(entry) as data, target.open("wb") as output:
                    shutil.copyfileobj(data, output)
                if entry.external_attr >> 16 & 0o111:
                    target.chmod(0o755)
    required = ("web_debug.zip", "web_release.zip", "web_nothreads_debug.zip", "web_nothreads_release.zip")
    if not all((destination / name).is_file() for name in required):
        raise RuntimeError("The official template bundle is missing an expected Web template.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=Path.home() / ".cache/arenic/godot" / VERSION)
    parser.add_argument("--templates", action="store_true", help="Also install matching official Web export templates.")
    args = parser.parse_args()
    if sys.platform != "linux" or platform.machine() not in ("x86_64", "AMD64"):
        parser.error("This installer targets Linux x86_64. On macOS, pass the installed binary to test-godot.py --godot.")
    directory = args.directory.expanduser().resolve()
    directory.mkdir(parents=True, exist_ok=True)
    source = archive(ENGINE_ARCHIVE, directory / "downloads")
    engine = directory / "godot"
    with zipfile.ZipFile(source) as bundle, tempfile.NamedTemporaryFile(dir=directory, delete=False) as output:
        temporary = Path(output.name)
        try:
            with bundle.open(f"Godot_v{VERSION}-stable_linux.x86_64") as data:
                shutil.copyfileobj(data, output)
            output.flush()
            temporary.chmod(0o755)
            temporary.replace(engine)
        finally:
            temporary.unlink(missing_ok=True)
    result = {"godot_path": str(engine), "version": VERSION}
    if args.templates:
        data_root = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
        templates = data_root / "godot/export_templates" / f"{VERSION}.stable"
        install_templates(archive(TEMPLATE_ARCHIVE, directory / "downloads"), templates)
        result["templates_path"] = str(templates)
    print(json.dumps(result, indent=2))
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
            for key, value in result.items():
                output.write(f"{key}={value}\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, zipfile.BadZipFile) as error:
        print(f"Godot installation failed: {error}", file=sys.stderr)
        raise SystemExit(1)

#!/usr/bin/env python3
"""Build an unsigned F-Droid APK at a stable path for Dart's generated URIs."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
WORKSPACE = Path("/var/tmp/hadithsearcher-fdroid")
OUTPUT = Path("build/app/outputs/flutter-apk/app-fdroid-release.apk")


def main(flutter=None):
    executable = shutil.which(str(flutter or os.environ.get("FLUTTER_BIN", "flutter")))
    if executable is None:
        raise RuntimeError("Install Flutter on PATH or specify --flutter /path/to/flutter")
    flutter = Path(executable).resolve()
    # Exclusive creation also prevents concurrent builds from sharing this path.
    WORKSPACE.mkdir()
    try:
        files = subprocess.check_output(
            ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
            cwd=ROOT,
        ).decode().split("\0")
        for name in files:
            source = ROOT / name
            if name and source.is_file():
                target = WORKSPACE / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
        local = ROOT / "android/local.properties"
        if local.is_file():
            shutil.copy2(local, WORKSPACE / "android/local.properties")
        shutil.rmtree(WORKSPACE / "android/app/src/play", ignore_errors=True)
        gradle = WORKSPACE / "android/app/build.gradle.kts"
        gradle.write_text("\n".join(
            line for line in gradle.read_text().splitlines() if '"playImplementation"' not in line
        ) + "\n")
        for args in (
            ["pub", "get", "--enforce-lockfile"],
            ["build", "apk", "--release", "--flavor", "fdroid",
             "--dart-define=UPDATE_CHANNEL=fdroid"],
        ):
            subprocess.run([str(flutter), *args], cwd=WORKSPACE, check=True)
        destination = ROOT / OUTPUT
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(WORKSPACE / OUTPUT, destination)
    finally:
        shutil.rmtree(WORKSPACE)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter", help="Flutter executable; defaults to FLUTTER_BIN or PATH")
    args = parser.parse_args()
    try:
        main(args.flutter)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from error

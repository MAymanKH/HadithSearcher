#!/usr/bin/env python3
"""Build an unsigned F-Droid APK at a stable path for Dart's generated URIs."""

from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
WORKSPACE = Path("/var/tmp/hadithsearcher-fdroid")
OUTPUT = Path("build/app/outputs/flutter-apk/app-fdroid-release.apk")


def main():
    flutter = ROOT / ".flutter/bin/flutter"
    if not flutter.is_file():
        raise RuntimeError("Initialize the pinned SDK with git submodule update --init .flutter")
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
        (WORKSPACE / ".flutter").symlink_to(ROOT / ".flutter", target_is_directory=True)
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
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from error

#!/usr/bin/env python3
"""Build the store releases from the current working tree."""

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
SHOREBIRD_FLUTTER_VERSION = "3.47.7"
PLAY_ASSET = "    - path: shorebird.yaml\n      flavors:\n        - play\n"


def run(*args, cwd=ROOT):
    subprocess.run(args, cwd=cwd, check=True)


def verify_artifact(path, *, shorebird):
    with zipfile.ZipFile(path) as artifact:
        names = artifact.namelist()
        configs = [name for name in names if name.endswith("/shorebird.yaml")]
        engines = [name for name in names if name.endswith("/libflutter.so")]
        if not engines:
            raise RuntimeError("The artifact has no Flutter engine")
        if bool(configs) != shorebird:
            raise RuntimeError("Unexpected Shorebird configuration in artifact")
        for name in engines:
            contains_updater = b"shorebird" in artifact.read(name).lower()
            if contains_updater != shorebird:
                raise RuntimeError("Unexpected Flutter engine in artifact")


def keep_artifact(source, store, version):
    destination = ROOT / "build" / "releases" / store
    destination.mkdir(parents=True, exist_ok=True)
    target = destination / f"HadithSearcher-{version}-{store}{source.suffix}"
    shutil.copy2(source, target)
    print(f"Release artifact: {target}", flush=True)


def build_fdroid(version):
    run("flutter", "build", "apk", "--release", "--flavor", "fdroid")
    apk = ROOT / "build/app/outputs/flutter-apk/app-fdroid-release.apk"
    verify_artifact(apk, shorebird=False)
    keep_artifact(apk, "fdroid", version)


def build_github(version):
    apk = ROOT / "build/releases/fdroid" / f"HadithSearcher-{version}-fdroid.apk"
    if not apk.is_file():
        raise RuntimeError("Build the unsigned APK first: ./scripts/release.py fdroid")
    verify_artifact(apk, shorebird=False)
    properties = dict(re.findall(
        r"^\s*(\w+)\s*=\s*(.*?)\s*$",
        (ROOT / "android/key.properties").read_text(), re.MULTILINE,
    ))
    for key in ("storeFile", "storePassword", "keyAlias", "keyPassword"):
        if not properties.get(key):
            raise RuntimeError(f"Signing configuration has no {key}")
    keystore = Path(properties["storeFile"].replace("\\ ", " "))
    if not keystore.is_absolute():
        keystore = (ROOT / "android/app" / keystore).resolve()
    if not keystore.is_file():
        raise RuntimeError("The configured signing keystore does not exist")
    sdk = re.search(
        r"^sdk.dir\s*=\s*(.+)$",
        (ROOT / "android/local.properties").read_text(), re.MULTILINE,
    )
    if sdk is None:
        raise RuntimeError("android/local.properties has no sdk.dir")
    build_tools = Path(sdk.group(1).strip().replace("\\ ", " ")) / "build-tools"
    versions = sorted(
        (path for path in build_tools.iterdir() if re.fullmatch(r"\d+\.\d+\.\d+", path.name)),
        key=lambda path: tuple(map(int, path.name.split("."))), reverse=True,
    )
    tools = next((path for path in versions if (path / "apksigner").is_file()
                  and (path / "zipalign").is_file()), None)
    if tools is None:
        raise RuntimeError("Install Android SDK Build Tools with apksigner and zipalign")
    env = os.environ.copy()
    env["HADITH_STORE_PASSWORD"] = properties["storePassword"]
    env["HADITH_KEY_PASSWORD"] = properties["keyPassword"]
    with tempfile.TemporaryDirectory(prefix="hadith-sign-") as directory:
        aligned = Path(directory) / "aligned.apk"
        signed = Path(directory) / "signed.apk"
        run(str(tools / "zipalign"), "-P", "16", "-f", "4", str(apk), str(aligned))
        subprocess.run([
            str(tools / "apksigner"), "sign", "--ks", str(keystore),
            "--ks-key-alias", properties["keyAlias"],
            "--ks-pass", "env:HADITH_STORE_PASSWORD",
            "--key-pass", "env:HADITH_KEY_PASSWORD",
            "--out", str(signed), str(aligned),
        ], cwd=ROOT, env=env, check=True)
        run(str(tools / "apksigner"), "verify", "--verbose", str(signed))
        run(str(tools / "zipalign"), "-P", "16", "-c", "4", str(signed))
        verify_artifact(signed, shorebird=False)
        keep_artifact(signed, "github", version)


def build_play(version, dry_run, *, patch=False):
    properties_path = ROOT / "android/key.properties"
    if not properties_path.is_file():
        raise RuntimeError("Play release requires android/key.properties")
    properties = properties_path.read_text()
    store = re.search(r"^storeFile\s*=\s*(.+)$", properties, re.MULTILINE)
    if store is None:
        raise RuntimeError("Signing configuration has no storeFile")
    keystore = Path(store.group(1).strip().replace("\\ ", " "))
    if not keystore.is_absolute():
        keystore = (ROOT / "android/app" / keystore).resolve()
    if not keystore.is_file():
        raise RuntimeError("The configured signing keystore does not exist")

    # Shorebird's asset validator requires a plain asset entry. Build in a
    # separate directory so the F-Droid manifest always excludes that asset.
    with tempfile.TemporaryDirectory(prefix="hadith-play-") as directory:
        workspace = Path(directory)
        files = subprocess.check_output(
            ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
            cwd=ROOT,
        ).decode().split("\0")
        for name in files:
            source = ROOT / name
            if name and source.is_file():
                target = workspace / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
        pubspec = workspace / "pubspec.yaml"
        text = pubspec.read_text()
        if PLAY_ASSET not in text:
            raise RuntimeError("pubspec.yaml must declare the play-only Shorebird asset")
        pubspec.write_text(text.replace(PLAY_ASSET, "    - shorebird.yaml\n", 1))

        signing = workspace / "android/key.properties"
        absolute_store = str(keystore).replace("\\", "\\\\").replace(" ", "\\ ")
        signing.write_text(
            properties[:store.start()] + "storeFile=" + absolute_store + properties[store.end():]
        )
        signing.chmod(0o600)
        command = [
            "shorebird", "patch" if patch else "release", "android",
            "--flavor", "play", "--no-confirm",
        ]
        if patch:
            command.extend(["--release-version", version])
        else:
            command.extend(["--flutter-version", SHOREBIRD_FLUTTER_VERSION])
        if dry_run:
            command.append("--dry-run")
        run(*command, cwd=workspace)
        if patch:
            return
        bundle = workspace / "build/app/outputs/bundle/playRelease/app-play-release.aab"
        verify_artifact(bundle, shorebird=True)
        keep_artifact(bundle, "play", version)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("store", choices=["play", "fdroid", "all", "patch-play", "github"], nargs="?", default="all")
    parser.add_argument("--dry-run", action="store_true", help="Build Play without registering a Shorebird release")
    args = parser.parse_args()
    version = re.search(r"^version:\s*(\S+)", (ROOT / "pubspec.yaml").read_text(), re.MULTILINE)
    if version is None:
        parser.error("pubspec.yaml has no version")
    if args.store in ("fdroid", "all"):
        build_fdroid(version.group(1))
    if args.store in ("play", "all"):
        build_play(version.group(1), args.dry_run)
    if args.store == "patch-play":
        build_play(version.group(1), args.dry_run, patch=True)
    if args.store == "github":
        build_github(version.group(1))


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from error

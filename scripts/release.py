#!/usr/bin/env python3
"""Build the store releases from the current working tree."""

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
SHOREBIRD_FLUTTER_VERSION = "3.47.7"
PLAY_ASSET = "    - path: shorebird.yaml\n      flavors:\n        - play\n"


def run(*args, cwd=ROOT):
    subprocess.run(args, cwd=cwd, check=True)


def verify_artifact(path, *, shorebird, abi=None):
    with zipfile.ZipFile(path) as artifact:
        names = artifact.namelist()
        configs = [name for name in names if name.endswith("/shorebird.yaml")]
        engines = [name for name in names if name.endswith("/libflutter.so")]
        native_abis = {name.split("/")[1] for name in names if name.startswith("lib/") and name.endswith(".so")}
        if abi is not None and native_abis != {abi}:
            raise RuntimeError(f"Expected only {abi} native libraries, found {native_abis}")
        if not engines:
            raise RuntimeError("The artifact has no Flutter engine")
        if bool(configs) != shorebird:
            raise RuntimeError("Unexpected Shorebird configuration in artifact")
        for name in engines:
            contains_updater = b"shorebird" in artifact.read(name).lower()
            if contains_updater != shorebird:
                raise RuntimeError("Unexpected Flutter engine in artifact")


def keep_artifact(source, store, version, *, abi=None):
    destination = ROOT / "build" / "releases" / store
    destination.mkdir(parents=True, exist_ok=True)
    target = destination / f"HadithSearcher-{version}-{store}{'-' + abi if abi else ''}{source.suffix}"
    shutil.copy2(source, target)
    print(f"Release artifact: {target}", flush=True)


ABI_CODES = {"armeabi-v7a": 1, "arm64-v8a": 2, "x86_64": 3}


def build_unsigned_apks():
    run(sys.executable, str(ROOT / "scripts/build_foss_unsigned.py"))
    apks = {abi: ROOT / f"build/app/outputs/flutter-apk/app-{abi}-foss-release.apk" for abi in ABI_CODES}
    for abi, apk in apks.items():
        verify_artifact(apk, shorebird=False, abi=abi)
    return apks


def build_foss(version):
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
    apks = build_unsigned_apks()
    name, base_code = version.split("+")
    env = os.environ.copy()
    env["HADITH_STORE_PASSWORD"] = properties["storePassword"]
    env["HADITH_KEY_PASSWORD"] = properties["keyPassword"]
    for abi, apk in apks.items():
        with tempfile.TemporaryDirectory(prefix="hadith-sign-") as directory:
            aligned = Path(directory) / "aligned.apk"
            signed = Path(directory) / "signed.apk"
            run(str(tools / "zipalign"), "-P", "16", "-f", "4", str(apk), str(aligned))
            subprocess.run([
                str(tools / "apksigner"), "sign", "--ks", str(keystore),
                "--alignment-preserved", "true",
                "--v1-signing-enabled", "false",
                "--ks-key-alias", properties["keyAlias"],
                "--ks-pass", "env:HADITH_STORE_PASSWORD",
                "--key-pass", "env:HADITH_KEY_PASSWORD",
                "--out", str(signed), str(aligned),
            ], cwd=ROOT, env=env, check=True)
            run(str(tools / "apksigner"), "verify", "--verbose", str(signed))
            run(str(tools / "zipalign"), "-P", "16", "-c", "4", str(signed))
            verify_artifact(signed, shorebird=False, abi=abi)
            keep_artifact(signed, "foss", f"{name}+{int(base_code) + ABI_CODES[abi]}", abi=abi)


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
    # separate directory so the FOSS manifest always excludes that asset.
    # Android intermediates can exceed the system temporary filesystem's quota.
    build_directory = ROOT / "build"
    build_directory.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="hadith-play-", dir=build_directory) as directory:
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
    parser.add_argument("store", choices=["play", "foss", "all", "patch-play"], nargs="?", default="all")
    parser.add_argument("--dry-run", action="store_true", help="Build Play without registering a Shorebird release")
    args = parser.parse_args()
    version = re.search(r"^version:\s*(\S+)", (ROOT / "pubspec.yaml").read_text(), re.MULTILINE)
    if version is None:
        parser.error("pubspec.yaml has no version")
    if int(version.group(1).split("+")[1]) % 10 != 0:
        parser.error("The versionCode must be divisible by 10; the last digit identifies the ABI")
    if args.store in ("foss", "all"):
        build_foss(version.group(1))
    if args.store in ("play", "all"):
        build_play(version.group(1), args.dry_run)
    if args.store == "patch-play":
        build_play(version.group(1), args.dry_run, patch=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from error

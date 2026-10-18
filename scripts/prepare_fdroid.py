#!/usr/bin/env python3
"""Refresh F-Droid listing images and check the listing against the app version.

Requires Pillow, which is included with fdroidserver.
"""

import argparse
from pathlib import Path
import re
import shutil

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LISTING = ROOT / "fastlane/metadata/android"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check without updating images")
    args = parser.parse_args()
    version = re.search(r"^version: (\d+\.\d+\.\d+)\+(\d+)$",
                        (ROOT / "pubspec.yaml").read_text(), re.MULTILINE)
    if not version:
        raise SystemExit("Expected version: x.y.z+number in pubspec.yaml")
    name, code = version.group(1), int(version.group(2))

    with Image.open(ROOT / "assets/icons/launcher.png") as source:
        icon = source.convert("RGBA").resize((512, 512), Image.Resampling.LANCZOS)
    screenshots = sorted((ROOT / "store/screenshots/ar/phone").glob("*.png"))
    if not screenshots:
        raise SystemExit("No Arabic store screenshots found")

    for locale in ("en-US", "ar"):
        directory = LISTING / locale
        for filename, limit in (("title.txt", 30), ("short_description.txt", 80),
                                ("full_description.txt", 4000),
                                (f"changelogs/{code}.txt", 500)):
            text = (directory / filename).read_text().strip()
            if not text or len(text) > limit:
                raise SystemExit(f"{locale}/{filename}: expected 1 to {limit} characters")
        images = directory / "images"
        if not args.check:
            images.mkdir(parents=True, exist_ok=True)
            icon.save(images / "icon.png")
        with Image.open(images / "icon.png") as actual:
            if actual.size != icon.size or actual.convert("RGBA").tobytes() != icon.tobytes():
                raise SystemExit(f"Refresh {locale}/images/icon.png")

    # The available screenshots contain Arabic text, so keep them in that locale.
    destination = LISTING / "ar/images/phoneScreenshots"
    if not args.check:
        destination.mkdir(parents=True, exist_ok=True)
        for source in screenshots:
            shutil.copyfile(source, destination / source.name)
    if {p.name for p in destination.glob("*.png")} != {p.name for p in screenshots}:
        raise SystemExit("The Arabic listing screenshots differ from store/screenshots/ar/phone")
    for source in screenshots:
        if source.read_bytes() != (destination / source.name).read_bytes():
            raise SystemExit(f"Refresh screenshot {source.name}")
        with Image.open(source) as image:
            image.verify()
    print(f"F-Droid listing checked: {name}+{code}, two locales, {len(screenshots)} screenshots")


if __name__ == "__main__":
    main()

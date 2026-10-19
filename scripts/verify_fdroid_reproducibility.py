#!/usr/bin/env python3
"""Verify a signed F-Droid release against an independently rebuilt unsigned APK.

Requires apksigcopier in the Python environment and Android SDK apksigner.
"""

import argparse
from pathlib import Path
import re
import subprocess
import tempfile

import apksigcopier

ROOT = Path(__file__).resolve().parent.parent


def verify(signed, unsigned, apksigner):
    metadata = (ROOT / "fdroid/com.moaymandev.hadithsearcher.yml").read_text()
    key = re.search(r"^AllowedAPKSigningKeys:\n  - ([0-9a-f]{64})$", metadata, re.MULTILINE)
    if key is None:
        raise RuntimeError("F-Droid recipe must pin one SHA-256 signing certificate")
    with tempfile.TemporaryDirectory(prefix="hadith-repro-") as directory:
        copied = Path(directory) / "copied.apk"
        apksigcopier.do_copy(str(signed), str(unsigned), str(copied))
        result = subprocess.check_output(
            [apksigner, "verify", "--print-certs", str(copied)], text=True,
        )
        certificates = re.findall(r"certificate SHA-256 digest: ([0-9a-f]{64})", result)
        if not certificates or set(certificates) != {key.group(1)}:
            raise RuntimeError("APK signing certificate does not match the F-Droid recipe")
    print("F-Droid rebuild matches the signed APK and the pinned signing certificate")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("signed", type=Path)
    parser.add_argument("unsigned", type=Path)
    parser.add_argument("--apksigner", default="apksigner")
    args = parser.parse_args()
    verify(args.signed, args.unsigned, args.apksigner)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, apksigcopier.APKSigCopierError,
            subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from error

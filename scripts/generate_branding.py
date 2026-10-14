#!/usr/bin/env python3
"""Render branding from logo.svg. Requires librsvg's rsvg-convert and ImageMagick.

Run: python scripts/generate_branding.py
Then: dart run flutter_launcher_icons && dart run flutter_native_splash:create
"""

from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ICONS = ROOT / 'assets/icons'


def render(svg, target, size):
    subprocess.run(
        ['rsvg-convert', '-w', str(size), '-h', str(size), '-o', str(target)],
        input=svg.encode(), check=True,
    )


def padded(source, target, size, mark_size, background='none'):
    subprocess.run([
        'magick', str(source), '-resize', f'{mark_size}x{mark_size}',
        '-gravity', 'center', '-background', background,
        '-extent', f'{size}x{size}', '-strip', str(target),
    ], check=True)


def main():
    svg = (ICONS / 'logo.svg').read_text()
    render(svg, ICONS / 'logo.png', 512)
    with tempfile.TemporaryDirectory() as directory:
        white = Path(directory) / 'white.png'
        render(svg.replace('#000000', '#ffffff'), white, 1024)
        padded(white, ICONS / 'launcher.png', 1024, 800, '#000000')
        # Keep the whole mark within Android's circular adaptive safe zone.
        padded(white, ICONS / 'launcher_foreground.png', 1024, 552)
        padded(white, ICONS / 'logo_dark.png', 512, 512)
        padded(ICONS / 'logo.png', ICONS / 'splash_android12.png', 1152, 640)
        padded(white, ICONS / 'splash_android12_dark.png', 1152, 640)


if __name__ == '__main__':
    main()

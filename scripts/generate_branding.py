#!/usr/bin/env python3
"""Render branding from logo.svg. Requires librsvg's rsvg-convert and ImageMagick.

Run: python scripts/generate_branding.py
Check: python scripts/generate_branding.py --check
Then: dart run flutter_launcher_icons && dart run flutter_native_splash:create
"""

from pathlib import Path
import argparse
import json
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ICONS = ROOT / 'assets/icons'


def render(svg, target, size):
    subprocess.run(
        ['rsvg-convert', '-w', str(size), '-h', str(size), '-o', str(target)],
        input=svg.encode(), check=True,
    )


def padded(source, target, size, mark_size, background='none', *, rgba=False):
    subprocess.run([
        'magick', str(source), '-resize', f'{mark_size}x{mark_size}',
        '-gravity', 'center', '-background', background,
        '-extent', f'{size}x{size}', '-strip',
        f'PNG32:{target}' if rgba else str(target),
    ], check=True)


def generate(icons):
    colors = json.loads((ROOT / 'lib/core/theme/colors.json').read_text())['shared']
    black_color, white_color = colors['black'].lower(), colors['white'].lower()
    svg = (icons / 'logo.svg').read_text()
    white_mark = ET.fromstring(svg)
    white_mark.find('{http://www.w3.org/2000/svg}g').set('fill', white_color)
    white_svg = ET.tostring(white_mark, encoding='unicode')
    ET.register_namespace('', 'http://www.w3.org/2000/svg')
    readme_logo = ET.fromstring(white_svg)
    readme_logo.insert(0, ET.Element('{http://www.w3.org/2000/svg}rect', {
        'width': '256', 'height': '256', 'rx': '48', 'fill': black_color,
    }))
    readme_logo.find('{http://www.w3.org/2000/svg}g').set(
        'transform', 'translate(28 28) scale(0.78)',
    )
    (icons / 'logo_readme.svg').write_text(
        ET.tostring(readme_logo, encoding='unicode') + '\n',
    )
    light_logo = ET.fromstring(white_svg)
    mark = light_logo.find('{http://www.w3.org/2000/svg}g')
    mark.set('stroke', black_color)
    mark.set('stroke-width', '4')
    mark.set('stroke-linejoin', 'round')
    outlined_svg = ET.tostring(light_logo, encoding='unicode')
    (icons / 'logo_light.svg').write_text(outlined_svg + '\n')
    render(outlined_svg, icons / 'logo.png', 512)
    with tempfile.TemporaryDirectory() as directory:
        white = Path(directory) / 'white.png'
        render(white_svg, white, 1024)
        padded(white, icons / 'launcher.png', 1024, 800, black_color)
        # Keep the whole mark within Android's circular adaptive safe zone.
        padded(white, icons / 'launcher_foreground.png', 1024, 552)
        padded(white, icons / 'logo_dark.png', 512, 512)
        # Native splash images use 4 source pixels per dp, matching AppLogo's 112 dp.
        splash_size = 112 * 4
        render(svg, icons / 'splash.png', splash_size)
        padded(white, icons / 'splash_dark.png', splash_size, splash_size)
        padded(icons / 'splash.png', icons / 'splash_android12.png', 1152, splash_size, rgba=True)
        padded(white, icons / 'splash_android12_dark.png', 1152, splash_size)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if not args.check:
        generate(ICONS)
        return
    with tempfile.TemporaryDirectory() as directory:
        icons = Path(directory)
        shutil.copyfile(ICONS / 'logo.svg', icons / 'logo.svg')
        generate(icons)
        stale = [file.name for file in icons.iterdir()
                 if not (ICONS / file.name).exists()
                 or file.read_bytes() != (ICONS / file.name).read_bytes()]
        if stale:
            raise SystemExit('Stale branding: ' + ', '.join(sorted(stale)))


if __name__ == '__main__':
    main()

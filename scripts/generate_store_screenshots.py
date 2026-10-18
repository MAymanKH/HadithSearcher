#!/usr/bin/env python3
"""Render store artwork from real Flutter screenshots using Chromium."""
import argparse
import base64
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'store/screenshots/ar'
PANELS = [
    ('01-search', 'ابحث في أحاديث\nالنبي ﷺ'),
    ('02-filters', 'اجعل بحثك\nأكثر دقة'),
    ('03-origins', 'اطّلع على\nأصول الحديث'),
    ('04-saved', 'احتفظ بما\nتريد مراجعته'),
    ('05-appearance', 'خصّص مظهر\nالتطبيق'),
    ('06-sources', 'معلومات عن\nالمحدث والكتاب'),
]
APPEARANCE_SOURCES = [
    '05-appearance', '05-appearance-forest', '05-appearance-ocean',
    '05-appearance-lavender', '05-appearance-rose', '05-appearance-amber',
]
SOURCE_NAMES = [name for name, _ in PANELS] + APPEARANCE_SOURCES[1:]


def data_url(path, mime):
    return f'data:{mime};base64,' + base64.b64encode(path.read_bytes()).decode()


def artwork(name, title):
    font = data_url(ROOT / 'assets/fonts/Cairo-Variable.ttf', 'font/ttf')
    def screen(source):
        return data_url(DEST / 'sources' / f'{source}.png', 'image/png')
    if name == '05-appearance':
        slices = []
        band = 100 / len(APPEARANCE_SOURCES)
        slant = band * .4
        for index, source in enumerate(APPEARANCE_SOURCES):
            last = index == len(APPEARANCE_SOURCES) - 1
            top_left = 0 if index == 0 else index * band + slant
            top_right = 0 if index == 0 else index * band - slant
            bottom_left = 100 if last else (index + 1) * band + slant
            bottom_right = 100 if last else (index + 1) * band - slant
            slices.append(f'<div class="slice" style="clip-path:polygon(0 {top_left}%,100% {top_right}%,100% {bottom_right}%,0 {bottom_left}%)"><img src="{screen(source)}" alt=""></div>')
        content = '<div class="palette-stack">' + ''.join(slices) + '</div>'
    else:
        content = f'<img src="{screen(name)}" alt="واجهة التطبيق الحالية">'
    headline = title.replace('\n', '<br>')
    return f'''<!doctype html><html lang="ar" dir="ltr"><meta charset="utf-8">
<style>
@font-face{{font-family:Cairo;src:url({font});font-weight:200 1000}}
*{{box-sizing:border-box}}html,body{{margin:0;width:1080px;height:1920px;overflow:hidden;position:relative}}
body{{background:#29272b;color:#FFF;font-family:Cairo,sans-serif}}
body::before,body::after{{content:"";position:absolute;left:-270px;top:713px;width:1620px;height:1404px;border-radius:50%;transform:rotate(-20deg)}}
body::before{{background:#353338}}
body::after{{top:626px;border:1px solid #ffffff13}}
h1{{direction:rtl;text-align:right;position:absolute;z-index:3;top:76px;right:76px;left:76px;margin:0;font-size:103px;line-height:1.3;font-weight:850}}
.phone{{position:absolute;z-index:2;top:421px;left:205px;width:670px;padding:12px;background:#080808;border-radius:65px;overflow:hidden;transform:rotate(-4deg);box-shadow:0 43px 76px #0006,inset 0 0 0 2.7px #ffffff55}}
.phone img{{display:block;width:100%;height:auto;border-radius:53px}}
.palette-stack{{position:relative;width:100%;aspect-ratio:9/20;border-radius:53px;overflow:hidden}}
.slice{{position:absolute;inset:0}}
.panel-02-filters::before{{left:500px;top:-180px;width:900px;height:1900px;transform:rotate(18deg);border-radius:430px}}
.panel-02-filters::after{{display:none}}
.panel-02-filters h1{{top:1570px;right:90px}}
.panel-02-filters .phone{{top:85px;left:210px;width:640px;transform:rotate(3deg)}}
.panel-03-origins::before{{left:-110px;top:620px;width:1300px;height:1300px;transform:none}}
.panel-03-origins::after{{left:-160px;top:570px;width:1400px;height:1400px;transform:none}}
.panel-03-origins h1{{text-align:center}}
.panel-03-origins .phone{{top:405px;left:205px;transform:none}}
.panel-04-saved::before{{left:-170px;top:240px;width:760px;height:1800px;border-radius:380px;transform:rotate(12deg)}}
.panel-04-saved::after{{display:none}}
.panel-04-saved h1{{top:100px;right:70px}}
.panel-04-saved .phone{{top:430px;left:150px;transform:rotate(5deg)}}
.panel-05-appearance::before{{left:650px;top:270px;width:800px;height:1700px;border-radius:400px;transform:rotate(15deg)}}
.panel-05-appearance::after{{left:95px;top:545px;width:22px;height:1110px;border:0;border-radius:12px;transform:none;background:linear-gradient(to bottom,#8b7951 0% 16.67%,#42634c 16.67% 33.33%,#3d6671 33.33% 50%,#665172 50% 66.67%,#794c60 66.67% 83.33%,#8b6b34 83.33%)}}
.panel-05-appearance .phone{{left:245px;transform:rotate(4deg)}}
.panel-06-sources::before{{left:-340px;top:-420px;width:1520px;height:1700px;transform:rotate(25deg)}}
.panel-06-sources::after{{display:none}}
.panel-06-sources .phone{{top:90px;left:205px;transform:rotate(-2deg)}}
.panel-06-sources h1{{top:1610px;left:70px;right:70px;font-size:94px;text-align:center}}
</style><body class="panel-{name}"><h1>{headline}</h1><div class="phone">{content}</div></html>'''


def rgb_png(path):
    """Verify the dimensions and opaque RGB encoding of an export."""
    # Chromium exports opaque screenshots as RGB; reject anything else.
    data = path.read_bytes()
    width, height, depth, color = struct.unpack('>IIBB', data[16:26])
    if (width, height, depth, color) != (1080, 1920, 8, 2):
        raise ValueError(f'{path}: expected 1080x1920 RGB PNG, got {width}x{height}, depth {depth}, color {color}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browser', default=shutil.which('chromium') or shutil.which('google-chrome'))
    args = parser.parse_args()
    if not args.browser:
        parser.error('Install Chromium or pass --browser /path/to/chromium')
    output = DEST / 'phone'
    templates = ROOT / 'build/store-screenshots'
    templates.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    for name in SOURCE_NAMES:
        source = DEST / 'sources' / f'{name}.png'
        dimensions = struct.unpack('>II', source.read_bytes()[16:24])
        if dimensions != (1080, 2400):
            raise ValueError(f'{source}: expected 1080x2400, got {dimensions}')
    for panel in PANELS:
        name = panel[0]
        html = artwork(*panel)
        (templates / f'{name}.html').write_text(html)
        with tempfile.TemporaryDirectory(prefix='hadith-store-') as profile:
            subprocess.run([args.browser, '--headless', '--no-sandbox', '--disable-gpu', '--hide-scrollbars',
                '--disable-dev-shm-usage', '--run-all-compositor-stages-before-draw',
                '--no-pdf-header-footer', '--force-device-scale-factor=1', '--window-size=1080,1920',
                '--virtual-time-budget=2500', f'--user-data-dir={profile}',
                f'--screenshot={output / (name + ".png")}', (templates / f'{name}.html').as_uri()],
                check=True, timeout=60, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        rgb_png(output / f'{name}.png')
        print(f'Verified {name}.png: 1080 × 1920, RGB')
    # The gallery uses the exact exported PNGs rather than a second rendering.
    cards = ''.join(f'<a href="phone/{p[0]}.png"><img src="phone/{p[0]}.png" alt="{p[1].replace(chr(10), " ")}"></a>' for p in PANELS)
    gallery = f'''<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Hadith Searcher store screenshots</title><style>body{{margin:0;font-family:sans-serif}}main{{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}}img{{display:block;width:100%;border-radius:12px}}@media(max-width:500px){{main{{grid-template-columns:minmax(0,1fr)}}}}</style><main>{cards}</main></html>'''
    (DEST / 'index.html').write_text(gallery)
    with zipfile.ZipFile(templates / 'hadith-searcher-store-ar.zip', 'w', zipfile.ZIP_DEFLATED) as bundle:
        for name, *_ in PANELS:
            bundle.write(output / f'{name}.png', f'{name}.png')


if __name__ == '__main__':
    main()

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
    ('01-search', 'ابحث في أحاديث\nالنبي ﷺ', 'نص الحديث، ومصدره، وحكم المحدث في مكان واحد.', False),
    ('02-filters', 'اجعل بحثك\nأكثر دقة', 'اختر الدرجة والمحدث والكتاب والراوي.', False),
    ('03-details', 'تعرّف على\nمصادر الحديث', 'اطّلع على التخريج والتصنيف وأصول الحديث.', False),
    ('04-saved', 'احتفظ بما\nتريد مراجعته', 'أحاديثك المحفوظة متاحة دون اتصال.', True),
    ('05-appearance', 'اقرأ بالطريقة\nالتي تناسبك', 'اختر الألوان والخط وحجم النص.', False),
    ('06-dark', 'قراءة هادئة\nبالمظهر الداكن', 'انتقل بين المظهر الفاتح والداكن.', True),
]


def data_url(path, mime):
    return f'data:{mime};base64,' + base64.b64encode(path.read_bytes()).decode()


def artwork(name, title, subtitle, dark):
    bg, fg, muted = ('#000000', '#FFFFFF', '#BCC0C7') if dark else ('#E1E2E6', '#000000', '#45474D')
    font = data_url(ROOT / 'assets/fonts/Cairo-Variable.ttf', 'font/ttf')
    logo = data_url(ROOT / ('assets/icons/logo_light.svg' if dark else 'assets/icons/logo.svg'), 'image/svg+xml')
    screen = data_url(DEST / 'sources' / f'{name}.png', 'image/png')
    headline = title.replace('\n', '<br>')
    return f'''<!doctype html><html lang="ar" dir="ltr"><meta charset="utf-8">
<style>
@font-face{{font-family:Cairo;src:url({font});font-weight:200 1000}}
*{{box-sizing:border-box}}html,body{{margin:0;width:1080px;height:1920px;overflow:hidden;position:relative}}
body{{background:{bg};color:{fg};font-family:Cairo,sans-serif}}
.brand{{direction:rtl;position:absolute;top:52px;right:80px;display:flex;align-items:center;gap:20px;font-size:30px;font-weight:700}}
.brand img{{width:58px;height:58px}}
h1{{direction:rtl;text-align:right;position:absolute;top:136px;right:80px;left:80px;margin:0;font-size:80px;line-height:1.48;font-weight:800;letter-spacing:0}}
p{{direction:rtl;text-align:right;position:absolute;top:382px;right:80px;left:60px;margin:0;font-size:30px;line-height:1.8;color:{muted};font-weight:500}}
.orbit{{position:absolute;width:1450px;height:1450px;border:2px solid {fg};border-radius:50%;opacity:.09;top:690px;right:-185px}}
.orbit:after{{content:'';position:absolute;inset:100px;border:2px solid {fg};border-radius:50%}}
.phone{{position:absolute;top:505px;left:228px;width:624px;padding:10px;background:#000;border:2px solid #656970;border-radius:48px;box-shadow:0 25px 50px #0003}}
.phone img{{display:block;width:600px;height:auto;border-radius:36px}}
</style><div class="orbit"></div><div class="brand"><img src="{logo}" alt=""><span dir="ltr">Hadith Searcher</span></div>
<h1>{headline}</h1><p>{subtitle}</p><div class="phone"><img src="{screen}" alt="واجهة التطبيق الحالية"></div></html>'''


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
    for name, *_ in PANELS:
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
<title>Hadith Searcher store screenshots</title><style>body{{margin:0;font-family:sans-serif}}main{{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}}img{{display:block;width:100%;border-radius:12px}}@media(max-width:500px){{main{{grid-template-columns:repeat(2,minmax(0,1fr))}}}}</style><main>{cards}</main></html>'''
    (DEST / 'index.html').write_text(gallery)
    with zipfile.ZipFile(templates / 'hadith-searcher-store-ar.zip', 'w', zipfile.ZIP_DEFLATED) as bundle:
        for name, *_ in PANELS:
            bundle.write(output / f'{name}.png', f'{name}.png')


if __name__ == '__main__':
    main()

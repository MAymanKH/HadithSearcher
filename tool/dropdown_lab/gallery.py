#!/usr/bin/env python3
"""Build a portable comparison from the Flutter lab's captured screens."""
import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'build/dropdown-lab'
STYLES = ['outlined', 'soft', 'compact', 'current']
CONFIGS = ['ar-light', 'ar-dark', 'ar-forest', 'en-light', 'ar-large']
STATES = ['closed', 'single', 'multiple']
images = {}
for style in STYLES:
    for config in CONFIGS:
        for state in STATES:
            name = f'{style}-{config}-{state}'
            path = OUTPUT / f'{name}.png'
            if not path.exists():
                raise SystemExit('Capture screens first. See tool/dropdown_lab/README.md.')
            images[name] = 'data:image/png;base64,' + base64.b64encode(path.read_bytes()).decode()

html = '''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Dropdown experiments</title>
<style>
*{box-sizing:border-box}body{margin:0;color:var(--foreground,#202124);font-family:var(--font-sans,system-ui);font-size:14px}
.intro{margin:0 0 16px;line-height:1.6;color:var(--muted-foreground,#666)}
.controls{display:flex;flex-wrap:wrap;gap:10px;margin-bottom:18px;align-items:center}
label{display:flex;gap:8px;align-items:center}select,button{font:inherit;color:inherit;background:var(--card,#fff);border:1px solid var(--border,#ccc);border-radius:8px;padding:8px;cursor:pointer}button:focus-visible,select:focus-visible,input:focus-visible{outline:3px solid #5b8def;outline-offset:3px}
.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}.grid.baseline{grid-template-columns:repeat(4,minmax(0,1fr))}
article{min-width:0}h3{font-size:16px;margin:0 0 5px}p{line-height:1.5;margin:0 0 12px}.note{font-size:12px;color:var(--muted-foreground,#666);min-height:54px}.frame{padding:16px;border-radius:var(--radius,16px);background:var(--secondary,#ededee)}.screen{padding:0;border:0;display:block;width:100%;background:transparent}.screen img{display:block;width:100%;border-radius:8px}.hint{font-size:12px;margin-top:12px;color:var(--muted-foreground,#666)}
.recommendation{margin:18px 0 0;line-height:1.6}dialog{border:1px solid var(--border,#ccc);border-radius:16px;padding:16px;background:var(--card,#fff);color:inherit;max-width:95%;max-height:94vh}dialog::backdrop{background:#0009}dialog img{display:block;max-width:100%;max-height:78vh;margin-top:12px}dialog button{float:right}
@media(max-width:580px){.grid,.grid.baseline{grid-template-columns:repeat(2,minmax(0,1fr))}.frame{padding:16px}.note{min-height:72px}}
@media(max-width:360px){.grid,.grid.baseline{grid-template-columns:1fr}.note{min-height:0}}
</style>
<p class="intro">Three Flutter prototypes using the app's Cairo typeface, existing palettes, search field, and navigation. Compare fields and both kinds of selection sheet.</p>
<div class="controls">
<label>View <select id="state"><option value="closed">Dropdown fields</option><option value="single" selected>Single choice</option><option value="multiple">Searchable multi-select</option></select></label>
<label>Context <select id="config"><option value="ar-light">Arabic · Light</option><option value="ar-dark">Arabic · Dark</option><option value="ar-forest">Arabic · Forest</option><option value="en-light">English · Light</option><option value="ar-large">Arabic · Large text</option></select></label>
<label><input id="baseline" type="checkbox"> Include current</label>
</div>
<div class="grid" id="grid"></div>
<p class="hint">Tap any screen to inspect it at full size. These are captures of the working Flutter prototypes.</p>
<p class="recommendation">My pick is <strong>Outlined</strong>. It gives each field a clear boundary and keeps the choices quiet and easy to scan. <strong>Soft</strong> is closer to the current rounded controls. <strong>Compact</strong> gives the form more breathing room and keeps the sheet visibly separate.</p>
<dialog id="zoom"><button id="close">Close</button><img id="large" alt=""></dialog>
<script>
const images = __IMAGES__;
const styles = [
 ['outlined','Outlined','Fine borders, plain divided rows, a checkmark for the selected choice.'],
 ['soft','Soft','Filled fields, an inset list, and outlined selected rows with radio controls.'],
 ['compact','Compact','Underlined fields and a floating sheet with leading selection controls.'],
 ['current','Current','Existing filled inputs and full-width selection sheet.']
];
const grid=document.getElementById('grid'), state=document.getElementById('state'), config=document.getElementById('config'), baseline=document.getElementById('baseline'), zoom=document.getElementById('zoom');
function render(){
 grid.replaceChildren();grid.classList.toggle('baseline',baseline.checked);
 styles.filter(s=>baseline.checked||s[0]!=='current').forEach(([key,title,description])=>{
  const article=document.createElement('article');
  const heading=document.createElement('h3');heading.textContent=title;
  const note=document.createElement('p');note.className='note';note.textContent=description;
  const frame=document.createElement('div');frame.className='frame';
  const button=document.createElement('button');button.className='screen';button.setAttribute('aria-label','Enlarge '+title);
  const img=document.createElement('img');img.src=images[`${key}-${config.value}-${state.value}`];img.alt=`${title}, ${config.selectedOptions[0].text}, ${state.selectedOptions[0].text}`;
  button.onclick=()=>{document.getElementById('large').src=img.src;document.getElementById('large').alt=img.alt;zoom.showModal()};
  button.append(img);frame.append(button);article.append(heading,note,frame);grid.append(article);
 });
}
[state,config,baseline].forEach(el=>el.addEventListener('change',render));
document.getElementById('close').onclick=()=>zoom.close();zoom.onclick=e=>{if(e.target===zoom)zoom.close()};render();
</script></html>'''.replace('__IMAGES__', json.dumps(images))
OUTPUT.mkdir(parents=True, exist_ok=True)
(OUTPUT / 'index.html').write_text(html)
local_images = {name: str(OUTPUT / f'{name}.png') for name in images}
(OUTPUT / 'preview.html').write_text(html.replace(json.dumps(images), json.dumps(local_images)))
print(OUTPUT / 'index.html')

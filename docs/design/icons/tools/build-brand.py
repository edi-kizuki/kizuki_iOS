import re, os, json, subprocess
ROOT='/Users/edisonabdiel/Projects/kizuki_iOS'
ICONS=f'{ROOT}/docs/design/icons'
FIG=f'{ICONS}/figma'
cat=f'{ROOT}/ios/Packages/KizukiKit/Sources/KizukiDesignSystem/Resources/KizukiIcons.xcassets'
os.makedirs(f'{ICONS}/brand',exist_ok=True); os.makedirs(f'{ICONS}/app-icon',exist_ok=True)
def paths(f):
    s=open(f'{FIG}/{f}').read()
    return [(m.group(1),m.group(2)) for m in re.finditer(r'<path id="[^"]*" d="([^"]+)" fill="([^"]+)"',s)], s
def imageset(name, svg):
    d=f'{cat}/{name}.imageset'; os.makedirs(d,exist_ok=True)
    open(f'{d}/{name}.svg','w').write(svg)
    json.dump({'images':[{'filename':f'{name}.svg','idiom':'universal'}],'info':{'author':'xcode','version':1},
               'properties':{'preserves-vector-representation':True,'template-rendering-intent':'template'}},open(f'{d}/Contents.json','w'),indent=2)

# Wordmark: all dark paths, no background rects (the cream rect is the Figma frame, not artwork)
ps,s=paths('wordmark-614-262.svg')
print('wordmark paths',[(c,len(d)) for d,c in ps])
body=''.join(f'<path d="{d}"/>' for d,c in ps if c.upper()=='#1A1A1A')
wm=f'<svg xmlns="http://www.w3.org/2000/svg" width="237" height="92" viewBox="0 0 474 184" fill="#000000" fill-rule="evenodd">{body}</svg>\n'
open(f'{ICONS}/brand/kizuki-wordmark.svg','w').write(wm.replace('#000000','#1A1A1A'))
imageset('KizukiWordmark', wm)

# K mark: body + eye holes (evenodd) + pupils
ps,s=paths('k-mark-eyes-614-372.svg')
print('k paths',[(c,len(d)) for d,c in ps])
body=ps[0][0]; whites=[d for d,c in ps[1:] if c.upper()=='#F2EEE7']; pupils=[d for d,c in ps[1:] if c.upper()=='#1A1A1A']
def kmark(fill, tile=None):
    d=body+' '+' '.join(whites)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="145" height="278" viewBox="0 0 290 557" fill="{fill}">'
            f'<path d="{d}" fill-rule="evenodd"/>'+''.join(f'<path d="{p}"/>' for p in pupils)+'</svg>\n')
open(f'{ICONS}/brand/kizuki-k-mark-ink.svg','w').write(kmark('#1A1A1A'))
open(f'{ICONS}/brand/kizuki-k-mark-orange.svg','w').write(kmark('#FF6139'))
imageset('KizukiKMark', kmark('#000000'))

# App icon: Figma "icon - edid this" 614:319 (cream F2EEE7 tile + black K with eye cut-outs). iOS applies its own mask, so the
# artwork is a full-bleed square, not the rounded tile Figma shows.
ps,s=paths('app-icon-artwork-614-319.svg')
kd=ps[0][0]
def icon(bg,fg):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 293 293"><rect width="293" height="293" fill="{bg}"/>'
            f'<path d="{kd}" fill="{fg}" fill-rule="evenodd"/></svg>\n')
variants={'app-icon-light':('#F2EEE7','#1A1A1A'),'app-icon-dark':('#1A1A1A','#FF6139'),'app-icon-tinted':('#000000','#FFFFFF')}
for n,(bg,fg) in variants.items():
    open(f'{ICONS}/app-icon/{n}.svg','w').write(icon(bg,fg))

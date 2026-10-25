import re, os, json, shutil
ROOT='/Users/edisonabdiel/Projects/kizuki_iOS'
ICONS=f'{ROOT}/docs/design/icons'
cat=f'{ROOT}/ios/Packages/KizukiKit/Sources/KizukiDesignSystem/Resources/KizukiIcons.xcassets'
FIG='/tmp/kz_fig'
os.makedirs(f'{ICONS}/figma',exist_ok=True); os.makedirs(f'{ICONS}/brand',exist_ok=True)
def strip(s): return s.replace('preserveAspectRatio="none" overflow="visible" style="display: block;" ','')
def imageset(name, svg, template=True):
    d=f'{cat}/{name}.imageset'; shutil.rmtree(d,ignore_errors=True); os.makedirs(d)
    open(f'{d}/{name}.svg','w').write(svg)
    props={'preserves-vector-representation':True}
    if template: props['template-rendering-intent']='template'
    json.dump({'images':[{'filename':f'{name}.svg','idiom':'universal'}],'info':{'author':'xcode','version':1},'properties':props},open(f'{d}/Contents.json','w'),indent=2)
# raw exports
shutil.copy(f'{FIG}/feedlogo.svg',f'{ICONS}/figma/feed-logo-1312-8143.svg')
shutil.copy(f'{FIG}/gear.svg',f'{ICONS}/figma/feed-nav-settings-I1312-8142-414-5049.svg')
shutil.copy(f'{FIG}/chat.svg',f'{ICONS}/figma/feed-nav-messages-I1312-8142-414-5047.svg')
shutil.copy(f'{ROOT}/docs/design/illustrations/vector/illustration-12.svg',f'{ICONS}/figma/suki-mascot-614-9214.svg')
# feed logo: keep Figma colours (blue K, dark eyes); drop wrapper rects + clip
s=open(f'{FIG}/feedlogo.svg').read()
paths=re.findall(r'<path id="[^"]*" d="([^"]+)" fill="([^"]+)"',s)
body=''.join(f'<path d="{d}" fill="{c}"/>' for d,c in paths)
logo=f'<svg xmlns="http://www.w3.org/2000/svg" width="22" height="42.2346" viewBox="0 0 22 42.2346">{body}</svg>\n'
open(f'{ICONS}/brand/kizuki-feed-logo-blue.svg','w').write(logo)
imageset('KizukiFeedLogo', logo, template=False)
imageset('IconSettings', strip(open(f'{FIG}/gear.svg').read()))
imageset('IconMessages', strip(open(f'{FIG}/chat.svg').read()))
imageset('SukiMascot', strip(open(f'{ROOT}/docs/design/illustrations/vector/illustration-12.svg').read()))
print(paths and [c for d,c in paths])

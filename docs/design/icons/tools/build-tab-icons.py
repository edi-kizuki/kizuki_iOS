import re, os, shutil, json
ROOT='/Users/edisonabdiel/Projects/kizuki_iOS'
ICONS=f'{ROOT}/docs/design/icons'
TRACE='/tmp/kz_trace'
names={
 'i00':'current-home-cat-head','i01':'current-search-pixel-magnifier','i02':'current-suki-eye-disc','i03':'current-projects-drawer','i04':'current-profile-bust',
 'i05':'alt-home-polaroid-star','i10':'alt-home-tiles-star','i15':'alt-home-stacked-cards',
 'i06':'alt-search-magnifier-star','i11':'alt-search-eye-star','i16':'alt-search-blob-lens','i20':'alt-search-magnifier-star-2','i24':'alt-search-eye-rays-magnifier',
 'i07':'alt-suki-blob-plus','i12':'alt-suki-brush-plus','i18':'alt-suki-clover-plus','i21':'alt-suki-bracket-plus',
 'i08':'alt-projects-open-book','i13':'alt-projects-cards-bookmark','i19':'alt-projects-folder-star','i22':'alt-projects-stacked-cards-star','i25':'alt-projects-card-fan',
 'i09':'alt-profile-horned-head','i14':'alt-profile-medusa','i17':'alt-profile-head-closed-eye','i23':'alt-profile-bust-starburst'}
os.makedirs(f'{ICONS}/sheet-traced',exist_ok=True)
def clean(i, fill, size=None):
    s=open(f'{TRACE}/{i}.svg').read()
    vb=re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"',s); W,H=float(vb.group(1)),float(vb.group(2))
    d=re.findall(r'<path d="([^"]+)"',s)
    d=' '.join(' '.join(x.split()) for x in d)
    S=max(W,H); ox=(S-W)/2; oy=(S-H)/2
    sz=size or 30
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{sz}" height="{sz}" viewBox="0 0 {S:g} {S:g}">\n'
            f'<g transform="translate({ox:g} {oy:g})"><g transform="translate(0 {H:g}) scale(0.1 -0.1)" fill="{fill}" stroke="none" fill-rule="evenodd">'
            f'<path d="{d}"/></g></g>\n</svg>\n')
for i,n in names.items():
    open(f'{ICONS}/sheet-traced/{n}.svg','w').write(clean(i,'#F2EEE7'))
# asset-catalog versions (template, black fill) for the five chosen tab icons
chosen={'TabHome':'i05','TabSearch':'i06','TabSuki':'i02','TabMyProjects':'i19','TabProfile':'i23'}
cat=f'{ROOT}/ios/Packages/KizukiKit/Sources/KizukiDesignSystem/Resources/KizukiIcons.xcassets'
shutil.rmtree(cat,ignore_errors=True); os.makedirs(cat)
json.dump({'info':{'author':'xcode','version':1}},open(f'{cat}/Contents.json','w'),indent=2)
def imageset(name, svg, template=True):
    d=f'{cat}/{name}.imageset'; os.makedirs(d)
    open(f'{d}/{name}.svg','w').write(svg)
    props={'preserves-vector-representation':True}
    if template: props['template-rendering-intent']='template'
    json.dump({'images':[{'filename':f'{name}.svg','idiom':'universal'}],'info':{'author':'xcode','version':1},'properties':props},open(f'{d}/Contents.json','w'),indent=2)
for name,i in chosen.items(): imageset(name, clean(i,'#000000'))
print('ok')

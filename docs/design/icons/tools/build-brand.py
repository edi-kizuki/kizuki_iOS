"""Render original app icons. Related: [[README]], [[Header appearance experiment]]."""

from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ElementTree

ROOT = Path(__file__).resolve().parents[4]
ICONS = ROOT / "docs/design/icons"
APP_ICONS = ROOT / "ios/App/Assets.xcassets/AppIcon.appiconset"
(ICONS / "app-icon").mkdir(parents=True, exist_ok=True)
namespace = "{http://www.w3.org/2000/svg}"
source = ElementTree.parse(ICONS / "figma/app-icon-artwork-614-319.svg")
paths = source.findall(f".//{namespace}path")
assert len(paths) == 1, "Expected the original K artwork with eye cut-outs"
artwork = paths[0]
artwork.set("fill-rule", "evenodd")
ElementTree.register_namespace("", "http://www.w3.org/2000/svg")
variants = [
    ("light", "#F2EEE7", "#1A1A1A", "AppIcon.png"),
    ("dark", "#1A1A1A", "#E95833", "AppIcon-Dark.png"),
    ("tinted", "#000000", "#FFFFFF", "AppIcon-Tinted.png"),
]
for name, background, foreground, filename in variants:
    artwork.set("fill", foreground)
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 293 293">'
        '<metadata>Related: [[README]], [[Header appearance experiment]]</metadata>'
        f'<rect width="293" height="293" fill="{background}"/>'
        f'{ElementTree.tostring(artwork, encoding="unicode")}</svg>\n'
    )
    source_path = ICONS / f"app-icon/app-icon-{name}.svg"
    output_path = ICONS / f"app-icon/app-icon-{name}-1024.png"
    source_path.write_text(svg)
    subprocess.run(["rsvg-convert", str(source_path), "-o", str(output_path)], check=True)
    shutil.copyfile(output_path, APP_ICONS / filename)

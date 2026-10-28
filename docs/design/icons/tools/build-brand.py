"""Regenerate approved brand artwork. Related: [[README]], [[Header appearance experiment]]."""

from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ElementTree

ROOT = Path(__file__).resolve().parents[4]
ICONS = ROOT / "docs/design/icons"
CATALOG = ROOT / "ios/Packages/KizukiKit/Sources/KizukiDesignSystem/Resources/KizukiIcons.xcassets"
APP_ICONS = ROOT / "ios/App/Assets.xcassets/AppIcon.appiconset"
for directory in [ICONS / "brand", ICONS / "app-icon"]:
    directory.mkdir(parents=True, exist_ok=True)


def source(name):
    return (ICONS / "figma" / name).read_text()


def write_svg(path, content):
    path.write_text(content)


wordmark = source("wordmark-570-167.svg")
mark = source("k-mark-570-175.svg")
write_svg(ICONS / "brand/kizuki-wordmark.svg", wordmark)
write_svg(ICONS / "brand/kizuki-k-mark-ink.svg", mark)
write_svg(ICONS / "brand/kizuki-k-mark-orange.svg", mark.replace("#1A1A1A", "#E95833"))
for name, artwork in [("KizukiWordmark", wordmark), ("KizukiKMark", mark), ("KizukiFeedLogo", mark)]:
    write_svg(CATALOG / f"{name}.imageset/{name}.svg", artwork)

artwork = ElementTree.fromstring(source("app-icon-mark-570-178.svg"))
artwork.set("x", "85.85")
artwork.set("y", "17.06")
artwork.set("width", "130.51")
artwork.set("height", "248.31")
ElementTree.register_namespace("", "http://www.w3.org/2000/svg")
variants = [
    ("light", "#F2EEE7", "#1A1A1A", "AppIcon.png"),
    ("dark", "#1A1A1A", "#EBAF41", "AppIcon-Dark.png"),
    ("tinted", "#000000", "#FFFFFF", "AppIcon-Tinted.png"),
]
for name, background, foreground, filename in variants:
    nested = ElementTree.tostring(artwork, encoding="unicode").replace("#1A1A1A", foreground)
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 293 293">'
        f'<rect width="293" height="293" fill="{background}"/>{nested}</svg>\n'
    )
    source_path = ICONS / f"app-icon/app-icon-{name}.svg"
    output_path = ICONS / f"app-icon/app-icon-{name}-1024.png"
    write_svg(source_path, svg)
    subprocess.run(["rsvg-convert", str(source_path), "-o", str(output_path)], check=True)
    shutil.copyfile(output_path, APP_ICONS / filename)

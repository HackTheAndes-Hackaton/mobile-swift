#!/usr/bin/env python3
"""Extract Tiskz Android vector artwork and Tabler ImageVectors into Xcode assets."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
AAPT_NS = "{http://schemas.android.com/aapt}"
ICON_NAMES = [
    "Activity", "AlertTriangle", "ArrowLeft", "Backspace", "Ban", "ChevronLeft",
    "ChevronRight", "ExternalLink", "Fingerprint", "GridDots", "Headset", "Microphone",
    "MicrophoneOff", "Phone", "PhoneIncoming", "PhoneOff", "PhoneOutgoing", "Search",
    "Settings", "ShieldCheck", "ShieldOff", "ShieldX", "Star", "User", "UserPlus", "Users", "Volume",
]
COMMANDS = {
    "moveTo": "M", "moveToRelative": "m", "lineTo": "L", "lineToRelative": "l",
    "horizontalLineToRelative": "h", "verticalLineToRelative": "v", "curveToRelative": "c",
    "arcTo": "A", "arcToRelative": "a", "close": "Z",
}


def android_attr(element: ET.Element, name: str, default: str = "") -> str:
    return element.attrib.get(ANDROID_NS + name, default)


def asset_set(root: Path, name: str, svg: str) -> None:
    folder = root / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{name}.svg").write_text(svg.rstrip() + "\n", encoding="utf-8")
    contents = {
        "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def android_color(value: str) -> tuple[str, str]:
    raw = value.removeprefix("#")
    if len(raw) == 8:
        alpha, rgb = raw[:2], raw[2:]
        return f"#{rgb}", "1" if alpha.lower() == "ff" else f"{int(alpha, 16) / 255:.6f}"
    if len(raw) == 6:
        return f"#{raw}", "1"
    raise ValueError(f"Unsupported Android vector color: {value}")


def stop_list(gradient: ET.Element) -> str:
    stops = []
    for item in gradient.findall("item"):
        color, opacity = android_color(android_attr(item, "color"))
        offset = android_attr(item, "offset", "0")
        stops.append(f'<stop offset="{offset}" stop-color="{color}" stop-opacity="{opacity}"/>')
    return "".join(stops)


def extract_brand_vectors(android_res: Path, output: Path) -> None:
    drawable = android_res / "drawable"
    shield_root = ET.parse(drawable / "ic_tiskz_shield.xml").getroot()
    group = shield_root.find("group")
    shield = shield_root.find(".//path")
    if group is None or shield is None:
        raise ValueError("The original Tiskz shield vector is incomplete")
    scale_x = android_attr(group, "scaleX", "1")
    scale_y = android_attr(group, "scaleY", "1")
    translate_x = android_attr(group, "translateX", "0")
    translate_y = android_attr(group, "translateY", "0")
    width = android_attr(shield_root, "width", "24dp").removesuffix("dp")
    height = android_attr(shield_root, "height", "24dp").removesuffix("dp")
    shield_svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <path d="{android_attr(shield, 'pathData')}" transform="matrix({scale_x} 0 0 {scale_y} {translate_x} {translate_y})" fill="#FFFFFF" fill-rule="evenodd"/>
</svg>'''
    asset_set(output, "BrandShield", shield_svg)

    foreground_root = ET.parse(drawable / "ic_launcher_foreground.xml").getroot()
    foreground_paths = foreground_root.findall("path")
    if len(foreground_paths) != 3:
        raise ValueError("The original launcher foreground vector changed shape")
    shadow, shield, waves = foreground_paths
    shadow_color, shadow_opacity = android_color(android_attr(shadow, "fillColor"))
    shield_color, shield_opacity = android_color(android_attr(shield, "fillColor"))
    gradient = waves.find(f"{AAPT_NS}attr/gradient")
    if gradient is None:
        raise ValueError("The original launcher wave gradient is missing")
    sx, sy = android_attr(gradient, "startX"), android_attr(gradient, "startY")
    ex, ey = android_attr(gradient, "endX"), android_attr(gradient, "endY")
    foreground_svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="108" height="108" viewBox="0 0 108 108">
  <defs><linearGradient id="waves" x1="{sx}" y1="{sy}" x2="{ex}" y2="{ey}" gradientUnits="userSpaceOnUse">{stop_list(gradient)}</linearGradient></defs>
  <path d="{android_attr(shadow, 'pathData')}" fill="{shadow_color}" fill-opacity="{shadow_opacity}"/>
  <path d="{android_attr(shield, 'pathData')}" fill="{shield_color}" fill-opacity="{shield_opacity}"/>
  <path d="{android_attr(waves, 'pathData')}" fill="url(#waves)"/>
</svg>'''
    asset_set(output, "LauncherForeground", foreground_svg)

    background_root = ET.parse(drawable / "ic_launcher_background.xml").getroot()
    paths = background_root.findall("path")
    if len(paths) != 2:
        raise ValueError("The original launcher background vector changed shape")
    gradient = paths[0].find(f"{AAPT_NS}attr/gradient")
    if gradient is None:
        raise ValueError("The original launcher background gradient is missing")
    sx, sy = android_attr(gradient, "startX"), android_attr(gradient, "startY")
    ex, ey = android_attr(gradient, "endX"), android_attr(gradient, "endY")
    tint, opacity = android_color(android_attr(paths[1], "fillColor"))
    background_svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="108" height="108" viewBox="0 0 108 108">
  <defs><linearGradient id="background" x1="{sx}" y1="{sy}" x2="{ex}" y2="{ey}" gradientUnits="userSpaceOnUse">{stop_list(gradient)}</linearGradient></defs>
  <path d="{android_attr(paths[0], 'pathData')}" fill="url(#background)"/>
  <path d="{android_attr(paths[1], 'pathData')}" fill="{tint}" fill-opacity="{opacity}"/>
</svg>'''
    asset_set(output, "LauncherBackground", background_svg)

    mono_root = ET.parse(drawable / "ic_launcher_monochrome.xml").getroot()
    mono = mono_root.find("path")
    if mono is None:
        raise ValueError("The original monochrome shield vector is missing")
    mono_svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="108" height="108" viewBox="0 0 108 108">
  <path d="{android_attr(mono, 'pathData')}" fill="#FFFFFF" fill-rule="evenodd"/>
</svg>'''
    asset_set(output, "LauncherMonochrome", mono_svg)


def constant(line: str):
    match = re.search(r"// float (-?[0-9.]+)f?\s*$", line)
    if match:
        return match.group(1)
    match = re.search(r"fconst_([012])\s*$", line)
    if match:
        return match.group(1)
    match = re.search(r"iconst_([01])\s*$", line)
    if match:
        return match.group(1)
    return None


def param_count(descriptor: str) -> int:
    raw = descriptor.split(")", 1)[0].removeprefix("(")
    return sum(1 for char in raw if char in "FZ")


def extract_image_vector(class_name: str, jar: Path) -> str:
    fqcn = f"compose.icons.tablericons.{class_name}Kt"
    output = subprocess.run(["javap", "-classpath", str(jar), "-c", "-p", fqcn], check=True, text=True, capture_output=True).stdout
    pieces: list[str] = []
    pending: list[str] = []
    for line in output.splitlines():
        if "new" in line and "PathBuilder" in line:
            pending.clear()
            continue
        call = re.search(r"PathBuilder\.([A-Za-z]+):\(([^)]*)\)", line)
        if call:
            method, descriptor = call.groups()
            if method in COMMANDS:
                count = param_count(descriptor)
                values = pending[-count:] if count else []
                if len(values) != count:
                    raise ValueError(f"Could not read {method} parameters for Tabler {class_name}: {pending}")
                command = COMMANDS[method]
                if command == "Z":
                    pieces.append(command)
                elif command in {"a", "A"}:
                    if len(values) != 7:
                        raise ValueError(f"Unexpected arc in Tabler {class_name}: {values}")
                    pieces.append(command + " " + " ".join(values))
                else:
                    pieces.append(command + " " + " ".join(values))
            pending.clear()
            continue
        value = constant(line)
        if value is not None:
            pending.append(value)
    if not pieces:
        raise ValueError(f"No vector path extracted for {class_name}")
    return " ".join(pieces)


def extract_tabler_vectors(aar: Path, output: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="tiskz-tabler-") as temp:
        root = Path(temp)
        with zipfile.ZipFile(aar) as archive:
            archive.extract("classes.jar", root)
        jar = root / "classes.jar"
        for name in ICON_NAMES:
            path = extract_image_vector(name, jar)
            svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
  <path d="{path}" stroke="#000000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>'''
            asset_set(output, f"Tabler{name}", svg)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--android-res", type=Path, required=True, help="Path to mobile-repo/app/src/main/res")
    parser.add_argument("--tabler-aar", type=Path, required=True, help="tabler-icons-android 1.1.1 AAR from the Gradle cache")
    parser.add_argument("--output", type=Path, required=True, help="Xcode Assets.xcassets directory")
    args = parser.parse_args()
    extract_brand_vectors(args.android_res, args.output)
    extract_tabler_vectors(args.tabler_aar, args.output)
    print(f"Extracted 4 original Tiskz vectors and {len(ICON_NAMES)} Tabler icons into {args.output}")


if __name__ == "__main__":
    main()

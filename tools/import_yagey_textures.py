#!/usr/bin/env python3
"""Import YAGEY PNGs into existing Donorcraft texture slots.

A source texture is copied to every exact basename/suffix match within its
asset category's allowed mod groups. This handles duplicated shared textures
(e.g. the same block image shipped by CORE and ITEMS) instead of skipping them.
Files with no compatible target are reported and left untouched.
"""
from pathlib import Path
from zipfile import ZipFile
import shutil

ROOT = Path(".")
ARCHIVE = ROOT / "yagey.zip"
TEXTURE_ROOT = ROOT / "mods"
CATEGORY_SCOPES = {
    "block": ("CORE", "ITEMS"),
    "item": ("ITEMS",),
    "entity": ("ENTITIES",),
    "particle": ("CORE", "ENTITIES", "ITEMS"),
    "gui": ("CORE", "ITEMS"),
    "environment": ("CORE",),
    "misc": ("CORE", "ITEMS"),
    "mob_effect": ("CORE",),
    "map": ("CORE", "ITEMS"),
    "painting": ("CORE", "ITEMS"),
    "trims": ("ITEMS", "ENTITIES"),
    "font": ("CORE",),
    "colormap": ("CORE",),
    "effect": ("CORE",),
}

def main():
    if not ARCHIVE.is_file():
        raise SystemExit("yagey.zip was not found in repository root")

    targets = {}
    for path in TEXTURE_ROOT.rglob("*.png"):
        if "textures" not in path.parts:
            continue
        try:
            group = path.parts[path.parts.index("mods") + 1]
        except (ValueError, IndexError):
            continue
        targets.setdefault(group, []).append(path)

    copied_sources = 0
    changed_targets = set()
    unchanged_targets = set()
    unmatched = []
    ambiguous_sources = 0

    with ZipFile(ARCHIVE) as archive:
        bad = archive.testzip()
        if bad:
            raise SystemExit(f"Corrupt ZIP entry: {bad}")

        for info in archive.infolist():
            if info.is_dir() or not info.filename.lower().endswith(".png"):
                continue
            parts = Path(info.filename).parts
            if len(parts) < 2:
                continue
            category = parts[0].lower()
            if category not in CATEGORY_SCOPES:
                continue

            source_stem = Path(parts[-1]).stem.lower()
            matches = []
            for group in CATEGORY_SCOPES[category]:
                for target in targets.get(group, ()):
                    target_stem = target.stem.lower()
                    if target_stem == source_stem or target_stem.endswith("_" + source_stem):
                        matches.append(target)

            matches = sorted(set(matches))
            if not matches:
                unmatched.append(info.filename)
                continue
            if len(matches) > 1:
                ambiguous_sources += 1

            with archive.open(info) as src:
                data = src.read()
            for target in matches:
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.exists() and target.read_bytes() == data:
                    unchanged_targets.add(str(target))
                    continue
                target.write_bytes(data)
                changed_targets.add(str(target))
            copied_sources += 1

    print("YAGEY import summary:")
    print(f"  source PNGs mapped: {copied_sources}")
    print(f"  target files changed: {len(changed_targets)}")
    print(f"  target files already identical: {len(unchanged_targets)}")
    print(f"  source PNGs with multiple valid targets: {ambiguous_sources}")
    print(f"  source PNGs without a compatible existing slot: {len(unmatched)}")
    if changed_targets:
        print("Changed targets (first 40):")
        for name in sorted(changed_targets)[:40]:
            print("  " + name)
    if unmatched:
        print("Unmatched source assets (not forced into incompatible slots; first 60):")
        for name in unmatched[:60]:
            print("  " + name)

if __name__ == "__main__":
    main()

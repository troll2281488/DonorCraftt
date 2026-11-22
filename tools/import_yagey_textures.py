#!/usr/bin/env python3
"""Import YAGEY Minecraft-style assets into matching Donorcraft texture slots.

Only unambiguous basename matches are copied. Ambiguous or unmatched assets are
reported instead of overwriting unrelated textures.
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
    for p in TEXTURE_ROOT.rglob("*.png"):
        if "textures" not in p.parts:
            continue
        try:
            group = p.parts[p.parts.index("mods") + 1]
        except (ValueError, IndexError):
            continue
        targets.setdefault(group, []).append(p)

    copied, ambiguous, missing = [], [], []
    with ZipFile(ARCHIVE) as z:
        for info in z.infolist():
            if info.is_dir() or not info.filename.lower().endswith(".png"):
                continue
            parts = Path(info.filename).parts
            if len(parts) < 2 or parts[0].lower() not in CATEGORY_SCOPES:
                continue
            category = parts[0].lower()
            source_name = Path(parts[-1]).name.lower()
            stem = source_name[:-4]
            candidates = []
            for group in CATEGORY_SCOPES[category]:
                for target in targets.get(group, ()):
                    name = target.name.lower()
                    target_stem = name[:-4] if name.endswith(".png") else name
                    if target_stem == stem or target_stem.endswith("_" + stem):
                        candidates.append(target)
            # A source file is copied only when exactly one target slot matches.
            unique = sorted(set(candidates))
            if len(unique) == 1:
                dest = unique[0]
                dest.parent.mkdir(parents=True, exist_ok=True)
                with z.open(info) as src, dest.open("wb") as out:
                    shutil.copyfileobj(src, out)
                copied.append((info.filename, str(dest)))
            elif unique:
                ambiguous.append((info.filename, len(unique)))
            else:
                missing.append(info.filename)

    print(f"YAGEY import: copied={len(copied)}, ambiguous={len(ambiguous)}, unmatched={len(missing)}")
    if copied:
        print("First imported files:")
        for src, dst in copied[:25]:
            print(f"  {src} -> {dst}")
    if ambiguous:
        print("Ambiguous matches (left unchanged):")
        for src, count in ambiguous[:25]:
            print(f"  {src}: {count} candidates")
    if missing:
        print("Unmatched source files (not silently forced into unrelated slots):")
        for src in missing[:25]:
            print(f"  {src}")

if __name__ == "__main__":
    main()

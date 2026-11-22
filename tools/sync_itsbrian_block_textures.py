#!/usr/bin/env python3
"""Copy matching ItsBrian Java block textures into Donorcraft's block texture slots.

Only existing PNG files under mods/ITEMS/*/textures are candidates. A source
texture is selected from ItsBrian's block/ directory by exact basename after
removing known Mineclonia prefixes. No mobs, tools, UI, sounds or models are
touched. Unmatched textures are deliberately left unchanged.
"""
from pathlib import Path
import argparse
import shutil

PREFIXES = (
    "default_", "mcl_core_", "mcl_", "mesecons_", "jeija_",
    "doors_", "stairs_", "walls_", "xpanes_",
)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path,
                        help="Path to ItsBrian/minecraft-textures/block")
    parser.add_argument("--repo", required=True, type=Path,
                        help="DonorCraftt checkout")
    args = parser.parse_args()
    source = args.source
    repo = args.repo
    if not source.is_dir():
        raise SystemExit(f"Source texture directory not found: {source}")

    sources = {p.stem: p for p in source.glob("*.png")}
    targets = sorted((repo / "mods" / "ITEMS").glob("**/textures/*.png"))
    copied = []
    for target in targets:
        stem = target.stem
        candidates = [stem]
        # Mineclonia commonly prefixes block files with their owning mod name,
        # e.g. mcl_amethyst_amethyst_block.png -> amethyst_block.png.
        module_name = target.parent.parent.name
        if stem.startswith(module_name + "_"):
            candidates.append(stem[len(module_name) + 1:])
        candidates.extend(stem[len(prefix):] for prefix in PREFIXES
                          if stem.startswith(prefix))
        source_file = next((sources[name] for name in candidates
                            if name in sources), None)
        if source_file is None:
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source_file, target)
        copied.append((source_file.name, target.relative_to(repo).as_posix()))

    print(f"Replaced {len(copied)} existing block texture files.")
    for source_name, target_name in copied:
        print(f"{source_name} -> {target_name}")
    if not copied:
        raise SystemExit("No matching block textures found; refusing empty update.")

if __name__ == "__main__":
    main()

# Sync script revision: retrigger the texture replacement workflow on main.

#!/usr/bin/env python3
"""
Clean dark edge artifacts from sprite PNGs.

Strategy (conservative, preserves character detail):
1. Remove isolated dark pixels (0-1 opaque neighbors, brightness < 40)
   → These are 100% background-removal artifacts
2. Remove dark edge pixels (adjacent to transparent, brightness < 20)
   → Very dark fringe that isn't part of the character
3. Second pass: remove newly-isolated dark pixels after step 2

Backs up originals to assets-v11/sprites-backup/ before modifying.
"""

import os
import shutil
import sys
from PIL import Image
import numpy as np

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES_DIR = os.path.join(BASE, "assets-v11", "sprites")
BACKUP_DIR = os.path.join(BASE, "assets-v11", "sprites-backup")
USED_LIST = os.path.join(BASE, "tasks", "used-sprites.txt")

ISOLATED_BRIGHTNESS_THRESH = 40   # For isolated pixels
EDGE_BRIGHTNESS_THRESH = 20       # For edge pixels (more conservative)


def get_neighbors_count(alpha, y, x, h, w):
    """Count opaque 4-connected neighbors."""
    count = 0
    if y > 0 and alpha[y-1, x] > 0: count += 1
    if y < h-1 and alpha[y+1, x] > 0: count += 1
    if x > 0 and alpha[y, x-1] > 0: count += 1
    if x < w-1 and alpha[y, x+1] > 0: count += 1
    return count


def is_edge(alpha, y, x, h, w):
    """Check if pixel is adjacent to at least one transparent pixel."""
    if y > 0 and alpha[y-1, x] == 0: return True
    if y < h-1 and alpha[y+1, x] == 0: return True
    if x > 0 and alpha[y, x-1] == 0: return True
    if x < w-1 and alpha[y, x+1] == 0: return True
    return False


def clean_sprite(img_path):
    """Clean dark artifacts from a single sprite. Returns (isolated_removed, edge_removed)."""
    img = Image.open(img_path).convert("RGBA")
    data = np.array(img)
    h, w = data.shape[:2]

    alpha = data[:, :, 3].copy()
    rgb = data[:, :, :3].astype(float)
    brightness = rgb.mean(axis=2)  # Average of R, G, B

    removed_isolated = 0
    removed_edge = 0

    # Pass 1: Remove isolated dark pixels (0-1 opaque neighbors)
    opaque_ys, opaque_xs = np.where(alpha > 0)
    for y, x in zip(opaque_ys, opaque_xs):
        n = get_neighbors_count(alpha, y, x, h, w)
        if n <= 1 and brightness[y, x] < ISOLATED_BRIGHTNESS_THRESH:
            data[y, x, 3] = 0
            alpha[y, x] = 0
            removed_isolated += 1

    # Pass 2: Remove dark edge pixels (adjacent to transparent, very dark)
    opaque_ys, opaque_xs = np.where(alpha > 0)
    for y, x in zip(opaque_ys, opaque_xs):
        if is_edge(alpha, y, x, h, w) and brightness[y, x] < EDGE_BRIGHTNESS_THRESH:
            data[y, x, 3] = 0
            alpha[y, x] = 0
            removed_edge += 1

    # Pass 3: Clean up newly-isolated dark pixels from pass 2
    opaque_ys, opaque_xs = np.where(alpha > 0)
    for y, x in zip(opaque_ys, opaque_xs):
        n = get_neighbors_count(alpha, y, x, h, w)
        if n <= 1 and brightness[y, x] < ISOLATED_BRIGHTNESS_THRESH:
            data[y, x, 3] = 0
            alpha[y, x] = 0
            removed_isolated += 1

    if removed_isolated + removed_edge > 0:
        result = Image.fromarray(data)
        result.save(img_path)

    return removed_isolated, removed_edge


def main():
    # Read used files list
    with open(USED_LIST) as f:
        files = [line.strip() for line in f if line.strip()]

    print(f"Found {len(files)} sprites to clean")

    # Backup originals
    print(f"Backing up to {BACKUP_DIR} ...")
    backed_up = 0
    for rel_path in files:
        src = os.path.join(BASE, rel_path)
        # Preserve directory structure: sprites/dir/file.png → sprites-backup/dir/file.png
        sub_path = rel_path.replace("assets-v11/sprites/", "")
        dst = os.path.join(BACKUP_DIR, sub_path)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst):  # Don't overwrite existing backup
            shutil.copy2(src, dst)
            backed_up += 1
    print(f"Backed up {backed_up} files")

    # Clean each sprite
    total_isolated = 0
    total_edge = 0
    for i, rel_path in enumerate(files):
        full_path = os.path.join(BASE, rel_path)
        iso, edge = clean_sprite(full_path)
        total_isolated += iso
        total_edge += edge
        fname = os.path.basename(rel_path)
        if (i + 1) % 10 == 0 or iso + edge > 100:
            print(f"  [{i+1}/{len(files)}] {fname}: -{iso} isolated, -{edge} edge")

    print(f"\nDone! Removed {total_isolated} isolated + {total_edge} edge = {total_isolated + total_edge} dark pixels total")


if __name__ == "__main__":
    main()

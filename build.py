# Copies all listed files into 'build/'. Supports glob patterns and ignoring using '!'

import shutil
from pathlib import Path

BUILD_DIR = Path("./build")

PATTERNS = [
  "info.txt",
  "preview.png",
  "preview.jpg",
  "*.lua",
  "img/*",
  "vox/*",
  "snd/*",

  "!api.lua",
  "!vox/Missile_segmented.vox",
  "!img/noise_*.png",
]

print(f"Build started.")

if BUILD_DIR.exists():
  print(f'Build directory "{BUILD_DIR}" already exists. Removing.')
  shutil.rmtree(BUILD_DIR)
BUILD_DIR.mkdir()
print(f"Build directory was created.")

selected = set()
for pattern in PATTERNS:
  if pattern.startswith("!"):
    selected -= {p for p in Path(".").glob(pattern[1:]) if p.is_file()}
  else:
    selected |= {p for p in Path(".").glob(pattern) if p.is_file()}

for src in sorted(selected):
  dst = BUILD_DIR / src
  dst.parent.mkdir(parents=True, exist_ok=True)
  shutil.copy2(src, dst)
  print(f'Copied "{src}".')

print(f"{len(selected)} files copied.")

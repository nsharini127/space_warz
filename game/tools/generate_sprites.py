#!/usr/bin/env python3
"""
Generates game sprites using DALL-E 3 API and post-processes them.
Removes backgrounds and resizes for use in Godot.
"""

import os
import sys
import json
import urllib.request
import urllib.error
from pathlib import Path

API_KEY = os.environ.get("OPENAI_API_KEY", "")
OUTPUT_DIR = Path(__file__).parent.parent / "assets" / "sprites" / "enemies" / "space"
PLAYER_DIR = Path(__file__).parent.parent / "assets" / "sprites" / "player" / "space"
TEMP_DIR = Path(__file__).parent / "temp_sprites"

# Style prefix for all prompts
STYLE = (
    "2D top-down game sprite, single spaceship centered on pure black background, "
    "cyberpunk neon style inspired by Evangelion and Ghost in the Shell, "
    "highly detailed metallic hull with glowing neon accents (cyan, magenta, purple), "
    "clean sharp edges, no text, no watermark, game-ready asset, "
    "digital art, 4K quality render, isolated single object, "
    "top-down orthographic view looking straight down"
)

SPRITES = {
    "player_ship": {
        "prompt": f"{STYLE}. Sleek futuristic fighter spacecraft, angular aggressive design, "
                  "glowing cyan engine trails, white and dark blue hull with neon cyan racing stripes, "
                  "pointed nose, swept-back wings, compact combat fighter, heroic protagonist ship",
        "output": PLAYER_DIR / "player_ship.png",
        "size": (128, 128),
    },
    "enemy_base": {
        "prompt": f"{STYLE}. Small alien drone spacecraft, rounded menacing design, "
                  "dark grey metallic hull with glowing red eyes/sensors, "
                  "simple compact shape, basic enemy grunt ship, red neon accents, "
                  "slightly organic-mechanical hybrid look",
        "output": OUTPUT_DIR / "enemy_base.png",
        "size": (64, 64),
    },
    "enemy_runner": {
        "prompt": f"{STYLE}. Fast sleek alien interceptor spacecraft, elongated aerodynamic body, "
                  "sharp swept-back fins, dark hull with bright orange and yellow neon speed lines, "
                  "twin engine pods glowing orange, designed for speed, aggressive streamlined shape",
        "output": OUTPUT_DIR / "enemy_runner.png",
        "size": (64, 64),
    },
    "enemy_shooter": {
        "prompt": f"{STYLE}. Heavily armed alien gunship spacecraft, wider bulky design, "
                  "visible weapon turrets and cannon barrels, dark purple hull with magenta neon weapon glows, "
                  "intimidating military design, multiple gun ports visible from above",
        "output": OUTPUT_DIR / "enemy_shooter.png",
        "size": (72, 72),
    },
    "enemy_charger": {
        "prompt": f"{STYLE}. Aggressive ramming alien spacecraft with reinforced front armor, "
                  "wedge-shaped battering ram nose, heavy plating, dark red hull with bright crimson neon veins, "
                  "powerful engines at rear, built like a bullet, menacing charging ship",
        "output": OUTPUT_DIR / "enemy_charger.png",
        "size": (64, 64),
    },
    "enemy_midboss": {
        "prompt": f"{STYLE}. Medium-sized elite alien warship, commanding presence, "
                  "dark metallic hull with electric blue and purple neon patterns, "
                  "shield generator visible, multiple weapon systems, ornate alien design, "
                  "larger than regular enemies but smaller than a boss, lieutenant-class vessel",
        "output": OUTPUT_DIR / "enemy_midboss.png",
        "size": (96, 96),
    },
    "enemy_boss": {
        "prompt": f"{STYLE}. Massive alien flagship boss spacecraft, imposing dreadnought design, "
                  "dark obsidian hull covered in glowing blue and violet neon circuit patterns, "
                  "multiple weapon arrays, shield emitters, central command bridge visible, "
                  "Evangelion-inspired biomechanical elements, terrifying final boss presence, "
                  "intricate detailed surface, very large intimidating warship",
        "output": OUTPUT_DIR / "enemy_boss.png",
        "size": (128, 128),
    },
}


def generate_image(name: str, prompt: str) -> str:
    """Calls DALL-E 3 API and returns the image URL."""
    print(f"  [DALL-E] Generating: {name}...")

    data = json.dumps({
        "model": "dall-e-3",
        "prompt": prompt,
        "n": 1,
        "size": "1024x1024",
        "quality": "hd",
        "response_format": "url",
    }).encode("utf-8")

    req = urllib.request.Request(
        "https://api.openai.com/v1/images/generations",
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {API_KEY}",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            url = result["data"][0]["url"]
            print(f"  [OK] {name} generated successfully")
            return url
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8") if e.fp else ""
        print(f"  [ERROR] {name}: HTTP {e.code} - {body[:200]}")
        return ""
    except Exception as e:
        print(f"  [ERROR] {name}: {e}")
        return ""


def download_image(url: str, dest: Path) -> bool:
    """Downloads image from URL to destination path."""
    try:
        urllib.request.urlretrieve(url, str(dest))
        return True
    except Exception as e:
        print(f"  [ERROR] Download failed: {e}")
        return False


def process_sprite(src: Path, dest: Path, target_size: tuple):
    """Removes black background and resizes sprite using Pillow."""
    from PIL import Image
    import numpy as np

    img = Image.open(src).convert("RGBA")
    data = np.array(img)

    # Remove near-black background (threshold for dark pixels)
    r, g, b, a = data[:, :, 0], data[:, :, 1], data[:, :, 2], data[:, :, 3]
    brightness = r.astype(int) + g.astype(int) + b.astype(int)

    # Pixels where total brightness < 60 are considered background
    mask = brightness < 60
    data[mask, 3] = 0  # Set alpha to 0 for dark pixels

    # Also do edge cleanup - very dark pixels near transparent ones
    img_processed = Image.fromarray(data)

    # Crop to content (trim transparent edges)
    bbox = img_processed.getbbox()
    if bbox:
        img_processed = img_processed.crop(bbox)

    # Resize to target size with high-quality resampling
    img_processed = img_processed.resize(target_size, Image.LANCZOS)

    # Save
    dest.parent.mkdir(parents=True, exist_ok=True)
    img_processed.save(str(dest), "PNG")
    print(f"  [SAVED] {dest.name} ({target_size[0]}x{target_size[1]})")


def main():
    print("=" * 60)
    print("  SPRITE GENERATOR - Cyberpunk Space Shooter Assets")
    print("=" * 60)

    TEMP_DIR.mkdir(parents=True, exist_ok=True)

    # Check which sprites to generate (skip existing unless --force)
    force = "--force" in sys.argv
    to_generate = {}
    for name, config in SPRITES.items():
        if force or not config["output"].exists():
            to_generate[name] = config
        else:
            print(f"  [SKIP] {name} already exists (use --force to regenerate)")

    if not to_generate:
        print("\nAll sprites already exist. Use --force to regenerate.")
        return

    # Generate and process each sprite
    for name, config in to_generate.items():
        print(f"\n--- {name} ---")
        url = generate_image(name, config["prompt"])
        if not url:
            continue

        temp_file = TEMP_DIR / f"{name}_raw.png"
        if not download_image(url, temp_file):
            continue

        process_sprite(temp_file, config["output"], config["size"])

    # Cleanup temp files
    print("\n--- Cleanup ---")
    for f in TEMP_DIR.glob("*.png"):
        f.unlink()
    if TEMP_DIR.exists():
        try:
            TEMP_DIR.rmdir()
        except OSError:
            pass

    print("\n" + "=" * 60)
    print("  DONE! Sprites saved to assets/sprites/")
    print("=" * 60)


if __name__ == "__main__":
    main()

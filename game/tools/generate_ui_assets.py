#!/usr/bin/env python3
"""Generate cyberpunk-themed UI assets for the space shooter game.

Creates:
- Panel and button textures (procedural, Pillow)
- Skill/ability icons (DALL-E 3)
- UI upgrade icons (DALL-E 3)
"""

import os
import sys
import requests
from io import BytesIO

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError:
    print("Installing Pillow...")
    os.system(f"{sys.executable} -m pip install --break-system-packages Pillow")
    from PIL import Image, ImageDraw, ImageFilter, ImageFont

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI_THEME_DIR = os.path.join(PROJECT_ROOT, "assets", "ui", "theme_wood")
SKILL_ICONS_DIR = os.path.join(PROJECT_ROOT, "assets", "sprites", "ui", "skill_icons")
UI_ICONS_DIR = os.path.join(PROJECT_ROOT, "assets", "sprites", "ui")

OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")

# Cyberpunk color palette
DARK_BG = (8, 8, 20)
PANEL_BG = (12, 14, 28)
BORDER_CYAN = (30, 180, 255)
BORDER_HOVER = (80, 210, 255)
BORDER_PRESSED = (15, 120, 180)
GLOW_CYAN = (30, 180, 255, 60)
ACCENT_GOLD = (255, 215, 50)


# ---------------------------------------------------------------------------
# Procedural UI panel/button generation
# ---------------------------------------------------------------------------

def draw_rounded_rect(draw, rect, fill, outline, radius=4, width=2):
    """Draw a rounded rectangle with outline."""
    x0, y0, x1, y1 = rect
    draw.rounded_rectangle(rect, radius=radius, fill=fill, outline=outline, width=width)


def add_glow(img, color, radius=3):
    """Add outer glow effect to an image."""
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    # Draw the shape slightly larger
    for pixel in range(img.width):
        for py in range(img.height):
            r, g, b, a = img.getpixel((pixel, py))
            if a > 50:
                glow.putpixel((pixel, py), (*color[:3], min(a, 80)))

    glow = glow.filter(ImageFilter.GaussianBlur(radius=radius))
    result = Image.alpha_composite(glow, img)
    return result


def generate_panel(size=(64, 64)):
    """Generate cyberpunk panel texture (9-patch friendly)."""
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background fill with slight gradient
    for y in range(h):
        t = y / h
        r = int(PANEL_BG[0] * (1 - t * 0.3))
        g = int(PANEL_BG[1] * (1 - t * 0.3))
        b = int(PANEL_BG[2] * (1 - t * 0.2))
        draw.line([(0, y), (w - 1, y)], fill=(r, g, b, 230))

    # Border
    draw.rounded_rectangle(
        [1, 1, w - 2, h - 2],
        radius=6,
        fill=None,
        outline=(*BORDER_CYAN, 180),
        width=2
    )

    # Inner subtle border
    draw.rounded_rectangle(
        [3, 3, w - 4, h - 4],
        radius=4,
        fill=None,
        outline=(*BORDER_CYAN, 40),
        width=1
    )

    # Corner accents (small bright dots at corners)
    for cx, cy in [(6, 6), (w - 7, 6), (6, h - 7), (w - 7, h - 7)]:
        draw.ellipse([cx - 1, cy - 1, cx + 1, cy + 1], fill=(*BORDER_CYAN, 200))

    # Top edge highlight
    draw.line([(8, 2), (w - 9, 2)], fill=(*BORDER_CYAN, 100), width=1)

    return img


def generate_button(size=(64, 32), state="normal"):
    """Generate cyberpunk button texture."""
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if state == "normal":
        bg_color = (15, 25, 50, 220)
        border_color = (*BORDER_CYAN, 160)
        highlight_alpha = 60
    elif state == "hover":
        bg_color = (25, 40, 70, 235)
        border_color = (*BORDER_HOVER, 200)
        highlight_alpha = 100
    elif state == "pressed":
        bg_color = (8, 15, 35, 240)
        border_color = (*BORDER_PRESSED, 180)
        highlight_alpha = 30
    else:
        bg_color = (15, 25, 50, 220)
        border_color = (*BORDER_CYAN, 160)
        highlight_alpha = 60

    # Background
    draw.rounded_rectangle([1, 1, w - 2, h - 2], radius=4, fill=bg_color)

    # Border
    draw.rounded_rectangle(
        [1, 1, w - 2, h - 2],
        radius=4,
        fill=None,
        outline=border_color,
        width=2
    )

    # Top highlight line
    draw.line([(6, 2), (w - 7, 2)], fill=(255, 255, 255, highlight_alpha), width=1)

    # Bottom shadow line
    draw.line([(6, h - 3), (w - 7, h - 3)], fill=(0, 0, 0, 80), width=1)

    if state == "hover":
        # Add subtle glow on hover
        for y in range(h):
            for x in range(w):
                r, g, b, a = img.getpixel((x, y))
                if a > 0:
                    glow_add = int(15 * (1 - abs(y - h / 2) / (h / 2)))
                    img.putpixel((x, y), (
                        min(255, r + glow_add),
                        min(255, g + glow_add),
                        min(255, b + glow_add * 2),
                        a
                    ))

    return img


def generate_all_ui_textures():
    """Generate all panel and button textures."""
    os.makedirs(UI_THEME_DIR, exist_ok=True)

    print("Generating cyberpunk panel texture...")
    panel = generate_panel((64, 64))
    panel.save(os.path.join(UI_THEME_DIR, "panel.png"))
    print("  -> panel.png (64x64)")

    for state in ["normal", "hover", "pressed"]:
        print(f"Generating button_{state} texture...")
        btn = generate_button((64, 32), state)
        btn.save(os.path.join(UI_THEME_DIR, f"button_{state}.png"))
        print(f"  -> button_{state}.png (64x32)")

    print("UI textures generated successfully!")


# ---------------------------------------------------------------------------
# DALL-E icon generation
# ---------------------------------------------------------------------------

def generate_dalle_image(prompt, size="1024x1024"):
    """Call DALL-E 3 API and return PIL Image."""
    if not OPENAI_API_KEY:
        print(f"  [SKIP] No API key - cannot generate: {prompt[:50]}...")
        return None

    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "Content-Type": "application/json",
    }
    data = {
        "model": "dall-e-3",
        "prompt": prompt,
        "n": 1,
        "size": size,
        "quality": "standard",
        "response_format": "url",
    }

    try:
        resp = requests.post(
            "https://api.openai.com/v1/images/generations",
            headers=headers,
            json=data,
            timeout=60,
        )
        resp.raise_for_status()
        url = resp.json()["data"][0]["url"]
        img_resp = requests.get(url, timeout=30)
        return Image.open(BytesIO(img_resp.content)).convert("RGBA")
    except Exception as e:
        print(f"  [ERROR] DALL-E failed: {e}")
        return None


def crop_center_square(img, target_size):
    """Crop center square and resize."""
    w, h = img.size
    s = min(w, h)
    left = (w - s) // 2
    top = (h - s) // 2
    cropped = img.crop((left, top, left + s, top + s))
    return cropped.resize((target_size, target_size), Image.LANCZOS)


def make_transparent_bg(img, threshold=40):
    """Remove dark/black background."""
    data = img.getdata()
    new_data = []
    for pixel in data:
        r, g, b, a = pixel
        if r < threshold and g < threshold and b < threshold:
            new_data.append((r, g, b, 0))
        else:
            new_data.append(pixel)
    img.putdata(new_data)
    return img


def generate_icon_sheet(icons_config, output_dir, icon_size=32):
    """Generate multiple icons from DALL-E, one API call per icon.

    icons_config: list of (filename, prompt_suffix)
    """
    os.makedirs(output_dir, exist_ok=True)

    base_prompt = (
        "Single game UI icon, cyberpunk/sci-fi style, neon glow, "
        "dark background, clean simple design for a 2D space shooter game, "
        "pixel art inspired, centered composition, no text. "
    )

    for filename, desc in icons_config:
        filepath = os.path.join(output_dir, filename)
        print(f"  Generating {filename}...")

        full_prompt = base_prompt + desc
        img = generate_dalle_image(full_prompt)
        if img:
            img = crop_center_square(img, icon_size)
            img = make_transparent_bg(img, threshold=30)
            img.save(filepath)
            print(f"    -> {filename} ({icon_size}x{icon_size})")
        else:
            # Create fallback procedural icon
            _create_fallback_icon(filepath, icon_size, desc)


def _create_fallback_icon(filepath, size, desc):
    """Create a simple procedural fallback icon."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Simple colored circle with initial
    color = BORDER_CYAN
    if "heal" in desc.lower() or "health" in desc.lower():
        color = (50, 255, 100)
    elif "attack" in desc.lower() or "damage" in desc.lower():
        color = (255, 80, 60)
    elif "speed" in desc.lower() or "boots" in desc.lower():
        color = (255, 255, 80)
    elif "shield" in desc.lower() or "armor" in desc.lower() or "defense" in desc.lower():
        color = (80, 150, 255)

    cx, cy = size // 2, size // 2
    r = size // 2 - 2
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*color, 180), outline=(*color, 255))

    img.save(filepath)
    print(f"    -> {os.path.basename(filepath)} (fallback)")


def generate_skill_icons():
    """Generate cyberpunk skill icons to replace samurai-themed ones."""
    print("\nGenerating skill icons...")

    icons = [
        ("fireball.png", "A glowing plasma orb projectile, blue-white energy sphere with electric sparks"),
        ("heal.png", "A green healing nanomachine icon, glowing green cross with circuit patterns"),
        ("explosion.png", "A shockwave/EMP blast icon, circular expanding energy wave in orange-red"),
        ("shuriken.png", "A rotating energy disc weapon, cyan spinning blade with neon trails"),
        ("armor.png", "A force field/energy shield icon, hexagonal blue barrier with glow"),
        ("kunai.png", "A laser beam projectile icon, bright focused red laser with targeting reticle"),
        ("boots.png", "A thruster/boost icon, rocket engine flame in blue-white, speed boost"),
    ]

    generate_icon_sheet(icons, SKILL_ICONS_DIR, icon_size=32)


def generate_ui_icons():
    """Generate cyberpunk UI upgrade icons."""
    print("\nGenerating UI icons...")

    icons = [
        ("icon_attack.png", "Attack power icon, a glowing red targeting crosshair with energy"),
        ("icon_defense.png", "Defense/HP icon, a blue hexagonal energy shield barrier"),
        ("icon_heal.png", "Healing icon, green medical nanomachine cross with glow"),
        ("icon_upgrade.png", "Upgrade icon, cyan upward arrow with circuit board pattern"),
        ("icon_fireball.png", "Damage boost icon, orange-red plasma explosion energy"),
        ("icon_speed.png", "Speed boost icon, white-blue motion blur afterburner flames"),
        ("icon_multishot.png", "Multi-shot icon, three cyan laser beams fanning outward"),
        ("icon_pierce.png", "Pierce/penetration icon, a bright beam cutting through barriers"),
    ]

    generate_icon_sheet(icons, UI_ICONS_DIR, icon_size=32)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("=" * 60)
    print("  CYBERPUNK UI ASSET GENERATOR")
    print("=" * 60)

    # Phase 1: Procedural UI textures (no API needed)
    print("\n--- Phase 1: Procedural UI Textures ---")
    generate_all_ui_textures()

    # Phase 2: DALL-E skill icons
    print("\n--- Phase 2: DALL-E Skill Icons ---")
    if OPENAI_API_KEY:
        generate_skill_icons()
    else:
        print("[SKIP] No OPENAI_API_KEY set, generating fallback icons...")
        generate_skill_icons()

    # Phase 3: DALL-E UI icons
    print("\n--- Phase 3: DALL-E UI Icons ---")
    if OPENAI_API_KEY:
        generate_ui_icons()
    else:
        print("[SKIP] No OPENAI_API_KEY set, generating fallback icons...")
        generate_ui_icons()

    print("\n" + "=" * 60)
    print("  ALL UI ASSETS GENERATED!")
    print("=" * 60)


if __name__ == "__main__":
    main()

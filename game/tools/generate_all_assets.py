#!/usr/bin/env python3
"""
Generates ALL game assets: DALL-E for complex sprites, Pillow for small/procedural ones.
"""

import os
import json
import math
import urllib.request
import urllib.error
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np

API_KEY = os.environ.get("OPENAI_API_KEY", "")
ROOT = Path(__file__).parent.parent
ASSETS = ROOT / "assets"
TEMP = ROOT / "tools" / "temp_gen"

STYLE = (
    "2D top-down game sprite, single object centered on pure black background, "
    "cyberpunk neon style inspired by Evangelion and Ghost in the Shell, "
    "highly detailed metallic hull with glowing neon accents, "
    "clean sharp edges, no text, no watermark, game-ready asset, "
    "digital art, 4K quality render, isolated single object"
)

def dalle_generate(name, prompt, output_path, target_size):
    """Generate via DALL-E 3 and post-process."""
    print(f"  [DALL-E] {name}...")
    data = json.dumps({
        "model": "dall-e-3",
        "prompt": prompt,
        "n": 1,
        "size": "1024x1024",
        "quality": "hd",
        "response_format": "url",
    }).encode()

    req = urllib.request.Request(
        "https://api.openai.com/v1/images/generations",
        data=data,
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {API_KEY}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read().decode())
            url = result["data"][0]["url"]
    except Exception as e:
        print(f"  [ERROR] {name}: {e}")
        return False

    TEMP.mkdir(parents=True, exist_ok=True)
    temp_file = TEMP / f"{name}_raw.png"
    urllib.request.urlretrieve(url, str(temp_file))

    img = Image.open(temp_file).convert("RGBA")
    data_arr = np.array(img)
    brightness = data_arr[:,:,0].astype(int) + data_arr[:,:,1].astype(int) + data_arr[:,:,2].astype(int)
    data_arr[brightness < 60, 3] = 0
    img = Image.fromarray(data_arr)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    img = img.resize(target_size, Image.LANCZOS)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(str(output_path), "PNG")
    temp_file.unlink(missing_ok=True)
    print(f"  [OK] {name} -> {output_path.name} ({target_size[0]}x{target_size[1]})")
    return True


# ─── PROCEDURAL GENERATORS ───────────────────────────────────────

def make_gradient_circle(size, color, glow_color=None):
    """Creates a glowing circle/orb."""
    img = Image.new("RGBA", (size, size), (0,0,0,0))
    center = size // 2
    for y in range(size):
        for x in range(size):
            dist = math.sqrt((x - center)**2 + (y - center)**2)
            if dist < center:
                t = dist / center
                if t < 0.3:
                    a = 255
                    r, g, b = 255, 255, 255
                elif t < 0.6:
                    a = 255
                    t2 = (t - 0.3) / 0.3
                    r = int(255 + (color[0] - 255) * t2)
                    g = int(255 + (color[1] - 255) * t2)
                    b = int(255 + (color[2] - 255) * t2)
                else:
                    t2 = (t - 0.6) / 0.4
                    a = int(255 * (1 - t2))
                    gc = glow_color or color
                    r, g, b = gc[0], gc[1], gc[2]
                img.putpixel((x, y), (r, g, b, a))
    return img


def make_laser(width, height, color, glow_color=None):
    """Creates a glowing laser beam sprite."""
    img = Image.new("RGBA", (width, height), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    gc = glow_color or tuple(max(0, c - 40) for c in color)
    # Outer glow
    draw.rounded_rectangle([0, 0, width-1, height-1], radius=width//2,
                           fill=(*gc, 80))
    # Inner beam
    inset = max(1, width // 4)
    draw.rounded_rectangle([inset, 1, width-1-inset, height-2], radius=max(1, (width-2*inset)//2),
                           fill=(*color, 230))
    # Core (white)
    inset2 = max(1, width // 3)
    if width - 2*inset2 > 0:
        draw.rounded_rectangle([inset2, 2, width-1-inset2, height-3], radius=max(1, (width-2*inset2)//2),
                               fill=(255, 255, 255, 200))
    return img


def make_gem(size, color):
    """Creates a diamond-shaped gem sprite."""
    img = Image.new("RGBA", (size, size), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    c = size // 2
    points = [(c, 1), (size-2, c), (c, size-2), (1, c)]
    # Glow
    draw.polygon(points, fill=(*color, 100))
    # Inner
    s = size // 4
    inner = [(c, s), (size-1-s, c), (c, size-1-s), (s, c)]
    draw.polygon(inner, fill=(*color, 230))
    # Highlight
    draw.polygon([(c, s+1), (c+s//2, c), (c, c), (c-s//2, c)], fill=(255,255,255,180))
    return img


def make_powerup_icon(size, color, symbol):
    """Creates a powerup pickup icon."""
    img = Image.new("RGBA", (size, size), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    c = size // 2
    # Outer glow
    draw.ellipse([1, 1, size-2, size-2], fill=(*color, 60))
    # Main circle
    draw.ellipse([2, 2, size-3, size-3], fill=(*color, 200))
    # Center highlight
    draw.ellipse([size//4, size//4, 3*size//4, 3*size//4], fill=(255,255,255,150))
    return img


def make_heart(width, height, color=(255, 50, 80)):
    """Creates a heart icon."""
    img = Image.new("RGBA", (width*4, height*4), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    w, h = width*4, height*4
    # Two circles + triangle for heart shape
    r = w // 4
    draw.ellipse([w//4-r, h//4-r, w//4+r, h//4+r], fill=(*color, 255))
    draw.ellipse([3*w//4-r, h//4-r, 3*w//4+r, h//4+r], fill=(*color, 255))
    draw.polygon([(1, h//3), (w-1, h//3), (w//2, h-2)], fill=(*color, 255))
    # Highlight
    draw.ellipse([w//4-r//2, h//4-r, w//4+r//3, h//4], fill=(255,200,200,180))
    img = img.resize((width, height), Image.LANCZOS)
    return img


def make_star_particle(size, color):
    """Creates a glowing star particle."""
    img = Image.new("RGBA", (size, size), (0,0,0,0))
    c = size // 2
    for y in range(size):
        for x in range(size):
            dist = math.sqrt((x-c)**2 + (y-c)**2)
            if dist < c:
                t = 1 - dist/c
                a = int(255 * t * t)
                r = min(255, int(color[0] + (255-color[0]) * t))
                g = min(255, int(color[1] + (255-color[1]) * t))
                b = min(255, int(color[2] + (255-color[2]) * t))
                img.putpixel((x, y), (r, g, b, a))
    return img


def make_explosion_frame(size, t, color):
    """Creates one frame of explosion animation."""
    img = Image.new("RGBA", (size, size), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    c = size // 2
    radius = int(c * (0.3 + 0.7 * t))
    alpha = int(255 * (1 - t * 0.8))

    # Outer ring
    ring_r = radius + 2
    draw.ellipse([c-ring_r, c-ring_r, c+ring_r, c+ring_r],
                 fill=(color[0], color[1], color[2], max(0, alpha//3)))
    # Core
    core_r = max(1, int(radius * (1 - t * 0.5)))
    core_alpha = max(0, int(alpha * 0.9))
    draw.ellipse([c-core_r, c-core_r, c+core_r, c+core_r],
                 fill=(255, min(255, color[1]+100), min(255, color[2]+50), core_alpha))
    # White flash center
    if t < 0.4:
        flash_r = max(1, int(core_r * 0.5 * (1-t/0.4)))
        draw.ellipse([c-flash_r, c-flash_r, c+flash_r, c+flash_r],
                     fill=(255, 255, 255, int(255*(1-t/0.4))))
    return img


def make_engine_sheet(frame_w, frame_h, frames, color):
    """Creates an engine exhaust animation spritesheet."""
    sheet = Image.new("RGBA", (frame_w * frames, frame_h), (0,0,0,0))
    for i in range(frames):
        frame = Image.new("RGBA", (frame_w, frame_h), (0,0,0,0))
        draw = ImageDraw.Draw(frame)
        cx = frame_w // 2
        phase = i / frames

        # Flame layers
        for layer in range(3):
            t = (phase + layer * 0.3) % 1.0
            h_scale = 0.3 + 0.7 * (1 - layer * 0.25)
            flame_h = int(frame_h * h_scale * (0.7 + 0.3 * math.sin(t * math.pi * 2)))
            flame_w = max(2, int((frame_w // 2 - layer * 3) * (0.6 + 0.4 * math.sin(t * math.pi * 2 + 1))))

            alpha = max(0, int(200 - layer * 60))
            r = min(255, color[0] + layer * 30)
            g = min(255, color[1] - layer * 20)
            b = min(255, color[2] - layer * 40)

            y_start = 0
            points = [
                (cx - flame_w, y_start),
                (cx, y_start + flame_h),
                (cx + flame_w, y_start),
            ]
            draw.polygon(points, fill=(r, g, b, alpha))

        # White core
        core_h = int(frame_h * 0.2)
        core_w = max(1, frame_w // 6)
        draw.ellipse([cx-core_w, 0, cx+core_w, core_h], fill=(255,255,255,200))

        sheet.paste(frame, (i * frame_w, 0))
    return sheet


def make_shield_sheet(frame_w, frame_h, frames, color):
    """Creates a shield animation spritesheet."""
    sheet = Image.new("RGBA", (frame_w * frames, frame_h), (0,0,0,0))
    for i in range(frames):
        frame = Image.new("RGBA", (frame_w, frame_h), (0,0,0,0))
        draw = ImageDraw.Draw(frame)
        cx, cy = frame_w // 2, frame_h // 2
        phase = i / frames * math.pi * 2
        radius = min(cx, cy) - 2

        # Outer glow ring
        alpha_pulse = int(60 + 40 * math.sin(phase))
        draw.ellipse([cx-radius, cy-radius, cx+radius, cy+radius],
                     outline=(*color, alpha_pulse), width=2)
        # Inner ring
        inner_r = radius - 3
        draw.ellipse([cx-inner_r, cy-inner_r, cx+inner_r, cy+inner_r],
                     outline=(*color, max(0, alpha_pulse-30)), width=1)
        # Highlight arc (rotating)
        arc_start = int(math.degrees(phase)) % 360
        draw.arc([cx-radius+1, cy-radius+1, cx+radius-1, cy+radius-1],
                 arc_start, arc_start + 90, fill=(255,255,255, 120), width=2)

        sheet.paste(frame, (i * frame_w, 0))
    return sheet


# ─── MAIN GENERATION ─────────────────────────────────────────────

def generate_dalle_assets():
    """Generate complex assets via DALL-E."""
    print("\n=== DALL-E GENERATION ===\n")

    dalle_queue = [
        ("player_ship_dmg1",
         f"{STYLE}. Top-down futuristic fighter spacecraft, same angular design as a sleek combat fighter, "
         "white/dark blue hull with cyan neon accents, slight damage - small sparks on left wing, "
         "minor scorch marks, still mostly intact, space fighter with minor battle damage",
         ASSETS / "sprites/player/space/player_ship_dmg1.png", (128, 128)),

        ("player_ship_dmg2",
         f"{STYLE}. Top-down futuristic fighter spacecraft, angular combat design, "
         "hull showing significant damage - cracked armor plates, exposed orange-glowing internals, "
         "one wing partially broken, sparks and small fires, medium battle damage state",
         ASSETS / "sprites/player/space/player_ship_dmg2.png", (128, 128)),

        ("player_ship_dmg3",
         f"{STYLE}. Top-down futuristic fighter spacecraft, angular combat design, "
         "critically damaged - major hull breaches, heavy fire and smoke, missing wing section, "
         "red warning lights, glowing hot metal, barely holding together, critical battle damage",
         ASSETS / "sprites/player/space/player_ship_dmg3.png", (128, 128)),

        ("weapon_autocannon",
         f"{STYLE}. Top-down view of a futuristic autocannon weapon turret attachment, "
         "compact barrel design with rotating mechanism, metallic with orange neon energy glow, "
         "game weapon icon style, small detailed mechanical part",
         ASSETS / "sprites/player/space/weapon_autocannon.png", (32, 32)),

        ("weapon_zapper",
         f"{STYLE}. Top-down view of a futuristic electric zapper weapon attachment, "
         "tesla coil style with crackling blue-white energy, compact cylindrical design, "
         "electric arcs visible, game weapon icon style, small detailed sci-fi part",
         ASSETS / "sprites/player/space/weapon_zapper.png", (32, 32)),
    ]

    for name, prompt, path, size in dalle_queue:
        dalle_generate(name, prompt, path, size)


def generate_procedural_assets():
    """Generate small/procedural assets with Pillow."""
    print("\n=== PROCEDURAL GENERATION ===\n")

    proj_dir = ASSETS / "sprites/projectiles/space"
    ui_dir = ASSETS / "sprites/ui/space"
    fx_dir = ASSETS / "sprites/fx/space"
    player_dir = ASSETS / "sprites/player/space"
    heart_dir = ASSETS / "sprites/ui"

    for d in [proj_dir, ui_dir, fx_dir, player_dir, heart_dir]:
        d.mkdir(parents=True, exist_ok=True)

    # ── PROJECTILES ──
    print("  Projectiles...")

    # Player lasers (blue/cyan theme)
    make_laser(6, 16, (100, 180, 255), (50, 120, 255)).save(str(proj_dir / "laser_blue_short.png"))
    make_laser(4, 20, (80, 160, 255), (40, 100, 255)).save(str(proj_dir / "laser_blue_thin.png"))
    make_gradient_circle(14, (100, 200, 255), (50, 100, 255)).save(str(proj_dir / "laser_green_orb.png"))

    # Enemy lasers (red theme)
    make_laser(7, 20, (255, 80, 100), (255, 40, 60)).save(str(proj_dir / "laser_red_bolt.png"))
    make_gradient_circle(12, (255, 60, 80), (255, 30, 60)).save(str(proj_dir / "laser_red_orb.png"))
    make_laser(4, 20, (255, 70, 90), (255, 30, 50)).save(str(proj_dir / "laser_red_thin.png"))

    # Weapon-specific bullets (spritesheets: multiple frames horizontal)
    # autocannon: rapid fire small bullets
    sheet = Image.new("RGBA", (128, 32), (0,0,0,0))
    for i in range(4):
        bullet = make_gradient_circle(28, (255, 180, 50), (255, 120, 20))
        sheet.paste(bullet, (i*32+2, 2), bullet)
    sheet.save(str(proj_dir / "bullet_autocannon.png"))

    # rocket: larger projectile
    sheet = Image.new("RGBA", (96, 32), (0,0,0,0))
    for i in range(3):
        rocket = Image.new("RGBA", (28, 28), (0,0,0,0))
        d = ImageDraw.Draw(rocket)
        d.polygon([(14,2), (24,22), (4,22)], fill=(255,100,50,230))
        d.polygon([(14,6), (20,20), (8,20)], fill=(255,180,100,200))
        d.ellipse([10,0,18,8], fill=(255,255,200,220))
        sheet.paste(rocket, (i*32+2, 2), rocket)
    sheet.save(str(proj_dir / "bullet_rocket.png"))

    # spacegun: long energy beam segments
    sheet = Image.new("RGBA", (320, 32), (0,0,0,0))
    for i in range(10):
        beam = make_laser(8, 28, (50, 200, 255), (30, 150, 255))
        sheet.paste(beam, (i*32+12, 2), beam)
    sheet.save(str(proj_dir / "bullet_spacegun.png"))

    # zapper: electric bolts
    sheet = Image.new("RGBA", (256, 32), (0,0,0,0))
    for i in range(8):
        zap = make_gradient_circle(26, (180, 120, 255), (140, 80, 255))
        sheet.paste(zap, (i*32+3, 3), zap)
    sheet.save(str(proj_dir / "bullet_zapper.png"))

    print("  [OK] Projectiles done")

    # ── GEMS ──
    print("  Gems & Powerups...")

    make_gem(16, (80, 140, 255)).save(str(ui_dir / "gem_blue.png"))
    make_gem(16, (255, 200, 50)).save(str(ui_dir / "gem_gold.png"))
    make_gem(16, (50, 230, 100)).save(str(ui_dir / "gem_green.png"))

    # Powerup icons
    make_powerup_icon(16, (255, 80, 60), "P").save(str(ui_dir / "powerup_power.png"))
    make_powerup_icon(16, (60, 120, 255), "B").save(str(ui_dir / "powerup_bomb.png"))
    make_powerup_icon(16, (60, 230, 100), "L").save(str(ui_dir / "powerup_life.png"))

    # Life icon (small heart)
    make_heart(16, 12, (255, 50, 80)).save(str(ui_dir / "life_icon.png"))
    make_heart(12, 10, (255, 50, 80)).save(str(heart_dir / "heart.png"))

    print("  [OK] Gems & Powerups done")

    # ── EXPLOSION FRAMES ──
    print("  Explosion FX...")

    exp_colors = [(255, 150, 50), (255, 100, 30), (255, 60, 20), (200, 40, 10), (150, 30, 10)]
    for idx, t_val in enumerate([0, 4, 8, 12, 16]):
        t = t_val / 20.0
        color = exp_colors[idx]
        frame = make_explosion_frame(40, t, color)
        # Crop to 16x40 to match original format
        frame_cropped = frame.resize((16, 40), Image.LANCZOS)
        frame_cropped.save(str(fx_dir / f"fire{t_val:02d}.png"))

    print("  [OK] Explosion FX done")

    # ── STAR PARTICLES ──
    print("  Star particles...")

    make_star_particle(25, (200, 220, 255)).save(str(fx_dir / "star1.png"))
    make_star_particle(20, (255, 230, 180)).save(str(fx_dir / "star2.png"))
    make_star_particle(15, (180, 200, 255)).save(str(fx_dir / "star3.png"))

    print("  [OK] Stars done")

    # ── ENGINE SHEETS ──
    print("  Engine animations...")

    engine_base = make_engine_sheet(48, 96, 4, (80, 150, 255))
    engine_base.save(str(player_dir / "engine_base_sheet.png"))

    engine_super = make_engine_sheet(48, 96, 4, (255, 150, 50))
    engine_super.save(str(player_dir / "engine_super_sheet.png"))

    print("  [OK] Engines done")

    # ── SHIELD SHEETS ──
    print("  Shield animations...")

    shield_round = make_shield_sheet(64, 64, 12, (80, 200, 255))
    shield_round.save(str(player_dir / "shield_round.png"))

    shield_inv = make_shield_sheet(64, 64, 10, (255, 255, 200))
    shield_inv.save(str(player_dir / "shield_invincible.png"))

    print("  [OK] Shields done")


def download_font():
    """Download a cyberpunk-style font."""
    print("\n=== FONT DOWNLOAD ===\n")

    font_dir = ROOT / "theme"
    font_dir.mkdir(parents=True, exist_ok=True)
    target = font_dir / "NormalFont.ttf"

    # Orbitron - a great free geometric/futuristic font (Google Fonts, SIL Open Font License)
    url = "https://github.com/google/fonts/raw/main/ofl/orbitron/Orbitron%5Bwght%5D.ttf"

    try:
        print(f"  Downloading Orbitron font...")
        # Backup old font
        if target.exists():
            backup = font_dir / "NormalFont_old.ttf"
            if not backup.exists():
                os.rename(str(target), str(backup))
                print(f"  [BACKUP] Old font saved as NormalFont_old.ttf")

        urllib.request.urlretrieve(url, str(target))
        print(f"  [OK] Orbitron font installed as NormalFont.ttf")
    except Exception as e:
        print(f"  [ERROR] Font download failed: {e}")
        # Try alternative: Rajdhani
        try:
            alt_url = "https://github.com/nicholasgoss/rajdhani/raw/master/fonts/Rajdhani-SemiBold.ttf"
            urllib.request.urlretrieve(alt_url, str(target))
            print(f"  [OK] Rajdhani font installed as fallback")
        except Exception as e2:
            print(f"  [ERROR] Fallback also failed: {e2}")


def main():
    print("=" * 60)
    print("  COMPLETE ASSET GENERATION")
    print("  Cyberpunk/Evangelion Space Shooter")
    print("=" * 60)

    generate_procedural_assets()
    generate_dalle_assets()
    download_font()

    # Cleanup
    if TEMP.exists():
        for f in TEMP.glob("*"):
            f.unlink(missing_ok=True)
        TEMP.rmdir()

    print("\n" + "=" * 60)
    print("  ALL DONE!")
    print("=" * 60)


if __name__ == "__main__":
    main()

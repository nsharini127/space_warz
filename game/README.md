# Space Shooter

Vertical space shooter (shmup) built with Godot 4.6 and GDScript. 5-minute matches with escalating difficulty, 9 weapons with evolutions, 8+ enemy types, boss fights, and a trophy system.

## Quick Start

### Requirements

- [Godot 4.6+](https://godotengine.org/download/) (standard or .NET build)

### Running the Game

```bash
git clone https://github.com/YOUR_USERNAME/samurai-game.git
cd samurai-game
```

Open the project in Godot Editor, then press F5 (or Play).

Alternatively, from the command line:

```bash
godot --path . --headless --import   # import assets (first time only)
godot --path .                        # run the game
```

### Controls

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Move | WASD / Arrow Keys | Left Stick |
| Shoot | Z | A / Cross |
| Bomb | X | B / Circle |
| Focus (slow move) | Shift | LT |
| Pause | ESC / P | -- |

## Game Overview

- **Viewport**: 320x480 (pixel art, scaled 2x to 640x960)
- **Match length**: 5 minutes with final boss at timer zero
- **Difficulty curve**: Quadratic `1.0 + t*t*2.0`, range 1.0x to 3.0x
- **Loop**: Waves of enemies -> Boss every 5 waves -> Upgrade selection between waves -> Final boss at 0:00

### Weapons (9 base + 9 evolutions)

| Weapon | Type | Color | Evolution |
|--------|------|-------|-----------|
| Front Laser | Projectile | Cyan | Mega Laser |
| Spread Shot | Projectile | Yellow | Bullet Storm |
| Homing Missiles | Projectile | Orange | Swarm Rockets |
| Rear Cannon | Projectile | Red | Dual Turret |
| Side Cannons | Projectile | Green | Cross Fire |
| Lightning | Effect | Blue | Thunder Storm |
| Orbital Shield | Effect | Purple | Plasma Ring |
| Combat Drone | Effect | Light Blue | Drone Swarm |
| Shockwave | Effect | White-Blue | Nova Blast |

### Enemies

| Type | HP | Speed | First Appears | Behavior |
|------|-----|-------|---------------|----------|
| Runner | 1 | 100 | Wave 1 | Moves straight down |
| Shooter | 2 | 40 | Wave 1 | Stops and fires |
| Charger | 3 | 60 | Wave 3 | Telegraphs, then charges player |
| MidBoss | 15+ | 20 | Wave 5 | Attack patterns |
| Tank | 8 | 20 | Wave 7 | Heavy, ring of 6 bullets |
| Bomber | 5 | 60 | Wave 8 | Crosses screen, drops mines |
| Laser | 6 | 30 | Wave 10 | Tracking beam (1.5s) |
| Meteor | 2-5 | 60-120 | Pre-boss | Falls straight, procedural draw |

### Systems

- **Fever Mode**: 12 kills in 2s triggers 5s of 2x gems (extendable per kill, max 8s)
- **Trophy System**: 8 mid-run achievements with instant bonuses (score/heal/damage)
- **Wave Flavors**: NORMAL, RUSH, SWARM, ELITE variants with different enemy compositions
- **Formation Spawning**: V-shape, line, escort, pincer patterns
- **Drop System**: Power-ups, bombs, health, buffs (shield, invincibility, attack speed)

## Project Architecture

```
samurai-game/
├── scripts/                    # All GDScript source code
│   ├── game.gd                 # Main game controller (orchestrates everything)
│   ├── background_scroller.gd  # Parallax background
│   ├── enemies/                # Enemy AI and spawning
│   │   ├── enemy_base.gd       #   Base class for all enemies (HP, damage, drops)
│   │   ├── enemy_runner.gd     #   Moves straight down
│   │   ├── enemy_shooter.gd    #   Stops, aims, fires
│   │   ├── enemy_charger.gd    #   Telegraphs, then charges player position
│   │   ├── enemy_tank.gd       #   Heavy enemy, ring bullet pattern
│   │   ├── enemy_bomber.gd     #   Horizontal crossing, drops mines
│   │   ├── enemy_laser.gd      #   Tracking beam attack
│   │   ├── enemy_midboss.gd    #   Mini-boss with multi-phase patterns
│   │   ├── enemy_boss.gd       #   Main boss
│   │   ├── meteor.gd           #   Pre-boss obstacle (procedural _draw)
│   │   ├── mine.gd             #   Dropped by bomber, explodes in ring
│   │   ├── wave_spawner.gd     #   Wave management, burst spawning, formations
│   │   └── boss/               #   Multi-part mecha boss
│   ├── player/                 # Player systems
│   │   ├── player.gd           #   Movement, HP, power level, graze detection
│   │   ├── bomb.gd             #   Bomb clear effect
│   │   ├── shield_visual.gd    #   Shield bubble visual
│   │   └── option.gd           #   Drone followers
│   ├── weapons/                # Weapon system
│   │   ├── weapon_registry.gd  #   Pure data: all 9 weapons + evolutions (const)
│   │   ├── weapon_manager.gd   #   Firing logic, cooldowns, level tracking
│   │   ├── orbital_weapon.gd   #   Orbital shield behavior
│   │   └── effects/            #   Non-projectile weapons
│   │       ├── drone_weapon.gd
│   │       ├── lightning_effect.gd
│   │       └── shockwave_effect.gd
│   ├── projectiles/            # Bullet logic
│   │   ├── bullet.gd           #   Player/enemy bullets (procedural _draw per weapon_id)
│   │   └── bullet_pattern.gd   #   Pattern definitions for boss attacks
│   ├── items/                  # Collectibles
│   │   ├── gem.gd              #   XP gems (hexagonal, rotating, procedural _draw)
│   │   └── power_item.gd       #   Power-ups (procedural _draw per type)
│   ├── systems/                # Game systems (all extend Node)
│   │   ├── fever_system.gd     #   Combo tracking, fever activation/extension
│   │   ├── trophy_system.gd    #   8 achievements with bonuses
│   │   ├── counter_system.gd   #   Kill counter and multiplier
│   │   ├── rank_system.gd      #   Dynamic difficulty ranking
│   │   ├── environment_manager.gd  #   Background theme changes
│   │   └── ...
│   ├── effects/                # Visual effects
│   │   ├── explosion.gd        #   Procedural particles + flash + ring
│   │   ├── boss_explosion.gd   #   Multi-phase boss death effect
│   │   ├── bullet_trail.gd     #   Line2D trails behind bullets
│   │   ├── score_popup.gd      #   Floating score numbers
│   │   └── ...
│   ├── ui/                     # User interface
│   │   ├── hud.gd              #   In-game HUD (score, HP, timer, weapons, fever)
│   │   ├── game_over.gd        #   Results screen (grade, stats, weapon showcase)
│   │   ├── upgrade_menu.gd     #   Between-wave weapon/utility selection
│   │   ├── pause_menu.gd       #   Pause overlay
│   │   ├── title_screen.gd     #   Title with procedural stars/scanlines
│   │   ├── boss_hp_bar.gd      #   Boss health bar (procedural gradient)
│   │   ├── wave_announce.gd    #   "WAVE 5 - RUSH" announcements
│   │   ├── trophy_popup.gd     #   Achievement unlock popup
│   │   ├── weapon_icon_draw.gd #   Procedural 16x16 weapon icons
│   │   └── ui_colors.gd        #   Centralized color palette (autoload)
│   └── shared/                 # Shared data
│       ├── game_constants.gd   #   Boss HP formulas, spawn rates
│       ├── drop_table.gd       #   Item drop weights and chances
│       └── buff_system.gd      #   Shield/invincibility/speed buff durations
├── scenes/                     # Godot scene files (.tscn)
│   ├── game.tscn               #   Main game scene (instantiates all nodes)
│   ├── main.tscn               #   Title screen scene
│   ├── enemies/                #   One .tscn per enemy type
│   ├── player/                 #   Player scene
│   ├── projectiles/            #   Bullet scenes
│   ├── ui/                     #   UI overlay scenes
│   └── effects/                #   Effect scenes
├── assets/
│   ├── sprites/                #   Game sprites (player, enemies, UI, fx)
│   ├── audio/
│   │   ├── music/              #   theme_fight.ogg, theme_adventure.ogg
│   │   ├── sfx/                #   14 sound effects
│   │   └── jingles/            #   game_over.wav, level_up.wav
│   ├── backgrounds/            #   Parallax space backgrounds (multiple layers)
│   └── downloads/              #   Source asset packs (Kenney, CC0)
├── shaders/
│   ├── glow_sprite.gdshader    #   Colored glow for bullets/effects
│   └── vignette.gdshader       #   Screen edge darkening
├── theme/
│   ├── NormalFont.ttf          #   Pixel art font
│   └── wood_theme.tres         #   Legacy UI theme
└── default_bus_layout.tres     #   Audio buses: Master > Music, SFX
```

## Core Architecture

### Signal-Driven Communication

Nodes communicate exclusively via signals. No direct method calls between unrelated systems.

```
weapon_manager.weapon_bullet_fired  ->  game._on_player_bullet_fired
wave_spawner.spawn_enemy            ->  game._on_spawn_enemy
wave_spawner.wave_completed         ->  game._on_wave_completed
enemy.enemy_killed                  ->  game._on_enemy_killed
enemy.enemy_shoot                   ->  game._on_enemy_shoot
player.player_died                  ->  game._on_player_died
player.gem_collected                ->  game._on_gem_collected
fever_system.fever_started          ->  game._on_fever_started
trophy_system.trophy_unlocked       ->  game._on_trophy_unlocked
upgrade_menu.upgrade_selected       ->  game._on_upgrade_selected
```

### game.gd - Central Orchestrator

`game.gd` is the hub. It:
- Instantiates and connects all systems in `_init_systems()`
- Routes signals between subsystems (enemies, weapons, UI, player)
- Manages game state: `is_game_active`, `boss_wave_active`, `game_timer`
- Handles spawning of bullets, items, gems, explosions, effects
- Controls music crossfade and SFX playback
- Resets everything cleanly in `start_game()` for restarts

### Collision Layers

| Layer | Bit | Used By |
|-------|-----|---------|
| Player | 1 | Player hitbox |
| Enemy | 2 | Enemy bodies |
| PlayerBullet | 4 | Player projectiles |
| EnemyBullet | 8 | Enemy projectiles |
| Pickup | 16 | Gems, items |

### Groups

| Group | Purpose |
|-------|---------|
| `game` | game.gd node, for enemies to query `get_difficulty_multiplier()` |
| `enemy_hitbox` | Enemy hurtboxes for weapon targeting |
| `enemy_body` | Enemy collision bodies |
| `player_bullet` | Player bullets for cleanup on wave end |
| `enemy_bullet` | Enemy bullets for bomb cancel |

### Procedural Drawing Convention

Sprite sheets in `assets/sprites/projectiles/` are multi-frame and **cannot** be used as direct textures. All dynamic visuals use `_draw()` + `queue_redraw()`:

- Bullets: shape per `weapon_id` (cyan beam, yellow pellet, red bolt, etc.)
- Gems: rotating hexagonal crystals
- Power items: icon per type (bolt, bomb, cross, arrows, hexagon, star)
- Meteors: random rocky shapes
- Explosions: particle system with flash and ring
- Boss HP bar: gradient fill
- Weapon icons: unique 16x16 per weapon

### Difficulty Scaling

```gdscript
func get_difficulty_multiplier() -> float:
    var elapsed = 300.0 - game_timer
    var t = elapsed / 300.0
    return clampf(1.0 + t * t * 2.0, 1.0, 3.0)
```

Enemies read this at spawn via the `"game"` group. Boss HP applies this multiplier. Wave spawner scales enemy count and spawn intervals.

### Wave System

Wave spawner uses burst spawning with configurable flavor:

1. **Burst spawning**: 2-5 enemies rapid-fire (0.3s), then pause (0.8-2.0s)
2. **Wave flavors**: Selected per wave (NORMAL/RUSH/SWARM/ELITE)
3. **Formations**: 10-25% chance per wave (V-shape, line, escort, pincer)
4. **Boss waves**: Every 5th wave, with meteor shower pre-boss
5. **Mecha boss**: Every 10th wave (multi-part destructible boss)

### Weapon Data Model

All weapon stats live in `weapon_registry.gd` as `const WEAPONS` dictionary. Each weapon defines:

```
base_damage[5], fire_interval[5], projectile_count[5],
bullet_speed, glow_color, weapon_type, evolves_to
```

`weapon_manager.gd` reads this data and handles firing, cooldowns, and level progression. Max 6 simultaneous weapons.

### UI Layer Stack

| CanvasLayer | Content |
|-------------|---------|
| 0 (default) | Game world (enemies, bullets, effects) |
| 10 | HUD (score, HP, timer, weapons) |
| 20 | Upgrade menu |
| 25 | Pause menu |
| 30 | Game over screen |

### Audio Architecture

3-bus layout: `Master > Music, SFX`

- **Music**: 2 AudioStreamPlayers for crossfade between fight/adventure themes
- **SFX**: Polyphonic (shoot: 4 voices, coin: 4, enemy_die: 3, explosion: 2)
- **Pitch variation**: Random pitch per sound for organic feel (0.85-1.15 range)
- **Context**: Different sounds based on enemy value (slash for weak, explosion for tough)

## Contributing

### Setup

1. Fork the repository
2. Clone your fork
3. Open in Godot 4.6+
4. Create a feature branch: `git checkout -b feature/your-feature`

### Development Rules

- **Read before edit**: Always read a file before modifying it
- **No sprite sheets as textures**: Use `_draw()` procedural or single-frame images
- **Signals for communication**: No direct cross-node method calls
- **Null safety**: `is_instance_valid()` before accessing nodes that can die
- **Resetable systems**: Every system must clean up in `reset()` / `start_game()`
- **Viewport**: 320x480 fixed, design all positions relative to this
- **Font sizes**: Minimum 7px. Use tiers: 7 (tiny), 8 (small), 10 (body), 12 (heading), 14 (hero), 16 (title)

### Conventions

- Snake_case for files, variables, functions
- PascalCase for class names
- Signals defined at top of script
- `@onready var` for scene node references
- `const` or `static` for pure data
- Group membership set in `_ready()` or scene editor

### Project Configuration

The `context.md` file at the root is the **source of truth** for the project state. It documents every system, every sprint change, and every known issue. Read it before starting work. Update it after completing changes.

### AI-Assisted Development

This project uses an AI agent team system defined in `CLAUDE.md`. Each agent has a specific role (gameplay dev, UI dev, systems dev, QA, etc.) and can be invoked via slash commands. See `CLAUDE.md` for the full team structure.

## Asset Credits

- **Sprites & Backgrounds**: [Kenney.nl](https://kenney.nl) (CC0 - Creative Commons Zero)
  - Space Shooter Redux
  - Space Shooter Extension
- **Audio**: Various free SFX and music tracks
- **Font**: NormalFont.ttf (bundled in `theme/`)

## License

This project's source code is available under the MIT License. Art assets from Kenney are CC0 (public domain). See individual asset pack license files in `assets/downloads/` for details.

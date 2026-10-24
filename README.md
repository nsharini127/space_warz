# Space Warz

ECE Society, NIT Warangal event. A glove with a **Raspberry Pi Pico 2W** inside controls a space shooter on a laptop:
- tilt to fly
- buttons for bomb and menus
- the glove buzzes or lights up when you get hit

```
 ┌──────────────┐  USB serial ──┐      ┌──────────────────────┐  UDP :5005 →  ┌──────────┐
 │ Glove        │               ├────▶ │ Bridge app (laptop)  │ ────────────▶ │  Game    │
 │ (Pico 2W)    │  Bluetooth  ──┘ ◀─── │ auto-connect, GUI,   │ ◀──────────── │ (Godot)  │
 └──────────────┘                      │ calibration, routing │  ← UDP :5006  └──────────┘
                                       └──────────────────────┘
```

- **Glove → bridge:** sensor values, as text lines.
- **Bridge → game:** calibrated controls (`x`, `y`, buttons).
- **Game → bridge:** events like `hit`, `bomb`, `death`.
- **Bridge → glove:** output commands like `PULSE,0,150` (fires transistor/LED channel 0 for 150 ms).

The game and the glove never talk directly, so each part can be changed and tested on its own.

## Repo layout

| Folder | What | Status |
|---|---|---|
| `game/` | Godot 4.6 space shooter, with the glove hook already added | Working |
| `bridge/` | Python app that connects gloves ↔ game (USB + Bluetooth, auto-reconnect, multi-glove) | Working; Bluetooth not yet tested on hardware |
| `firmware/` | Pico 2W MicroPython code | **Test sample only.** BOOTSEL = button, on-board LED = hit indicator. Real glove firmware (IMU, buttons, transistors, Bluetooth) goes here. |
| `game_hooks/python/` | Same hook for Python/Pygame games, in case we switch engines | Working |
| `tests/` | Fake glove on a virtual serial port (Linux/Pi) | Dev tool |
| `PROTOCOL.md` | **The contract** between glove, bridge and game. Read this before changing firmware. | |
| `TESTING.md` | Step-by-step hardware test, for anyone with a board | |

## Quick start (Windows)

You need:
- **Python 3.12**, with "Add to PATH" ticked during install
- **Godot 4.6**: put `Godot_v4.6-stable_win64.exe` in the repo root, or open `game/project.godot` in Godot yourself

Then:
1. **No hardware:** double-click `start_bridge_test.bat` (the bridge with a fake glove), then `start_game.bat`. The fake glove starts the game, flies the ship and fires bombs.
2. **With a Pico 2W:** follow [`TESTING.md`](TESTING.md).

On Linux / Raspberry Pi:
```
cd bridge
pip install -r requirements.txt
python bridge.py          # add --sim 1 for a fake glove, --nogui with no screen
```

## Who changes what

### Firmware team (`firmware/`)
- Anything is fine as long as it follows `PROTOCOL.md`.
- Declare your sensor names in the `HELLO` line, e.g. `ax:ay:az:b0:b1:flex1`. The bridge picks them up automatically, with no bridge change needed.
- The board advertises as `SWGLOVE-xxxx` for Bluetooth.

### Game team (`game/`)
- Controls come in as normal Godot input actions, set up in `game/scripts/glove_input.gd`.
- To make the glove react to something, call `GloveInput.send_event("name")`, then add that event in `bridge/config.json`.

### Mapping / tuning (`bridge/config.json`)
- Which sensor drives which axis or button.
- Tilt sensitivity, deadzone and smoothing.
- Which game event fires which glove output.
- No code changes needed. Press **Reload config** in the bridge window after editing.

## Working on this repo

```
git clone <repo-url>
git checkout -b your-name/what-you-are-doing
# make changes, test
git push -u origin your-name/what-you-are-doing     # then open a Pull Request
```

- Please don't push straight to `main`.
- Never commit `bridge/calibration.json`, which holds per-machine calibration. It's already in `.gitignore`.

## Credits

- Game based on [M4rdine/space-shooter-godot-game](https://github.com/M4rdine/space-shooter-godot-game). The code is MIT licensed; the art is Kenney.nl (CC0). See `game/README.md`.
- Glove bridge, protocol and hooks were written for Space Warz.

# Space Warz – Pico 2W test

Goal: check that the Pico 2W and the game can talk in both directions.

- **Board → game:** pressing the **BOOTSEL** button on the board starts the game and fires bombs.
- **Game → board:** when the ship gets hit, the **on-board LED** flashes.

No wiring is needed: just the board and a USB **data** cable. Some cables are charge-only and won't work.

## You need (Windows laptop)

1. **Python 3.12** from https://www.python.org/downloads/. On the first install screen, tick **"Add python.exe to PATH"**.
2. **Thonny** from https://thonny.org. It's used to copy the code onto the Pico.
3. **Godot 4.6, Windows version** from https://godotengine.org/download/windows/.
   - Unzip it.
   - Put `Godot_v4.6-stable_win64.exe` **inside this folder**, next to `start_game.bat`.
4. **MicroPython for Pico 2 W** from https://micropython.org/download/RPI_PICO2_W/.
   - Download the latest `.uf2` file.
   - It must be the **Pico 2 W** build, not "Pico W" and not "Pico 2".

## Step 1 – Put MicroPython on the board (skip if it already has it)

1. Hold the **BOOTSEL** button and plug the board into USB. Let go of the button.
2. A drive called **RP2350** appears.
3. Drag the `.uf2` file onto it. The drive disappears and the board restarts.

## Step 2 – Copy the test program onto the board

1. Open Thonny.
2. Click the bottom-right corner and choose **MicroPython (Raspberry Pi Pico)**.
3. Open `firmware\main.py` from this folder.
4. Go to **File → Save as… → Raspberry Pi Pico** and name it exactly `main.py`.
5. **Close Thonny completely.** This is important: Thonny blocks the USB port while it's open.
6. Unplug the board and plug it back in. Don't hold BOOTSEL this time.

✅ The on-board LED blinks **3 times quickly**. That means the program is running.

## Step 3 – Board ↔ laptop check (no game yet)

1. Double-click **`start_bridge.bat`**. The first time, it installs two small Python packages.
2. A "Glove Bridge" window opens. Within a few seconds a row appears with **P1, USB, COM-something, about 50 Hz**.

✅ Press **BOOTSEL**. The **A** box in the window turns green while you hold it.

✅ Click the glove row, leave "Output ch" at **0**, and click **Pulse 200ms**. The **on-board LED blinks**.

If both happen, the link works in both directions. **Leave the bridge window open.**

## Step 4 – With the game

1. Double-click **`start_game.bat`**. The first run imports assets, which takes about a minute.
2. The title screen shows "Press ENTER to Start".

✅ Press **BOOTSEL**. The game starts.

✅ In the game, press **BOOTSEL**. A **bomb** goes off (screen flash), and the bomb counter at the top right (x3) goes down.

✅ Steer into an enemy with the **arrow keys**. The ship fires automatically. When you get hit, the **on-board LED flashes**.

The game will print some red "ERROR" lines in its console. Those come from the original game and are harmless.

## Please send back

1. A **screenshot of the bridge window** after the tests, including the log on the right.
2. Which ✅ checks worked and which didn't.

## If something goes wrong

| Problem | Fix |
|---|---|
| No row appears in the bridge | Use a different USB cable (data, not charge-only). Check Thonny is closed. |
| Log says "Can't open COM…" / "Access denied" | Thonny or another serial program is still open. Close it. |
| Log says "didn't answer WHO" | `main.py` isn't on the board or has an error. Redo Step 2. |
| `start_bridge.bat` says python not found | Reinstall Python with "Add to PATH" ticked. |
| `start_game.bat` says Godot not found | Put `Godot_v4.6-stable_win64.exe` in this folder. |
| Windows Firewall popup | Click **Allow**. The traffic stays on this laptop. |

# Space Warz - minimal glove TEST firmware (MicroPython, Raspberry Pi Pico 2 W, USB only)
#
#   BOOTSEL button on the board  -> button "a"  (= Enter on menus, bomb in game)
#   Game says "hit"/"death"       -> on-board LED flashes
#   Game says "bomb"              -> GP16 pulses (optional: LED + resistor to GND)
#
# Optional external button: GP15 to GND (works alongside BOOTSEL).
# Save this file to the Pico as main.py. It follows PROTOCOL.md.

import sys
import select
import time
import binascii
import machine

try:
    import rp2
    HAVE_BOOTSEL = hasattr(rp2, "bootsel_button")
except ImportError:
    HAVE_BOOTSEL = False

EXT_BUTTON = machine.Pin(15, machine.Pin.IN, machine.Pin.PULL_UP)

# Output channels: index = channel number used in OUT / PULSE commands
OUTPUTS = [
    machine.Pin("LED", machine.Pin.OUT),   # ch 0: on-board LED
    machine.Pin(16, machine.Pin.OUT),      # ch 1: GP16 (transistor / LED later)
]
off_at = [None] * len(OUTPUTS)             # when each pulse should end (ticks_ms)

GLOVE_ID = binascii.hexlify(machine.unique_id()).decode().upper()
FIELDS = "b0"
FW = "test-0.1"


def hello():
    print("HELLO,%s,%s,%s,%d" % (GLOVE_ID, FW, FIELDS, len(OUTPUTS)))


def button_pressed():
    pressed = EXT_BUTTON.value() == 0
    if HAVE_BOOTSEL and rp2.bootsel_button():
        pressed = True
    return 1 if pressed else 0


def set_out(ch, on):
    if 0 <= ch < len(OUTPUTS):
        OUTPUTS[ch].value(1 if on else 0)


def handle(line):
    parts = line.split(",")
    cmd = parts[0]
    try:
        if cmd == "WHO":
            hello()
        elif cmd == "PING":
            print("PONG," + parts[1])
        elif cmd == "OUT":
            ch = int(parts[1])
            off_at[ch] = None
            set_out(ch, int(parts[2]))
        elif cmd == "PULSE":
            ch = int(parts[1])
            set_out(ch, 1)
            off_at[ch] = time.ticks_add(time.ticks_ms(), int(parts[2]))
        elif cmd == "PWM":  # no PWM in the test build: >0 means on
            ch = int(parts[1])
            off_at[ch] = None
            set_out(ch, int(parts[2]) > 0)
        else:
            print("ERR,unknown cmd " + cmd)
    except Exception:
        print("ERR,bad line " + line)


# --- read USB input without blocking the loop
poller = select.poll()
poller.register(sys.stdin, select.POLLIN)
buf = ""


def read_commands():
    global buf
    while poller.poll(0):
        c = sys.stdin.read(1)
        if not c:
            break
        if c == "\n":
            if buf:
                handle(buf.strip())
            buf = ""
        elif c != "\r":
            buf += c
            if len(buf) > 120:  # garbage, start over
                buf = ""


# --- boot: 3 quick blinks so you can see the firmware started
for _ in range(3):
    OUTPUTS[0].on()
    time.sleep_ms(80)
    OUTPUTS[0].off()
    time.sleep_ms(80)
hello()

# --- main loop: ~50 times a second
while True:
    read_commands()
    now = time.ticks_ms()
    for ch in range(len(OUTPUTS)):
        if off_at[ch] is not None and time.ticks_diff(now, off_at[ch]) >= 0:
            set_out(ch, 0)
            off_at[ch] = None
    print("D,%d" % button_pressed())
    time.sleep_ms(20)

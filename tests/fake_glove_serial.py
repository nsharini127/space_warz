"""
Linux/Raspberry Pi only: pretend to be a glove on a virtual serial port, so the
bridge's USB code path can be tested without hardware.

    python fake_glove_serial.py            # prints the port name, e.g. /dev/pts/5
    # put that port in config.json -> usb.manual_ports, then start the bridge

Options:
    --id ABCD1234      glove id to report
    --silent           open the port but never answer (tests the "no HELLO" path)
    --die-after 5      stop sending after N seconds (tests timeout + reconnect)
"""
import argparse
import math
import os
import pty
import select
import time
import tty

ap = argparse.ArgumentParser()
ap.add_argument("--id", default="FAKE0000CAFE")
ap.add_argument("--silent", action="store_true")
ap.add_argument("--die-after", type=float, default=0)
ap.add_argument("--portfile", default="")
args = ap.parse_args()

master, slave = pty.openpty()
tty.setraw(slave)
name = os.ttyname(slave)
print(name, flush=True)
if args.portfile:
    with open(args.portfile, "w") as f:
        f.write(name)

FIELDS = "ax:ay:az:gx:gy:gz:b0:b1"
hello = f"HELLO,{args.id},fake-1.0,{FIELDS},2\n"
t0 = time.time()
buf = b""
outs = {}

def send(s):
    try:
        os.write(master, s.encode())
    except OSError:
        pass

if not args.silent:
    send(hello)
while True:
    r, _, _ = select.select([master], [], [], 0.02)
    if r:
        try:
            buf += os.read(master, 1024)
        except OSError:
            buf = b""
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            line = line.decode().strip()
            if args.silent or not line:
                continue
            print("rx:", line, flush=True)
            head, _, rest = line.partition(",")
            if head == "WHO":
                send(hello)
            elif head == "PING":
                send(f"PONG,{rest}\n")
            elif head in ("OUT", "PULSE", "PWM"):
                send(f"LOG,fake applied {line}\n")
    t = time.time() - t0
    if args.silent:
        continue
    if args.die_after and t > args.die_after:
        continue  # stay open but go quiet, like crashed firmware
    ax, ay = 0.3 * math.sin(t), 0.3 * math.cos(t)
    send(f"D,{ax:.3f},{ay:.3f},0.95,0,0,0,{1 if t % 2 < 0.3 else 0},0\n")

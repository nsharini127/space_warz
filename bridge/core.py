"""
Space Warz glove bridge - core logic (no GUI).

Finds gloves over USB serial and Bluetooth LE, keeps them connected, turns their
sensor data into game controls, and passes messages between gloves and the game
over UDP. See PROTOCOL.md for the wire formats.

Threads:
  usb-scan    looks for new Pico serial ports every second and opens them
  serial-*    one reader per open serial port
  ble         an asyncio loop that scans for and talks to Bluetooth gloves
  watchdog    handshakes, timeouts, pings
  game-tx     sends glove state to the game ~60 times a second
  game-rx     receives events/commands from the game
"""

import asyncio
import json
import math
import os
import socket
import threading
import time
from collections import deque

try:
    import serial
    from serial.tools import list_ports
except ImportError:  # the GUI shows a warning; the simulator still works
    serial = None
    list_ports = None

try:
    from bleak import BleakClient, BleakScanner
except ImportError:
    BleakClient = BleakScanner = None

NUS_SERVICE = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
NUS_RX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"  # bridge -> glove (write)
NUS_TX = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"  # glove -> bridge (notify)

LINK_PRIORITY = {"usb": 0, "ble": 1, "sim": 2}
HANDSHAKE_TIMEOUT_S = 4.0
WHO_RESEND_S = 0.7
PORT_COOLDOWN_S = 5.0

HERE = os.path.dirname(os.path.abspath(__file__))


def now():
    return time.monotonic()


# --------------------------------------------------------------------------- links

class Link:
    """One physical connection to one glove (a serial port, a BLE connection, or the simulator)."""

    kind = "?"

    def __init__(self, bridge, label):
        self.bridge = bridge
        self.label = label
        self.glove = None          # set once the glove has said HELLO
        self.alive = True
        self.created = now()
        self.last_rx = now()
        self.last_data = now()     # last sensor frame; silence here = glove is dead
        self.frames = 0            # sensor frames received on this link
        self.last_who = 0.0
        self.handshake_failed = False
        self._buf = ""

    def feed(self, text):
        """Called with raw text from the transport; splits it into lines."""
        self.last_rx = now()
        self._buf += text
        if len(self._buf) > 4096:  # garbage with no newlines - drop it
            self._buf = self._buf[-512:]
        while "\n" in self._buf:
            line, self._buf = self._buf.split("\n", 1)
            line = line.strip()
            if line:
                self.bridge._on_line(self, line)

    def send_line(self, line):
        raise NotImplementedError

    def close(self, reason=""):
        if not self.alive:
            return
        self.alive = False
        self._close_transport()
        self.bridge._link_closed(self, reason)

    def _close_transport(self):
        pass


class SerialLink(Link):
    kind = "usb"

    def __init__(self, bridge, port):
        super().__init__(bridge, port)
        self.port = port
        self._wlock = threading.Lock()
        self.ser = serial.Serial(port, 115200, timeout=0.05, write_timeout=0.5)
        try:
            self.ser.dtr = True  # some USB-serial stacks only send while DTR is set
        except Exception:
            pass
        self.ser.reset_input_buffer()
        threading.Thread(target=self._reader, name=f"serial-{port}", daemon=True).start()

    def _reader(self):
        while self.alive:
            try:
                data = self.ser.read(self.ser.in_waiting or 1)
            except Exception as e:  # unplugged, driver error...
                self.close(f"read error: {e}")
                return
            if data:
                self.feed(data.decode("ascii", "replace"))

    def send_line(self, line):
        if not self.alive:
            return
        try:
            with self._wlock:
                self.ser.write((line + "\n").encode("ascii", "replace"))
        except Exception as e:
            self.close(f"write error: {e}")

    def _close_transport(self):
        try:
            self.ser.close()
        except Exception:
            pass


class BleLink(Link):
    kind = "ble"

    def __init__(self, bridge, client, label, loop, addr):
        super().__init__(bridge, label)
        self.addr = addr
        self.client = client
        self.loop = loop
        self.closed_event = asyncio.Event()
        self._wlock = asyncio.Lock()

    def on_notify(self, _char, data):
        self.feed(bytes(data).decode("ascii", "replace"))

    def send_line(self, line):
        if self.alive:
            asyncio.run_coroutine_threadsafe(self._write((line + "\n").encode("ascii", "replace")), self.loop)

    async def _write(self, data):
        try:
            async with self._wlock:
                # 20 bytes always fits, whatever MTU was negotiated
                for i in range(0, len(data), 20):
                    await self.client.write_gatt_char(NUS_RX, data[i:i + 20], response=False)
        except Exception as e:
            self.close(f"BT write error: {e}")

    def _close_transport(self):
        self.loop.call_soon_threadsafe(self.closed_event.set)


class SimLink(Link):
    """A fake glove for testing without hardware. Behaves like real firmware."""

    kind = "sim"
    FIELDS = ["ax", "ay", "az", "gx", "gy", "gz", "b0", "b1", "b2"]

    def __init__(self, bridge, sim_id):
        super().__init__(bridge, f"simulator {sim_id}")
        self.sim_id = sim_id
        self.phase = (hash(sim_id) % 100) / 10.0
        self.paused = False
        self._hello()
        threading.Thread(target=self._run, name=f"sim-{sim_id}", daemon=True).start()

    def _hello(self):
        self.feed(f"HELLO,{self.sim_id},sim-1.0,{':'.join(self.FIELDS)},2\n")

    def _run(self):
        t0 = now()
        while self.alive:
            time.sleep(0.02)  # 50 Hz
            if self.paused:
                continue
            t = now() - t0 + self.phase
            ax = 0.35 * math.sin(t * 0.9)
            ay = 0.35 * math.sin(t * 1.3 + 1.0)
            az = 0.95
            gx, gy, gz = 20 * math.cos(t * 0.9), 25 * math.cos(t * 1.3), 0.0
            b0 = 1 if (t % 3.0) < 0.4 else 0
            b1 = 1 if (t % 7.0) < 1.0 else 0
            self.feed(f"D,{ax:.3f},{ay:.3f},{az:.3f},{gx:.1f},{gy:.1f},{gz:.1f},{b0},{b1},0\n")

    def send_line(self, line):
        if not self.alive:
            return
        head, _, rest = line.partition(",")
        if head == "WHO":
            self._hello()
        elif head == "PING":
            self.feed(f"PONG,{rest}\n")
        elif head in ("OUT", "PULSE", "PWM"):
            self.feed(f"LOG,sim got {line}\n")
        else:
            self.feed(f"ERR,unknown cmd {head}\n")


# --------------------------------------------------------------------------- glove

class Glove:
    def __init__(self, gid):
        self.id = gid
        self.fw = ""
        self.fields = []
        self.n_outputs = 0
        self.links = {}            # kind -> Link
        self.values = {}           # latest raw values by field name
        self.history = deque(maxlen=25)
        self.frame_times = deque(maxlen=200)
        self.bad_frames = 0
        self.player = None
        self.x = 0.0
        self.y = 0.0
        self.buttons = {}
        self.rtt_ms = None
        self.pings = {}
        self.last_ping = 0.0
        self.last_seen = 0.0
        self.was_online = False
        self.out_until = {}        # channel -> monotonic time it switches off (inf = on)

    @property
    def short(self):
        return self.id[-4:] if len(self.id) > 6 else self.id

    def alive_links(self):
        return [l for l in list(self.links.values()) if l.alive]

    def live_links(self):
        """Links that are actually streaming sensor data."""
        return [l for l in self.alive_links() if l.frames > 0]

    def preferred(self):
        links = self.live_links() or self.alive_links()
        return min(links, key=lambda l: LINK_PRIORITY.get(l.kind, 9)) if links else None

    @property
    def online(self):
        return bool(self.live_links())

    def rate(self):
        cutoff = now() - 1.0
        return sum(1 for t in self.frame_times if t >= cutoff)


# --------------------------------------------------------------------------- bridge

class Bridge:
    def __init__(self, config_path=None, log=print):
        self.config_path = config_path or os.path.join(HERE, "config.json")
        self.calib_path = os.path.join(os.path.dirname(self.config_path), "calibration.json")
        self._log_fn = log
        self.lock = threading.RLock()
        self.gloves = {}            # id -> Glove
        self.pending = set()        # links that haven't said HELLO yet
        self.open_ports = {}        # serial port name -> SerialLink
        self.port_cooldown = {}     # port -> time
        self.port_errors = {}       # port -> last error text (so we don't spam the log)
        self.ble_active = set()     # addresses being connected / connected
        self.ble_cooldown = {}
        self.ble_last_drop = 0.0
        self.ble_status = "starting"
        self.usb_enabled = True
        self.ble_enabled = True
        self.running = False
        self.last_game_msg = 0.0
        self.game_rx_ok = False
        self.sim_count = 0
        self._ble_loop = None
        self._gamepads = {}
        self._vg = None
        self.load_config()
        self._calib = self._load_json(self.calib_path, {"gloves": {}})

    # ---------------------------------------------------------------- config / logging

    def log(self, msg):
        try:
            self._log_fn(time.strftime("%H:%M:%S ") + msg)
        except Exception:
            pass

    @staticmethod
    def _load_json(path, default):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except FileNotFoundError:
            return default
        except Exception as e:
            print(f"Could not read {path}: {e}")
            return default

    def load_config(self):
        cfg = self._load_json(self.config_path, None)
        if cfg is None:
            raise SystemExit(f"Config file missing or broken: {self.config_path}")
        self.cfg = cfg
        self.usb_enabled = cfg.get("usb", {}).get("enabled", True)
        self.ble_enabled = cfg.get("ble", {}).get("enabled", True)

    def reload_config(self):
        try:
            self.load_config()
            self.log("Config reloaded (game ports need a restart to change).")
        except SystemExit as e:
            self.log(str(e))

    def _save_calib(self):
        try:
            with open(self.calib_path, "w", encoding="utf-8") as f:
                json.dump(self._calib, f, indent=2)
        except Exception as e:
            self.log(f"Could not save calibration: {e}")

    def _calib_for(self, gid):
        return self._calib.setdefault("gloves", {}).setdefault(gid, {})

    # ---------------------------------------------------------------- lifecycle

    def start(self):
        self.running = True
        if serial is None:
            self.log("pyserial is not installed - USB disabled. Run: pip install pyserial")
        for target, name in [(self._usb_scan_loop, "usb-scan"), (self._watchdog_loop, "watchdog"),
                             (self._game_tx_loop, "game-tx"), (self._game_rx_loop, "game-rx"),
                             (self._ble_thread, "ble")]:
            threading.Thread(target=target, name=name, daemon=True).start()
        self.log("Bridge started. Waiting for gloves...")

    def stop(self):
        self.running = False
        with self.lock:
            links = [l for g in self.gloves.values() for l in g.alive_links()] + list(self.pending)
        for l in links:
            l.close("bridge stopping")
        time.sleep(0.2)

    # ---------------------------------------------------------------- incoming lines

    def _on_line(self, link, line):
        head, _, rest = line.partition(",")
        if head == "HELLO":
            self._on_hello(link, rest.split(","))
            return
        g = link.glove
        if g is None:
            return  # not a glove yet (could be REPL noise) - ignore until HELLO
        if head == "D":
            self._on_data(g, link, rest)
        elif head == "PONG":
            sent = g.pings.pop(rest.strip(), None)
            if sent is not None:
                g.rtt_ms = (now() - sent) * 1000.0
        elif head in ("LOG", "ERR", "OK"):
            self.log(f"[glove {g.short} {link.kind}] {head} {rest}")

    def _on_hello(self, link, parts):
        if len(parts) < 3 or not parts[0].strip():
            self.log(f"{link.label}: bad HELLO line, ignoring")
            return
        gid = parts[0].strip()
        with self.lock:
            g = self.gloves.get(gid)
            if g is None:
                g = self.gloves[gid] = Glove(gid)
            g.fw = parts[1].strip()
            g.fields = [f.strip() for f in parts[2].split(":") if f.strip()]
            try:
                g.n_outputs = int(parts[3]) if len(parts) > 3 else 0
            except ValueError:
                g.n_outputs = 0
            if link.glove is g:
                return  # repeated HELLO on an existing link (e.g. answer to WHO)
            old = g.links.get(link.kind)
            if old is not None and old is not link and old.alive:
                old.close("replaced by a new connection")
            self.pending.discard(link)
            self.port_errors.pop(("nohello", link.label), None)
            link.glove = g
            link.last_data = now()
            g.links[link.kind] = link
            g.last_seen = now()
            # "connected" is announced on the first sensor frame (see _first_frame)

    def _first_frame(self, g, link):
        with self.lock:
            self.port_errors.pop(("nodata", link.label), None)
            if not g.was_online:
                g.was_online = True
                self._assign_player(g)
                self.log(f"Glove {g.short} connected via {link.kind.upper()} ({link.label}) -> Player {g.player}. "
                         f"Fields: {', '.join(g.fields) or '(none)'}; outputs: {g.n_outputs}")
                self._send_game({"t": "connected", "player": g.player, "glove": g.id})
            else:
                kinds = "+".join(l.kind.upper() for l in sorted(g.live_links(), key=lambda l: LINK_PRIORITY.get(l.kind, 9)))
                self.log(f"Glove {g.short}: {link.kind.upper()} link up ({link.label}); now {kinds}")

    def _on_data(self, g, link, rest):
        link.last_data = now()
        link.frames += 1
        if link.frames == 1:
            self._first_frame(g, link)
        if link is not g.preferred():
            return  # backup link (e.g. BLE while USB is plugged) - keep it alive, ignore its data
        parts = rest.split(",")
        if len(parts) != len(g.fields):
            g.bad_frames += 1
        vals = {}
        for name, text in zip(g.fields, parts):
            try:
                vals[name] = float(text)
            except ValueError:
                g.bad_frames += 1
        t = now()
        with self.lock:
            g.values.update(vals)
            g.history.append(dict(g.values))
            g.frame_times.append(t)
            g.last_seen = t
            self._map_controls(g)

    # ---------------------------------------------------------------- mapping

    def _axis(self, g, spec, prev):
        if not spec:
            return 0.0
        field = spec.get("field")
        if field not in g.values:
            return 0.0
        center = self._calib_for(g.id).get("center", {}).get(field, spec.get("center", 0.0))
        rng = spec.get("range", 1.0) or 1.0
        v = (g.values[field] - center) / rng
        if spec.get("invert"):
            v = -v
        v = max(-1.0, min(1.0, v))
        dz = spec.get("deadzone", 0.0)
        if abs(v) < dz:
            v = 0.0
        else:
            v = math.copysign((abs(v) - dz) / (1.0 - dz), v) if dz < 1 else 0.0
        a = spec.get("smoothing", 0.0)  # 0 = none, 0.9 = very smooth/laggy
        return a * prev + (1 - a) * v

    def _map_controls(self, g):
        c = self.cfg.get("controls", {})
        g.x = self._axis(g, c.get("x"), g.x)
        g.y = self._axis(g, c.get("y"), g.y)
        if abs(g.x) < 1e-3:
            g.x = 0.0
        if abs(g.y) < 1e-3:
            g.y = 0.0
        buttons = {}
        for name, spec in c.get("buttons", {}).items():
            if isinstance(spec, str):
                spec = {"field": spec}
            v = g.values.get(spec.get("field"))
            pressed = v is not None and v >= spec.get("threshold", 0.5)
            if spec.get("invert"):
                pressed = (v is not None) and not pressed
            buttons[name] = pressed
        g.buttons = buttons

    def calibrate(self, gid):
        """Treat the glove's current (averaged) pose as the centre."""
        with self.lock:
            g = self.gloves.get(gid)
            if not g or not g.history:
                return False
            c = self.cfg.get("controls", {})
            centers = self._calib_for(gid).setdefault("center", {})
            for axis in ("x", "y"):
                field = (c.get(axis) or {}).get("field")
                samples = [h[field] for h in g.history if field in h]
                if samples:
                    centers[field] = sum(samples) / len(samples)
            self._save_calib()
        self.log(f"Glove {g.short} calibrated: centre = {', '.join(f'{k}={v:.3f}' for k, v in centers.items())}")
        return True

    def reset_calibration(self, gid):
        with self.lock:
            self._calib_for(gid).pop("center", None)
            self._save_calib()
        self.log(f"Glove {gid[-4:]} calibration reset")

    # ---------------------------------------------------------------- players

    def _assign_player(self, g):
        taken = {o.player for o in self.gloves.values() if o is not g and o.online and o.player}
        remembered = self._calib_for(g.id).get("player")
        if remembered and remembered not in taken:
            g.player = remembered
        elif g.player and g.player not in taken:
            pass
        else:
            n = 1
            while n in taken:
                n += 1
            g.player = n
        self._calib_for(g.id)["player"] = g.player
        self._save_calib()

    def set_player(self, gid, n):
        with self.lock:
            g = self.gloves.get(gid)
            if not g or n < 1:
                return
            for o in self.gloves.values():
                if o is not g and o.player == n:
                    o.player = g.player  # swap
                    self._calib_for(o.id)["player"] = o.player
            g.player = n
            self._calib_for(gid)["player"] = n
            self._save_calib()
        self.log(f"Glove {g.short} is now Player {n}")

    def forget_offline(self):
        with self.lock:
            for gid in [k for k, g in self.gloves.items() if not g.online]:
                del self.gloves[gid]

    # ---------------------------------------------------------------- commands to gloves

    def send_command(self, g, line):
        link = g.preferred()
        if link is None:
            return False
        link.send_line(line)
        parts = line.split(",")
        try:
            if parts[0] == "PULSE":
                g.out_until[int(parts[1])] = now() + int(parts[2]) / 1000.0
            elif parts[0] == "OUT":
                g.out_until[int(parts[1])] = float("inf") if int(parts[2]) else 0.0
        except (IndexError, ValueError):
            pass
        return True

    def targets(self, player):
        with self.lock:
            return [g for g in self.gloves.values() if g.online and (player in (0, None) or g.player == player)]

    def fire_event(self, name, player=0):
        cmds = self.cfg.get("events", {}).get(name)
        if cmds is None:
            self.log(f"Game sent unknown event '{name}' - add it to config.json 'events' to make it do something")
            return
        for g in self.targets(player):
            for cmd in cmds:
                self.send_command(g, ",".join(str(c) for c in cmd))

    def add_simulated_glove(self):
        with self.lock:
            self.sim_count += 1
            sid = f"SIM-{self.sim_count}"
        SimLink(self, sid)
        return sid

    def disconnect(self, gid):
        with self.lock:
            g = self.gloves.get(gid)
            links = g.alive_links() if g else []
        for l in links:
            if l.kind == "usb":
                self.port_cooldown[l.port] = now() + PORT_COOLDOWN_S
            l.close("disconnected by operator")

    # ---------------------------------------------------------------- link bookkeeping

    def _register_pending(self, link):
        with self.lock:
            self.pending.add(link)

    def _link_closed(self, link, reason):
        with self.lock:
            self.pending.discard(link)
            if isinstance(link, SerialLink):
                if self.open_ports.get(link.port) is link:
                    del self.open_ports[link.port]
                if link.handshake_failed:
                    self.port_cooldown[link.port] = now() + PORT_COOLDOWN_S
            elif isinstance(link, BleLink) and link.handshake_failed:
                self.ble_cooldown[link.addr] = now() + PORT_COOLDOWN_S
            g = link.glove
            if g is None:
                return
            if g.links.get(link.kind) is link:
                del g.links[link.kind]
            if link.kind == "ble":
                self.ble_last_drop = now()
            if link.frames == 0 and self.running:
                # said HELLO but never streamed: back off instead of flapping
                if isinstance(link, SerialLink):
                    self.port_cooldown[link.port] = now() + PORT_COOLDOWN_S
                elif isinstance(link, BleLink):
                    self.ble_cooldown[link.addr] = now() + PORT_COOLDOWN_S
                key = ("nodata", link.label)
                if key not in self.port_errors:
                    self.port_errors[key] = True
                    self.log(f"Glove {g.short} on {link.label} answers WHO but sends no sensor (D) lines - "
                             f"is the sensor loop stuck? (will keep retrying every {PORT_COOLDOWN_S:.0f}s)")
            if g.online:
                if link.frames:
                    self.log(f"Glove {g.short}: {link.kind.upper()} lost ({reason}) - now using {g.preferred().kind.upper()}")
                return
            if not g.was_online:
                return
            g.was_online = False
            g.x = g.y = 0.0
            g.buttons = {k: False for k in g.buttons}
            g.rtt_ms = None
            g.out_until.clear()
        self.log(f"Glove {g.short} (Player {g.player}) DISCONNECTED: {reason}. Will reconnect automatically.")
        self._send_game({"t": "disconnected", "player": g.player, "glove": g.id})

    # ---------------------------------------------------------------- USB

    def _usb_scan_loop(self):
        while self.running:
            usb = self.cfg.get("usb", {})
            if serial is not None and self.usb_enabled:
                try:
                    self._usb_scan_once(usb)
                except Exception as e:
                    self.log(f"USB scan error: {e}")
            time.sleep(usb.get("scan_interval_s", 1.0))

    def _usb_scan_once(self, usb):
        vid = int(str(usb.get("vid", "2E8A")), 16)
        ports = [p.device for p in list_ports.comports() if p.vid == vid]
        ports += [p for p in usb.get("manual_ports", []) if p not in ports]
        t = now()
        for port in ports:
            with self.lock:
                if port in self.open_ports or self.port_cooldown.get(port, 0) > t:
                    continue
            try:
                link = SerialLink(self, port)
            except Exception as e:
                msg = str(e)
                if self.port_errors.get(port) != msg:
                    self.port_errors[port] = msg
                    hint = " (is Thonny / Arduino Serial Monitor / another bridge using it?)" if "ermission" in msg or "busy" in msg.lower() or "denied" in msg.lower() else ""
                    self.log(f"Can't open {port}: {msg}{hint}")
                self.port_cooldown[port] = t + PORT_COOLDOWN_S
                continue
            self.port_errors.pop(port, None)
            with self.lock:
                self.open_ports[port] = link
                self.pending.add(link)
            link.last_who = now()
            link.send_line("WHO")

    # ---------------------------------------------------------------- watchdog

    def _watchdog_loop(self):
        while self.running:
            time.sleep(0.1)
            t = now()
            timeout = self.cfg.get("link_timeout_s", 1.5)
            ping_every = self.cfg.get("ping_interval_s", 1.0)
            with self.lock:
                pending = list(self.pending)
                attached = [(g, l) for g in self.gloves.values() for l in g.alive_links()]
                online = [g for g in self.gloves.values() if g.online]
            for link in pending:
                if not link.alive:
                    continue
                if t - link.created > HANDSHAKE_TIMEOUT_S:
                    link.handshake_failed = True
                    link.close("no HELLO reply")
                    key = ("nohello", link.label)
                    if key not in self.port_errors:  # say it once, keep retrying quietly
                        self.port_errors[key] = True
                        self.log(f"{link.label} is connected but didn't answer WHO - is the glove firmware running? "
                                 f"(will keep retrying every {PORT_COOLDOWN_S:.0f}s)")
                elif t - link.last_who > WHO_RESEND_S:
                    link.last_who = t
                    link.send_line("WHO")
            for g, link in attached:
                if t - link.last_data > timeout:
                    link.close(f"no sensor data for {timeout}s")
            for g in online:
                if t - g.last_ping >= ping_every:
                    g.last_ping = t
                    token = str(int(t * 1000) % 1000000)
                    g.pings = {k: v for k, v in g.pings.items() if t - v < 5}
                    g.pings[token] = t
                    link = g.preferred()
                    if link:
                        link.send_line(f"PING,{token}")
                for ch, until in list(g.out_until.items()):
                    if until <= t:
                        del g.out_until[ch]

    # ---------------------------------------------------------------- Bluetooth

    def _ble_thread(self):
        if BleakScanner is None:
            self.ble_status = "bleak not installed"
            self.log("bleak is not installed - Bluetooth disabled. Run: pip install bleak")
            return
        try:  # Windows: make sure this thread isn't a COM single-threaded apartment
            from bleak.backends.winrt.util import uninitialize_sta
            uninitialize_sta()
        except Exception:
            pass
        loop = asyncio.new_event_loop()
        self._ble_loop = loop
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(self._ble_main())
        except Exception as e:
            self.ble_status = f"error: {e}"
            self.log(f"Bluetooth stopped: {e}")

    async def _ble_main(self):
        last_error = None
        while self.running:
            ble = self.cfg.get("ble", {})
            if not self.ble_enabled:
                self.ble_status = "off"
                await asyncio.sleep(0.5)
                continue
            self.ble_status = "scanning"
            try:
                found = await BleakScanner.discover(timeout=ble.get("scan_seconds", 4), return_adv=True)
                last_error = None
            except Exception as e:
                msg = str(e) or type(e).__name__
                if msg != last_error:
                    self.log(f"Bluetooth unavailable: {msg} (USB still works)")
                    last_error = msg
                self.ble_status = "unavailable"
                await asyncio.sleep(10)
                continue
            prefix = ble.get("name_prefix", "SWGLOVE")
            t = now()
            for addr, (dev, adv) in found.items():
                name = adv.local_name or dev.name or ""
                uuids = [u.lower() for u in (adv.service_uuids or [])]
                if not (name.startswith(prefix) or NUS_SERVICE in uuids):
                    continue
                if addr in self.ble_active or self.ble_cooldown.get(addr, 0) > t:
                    continue
                self.ble_active.add(addr)
                asyncio.ensure_future(self._ble_connect(dev, name or addr))
            self.ble_status = "idle"
            # scan again sooner if a Bluetooth glove dropped recently
            wait = 1.0 if now() - self.ble_last_drop < 60 else ble.get("scan_interval_s", 8)
            await asyncio.sleep(wait)

    async def _ble_connect(self, dev, name):
        addr = dev.address
        link = None
        client = None
        dropped = asyncio.Event()
        try:
            self.log(f"Bluetooth: connecting to {name}...")
            client = BleakClient(dev, disconnected_callback=lambda _c: dropped.set())
            await asyncio.wait_for(client.connect(), 15)
            link = BleLink(self, client, f"{name} {addr}", asyncio.get_running_loop(), addr)
            self._register_pending(link)
            await client.start_notify(NUS_TX, link.on_notify)
            link.last_who = now()
            link.send_line("WHO")
            waiters = [asyncio.ensure_future(dropped.wait()), asyncio.ensure_future(link.closed_event.wait())]
            await asyncio.wait(waiters, return_when=asyncio.FIRST_COMPLETED)
            for w in waiters:
                w.cancel()
        except Exception as e:
            self.log(f"Bluetooth: {name} connect failed: {e or type(e).__name__}")
            self.ble_cooldown[addr] = now() + PORT_COOLDOWN_S
        finally:
            if link is not None:
                link.close("Bluetooth link dropped")
            if client is not None:
                try:
                    await client.disconnect()
                except Exception:
                    pass
            self.ble_active.discard(addr)

    # ---------------------------------------------------------------- game link

    def _send_game(self, msg):
        try:
            g = self.cfg.get("game", {})
            # one game window per player on the same PC: give each player its own port
            port = g.get("player_ports", {}).get(str(msg.get("player")), g.get("send_port", 5005))
            self._tx_sock.sendto(json.dumps(msg, separators=(",", ":")).encode(),
                                 (g.get("host", "127.0.0.1"), int(port)))
        except AttributeError:
            pass  # game-tx thread not started yet
        except OSError:
            pass  # nothing listening - that's fine for UDP

    def _game_tx_loop(self):
        self._tx_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        while self.running:
            rate = max(1, self.cfg.get("game", {}).get("rate_hz", 60))
            time.sleep(1.0 / rate)
            with self.lock:
                msgs = [{"t": "state", "player": g.player, "glove": g.id,
                         "link": g.preferred().kind if g.preferred() else None,
                         "x": round(g.x, 4), "y": round(g.y, 4), "buttons": dict(g.buttons),
                         "raw": dict(g.values)}
                        for g in self.gloves.values() if g.online]
            for m in msgs:
                self._send_game(m)
            self._update_gamepads(msgs)

    def _game_rx_loop(self):
        g = self.cfg.get("game", {})
        host, port = g.get("listen_host", "127.0.0.1"), g.get("listen_port", 5006)
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            sock.bind((host, port))
        except OSError as e:
            self.log(f"Can't listen for the game on {host}:{port}: {e} (is another bridge already running?)")
            return
        self.game_rx_ok = True
        sock.settimeout(0.5)
        while self.running:
            try:
                data, _addr = sock.recvfrom(4096)
            except socket.timeout:
                continue
            except OSError:  # Windows reports ICMP "port unreachable" here; ignore
                continue
            self.last_game_msg = now()
            try:
                self._handle_game_msg(json.loads(data.decode("utf-8")))
            except Exception as e:
                self.log(f"Bad message from game: {data[:80]!r} ({e})")

    def _handle_game_msg(self, m):
        t = m.get("t")
        player = int(m.get("player", 0) or 0)
        if t == "event":
            self.fire_event(str(m.get("name", "")), player)
            return
        if t == "pulse":
            line = f"PULSE,{int(m['ch'])},{int(m['ms'])}"
        elif t == "out":
            line = f"OUT,{int(m['ch'])},{1 if m.get('value') else 0}"
        elif t == "raw":
            line = str(m["line"]).strip()
        else:
            self.log(f"Game sent unknown message type: {t!r}")
            return
        for gl in self.targets(player):
            self.send_command(gl, line)

    # ---------------------------------------------------------------- optional virtual Xbox pad (Windows)

    def _update_gamepads(self, msgs):
        vcfg = self.cfg.get("virtual_gamepad", {})
        if not vcfg.get("enabled"):
            return
        if self._vg is None:
            try:
                import vgamepad
                self._vg = vgamepad
                self.log("Virtual gamepad enabled (one Xbox controller per player)")
            except Exception as e:
                self.log(f"Virtual gamepad unavailable: {e}. Needs Windows + 'pip install vgamepad'. Turning it off.")
                vcfg["enabled"] = False
                return
        vg = self._vg
        for m in msgs:
            pad = self._gamepads.get(m["player"])
            if pad is None:
                try:
                    pad = self._gamepads[m["player"]] = vg.VX360Gamepad()
                except Exception as e:
                    self.log(f"Could not create virtual gamepad: {e}")
                    vcfg["enabled"] = False
                    return
            pad.left_joystick_float(x_value_float=m["x"], y_value_float=-m["y"])  # Xbox: up is +
            for logical, xbtn in vcfg.get("buttons", {}).items():
                b = getattr(vg.XUSB_BUTTON, f"XUSB_GAMEPAD_{xbtn}", None)
                if b is None:
                    continue
                if m["buttons"].get(logical):
                    pad.press_button(b)
                else:
                    pad.release_button(b)
            pad.update()

    # ---------------------------------------------------------------- for the GUI

    def snapshot(self):
        t = now()
        with self.lock:
            rows = []
            for g in sorted(self.gloves.values(), key=lambda g: (g.player or 99, g.id)):
                pref = g.preferred()
                rows.append({
                    "id": g.id, "short": g.short, "player": g.player, "fw": g.fw,
                    "online": g.online, "link": pref.kind if pref else None,
                    "links": sorted((l.kind for l in g.alive_links()), key=lambda k: LINK_PRIORITY.get(k, 9)),
                    "label": pref.label if pref else "", "rate": g.rate(),
                    "rtt": g.rtt_ms, "x": g.x, "y": g.y, "buttons": dict(g.buttons),
                    "values": dict(g.values), "fields": list(g.fields), "n_outputs": g.n_outputs,
                    "outputs_on": sorted(g.out_until.keys()), "bad_frames": g.bad_frames,
                    "since": t - g.last_seen if g.last_seen else None,
                })
            return {
                "gloves": rows,
                "pending": [l.label for l in self.pending if l.alive],
                "ble_status": self.ble_status,
                "game_rx_ok": self.game_rx_ok,
                "game_last": (t - self.last_game_msg) if self.last_game_msg else None,
            }

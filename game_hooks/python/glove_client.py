"""
Space Warz glove client for Python games (Pygame or anything else).

Copy this file next to your game and:

    from glove_client import GloveClient
    glove = GloveClient()

    # every frame:
    glove.poll()
    p1 = glove.get(1)                 # player 1's glove
    if p1.connected:
        dx, dy = glove.move_delta(1, speed=4)   # analog movement, whole pixels
        player.rect.move_ip(dx, dy)
        if p1.just_pressed("a"):
            fire_bomb()

    # when something happens in the game:
    glove.send_event("hit", player=1)   # config.json in the bridge decides what the glove does

No extra packages needed - only the standard library.
"""

import json
import socket
import time


class GloveState:
    """Latest data for one player's glove."""

    def __init__(self, player):
        self.player = player
        self.x = 0.0              # -1 (left) .. 1 (right), already calibrated + dead-zoned
        self.y = 0.0              # -1 (up)   .. 1 (down)
        self.buttons = {}         # e.g. {"a": True, "b": False}
        self.raw = {}             # every sensor value the glove reports
        self.link = None          # "usb" / "ble" / "sim"
        self.last_update = 0.0
        self._prev_buttons = {}
        self._frac = [0.0, 0.0]
        self._stale_after = 0.5

    @property
    def connected(self):
        return time.monotonic() - self.last_update < self._stale_after

    def pressed(self, name):
        return self.connected and bool(self.buttons.get(name))

    def just_pressed(self, name):
        """True only on the poll() where the button went down."""
        return self.pressed(name) and not self._prev_buttons.get(name)

    def just_released(self, name):
        return bool(self._prev_buttons.get(name)) and not self.pressed(name)

    def _reset(self):
        self.x = self.y = 0.0
        self.buttons = {}
        self.last_update = 0.0


class GloveClient:
    def __init__(self, listen_port=5005, bridge_host="127.0.0.1", bridge_port=5006, stale_after=0.5):
        self.bridge = (bridge_host, bridge_port)
        self.stale_after = stale_after
        self.players = {}
        self.ok = True
        self._rx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            self._rx.bind(("127.0.0.1", listen_port))
        except OSError as e:
            print(f"[glove] can't listen on UDP {listen_port}: {e} - glove input disabled")
            self.ok = False
        self._rx.setblocking(False)
        # separate socket for sending: on Windows, a failed send can make the next recv on
        # the same socket raise an error
        self._tx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    def get(self, player=1):
        st = self.players.get(player)
        if st is None:
            st = self.players[player] = GloveState(player)
            st._stale_after = self.stale_after
        return st

    def poll(self):
        """Read everything the bridge sent since last call. Call once per frame."""
        for st in self.players.values():
            st._prev_buttons = dict(st.buttons)
        while self.ok:
            try:
                data = self._rx.recv(65535)
            except (BlockingIOError, InterruptedError):
                break
            except OSError:  # e.g. ConnectionResetError on Windows - harmless for UDP
                continue
            try:
                m = json.loads(data.decode("utf-8"))
            except ValueError:
                continue
            player = m.get("player")
            if player is None:
                continue
            st = self.get(int(player))
            t = m.get("t")
            if t == "state":
                st.x = float(m.get("x", 0.0))
                st.y = float(m.get("y", 0.0))
                st.buttons = m.get("buttons", {}) or {}
                st.raw = m.get("raw", {}) or {}
                st.link = m.get("link")
                st.last_update = time.monotonic()
            elif t == "disconnected":
                st._reset()
        for st in self.players.values():
            if not st.connected and st.last_update:
                st._reset()
        return self

    def move_delta(self, player, speed):
        """Analog movement as whole-pixel (dx, dy) for this frame; keeps the fractions
        so slow tilts still move smoothly instead of rounding to zero."""
        st = self.get(player)
        if not st.connected:
            st._frac = [0.0, 0.0]
            return 0, 0
        fx = st.x * speed + st._frac[0]
        fy = st.y * speed + st._frac[1]
        dx, dy = int(fx), int(fy)
        st._frac = [fx - dx, fy - dy]
        return dx, dy

    # ---------------------------------------------------------------- game -> glove

    def _send(self, msg):
        try:
            self._tx.sendto(json.dumps(msg).encode("utf-8"), self.bridge)
        except OSError:
            pass

    def send_event(self, name, player=1):
        """player=0 sends to every glove."""
        self._send({"t": "event", "name": name, "player": player})

    def pulse(self, channel, ms, player=1):
        self._send({"t": "pulse", "player": player, "ch": channel, "ms": ms})

    def set_output(self, channel, on, player=1):
        self._send({"t": "out", "player": player, "ch": channel, "value": 1 if on else 0})

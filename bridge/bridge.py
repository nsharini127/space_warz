"""
Space Warz glove bridge.

    python bridge.py                 # GUI
    python bridge.py --sim 2         # GUI + two simulated gloves (no hardware needed)
    python bridge.py --nogui         # headless (e.g. Raspberry Pi with no screen)

Gloves are found automatically over USB and Bluetooth. Everything is set in config.json.
"""

import argparse
import os
import queue
import time

from core import Bridge, BleakScanner, serial

HERE = os.path.dirname(os.path.abspath(__file__))


# --------------------------------------------------------------------------- headless

def run_headless(args):
    b = Bridge(args.config, log=lambda m: print(m, flush=True))
    b.start()
    for _ in range(args.sim):
        b.add_simulated_glove()
    try:
        while True:
            time.sleep(5)
            snap = b.snapshot()
            on = [g for g in snap["gloves"] if g["online"]]
            parts = [f"P{g['player']}={g['short']}/{g['link']}/{g['rate']}Hz" for g in on]
            print(time.strftime("%H:%M:%S ") + f"[status] {len(on)} glove(s) online  " + "  ".join(parts), flush=True)
    except KeyboardInterrupt:
        print("Stopping...")
        b.stop()


# --------------------------------------------------------------------------- GUI

def run_gui(args):
    import tkinter as tk
    from tkinter import ttk
    from tkinter.scrolledtext import ScrolledText

    try:  # crisp text on Windows high-DPI screens
        import ctypes
        ctypes.windll.shcore.SetProcessDpiAwareness(1)
    except Exception:
        pass

    logq = queue.Queue()
    bridge = Bridge(args.config, log=lambda m: (logq.put(m), print(m, flush=True)))

    BG, PANEL, FG, MUTED, ACCENT, GOOD, BAD, WARN = (
        "#0f1420", "#171e2e", "#e6e9f0", "#8a93a8", "#5aa9ff", "#3ecf8e", "#ff5c6c", "#f5b942")

    root = tk.Tk()
    root.title("Space Warz - Glove Bridge")
    root.geometry("1180x760")
    root.minsize(980, 620)
    root.configure(bg=BG)

    style = ttk.Style(root)
    style.theme_use("clam")
    style.configure(".", background=BG, foreground=FG, fieldbackground=PANEL, font=("Segoe UI", 10))
    style.configure("TFrame", background=BG)
    style.configure("Panel.TFrame", background=PANEL)
    style.configure("TLabel", background=BG, foreground=FG)
    style.configure("Panel.TLabel", background=PANEL, foreground=FG)
    style.configure("Muted.TLabel", background=BG, foreground=MUTED)
    style.configure("PanelMuted.TLabel", background=PANEL, foreground=MUTED)
    style.configure("Title.TLabel", background=BG, foreground=FG, font=("Segoe UI Semibold", 15))
    style.configure("H.TLabel", background=PANEL, foreground=FG, font=("Segoe UI Semibold", 11))
    style.configure("TCheckbutton", background=BG, foreground=FG)
    style.map("TCheckbutton", background=[("active", BG)])
    style.configure("TButton", background="#26304a", foreground=FG, borderwidth=0, padding=(10, 5))
    style.map("TButton", background=[("active", "#33405f"), ("disabled", "#1b2233")],
              foreground=[("disabled", MUTED)])
    style.configure("Accent.TButton", background=ACCENT, foreground="#0b1220")
    style.map("Accent.TButton", background=[("active", "#7dbcff")])
    style.configure("Treeview", background=PANEL, fieldbackground=PANEL, foreground=FG, rowheight=28, borderwidth=0)
    style.configure("Treeview.Heading", background="#202a40", foreground=MUTED, relief="flat",
                    font=("Segoe UI Semibold", 9))
    style.map("Treeview", background=[("selected", "#2b3d63")])
    style.configure("TSpinbox", arrowsize=12)
    style.configure("TCombobox", arrowsize=12)

    # ---------------------------------------------------------------- top bar
    top = ttk.Frame(root, padding=(14, 10, 14, 6))
    top.pack(fill="x")
    ttk.Label(top, text="SPACE WARZ  ·  Glove Bridge", style="Title.TLabel").pack(side="left")

    usb_var = tk.BooleanVar(value=bridge.usb_enabled)
    ble_var = tk.BooleanVar(value=bridge.ble_enabled)

    def on_toggle():
        bridge.usb_enabled = usb_var.get()
        bridge.ble_enabled = ble_var.get()

    ttk.Button(top, text="Reload config", command=bridge.reload_config).pack(side="right", padx=(6, 0))
    ttk.Button(top, text="Forget offline", command=bridge.forget_offline).pack(side="right", padx=(6, 0))
    ttk.Button(top, text="+ Simulated glove", command=bridge.add_simulated_glove).pack(side="right", padx=(6, 0))
    ttk.Checkbutton(top, text="Bluetooth", variable=ble_var, command=on_toggle).pack(side="right", padx=(12, 0))
    ttk.Checkbutton(top, text="USB", variable=usb_var, command=on_toggle).pack(side="right", padx=(12, 0))

    status = ttk.Frame(root, padding=(14, 0, 14, 8))
    status.pack(fill="x")
    st_usb = ttk.Label(status, style="Muted.TLabel")
    st_ble = ttk.Label(status, style="Muted.TLabel")
    st_game = ttk.Label(status, style="Muted.TLabel")
    st_pending = ttk.Label(status, style="Muted.TLabel")
    for w in (st_usb, st_ble, st_game, st_pending):
        w.pack(side="left", padx=(0, 22))

    # ---------------------------------------------------------------- glove table
    cols = [("player", "PLAYER", 70), ("glove", "GLOVE", 110), ("link", "LINK", 90), ("port", "PORT / DEVICE", 220),
            ("rate", "RATE", 70), ("ping", "PING", 80), ("x", "X", 60), ("y", "Y", 60),
            ("buttons", "BUTTONS", 130), ("status", "STATUS", 150)]
    table_frame = ttk.Frame(root, padding=(14, 0, 14, 8))
    table_frame.pack(fill="x")
    tree = ttk.Treeview(table_frame, columns=[c[0] for c in cols], show="headings", height=6, selectmode="browse")
    for key, title, w in cols:
        tree.heading(key, text=title, anchor="w")
        tree.column(key, width=w, anchor="w", stretch=(key == "port"))
    tree.tag_configure("offline", foreground=MUTED)
    tree.tag_configure("online", foreground=FG)
    tree.pack(fill="x")
    empty_hint = ttk.Label(table_frame, style="Muted.TLabel",
                           text="No gloves yet. Plug a glove into USB, switch on a Bluetooth glove, "
                                "or click '+ Simulated glove' to test without hardware.")
    empty_hint.pack(anchor="w", pady=(6, 0))

    # ---------------------------------------------------------------- lower area: detail + log
    lower = ttk.Frame(root, padding=(14, 0, 14, 12))
    lower.pack(fill="both", expand=True)
    lower.columnconfigure(0, weight=0)
    lower.columnconfigure(1, weight=1)
    lower.rowconfigure(0, weight=1)

    detail = ttk.Frame(lower, style="Panel.TFrame", padding=12)
    detail.grid(row=0, column=0, sticky="nsew", padx=(0, 10))
    det_title = ttk.Label(detail, text="Select a glove", style="H.TLabel")
    det_title.grid(row=0, column=0, columnspan=2, sticky="w")
    det_sub = ttk.Label(detail, text="", style="PanelMuted.TLabel")
    det_sub.grid(row=1, column=0, columnspan=2, sticky="w", pady=(0, 8))

    STICK = 170
    canvas = tk.Canvas(detail, width=STICK, height=STICK, bg=PANEL, highlightthickness=0)
    canvas.grid(row=2, column=0, rowspan=6, sticky="nw", padx=(0, 14))

    raw_lbl = tk.Label(detail, text="", bg=PANEL, fg=MUTED, justify="left", anchor="nw",
                       font=("Consolas", 10), width=26, height=9)
    raw_lbl.grid(row=2, column=1, sticky="nw")
    btn_row = ttk.Frame(detail, style="Panel.TFrame")
    btn_row.grid(row=3, column=1, sticky="w", pady=(4, 0))
    out_row = ttk.Frame(detail, style="Panel.TFrame")
    out_row.grid(row=4, column=1, sticky="w", pady=(6, 0))

    ctl = ttk.Frame(detail, style="Panel.TFrame")
    ctl.grid(row=8, column=0, columnspan=2, sticky="ew", pady=(12, 0))

    selected = {"id": None}

    def sel_id():
        return selected["id"]

    def do_cal():
        if sel_id() and not bridge.calibrate(sel_id()):
            logq.put("Can't calibrate: no sensor data from that glove yet.")

    def do_reset_cal():
        if sel_id():
            bridge.reset_calibration(sel_id())

    player_var = tk.IntVar(value=1)
    ch_var = tk.IntVar(value=0)
    ev_var = tk.StringVar(value="hit")

    def with_glove(fn):
        gid = sel_id()
        g = bridge.gloves.get(gid) if gid else None
        if g is None or not g.online:
            logq.put("Select an online glove first.")
            return
        fn(g)

    r = 0
    ttk.Button(ctl, text="Calibrate centre", style="Accent.TButton", command=do_cal).grid(row=r, column=0, sticky="ew", padx=(0, 6))
    ttk.Button(ctl, text="Reset", command=do_reset_cal).grid(row=r, column=1, sticky="ew", padx=(0, 6))
    ttk.Button(ctl, text="Disconnect", command=lambda: sel_id() and bridge.disconnect(sel_id())).grid(row=r, column=2, sticky="ew")
    r += 1
    ttk.Label(ctl, text="Hold the glove in its neutral pose, then press Calibrate.", style="PanelMuted.TLabel").grid(
        row=r, column=0, columnspan=4, sticky="w", pady=(2, 10))
    r += 1
    ttk.Label(ctl, text="Player", style="Panel.TLabel").grid(row=r, column=0, sticky="w")
    ttk.Spinbox(ctl, from_=1, to=8, width=4, textvariable=player_var).grid(row=r, column=1, sticky="w")
    ttk.Button(ctl, text="Set player", command=lambda: sel_id() and bridge.set_player(sel_id(), player_var.get())).grid(
        row=r, column=2, sticky="ew")
    r += 1
    ttk.Label(ctl, text="Output ch", style="Panel.TLabel").grid(row=r, column=0, sticky="w", pady=(10, 0))
    ttk.Spinbox(ctl, from_=0, to=15, width=4, textvariable=ch_var).grid(row=r, column=1, sticky="w", pady=(10, 0))
    outs = ttk.Frame(ctl, style="Panel.TFrame")
    outs.grid(row=r, column=2, columnspan=2, sticky="w", pady=(10, 0))
    ttk.Button(outs, text="Pulse 200ms", command=lambda: with_glove(lambda g: bridge.send_command(g, f"PULSE,{ch_var.get()},200"))).pack(side="left")
    ttk.Button(outs, text="On", command=lambda: with_glove(lambda g: bridge.send_command(g, f"OUT,{ch_var.get()},1"))).pack(side="left", padx=4)
    ttk.Button(outs, text="Off", command=lambda: with_glove(lambda g: bridge.send_command(g, f"OUT,{ch_var.get()},0"))).pack(side="left")
    r += 1
    ttk.Label(ctl, text="Game event", style="Panel.TLabel").grid(row=r, column=0, sticky="w", pady=(10, 0))
    ev_box = ttk.Combobox(ctl, textvariable=ev_var, width=12, values=list(bridge.cfg.get("events", {}).keys()))
    ev_box.grid(row=r, column=1, sticky="w", pady=(10, 0))
    ttk.Button(ctl, text="Fire on this glove",
               command=lambda: with_glove(lambda g: bridge.fire_event(ev_var.get(), g.player))).grid(
        row=r, column=2, sticky="ew", pady=(10, 0))

    log_frame = ttk.Frame(lower, style="Panel.TFrame", padding=(12, 10))
    log_frame.grid(row=0, column=1, sticky="nsew")
    ttk.Label(log_frame, text="Log", style="H.TLabel").pack(anchor="w")
    log_box = ScrolledText(log_frame, bg=PANEL, fg=FG, insertbackground=FG, relief="flat", wrap="word",
                           font=("Consolas", 9), height=10, borderwidth=0)
    log_box.pack(fill="both", expand=True, pady=(6, 0))
    log_box.tag_configure("bad", foreground=BAD)
    log_box.tag_configure("good", foreground=GOOD)
    log_box.tag_configure("warn", foreground=WARN)
    log_box.configure(state="disabled")

    def on_select(_e=None):
        s = tree.selection()
        selected["id"] = s[0] if s else None
        g = bridge.gloves.get(selected["id"]) if selected["id"] else None
        if g and g.player:
            player_var.set(g.player)

    tree.bind("<<TreeviewSelect>>", on_select)

    # ---------------------------------------------------------------- drawing helpers
    def draw_stick(x, y, online, dz):
        canvas.delete("all")
        c, rad = STICK / 2, STICK / 2 - 8
        canvas.create_oval(c - rad, c - rad, c + rad, c + rad, outline="#2c3752", width=2)
        canvas.create_oval(c - rad * dz, c - rad * dz, c + rad * dz, c + rad * dz, outline="#25304a", dash=(3, 3))
        canvas.create_line(c - rad, c, c + rad, c, fill="#222b40")
        canvas.create_line(c, c - rad, c, c + rad, fill="#222b40")
        px, py = c + x * rad, c + y * rad
        col = ACCENT if online else MUTED
        canvas.create_line(c, c, px, py, fill=col, width=2)
        canvas.create_oval(px - 9, py - 9, px + 9, py + 9, fill=col, outline="")
        canvas.create_text(8, STICK - 8, anchor="sw", fill=MUTED, font=("Consolas", 9), text=f"x {x:+.2f}  y {y:+.2f}")

    def pills(frame, items):
        """items: list of (text, on) - redraws a row of small indicator pills."""
        key = tuple(items)
        if getattr(frame, "_key", None) == key:
            return
        frame._key = key
        for w in frame.winfo_children():
            w.destroy()
        for text, on in items:
            tk.Label(frame, text=f" {text} ", bg=GOOD if on else "#26304a", fg="#0b1220" if on else MUTED,
                     font=("Segoe UI Semibold", 9)).pack(side="left", padx=(0, 4))

    # ---------------------------------------------------------------- refresh loop
    def drain_log():
        n = 0
        while n < 200:
            try:
                m = logq.get_nowait()
            except queue.Empty:
                break
            n += 1
            tag = ("bad" if ("DISCONNECTED" in m or "error" in m.lower() or "Can't" in m or "failed" in m)
                   else "good" if " connected via " in m or "link up" in m
                   else "warn" if ("didn't answer" in m or "unknown" in m or "unavailable" in m or "stuck" in m)
                   else "")
            log_box.configure(state="normal")
            log_box.insert("end", m + "\n", tag)
            if int(log_box.index("end-1c").split(".")[0]) > 1500:
                log_box.delete("1.0", "300.0")
            log_box.configure(state="disabled")
            log_box.see("end")

    def refresh():
        drain_log()
        snap = bridge.snapshot()
        gcfg = bridge.cfg.get("game", {})

        usb_ok = serial is not None
        st_usb.configure(text=("USB: " + ("auto-connect on" if bridge.usb_enabled else "off")) if usb_ok
                         else "USB: pyserial missing (pip install pyserial)",
                         foreground=(GOOD if bridge.usb_enabled else MUTED) if usb_ok else BAD)
        st_ble.configure(text=f"Bluetooth: {snap['ble_status'] if bridge.ble_enabled else 'off'}"
                         if BleakScanner else "Bluetooth: bleak missing (pip install bleak)",
                         foreground=(GOOD if snap["ble_status"] in ("scanning", "idle") and bridge.ble_enabled
                                     else MUTED if not bridge.ble_enabled else WARN) if BleakScanner else BAD)
        gl = snap["game_last"]
        game_txt = f"Game: sending to {gcfg.get('host', '127.0.0.1')}:{gcfg.get('send_port', 5005)}  ·  "
        if not snap["game_rx_ok"]:
            game_txt += f"NOT listening on :{gcfg.get('listen_port', 5006)} (port busy)"
            game_col = BAD
        elif gl is None:
            game_txt += f"listening on :{gcfg.get('listen_port', 5006)} (no messages from game yet)"
            game_col = MUTED
        else:
            game_txt += f"last game message {gl:.1f}s ago"
            game_col = GOOD if gl < 10 else MUTED
        st_game.configure(text=game_txt, foreground=game_col)
        st_pending.configure(text=("Handshaking: " + ", ".join(snap["pending"])) if snap["pending"] else "")

        ids = set()
        for g in snap["gloves"]:
            ids.add(g["id"])
            if g["online"]:
                links = "+".join(k.upper() for k in g["links"])
                status_txt = "connected" if g["rate"] >= 10 else "connected (slow!)"
            else:
                links = "-"
                status_txt = f"offline {g['since']:.0f}s" if g["since"] is not None else "connecting..."
            vals = (
                f"P{g['player']}" if g["player"] else "-",
                g["short"], links, g["label"] or "-",
                f"{g['rate']} Hz" if g["online"] else "-",
                f"{g['rtt']:.0f} ms" if g["rtt"] is not None else "-",
                f"{g['x']:+.2f}", f"{g['y']:+.2f}",
                " ".join(k.upper() for k, v in g["buttons"].items() if v) or "-",
                status_txt,
            )
            if tree.exists(g["id"]):
                tree.item(g["id"], values=vals, tags=("online" if g["online"] else "offline",))
            else:
                tree.insert("", "end", iid=g["id"], values=vals, tags=("online" if g["online"] else "offline",))
        for iid in tree.get_children():
            if iid not in ids:
                tree.delete(iid)
        if snap["gloves"]:
            empty_hint.pack_forget()
        elif not empty_hint.winfo_ismapped():
            empty_hint.pack(anchor="w", pady=(6, 0))
        if selected["id"] is None and snap["gloves"]:
            tree.selection_set(snap["gloves"][0]["id"])

        g = next((x for x in snap["gloves"] if x["id"] == selected["id"]), None)
        dz = bridge.cfg.get("controls", {}).get("x", {}).get("deadzone", 0.1)
        if g is None:
            det_title.configure(text="Select a glove")
            det_sub.configure(text="")
            draw_stick(0, 0, False, dz)
            raw_lbl.configure(text="")
            pills(btn_row, [])
            pills(out_row, [])
        else:
            det_title.configure(text=f"Player {g['player']}  ·  glove {g['id']}")
            det_sub.configure(text=f"firmware {g['fw'] or '?'}  ·  {g['label'] or 'offline'}"
                                   + (f"  ·  {g['bad_frames']} bad frames" if g["bad_frames"] else ""))
            draw_stick(g["x"], g["y"], g["online"], dz)
            raw_lbl.configure(text="\n".join(f"{k:<8}{g['values'].get(k, float('nan')):>9.3f}" for k in g["fields"][:12])
                              or "(no fields declared)")
            pills(btn_row, [(k.upper(), v) for k, v in g["buttons"].items()])
            pills(out_row, [(f"OUT{ch}", ch in g["outputs_on"]) for ch in range(g["n_outputs"])])
        root.after(50, refresh)

    def on_close():
        bridge.stop()
        root.destroy()

    root.protocol("WM_DELETE_WINDOW", on_close)
    bridge.start()
    for _ in range(args.sim):
        bridge.add_simulated_glove()
    root.after(100, refresh)
    if args.screenshot:  # used for automated testing
        def snap_and_quit():
            os.system(f"import -window root {args.screenshot}")
            on_close()
        root.after(int(args.screenshot_after * 1000), snap_and_quit)
    root.mainloop()


def main():
    ap = argparse.ArgumentParser(description="Space Warz glove bridge")
    ap.add_argument("--nogui", action="store_true", help="run without a window")
    ap.add_argument("--sim", type=int, default=0, help="number of simulated gloves to add at start")
    ap.add_argument("--config", default=os.path.join(HERE, "config.json"))
    ap.add_argument("--screenshot", default="", help=argparse.SUPPRESS)
    ap.add_argument("--screenshot-after", type=float, default=3.0, help=argparse.SUPPRESS)
    args = ap.parse_args()
    if args.nogui:
        run_headless(args)
    else:
        try:
            run_gui(args)
        except Exception as e:  # no tkinter, or no display (e.g. Pi over SSH)
            if isinstance(e, ImportError) or "display" in str(e).lower():
                print(f"GUI not available ({e}); running headless. Use --nogui to skip this message.")
                run_headless(args)
            else:
                raise


if __name__ == "__main__":
    main()

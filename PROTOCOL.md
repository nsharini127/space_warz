# Space Warz glove protocol

There are two separate links. The game and the glove never talk to each other directly.

```
 Glove (Pico 2W)  <-- USB serial / Bluetooth -->  Bridge app (laptop)  <-- UDP on localhost -->  Game
        Link A: plain text lines                          Link B: JSON packets
```

---

## Link A: Glove <-> Bridge

The same protocol runs over both transports:

- **USB**: the Pico's normal USB serial port (what `print()` and `sys.stdin` use in MicroPython).
- **Bluetooth LE**: the standard "Nordic UART Service" (NUS). This is what MicroPython's `ble_uart_peripheral` example implements.
  - Service `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
  - RX (bridge writes here) `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
  - TX (glove notifies here) `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`
  - Advertise with a name starting with `SWGLOVE`, e.g. `SWGLOVE-2E2F` (last 4 chars of the board ID). That's how the bridge finds it.

Rules:
- Every message is one line of ASCII text ending in `\n`. Fields are separated by commas. No spaces.
- If the glove is connected over USB and Bluetooth at the same time, send everything on both. The bridge uses USB and falls back to Bluetooth if the cable is pulled.

### Glove -> Bridge

| Message | When | Example |
|---|---|---|
| `HELLO,<id>,<fw>,<fields>,<outputs>` | On boot, and whenever it receives `WHO` | `HELLO,E6614C311B7A2E2F,1.0,ax:ay:az:gx:gy:gz:b0:b1,2` |
| `D,<v1>,<v2>,...` | Continuously, 30–100 times a second | `D,0.12,-0.40,0.98,1.5,-3.0,0.2,1,0` |
| `PONG,<token>` | In reply to `PING,<token>` | `PONG,8812` |
| `LOG,<text>` | Any time; shown in the bridge's log window | `LOG,mpu init ok` |
| `ERR,<text>` | When something went wrong | `ERR,unknown cmd FOO` |

`HELLO` fields:
- `id`: a unique board ID. Use `machine.unique_id()` as hex. This is how the bridge tells gloves apart and remembers each glove's player number and calibration.
- `fw`: firmware version, any short string.
- `fields`: names of the values in every `D` line, separated by `:`, in the same order. **The glove decides these.** If you add a flex sensor, just add `flex1` to the list. The bridge shows whatever you declare.
- `outputs`: how many transistor output channels the glove has. Channels are numbered from 0.

`D` line values are numbers (int or float), in the order declared in `HELLO`.
- Buttons: send `1` for pressed and `0` for released.
- Accelerometer: send values in **g** (about -1.0 to 1.0 when tilting). The default tilt mapping in `config.json` assumes g. If you send raw int16 values instead, change `range` in the config.

**Keep streaming `D` lines even when nothing changes.** The bridge treats 1.5 s of silence as a disconnect.

### Bridge -> Glove

| Command | Meaning | Example |
|---|---|---|
| `WHO` | "Who are you?" Reply with `HELLO,...` | `WHO` |
| `PING,<token>` | Reply `PONG,<same token>` (used to measure latency) | `PING,8812` |
| `OUT,<ch>,<0or1>` | Switch transistor channel `ch` off/on | `OUT,0,1` |
| `PULSE,<ch>,<ms>` | Turn channel on, then off after `ms` milliseconds. **Must not block the sensor loop.** | `PULSE,0,150` |
| `PWM,<ch>,<0-100>` | Optional: duty cycle in percent, for motors/LED brightness | `PWM,1,40` |

Ignore commands you don't understand (or reply `ERR,...`). Never crash on a bad line.

### Minimal glove loop (for later, when you write the Pico side)

The firmware only needs to do this:

```
on boot:        print HELLO line
forever:
    read sensors -> print "D,..." line
    if a full line arrived on USB/BLE:
        WHO            -> print HELLO line
        PING,t         -> print "PONG,t"
        OUT,ch,v       -> pin[ch].value(v)
        PULSE,ch,ms    -> pin[ch].on(); off_time[ch] = now + ms
    for each ch: if off_time[ch] passed -> pin[ch].off()
    sleep ~10–20 ms
```

Read USB input without blocking. In MicroPython, use `select.poll()` on `sys.stdin`, otherwise the loop freezes waiting for input.

---

## Link B: Bridge <-> Game (UDP, JSON)

Each UDP packet is one JSON object.

- **Bridge -> Game**: sent to `127.0.0.1:5005` (`game.send_port` in config)
- **Game -> Bridge**: send to `127.0.0.1:5006` (`game.listen_port` in config)

Players are numbered from 1. In game -> bridge messages, `"player": 0` means all gloves.

### Bridge -> Game

```json
{"t":"state","player":1,"glove":"E6614C311B7A2E2F","link":"usb",
 "x":0.42,"y":-0.10,"buttons":{"a":true,"b":false,"c":false},
 "raw":{"ax":0.12,"ay":-0.40,"b0":1}}
```
Sent about 60 times a second per connected glove.
- `x` and `y` are already calibrated, dead-zoned and clamped to -1..1. Positive x is right, positive y is down.
- `buttons` are logical names; their source fields are set in `config.json`.
- `raw` holds every sensor value, in case the game wants something custom.

```json
{"t":"connected","player":1,"glove":"E661..."}
{"t":"disconnected","player":1,"glove":"E661..."}
```

### Game -> Bridge

```json
{"t":"event","name":"hit","player":1}
```
**This is the one games should normally use.** The game says *what happened*, and `config.json` decides which glove outputs fire. That way the hardware team can rewire channels without touching game code.

Direct control is also available:

```json
{"t":"pulse","player":1,"ch":0,"ms":200}
{"t":"out","player":1,"ch":1,"value":1}
{"t":"raw","player":1,"line":"PWM,1,40"}
```

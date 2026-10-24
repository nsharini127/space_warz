# Space Warz Pico 2 W test firmware: USB + Bluetooth LE Nordic UART.
# BOOTSEL or GP15-to-GND = A; output 0 = onboard LED; output 1 = GP16.
# All outputs have a hard 1000ms limit. Bridge commands must keep arriving.
import sys
import select
import time
import binascii
import machine
import rp2

GLOVE_ID = binascii.hexlify(machine.unique_id()).decode().upper()
NAME = 'SWGLOVE-' + GLOVE_ID[-4:]
FW = 'test-0.2-ble'
MAX_ON_MS = 1000
LINK_TIMEOUT_MS = 2500
OUTPUTS = [machine.Pin('LED', machine.Pin.OUT), machine.Pin(16, machine.Pin.OUT)]
BUTTON = machine.Pin(15, machine.Pin.IN, machine.Pin.PULL_UP)
off_at = [None, None]
last_command = None
radio = None


def all_off():
    for ch, pin in enumerate(OUTPUTS):
        pin.off()
        off_at[ch] = None


all_off()


class BluetoothUART:
    def __init__(self):
        import bluetooth
        self.ble = bluetooth.BLE()
        self.conn = None
        self.rx = []
        self.overflow = False
        self.changed = False
        self.need_advertise = True
        self.next_advertise = time.ticks_ms()
        self.tx_errors = 0
        self.resync = False
        self.ready = False
        self.connected_at = None
        self.last_receive = time.ticks_ms()
        self.ble.active(True)
        # Static random address avoids stale Windows GATT records for an older
        # service layout. The protocol's board ID remains the player identity.
        self.ble.config(addr_mode=1)
        self.ble.config(gap_name=NAME)
        uuid = bluetooth.UUID
        service = (uuid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E'), (
            (uuid('6E400003-B5A3-F393-E0A9-E50E24DCCA9E'), bluetooth.FLAG_NOTIFY),
            (uuid('6E400002-B5A3-F393-E0A9-E50E24DCCA9E'),
             bluetooth.FLAG_WRITE | bluetooth.FLAG_WRITE_NO_RESPONSE),
        ))
        ((self.tx, self.rx_handle),) = self.ble.gatts_register_services((service,))
        self.ble.gatts_set_buffer(self.rx_handle, 256, True)
        self.adv = b'\x02\x01\x06\x11\x07' + bytes(service[0])
        name = NAME.encode()
        self.scan_response = bytes((len(name) + 1, 9)) + name
        self.ble.irq(self.irq)

    def irq(self, event, data):
        if event == 1:  # central connected
            if self.conn is not None:
                self.ble.gap_disconnect(data[0])
                return
            self.conn = data[0]
            self.rx = []
            self.ble.gatts_read(self.rx_handle)
            self.changed = True
            self.need_advertise = False
            self.tx_errors = 0
            self.resync = False
            self.ready = False
            self.connected_at = time.ticks_ms()
            self.last_receive = self.connected_at
        elif event == 2 and data[0] == self.conn:
            self.conn = None
            self.ready = False
            self.rx = []
            self.changed = True
            self.need_advertise = True
            self.next_advertise = time.ticks_ms()
            all_off()
        elif event == 3 and data[1] == self.rx_handle:
            # The bridge subscribes before writing WHO. Do not notify during
            # Windows service discovery: notifications can fail before CCCD setup.
            self.ready = True
            self.last_receive = time.ticks_ms()
            packet = self.ble.gatts_read(self.rx_handle)
            if len(self.rx) < 16 and len(packet) < 256:
                self.rx.append(packet)
            else:
                self.overflow = True
                all_off()

    def maintain(self, now):
        if self.conn is not None and not self.ready and time.ticks_diff(now, self.connected_at) > 20000:
            self.ble.gap_disconnect(self.conn)
        # Reclaim a Windows connection retained after its bridge process exits.
        # USB heartbeats also keep a standby BLE connection healthy.
        if (self.conn is not None and self.ready and last_command is not None
                and time.ticks_diff(now, self.last_receive) > 5000
                and time.ticks_diff(now, last_command) > 5000):
            all_off()
            self.ble.gap_disconnect(self.conn)
        if self.need_advertise and self.conn is None and time.ticks_diff(now, self.next_advertise) >= 0:
            try:
                self.ble.gap_advertise(100000, adv_data=self.adv, resp_data=self.scan_response)
                self.need_advertise = False
            except OSError:
                self.next_advertise = time.ticks_add(now, 2000)

    def send(self, line):
        if self.conn is None or not self.ready:
            return
        payload = (('\n' if self.resync else '') + line + '\n').encode()
        try:
            for offset in range(0, len(payload), 20):
                self.ble.gatts_notify(self.conn, self.tx, payload[offset:offset + 20])
            self.tx_errors = 0
            self.resync = False
        except OSError:
            self.resync = True
            self.tx_errors += 1
            if self.tx_errors >= 5:
                all_off()
                try:
                    self.ble.gap_disconnect(self.conn)
                except OSError:
                    pass


def emit(line):
    print(line)
    if radio is not None:
        radio.send(line)


def hello():
    emit('HELLO,%s,%s,b0,2' % (GLOVE_ID, FW))


def handle(line):
    global last_command
    parts = line.split(',')
    cmd = parts[0]
    try:
        if cmd == 'WHO' and len(parts) == 1:
            hello()
        elif cmd == 'PING' and len(parts) == 2 and 0 < len(parts[1]) <= 40:
            emit('PONG,' + parts[1])
        elif cmd == 'STATUS' and len(parts) == 1:
            emit('LOG,outputs=%d:%d;ble=%d;max_on_ms=%d' % (
                OUTPUTS[0].value(), OUTPUTS[1].value(),
                radio is not None and radio.conn is not None, MAX_ON_MS))
        elif cmd in ('OUT', 'PWM', 'PULSE') and len(parts) == 3:
            ch, value = int(parts[1]), int(parts[2])
            if not 0 <= ch < len(OUTPUTS):
                raise ValueError()
            if cmd == 'OUT' and value not in (0, 1):
                raise ValueError()
            if cmd == 'PWM' and not 0 <= value <= 100:
                raise ValueError()
            if cmd == 'PULSE' and not 0 <= value <= MAX_ON_MS:
                raise ValueError()
            on = value > 0
            # Repeated OUT/PWM cannot extend an already-on output indefinitely.
            if on and not OUTPUTS[ch].value():
                duration = value if cmd == 'PULSE' else MAX_ON_MS
                off_at[ch] = time.ticks_add(time.ticks_ms(), duration)
            if not on:
                off_at[ch] = None
            OUTPUTS[ch].value(int(on))
        else:
            raise ValueError()
        last_command = time.ticks_ms()
    except (ValueError, IndexError):
        all_off()
        emit('ERR,bad command')


class Lines:
    def __init__(self):
        self.buf = ''
        self.discard = False

    def feed(self, data):
        for c in data:
            if c == '\n':
                if self.buf and not self.discard:
                    handle(self.buf)
                self.buf = ''
                self.discard = False
            elif c != '\r':
                if not 32 <= ord(c) <= 126 or len(self.buf) >= 120:
                    self.buf = ''
                    self.discard = True
                    all_off()
                elif not self.discard:
                    self.buf += c


def main():
    global radio, last_command
    poller = select.poll()
    poller.register(sys.stdin, select.POLLIN)
    usb_lines, ble_lines = Lines(), Lines()
    next_radio = time.ticks_ms()
    # RP2350 hardware watchdog recovers a stalled loop in <=8 seconds.
    watchdog = machine.WDT(timeout=8000)
    for _ in range(3):
        OUTPUTS[0].on()
        time.sleep_ms(80)
        OUTPUTS[0].off()
        time.sleep_ms(80)
    hello()
    while True:
        now = time.ticks_ms()
        if radio is None and time.ticks_diff(now, next_radio) >= 0:
            try:
                radio = BluetoothUART()
                emit('LOG,Bluetooth advertising as ' + NAME)
            except Exception as exc:
                all_off()
                print('LOG,Bluetooth init failed; retry in 5s: ' + str(exc))
                next_radio = time.ticks_add(time.ticks_ms(), 5000)
        if radio is not None:
            radio.maintain(now)
            if radio.changed or radio.overflow:
                # IRQ already discarded old-session data on connect/disconnect.
                ble_lines = Lines()
                if radio.overflow:
                    radio.rx = []
                radio.changed = False
                radio.overflow = False
                all_off()
            for _ in range(16):
                if not radio.rx:
                    break
                packet = radio.rx.pop(0)
                try:
                    ble_lines.feed(packet.decode('ascii'))
                except UnicodeError:
                    ble_lines = Lines()
                    all_off()
                    emit('ERR,non-ASCII command')
        # Bound work per tick, so a noisy host cannot starve output timers.
        for _ in range(256):
            if not poller.poll(0):
                break
            c = sys.stdin.read(1)
            if not c:
                break
            usb_lines.feed(c)
        now = time.ticks_ms()
        if last_command is None or time.ticks_diff(now, last_command) > LINK_TIMEOUT_MS:
            all_off()
        for ch, deadline in enumerate(off_at):
            if deadline is not None and time.ticks_diff(now, deadline) >= 0:
                OUTPUTS[ch].off()
                off_at[ch] = None
        pressed = BUTTON.value() == 0 or (hasattr(rp2, 'bootsel_button') and rp2.bootsel_button())
        emit('D,%d' % bool(pressed))
        watchdog.feed()
        time.sleep_ms(20)


if __name__ == '__main__':
    try:
        main()
    finally:
        all_off()

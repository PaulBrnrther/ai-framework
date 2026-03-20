#!/usr/bin/env python3
import sys
import json
import struct
import threading
import os
import datetime

FIFO = os.path.expanduser("~/.tab-manager.fifo")
LOG_FILE = os.path.expanduser("~/.tab-manager.log")

pending_response_file = [None]
pending_lock = threading.Lock()


def log(msg):
    ts = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
    with open(LOG_FILE, "a") as f:
        f.write(f"[{ts}] {msg}\n")


def send(msg):
    data = json.dumps(msg).encode("utf-8")
    log(f"send → Chrome: {data.decode()[:200]}")
    sys.stdout.buffer.write(struct.pack("<I", len(data)))
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()


def fifo_listener():
    if not os.path.exists(FIFO):
        os.mkfifo(FIFO)
    log("fifo_listener started")
    while True:
        log("waiting for FIFO writer...")
        with open(FIFO, "r") as f:
            log("FIFO opened (writer connected)")
            for line in f:
                line = line.strip()
                if line:
                    log(f"FIFO line: {line[:200]}")
                    try:
                        msg = json.loads(line)
                        response_file = msg.pop("response_file", None)
                        if response_file:
                            with pending_lock:
                                pending_response_file[0] = response_file
                        send(msg)
                    except json.JSONDecodeError as e:
                        log(f"JSON error: {e} — line: {line[:100]}")


t = threading.Thread(target=fifo_listener, daemon=True)
t.start()

# Read Chrome messages; write to response_file if one is pending
log("main loop started, reading Chrome messages")
while True:
    raw = sys.stdin.buffer.read(4)
    if len(raw) < 4:
        log("stdin EOF — Chrome disconnected, exiting")
        break
    length = struct.unpack("<I", raw)[0]
    data = sys.stdin.buffer.read(length)
    log(f"Chrome → host: {data.decode()[:200]}")
    with pending_lock:
        rf = pending_response_file[0]
        pending_response_file[0] = None
    if rf:
        try:
            with open(rf, "w") as f:
                f.write(data.decode("utf-8"))
            log(f"wrote response to {rf}")
        except OSError as e:
            log(f"OSError writing response: {e}")

"""
usbmuxd -> lockdownd client. Reads device identity over USB without
libimobiledevice. Uses the legacy ListDevices form that this Apple Mobile
Device Service build requires (no kLibUSBMuxVersion key).

Protocol:
  usbmuxd  : TCP 27015 (this host) / 62078 (stock)
             Connect request -> response with Attached + DevicePort
  lockdownd: SSL over the usbmux tunnel, plist-framed requests
"""
import socket
import struct
import plistlib
import ssl
import sys

HOST = "127.0.0.1"
PORT = 27015


def recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("peer closed")
        buf += chunk
    return buf


def usbmux_call(msg, tag=1):
    payload = plistlib.dumps(msg)
    header = struct.pack("<IIII", 16 + len(payload), 1, 8, tag)
    s = socket.create_connection((HOST, PORT), timeout=8)
    s.sendall(header + payload)
    hdr = recv_exact(s, 16)
    length = struct.unpack("<I", hdr[:4])[0]
    body = recv_exact(s, length - 16)
    s.close()
    return plistlib.loads(body)


def list_devices():
    return usbmux_call({"MessageType": "ListDevices",
                        "ClientVersionString": "tkfloatkey",
                        "ProgName": "tkfloatkey"})


def connect_to_device_port(device_id, port, tag=2):
    """Ask usbmuxd for a tunnel to lockdownd (port 62078 on the device)."""
    payload = plistlib.dumps({"MessageType": "Connect",
                              "ClientVersionString": "tkfloatkey",
                              "ProgName": "tkfloatkey",
                              "DeviceID": device_id,
                              "PortNumber": port})
    header = struct.pack("<IIII", 16 + len(payload), 1, 8, tag)
    s = socket.create_connection((HOST, PORT), timeout=8)
    s.sendall(header + payload)
    hdr = recv_exact(s, 16)
    length = struct.unpack("<I", hdr[:4])[0]
    body = recv_exact(s, length - 16)
    res = plistlib.loads(body)
    if res.get("MessageType") != "Result" or res.get("Number") not in (0, None):
        s.close()
        raise RuntimeError(f"usbmux Connect failed: {res}")
    return s          # ready-to-use tunnel socket


def lockdown_query(sock, request):
    sock.sendall(plistlib.dumps(request, fmt=plistlib.FMT_XML))
    return plistlib.loads(read_plist(sock))


def read_plist(sock):
    head = recv_exact(sock, 4)
    length = struct.unpack(">I", head)[0] if sock is not None else 0
    # lockdownd frames are big-endian u32 length, then the plist body
    if length == 0 or length > 64 * 1024 * 1024:
        raise ValueError(f"bad lockdownd frame length {length}")
    return recv_exact(sock, length)


def main():
    devs = list_devices().get("DeviceList") or []
    if not devs:
        print("没有可用设备")
        return 1

    dev = devs[0]
    props = dev["Properties"]
    print(f"UDID      : {props['UDID']}")
    print(f"Serial    : {props['SerialNumber']}")
    print(f"Connection: {props['ConnectionType']}")

    tunnel = connect_to_device_port(dev["DeviceID"], 62078)

    # lockdownd handshake
    resp = lockdown_query(tunnel, {"Label": "tkfloatkey", "Request": "QueryType"})
    print(f"QueryType : {resp.get('Type')}")

    ssl_sock = ssl.create_default_context().wrap_socket(tunnel, server_hostname="")
    return ssl_sock


if __name__ == "__main__":
    sys.exit(main() or 0)

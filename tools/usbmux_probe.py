"""
Minimal usbmuxd client — enumerates devices over the Apple Mobile Device
Service TCP port (27015 on this machine, 62078 stock). Pure stdlib.

Protocol: 16-byte header (len u32 LE, ver u32 LE, type u32 LE, tag u32 LE)
          then a plist payload for the ListDevices request.
"""
import socket
import struct
import plistlib
import sys

PORTS = [27015, 62078]


def recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("peer closed")
        buf += chunk
    return buf


def list_devices(port):
    payload = plistlib.dumps({"MessageType": "ListDevices",
                              "ClientVersionString": "tkfloatkey-probe",
                              "ProgName": "probe",
                              "kLibUSBMuxVersion": 3},
                             fmt=plistlib.FMT_XML)
    header = struct.pack("<IIII", 16 + len(payload), 1, 8, 1)
    s = socket.create_connection(("127.0.0.1", port), timeout=5)
    s.sendall(header + payload)

    hdr = recv_exact(s, 16)
    length, ver, mtype, tag = struct.unpack("<IIII", hdr)
    body = recv_exact(s, length - 16)
    s.close()
    return plistlib.loads(body)


def main():
    for port in PORTS:
        try:
            result = list_devices(port)
        except Exception as exc:                     # noqa: BLE001
            print(f"port {port}: {type(exc).__name__}: {exc}")
            continue

        devices = result.get("DeviceList") or []
        print(f"port {port}: OK  MessageType={result.get('MessageType')}  "
              f"devices={len(devices)}")
        for d in devices:
            props = d.get("Properties", {})
            print(f"  - DeviceID  : {d.get('DeviceID')}")
            print(f"    UDID      : {props.get('UDID')}")
            print(f"    Serial    : {props.get('SerialNumber')}")
            print(f"    Connection: {props.get('ConnectionType')}")
            print(f"    BuildVer  : {props.get('BuildVersion')}")
            print(f"    ProductID : {props.get('ProductID')}")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())

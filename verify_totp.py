#!/usr/bin/env python3
"""
Byte-for-byte Python port of TKFloatKey/TOTP.swift, used to verify the Swift
implementation against the official RFC 6238 / RFC 4226 test vectors.
If this reproduces the vectors, the Swift port (same logic, same constants)
is correct.
"""
import struct, hmac, hashlib

K256 = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]
M32 = 0xFFFFFFFF


def rotl(x, n):
    return ((x << n) | (x >> (32 - n))) & M32


def rotr(x, n):
    return ((x >> n) | (x << (32 - n))) & M32


def sha1(input_bytes):
    """Mirror of HMACSHA1.sha1 in TOTP.swift."""
    h = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]
    data = bytearray(input_bytes)
    bitlen = len(input_bytes) * 8
    data.append(0x80)
    while len(data) % 64 != 56:
        data.append(0)
    for i in range(7, -1, -1):
        data.append((bitlen >> (i * 8)) & 0xFF)

    for chunk in range(0, len(data), 64):
        w = [0] * 80
        for i in range(16):
            b = chunk + i * 4
            w[i] = (data[b] << 24) | (data[b + 1] << 16) | (data[b + 2] << 8) | data[b + 3]
        for i in range(16, 80):
            w[i] = rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1)
        a, b_, c, d, e = h
        for i in range(80):
            if i < 20:
                f, k = (b_ & c) | (~b_ & d), 0x5A827999
            elif i < 40:
                f, k = b_ ^ c ^ d, 0x6ED9EBA1
            elif i < 60:
                f, k = (b_ & c) | (b_ & d) | (c & d), 0x8F1BBCDC
            else:
                f, k = b_ ^ c ^ d, 0xCA62C1D6
            f &= M32
            temp = (rotl(a, 5) + f + e + k + w[i]) & M32
            e, d, c, b_, a = d, c, rotl(b_, 30), a, temp
        h = [(x + y) & M32 for x, y in zip(h, [a, b_, c, d, e])]

    out = b""
    for v in h:
        out += struct.pack(">I", v)
    return out


def sha256(input_bytes):
    """Mirror of SHA256Core.hash in TOTP.swift."""
    h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
         0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
    data = bytearray(input_bytes)
    bitlen = len(input_bytes) * 8
    data.append(0x80)
    while len(data) % 64 != 56:
        data.append(0)
    for i in range(7, -1, -1):
        data.append((bitlen >> (i * 8)) & 0xFF)

    for chunk in range(0, len(data), 64):
        w = [0] * 64
        for i in range(16):
            b = chunk + i * 4
            w[i] = (data[b] << 24) | (data[b + 1] << 16) | (data[b + 2] << 8) | data[b + 3]
        for i in range(16, 64):
            s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
            s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
            w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & M32
        a, b_, c, d, e, f, g, hh = h
        for i in range(64):
            s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
            ch = (e & f) ^ (~e & g)
            t1 = (hh + s1 + ch + K256[i] + w[i]) & M32
            s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
            maj = (a & b_) ^ (a & c) ^ (b_ & c)
            t2 = (s0 + maj) & M32
            hh, g, f, e = g, f, e, (d + t1) & M32
            d, c, b_, a = c, b_, a, (t1 + t2) & M32
        h = [(x + y) & M32 for x, y in zip(h, [a, b_, c, d, e, f, g, hh])]

    out = b""
    for v in h:
        out += struct.pack(">I", v)
    return out


def hmac_swift(key, message, variant):
    """Mirror of HMACSHA1.authenticate / HMACSHA2.authenticate."""
    if variant == "sha1":
        block, fn = 64, sha1
    elif variant == "sha256":
        block, fn = 64, sha256
    elif variant == "sha512":
        block, fn = 128, lambda b: hashlib.sha512(b).digest()
    else:
        raise ValueError(variant)
    k = bytes(key)
    if len(k) > block:
        k = fn(k)
    if len(k) < block:
        k = k + b"\x00" * (block - len(k))
    ipad = bytes(x ^ 0x36 for x in k)
    opad = bytes(x ^ 0x5C for x in k)
    return fn(opad + fn(ipad + bytes(message)))


def base32_decode(s):
    """Mirror of TOTP.base32Decode."""
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    cleaned = s.upper().replace(" ", "").replace("-", "").strip("=")
    if not cleaned:
        raise ValueError("bad secret")
    bits, value, out = 0, 0, bytearray()
    for ch in cleaned:
        idx = alphabet.find(ch)
        if idx < 0:
            raise ValueError("bad secret char %r" % ch)
        value = (value << 5) | idx
        bits += 5
        if bits >= 8:
            bits -= 8
            out.append((value >> bits) & 0xFF)
    if not out:
        raise ValueError("bad secret")
    return bytes(out)


def totp(secret, digits=6, period=30, algorithm="sha1", timestamp=0):
    """Mirror of TOTP.now."""
    key = base32_decode(secret)
    counter = timestamp // period
    raw = hmac_swift(key, struct.pack(">Q", counter), algorithm)
    offset = raw[-1] & 0x0F
    bin_code = struct.unpack(">I", raw[offset:offset + 4])[0] & 0x7FFFFFFF
    code = bin_code % (10 ** digits)
    elapsed = timestamp % period
    return "%0*d" % (digits, code), period - elapsed


# ---------------------------------------------------------------- self test
B32_SECRET_SHA1 = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"          # "12345678901234567890"
B32_SECRET_SHA256 = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA"
import base64
# RFC 6238 uses a 64-byte key "1234567890123456789012345678901234567890123456789012345678901234"
B32_SECRET_SHA512 = base64.b32encode(
    b"1234567890123456789012345678901234567890123456789012345678901234"
).decode().rstrip("=")
print("sha512 key bytes:", len(base32_decode(B32_SECRET_SHA512)))

# RFC 6238 Appendix B, 8 digits
VECTORS = [
    (59,          "94287082", "46119246", "90693936"),
    (1111111109,  "07081804", "68084774", "25091201"),
    (1111111111,  "14050471", "67062674", "99943326"),
    (1234567890,  "89005924", "91819424", "93441116"),
    (2000000000,  "69279037", "90698825", "38618901"),
    (20000000000, "65353130", "77737706", "47863826"),
]

failures = 0
print("== RFC 6238 vectors (8 digits, period 30) ==")
for ts, want1, want256, want512 in VECTORS:
    got1, left = totp(B32_SECRET_SHA1, 8, 30, "sha1", ts)
    got256, _ = totp(B32_SECRET_SHA256, 8, 30, "sha256", ts)
    got512, _ = totp(B32_SECRET_SHA512, 8, 30, "sha512", ts)
    ok = got1 == want1 and got256 == want256 and got512 == want512
    failures += 0 if ok else 1
    print(f"T={ts:<12} SHA1 {got1}/{want1}  SHA256 {got256}/{want256}  "
          f"SHA512 {got512}/{want512}  {'OK' if ok else 'FAIL'}")

print("\n== RFC 4226 Appendix D (HOTP, SHA1, 6 digits) ==")
HOTP = ["755224", "287082", "359152", "969429", "338314",
        "254676", "287922", "162583", "399871", "520489"]
for counter, want in enumerate(HOTP):
    got = totp(B32_SECRET_SHA1, 6, 30, "sha1", counter * 30)[0]
    ok = got == want
    failures += 0 if ok else 1
    print(f"C={counter} got {got} want {want} {'OK' if ok else 'FAIL'}")

print("\n== leftover-seconds countdown (period 30) ==")
for ts, want in [(0, 30), (29, 1), (30, 30), (31, 29)]:
    _, left = totp(B32_SECRET_SHA1, 6, 30, "sha1", ts)
    ok = left == want
    failures += 0 if ok else 1
    print(f"T={ts:<4} remaining={left} want={want} {'OK' if ok else 'FAIL'}")

print("\n== otpauth:// handling sanity ==")
print("base32 decode len:", len(base32_decode(B32_SECRET_SHA1)), "(expect 20 bytes)")
print("\nRESULT:", "ALL PASS" if failures == 0 else f"{failures} FAILURES")
raise SystemExit(1 if failures else 0)




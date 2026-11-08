import Foundation

/// RFC 6238 TOTP generator (HMAC-SHA1/256/512, 6-8 digits).
/// Pure Foundation + CryptoKit free implementation so it also compiles on
/// older deployment targets without importing CryptoKit symbols at call sites.
enum TOTP {

    struct Code {
        let value: String
        let remaining: Int          // seconds left in the current window
        let period: Int
    }

    enum Algorithm: String, Codable, CaseIterable {
        case sha1 = "SHA1"
        case sha256 = "SHA256"
        case sha512 = "SHA512"
    }

    enum TOTPError: LocalizedError {
        case badSecret
        case unsupported(String)

        var errorDescription: String? {
            switch self {
            case .badSecret:
                return "密钥不是合法的 Base32 字符串"
            case .unsupported(let s):
                return "不支持的算法：\(s)"
            }
        }
    }

    // MARK: - Public API

    /// Generates the current code for a Base32 secret.
    static func now(secret: String,
                    digits: Int = 6,
                    period: Int = 30,
                    algorithm: Algorithm = .sha1,
                    date: Date = Date()) throws -> Code {
        let key = try base32Decode(secret)
        let counter = UInt64(date.timeIntervalSince1970) / UInt64(period)
        let raw = try hmac(algorithm: algorithm, key: key, counter: counter)

        // Dynamic truncation (RFC 4226 §5.3)
        let offset = Int(raw[raw.count - 1] & 0x0F)
        let slice = raw[offset ..< offset + 4]
        var bin: UInt32 = 0
        for b in slice { bin = (bin << 8) | UInt32(b) }
        bin &= 0x7FFF_FFFF
        let mod = UInt32(pow(10.0, Double(digits)))
        let otp = bin % mod

        let elapsed = Int(date.timeIntervalSince1970) % period
        return Code(value: String(format: "%0\(digits)ld", otp),
                    remaining: period - elapsed,
                    period: period)
    }

    /// Accepts the usual otpauth:// URI as well as a bare Base32 secret.
    static func parse(_ input: String) -> (secret: String, digits: Int, period: Int, algorithm: Algorithm)? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("otpauth://") else {
            let cleaned = normalize(trimmed)
            return cleaned.isEmpty ? nil : (cleaned, 6, 30, .sha1)
        }
        guard let comps = URLComponents(string: trimmed),
              let query = comps.queryItems else { return nil }

        func q(_ name: String) -> String? {
            query.first { $0.name.lowercased() == name.lowercased() }?.value
        }
        guard let secret = q("secret").map(normalize), !secret.isEmpty else { return nil }
        let digits = Int(q("digits") ?? "") ?? 6
        let period = Int(q("period") ?? "") ?? 30
        let algo = Algorithm(rawValue: (q("algorithm") ?? "SHA1").uppercased()) ?? .sha1
        return (secret, digits, period, algo)
    }

    // MARK: - Base32

    static func normalize(_ s: String) -> String {
        s.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }

    static func base32Decode(_ s: String) throws -> [UInt8] {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var lookup = [Character: UInt8]()
        for (i, c) in alphabet.enumerated() { lookup[c] = UInt8(i) }

        let cleaned = normalize(s)
        guard !cleaned.isEmpty else { throw TOTPError.badSecret }

        var bits = 0
        var value: UInt32 = 0
        var out = [UInt8]()
        out.reserveCapacity(cleaned.count * 5 / 8)

        for ch in cleaned {
            guard let v = lookup[ch] else { throw TOTPError.badSecret }
            value = (value << 5) | UInt32(v)
            bits += 5
            if bits >= 8 {
                bits -= 8
                out.append(UInt8((value >> UInt32(bits)) & 0xFF))
            }
        }
        guard !out.isEmpty else { throw TOTPError.badSecret }
        return out
    }

    // MARK: - HMAC

    private static func hmac(algorithm: Algorithm, key: [UInt8], counter: UInt64) throws -> [UInt8] {
        var msg = counter.bigEndian
        let msgBytes = withUnsafeBytes(of: &msg) { Array($0) }

        switch algorithm {
        case .sha1:   return HMACSHA1.authenticate(key: key, message: msgBytes)
        case .sha256: return HMACSHA2.authenticate(key: key, message: msgBytes, variant: .sha256)
        case .sha512: return HMACSHA2.authenticate(key: key, message: msgBytes, variant: .sha512)
        }
    }
}

// MARK: - Minimal SHA-1 HMAC

enum HMACSHA1 {
    static func authenticate(key: [UInt8], message: [UInt8]) -> [UInt8] {
        var k = key
        if k.count > 64 { k = sha1(k) }
        if k.count < 64 { k += [UInt8](repeating: 0, count: 64 - k.count) }

        let ipad = k.map { $0 ^ 0x36 }
        let opad = k.map { $0 ^ 0x5C }
        return sha1(opad + sha1(ipad + message))
    }

    static func sha1(_ input: [UInt8]) -> [UInt8] {
        var h: [UInt32] = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]
        var data = input
        let bitLen = UInt64(input.count) * 8
        data.append(0x80)
        while data.count % 64 != 56 { data.append(0) }
        for i in (0..<8).reversed() { data.append(UInt8((bitLen >> (UInt64(i) * 8)) & 0xFF)) }

        for chunk in stride(from: 0, to: data.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 80)
            for i in 0..<16 {
                let b = chunk + i * 4
                w[i] = (UInt32(data[b]) << 24) | (UInt32(data[b + 1]) << 16)
                     | (UInt32(data[b + 2]) << 8) | UInt32(data[b + 3])
            }
            for i in 16..<80 {
                w[i] = rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1)
            }
            var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4]
            for i in 0..<80 {
                let (f, k): (UInt32, UInt32)
                switch i {
                case 0..<20:  f = (b & c) | (~b & d);            k = 0x5A827999
                case 20..<40: f = b ^ c ^ d;                     k = 0x6ED9EBA1
                case 40..<60: f = (b & c) | (b & d) | (c & d);   k = 0x8F1BBCDC
                default:      f = b ^ c ^ d;                     k = 0xCA62C1D6
                }
                let temp = rotl(a, 5) &+ f &+ e &+ k &+ w[i]
                e = d; d = c; c = rotl(b, 30); b = a; a = temp
            }
            h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c
            h[3] = h[3] &+ d; h[4] = h[4] &+ e
        }

        var out = [UInt8]()
        for v in h {
            out.append(UInt8((v >> 24) & 0xFF))
            out.append(UInt8((v >> 16) & 0xFF))
            out.append(UInt8((v >> 8) & 0xFF))
            out.append(UInt8(v & 0xFF))
        }
        return out
    }

    private static func rotl(_ x: UInt32, _ n: UInt32) -> UInt32 {
        (x << n) | (x >> (32 - n))
    }
}

// MARK: - SHA-256 / SHA-512 HMAC

enum HMACSHA2 {
    enum Variant { case sha256, sha512 }

    static func authenticate(key: [UInt8], message: [UInt8], variant: Variant) -> [UInt8] {
        let blockSize = variant == .sha256 ? 64 : 128
        var k = key
        if k.count > blockSize { k = hash(k, variant: variant) }
        if k.count < blockSize { k += [UInt8](repeating: 0, count: blockSize - k.count) }

        let ipad = k.map { $0 ^ 0x36 }
        let opad = k.map { $0 ^ 0x5C }
        return hash(opad + hash(ipad + message, variant: variant), variant: variant)
    }

    static func hash(_ input: [UInt8], variant: Variant) -> [UInt8] {
        switch variant {
        case .sha256: return SHA256Core.hash(input)
        case .sha512: return SHA512Core.hash(input)
        }
    }
}

enum SHA256Core {
    private static let k: [UInt32] = [
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
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]

    static func hash(_ input: [UInt8]) -> [UInt8] {
        var h: [UInt32] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                           0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
        var data = input
        let bitLen = UInt64(input.count) * 8
        data.append(0x80)
        while data.count % 64 != 56 { data.append(0) }
        for i in (0..<8).reversed() { data.append(UInt8((bitLen >> (UInt64(i) * 8)) & 0xFF)) }

        for chunk in stride(from: 0, to: data.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let b = chunk + i * 4
                w[i] = (UInt32(data[b]) << 24) | (UInt32(data[b + 1]) << 16)
                     | (UInt32(data[b + 2]) << 8) | UInt32(data[b + 3])
            }
            for i in 16..<64 {
                let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }
            var a = h[0], b = h[1], c = h[2], d = h[3]
            var e = h[4], f = h[5], g = h[6], hh = h[7]
            for i in 0..<64 {
                let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ (~e & g)
                let t1 = hh &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let t2 = s0 &+ maj
                hh = g; g = f; f = e; e = d &+ t1
                d = c; c = b; b = a; a = t1 &+ t2
            }
            h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d
            h[4] = h[4] &+ e; h[5] = h[5] &+ f; h[6] = h[6] &+ g; h[7] = h[7] &+ hh
        }

        var out = [UInt8]()
        for v in h {
            out.append(UInt8((v >> 24) & 0xFF)); out.append(UInt8((v >> 16) & 0xFF))
            out.append(UInt8((v >> 8) & 0xFF));  out.append(UInt8(v & 0xFF))
        }
        return out
    }

    private static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 {
        (x >> n) | (x << (32 - n))
    }
}

enum SHA512Core {
    private static let k: [UInt64] = [
        0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc,
        0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118,
        0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
        0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694,
        0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
        0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
        0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4,
        0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x06ca6351e003826f, 0x142929670a0e6e70,
        0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df,
        0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
        0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30,
        0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
        0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8,
        0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3,
        0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
        0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b,
        0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178,
        0x06f067aa72176fba, 0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
        0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c,
        0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817
    ]

    static func hash(_ input: [UInt8]) -> [UInt8] {
        var h: [UInt64] = [0x6a09e667f3bcc908, 0xbb67ae8584caa73b,
                           0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
                           0x510e527fade682d1, 0x9b05688c2b3e6c1f,
                           0x1f83d9abfb41bd6b, 0x5be0cd19137e2179]
        var data = input
        let bitLen = UInt64(input.count) * 8
        data.append(0x80)
        while data.count % 128 != 112 { data.append(0) }
        for _ in 0..<8 { data.append(0) }                       // 128-bit length, high half zero
        for i in (0..<8).reversed() { data.append(UInt8((bitLen >> (UInt64(i) * 8)) & 0xFF)) }

        for chunk in stride(from: 0, to: data.count, by: 128) {
            var w = [UInt64](repeating: 0, count: 80)
            for i in 0..<16 {
                let b = chunk + i * 8
                var v: UInt64 = 0
                for j in 0..<8 { v = (v << 8) | UInt64(data[b + j]) }
                w[i] = v
            }
            for i in 16..<80 {
                let s0 = rotr(w[i - 15], 1) ^ rotr(w[i - 15], 8) ^ (w[i - 15] >> 7)
                let s1 = rotr(w[i - 2], 19) ^ rotr(w[i - 2], 61) ^ (w[i - 2] >> 6)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }
            var a = h[0], b = h[1], c = h[2], d = h[3]
            var e = h[4], f = h[5], g = h[6], hh = h[7]
            for i in 0..<80 {
                let s1 = rotr(e, 14) ^ rotr(e, 18) ^ rotr(e, 41)
                let ch = (e & f) ^ (~e & g)
                let t1 = hh &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 = rotr(a, 28) ^ rotr(a, 34) ^ rotr(a, 39)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let t2 = s0 &+ maj
                hh = g; g = f; f = e; e = d &+ t1
                d = c; c = b; b = a; a = t1 &+ t2
            }
            h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d
            h[4] = h[4] &+ e; h[5] = h[5] &+ f; h[6] = h[6] &+ g; h[7] = h[7] &+ hh
        }

        var out = [UInt8]()
        for v in h {
            for i in (0..<8).reversed() { out.append(UInt8((v >> (UInt64(i) * 8)) & 0xFF)) }
        }
        return out
    }

    private static func rotr(_ x: UInt64, _ n: UInt64) -> UInt64 {
        (x >> n) | (x << (64 - n))
    }
}

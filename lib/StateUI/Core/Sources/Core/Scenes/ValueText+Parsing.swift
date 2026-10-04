// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// JSON read off its bytes into a tree of the values it says.
// Design: docs/design/core/scenes.md#what-the-platform-keeps

extension ValueText {
    /// A value as the text said it.
    indirect enum Tree {
        case null
        case bool(Bool)
        case number(String)
        case string(String)
        case array([Tree])
        case object([(key: String, value: Tree)])
    }

    /// JSON, read off its bytes.
    struct Parser {
        let bytes: [UInt8]
        var at = 0

        /// The one value the text holds, and nothing after it.
        mutating func document() -> Tree? {
            guard let tree = value() else { return nil }

            skip()
            return at == bytes.count ? tree : nil
        }

        private mutating func skip() {
            while at < bytes.count, [0x20, 0x0A, 0x0D, 0x09].contains(bytes[at]) {
                at += 1
            }
        }

        private mutating func value() -> Tree? {
            skip()

            guard at < bytes.count else { return nil }

            switch bytes[at] {
            case UInt8(ascii: "n"): return literal("null", .null)
            case UInt8(ascii: "t"): return literal("true", .bool(true))
            case UInt8(ascii: "f"): return literal("false", .bool(false))
            case UInt8(ascii: "\""): return string().map(Tree.string)
            case UInt8(ascii: "["): return array()
            case UInt8(ascii: "{"): return object()
            default: return number()
            }
        }

        private mutating func literal(_ word: String, _ tree: Tree) -> Tree? {
            let spelled = Array(word.utf8)

            guard at + spelled.count <= bytes.count,
                Array(bytes[at..<at + spelled.count]) == spelled
            else { return nil }

            at += spelled.count
            return tree
        }

        private mutating func number() -> Tree? {
            let start = at

            while at < bytes.count,
                let scalar = Optional(bytes[at]),
                (scalar >= UInt8(ascii: "0") && scalar <= UInt8(ascii: "9"))
                    || [UInt8(ascii: "-"), UInt8(ascii: "+"), UInt8(ascii: "."),
                        UInt8(ascii: "e"), UInt8(ascii: "E")].contains(scalar) {
                at += 1
            }

            guard at > start else { return nil }

            return .number(String(decoding: bytes[start..<at], as: UTF8.self))
        }

        private mutating func string() -> String? {
            guard at < bytes.count, bytes[at] == UInt8(ascii: "\"") else { return nil }

            at += 1
            var scalars = String.UnicodeScalarView()
            var run: [UInt8] = []

            func flush() {
                scalars.append(contentsOf: String(decoding: run, as: UTF8.self).unicodeScalars)
                run.removeAll()
            }

            while at < bytes.count {
                let byte = bytes[at]
                at += 1

                switch byte {
                case UInt8(ascii: "\""):
                    flush()
                    return String(scalars)

                case UInt8(ascii: "\\"):
                    flush()

                    guard at < bytes.count else { return nil }

                    let escape = bytes[at]
                    at += 1

                    switch escape {
                    case UInt8(ascii: "\""): scalars.append("\"")
                    case UInt8(ascii: "\\"): scalars.append("\\")
                    case UInt8(ascii: "/"): scalars.append("/")
                    case UInt8(ascii: "n"): scalars.append("\n")
                    case UInt8(ascii: "r"): scalars.append("\r")
                    case UInt8(ascii: "t"): scalars.append("\t")
                    case UInt8(ascii: "b"): scalars.append("\u{08}")
                    case UInt8(ascii: "f"): scalars.append("\u{0C}")
                    case UInt8(ascii: "u"):
                        guard let unit = hex() else { return nil }

                        // A pair of halves stands for one scalar past the first
                        // plane.
                        if (0xD800...0xDBFF).contains(unit), at + 1 < bytes.count,
                            bytes[at] == UInt8(ascii: "\\"), bytes[at + 1] == UInt8(ascii: "u") {
                            at += 2

                            guard let low = hex(), (0xDC00...0xDFFF).contains(low),
                                let scalar = Unicode.Scalar(0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00))
                            else { return nil }

                            scalars.append(scalar)
                        } else {
                            guard let scalar = Unicode.Scalar(unit) else { return nil }

                            scalars.append(scalar)
                        }
                    default:
                        return nil
                    }

                default:
                    run.append(byte)
                }
            }

            return nil
        }

        /// Four hex digits, as a number.
        private mutating func hex() -> UInt32? {
            guard at + 4 <= bytes.count,
                let value = UInt32(String(decoding: bytes[at..<at + 4], as: UTF8.self), radix: 16)
            else { return nil }

            at += 4
            return value
        }

        private mutating func array() -> Tree? {
            at += 1
            var items: [Tree] = []

            skip()
            if at < bytes.count, bytes[at] == UInt8(ascii: "]") {
                at += 1
                return .array(items)
            }

            while true {
                guard let item = value() else { return nil }

                items.append(item)
                skip()

                guard at < bytes.count else { return nil }

                if bytes[at] == UInt8(ascii: ",") {
                    at += 1
                    continue
                }

                guard bytes[at] == UInt8(ascii: "]") else { return nil }

                at += 1
                return .array(items)
            }
        }

        private mutating func object() -> Tree? {
            at += 1
            var members: [(key: String, value: Tree)] = []

            skip()
            if at < bytes.count, bytes[at] == UInt8(ascii: "}") {
                at += 1
                return .object(members)
            }

            while true {
                skip()

                guard let key = string() else { return nil }

                skip()

                guard at < bytes.count, bytes[at] == UInt8(ascii: ":") else { return nil }

                at += 1

                guard let member = value() else { return nil }

                members.append((key: key, value: member))
                skip()

                guard at < bytes.count else { return nil }

                if bytes[at] == UInt8(ascii: ",") {
                    at += 1
                    continue
                }

                guard bytes[at] == UInt8(ascii: "}") else { return nil }

                at += 1
                return .object(members)
            }
        }
    }
}

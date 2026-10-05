// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CWebTesting
@_spi(Host) import StateUI

/// The browser's page as the conformance suite reaches it (Testing/JavaScript/browser.mjs): the page going on a
/// frame while the program waits, a script run on an element, and the controller beside the browser asked for the
/// user's input and the repository's files.
@MainActor
enum WebBrowser {
    /// What a script on an element threw.
    struct Thrown: Error, CustomStringConvertible {
        let description: String
    }

    /// The page goes on a frame - its tasks, its rendering, what its observers say - while the program waits.
    static func pause() {
        stateui_web_testing_pause()
    }

    /// The value of `script` on `element`, its element `e`: words as they are, a list's entries a NUL apart, anything
    /// else as JavaScript writes it; nil for null or undefined.
    /// - Throws: `Thrown` where the script threw.
    static func evaluate(_ script: String, on element: Int32) throws -> String? {
        let answer = copyRead(length: withUTF8(script) { stateui_web_testing_evaluate(element, $0, $1) })
        if answer.hasPrefix("!") { throw Thrown(description: String(answer.dropFirst())) }
        return answer.isEmpty ? nil : String(answer.dropFirst())
    }

    /// `script`'s value on `element` as a number; nil for none.
    static func number(_ script: String, on element: Int32) throws -> Double? {
        try evaluate(script, on: element).flatMap(Double.init)
    }

    /// `script`'s value on `element` as true or false.
    static func truth(_ script: String, on element: Int32) throws -> Bool {
        try evaluate(script, on: element) == "true"
    }

    /// Runs `script` on the page, for what it does.
    static func run(_ script: String, on element: Int32 = 0) throws {
        _ = try evaluate("(() => { \(script); })()", on: element)
    }

    /// Asks the controller `message` - its fields written as JSON - and answers its words; nil for none.
    @discardableResult
    static func ask(_ message: [(String, Asked)]) -> String? {
        let json = "{" + message.map { "\(quoted($0.0)):\($0.1.json)" }.joined(separator: ",") + "}"
        let length = withUTF8(json) { stateui_web_testing_ask($0, $1) }
        return length < 0 ? nil : copyRead(length: length)
    }

    /// A value a message to the controller carries.
    enum Asked {
        case words(String)
        case number(Double)
        case truth(Bool)
        case points([Point])

        var json: String {
            switch self {
            case .words(let words): WebBrowser.quoted(words)
            case .number(let number): Self.written(number)
            case .truth(let truth): truth ? "true" : "false"
            case .points(let points): "[" + points.map { "[\(Self.written($0.x)),\(Self.written($0.y))]" }
                .joined(separator: ",") + "]"
            }
        }

        private static func written(_ number: Double) -> String {
            number.isFinite ? "\(number)" : "0"
        }
    }

    /// `words` as a JSON string.
    nonisolated static func quoted(_ words: String) -> String {
        var written = "\""
        for scalar in words.unicodeScalars {
            switch scalar {
            case "\"": written += "\\\""
            case "\\": written += "\\\\"
            case "\n": written += "\\n"
            case "\r": written += "\\r"
            case "\t": written += "\\t"
            case _ where scalar.value < 0x20:
                let hex = String(scalar.value, radix: 16)
                written += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            default: written.unicodeScalars.append(scalar)
            }
        }
        return written + "\""
    }

    private static func copyRead(length: Int32) -> String {
        let count = Int(length)
        guard count > 0 else { return "" }
        let bytes = [UInt8](unsafeUninitializedCapacity: count) { buffer, written in
            buffer.withMemoryRebound(to: CChar.self) { stateui_web_testing_copy_read($0.baseAddress) }
            written = count
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func withUTF8<Result>(_ text: String, _ body: (UnsafePointer<CChar>?, Int32) -> Result) -> Result {
        var text = text
        return text.withUTF8 { bytes in bytes.withMemoryRebound(to: CChar.self) { body($0.baseAddress, Int32($0.count)) } }
    }
}

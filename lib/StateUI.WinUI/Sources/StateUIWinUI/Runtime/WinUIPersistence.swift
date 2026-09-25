// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// The application's kept values, in a store of the host's own - Windows keeps none for an application that is no
/// package: read before the first scene, written whole as each changes, each as words its key's kind reads back.
/// Design: docs/design/platforms/winui/runtime.md#kept-values
@MainActor
enum WinUIPersistence {
    /// Hands the core every kept value there is, before the first render reads one.
    static func restore(into core: CoreLink) {
        let keys = core.persistentKeys
        guard !keys.isEmpty else { return }

        let stored = read()
        var restored: [String: HostValue] = [:]
        for key in keys {
            guard let word = stored[key.name] else { continue }
            switch key.kind {
            case .boolean: restored[key.name] = .bool(word == "true")
            case .integer, .number: if let number = Double(word) { restored[key.name] = .number(number) }
            case .text: restored[key.name] = .string(word)
            }
        }
        core.restorePersistent(restored)
    }

    /// Keeps a key's new value, as the act `persistValue` carries it.
    static func keep(_ call: HostActCall, core: CoreLink) {
        guard call.arguments.count >= 2,
              let name = call.arguments[0].name,
              let key = core.persistentKeys.first(where: { $0.name == name }),
              let word = word(of: call.arguments[1], kind: key.kind)
        else { return }

        var stored = read()
        stored[name] = word
        write(stored)
    }

    /// A value as the words its kind reads back; nil for a value of another kind.
    static func word(of value: HostValue, kind: PersistentKind) -> String? {
        switch kind {
        case .boolean: value.bool.map { $0 ? "true" : "false" }
        case .integer: value.number.map { String(Int64($0)) }
        case .number: value.number.map { String($0) }
        case .text: value.string
        }
    }

    /// The store: a line a key, its name and its words apart by a tab; a tab, a line's end and a backslash in
    /// either written escaped.
    static func read() -> [String: String] {
        var values: [String: String] = [:]
        for line in WinUIStrings.read({ stateui_winui_stored($0, $1) }).split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            values[unescaped(parts[0])] = unescaped(parts[1])
        }
        return values
    }

    /// Writes the whole store, its keys in order, so the same values write the same file.
    static func write(_ values: [String: String]) {
        let text = values.keys.sorted().map { "\(escaped($0))\t\(escaped(values[$0]!))\n" }.joined()
        if !stateui_winui_store(text) { WinUILog.error("the kept values could not be written") }
    }

    private static func escaped(_ words: String) -> String {
        words.replacing("\\", with: "\\\\").replacing("\t", with: "\\t").replacing("\n", with: "\\n")
            .replacing("\r", with: "\\r")
    }

    private static func unescaped(_ words: Substring) -> String {
        var result = ""
        var escaping = false
        for character in words {
            if escaping {
                result.append(character == "t" ? "\t" : character == "n" ? "\n" : character == "r" ? "\r" : character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        return result
    }
}

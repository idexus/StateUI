// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// The application's kept values in the platform's preferences: read before the first scene, written as each
/// changes, each as words its key's kind reads back.
/// Design: docs/design/platforms/android/runtime.md#kept-values
@MainActor
enum AndroidPersistence {
    /// Hands the core every kept value there is, before the first render reads one.
    static func restore(into core: CoreLink, context: jobject) {
        let keys = core.persistentKeys
        guard core.persistentStorage == .preferences, !keys.isEmpty else { return }

        let words: [String?] = Java.frame {
            let names = Java.array(of: JavaAPI.string, keys.map { Java.string($0.name) })
            let read = Java.callStaticObject(JavaAPI.store, JavaAPI.readStore, .object(context), .object(names))
            return read.map { array in
                (0..<keys.count).map { index -> String? in
                    let element = Java.jni.GetObjectArrayElement(Java.env, array, jsize(index))
                    defer { Java.release(local: element) }
                    return element.map { Java.text($0) }
                }
            } ?? []
        }

        var restored: [String: HostValue] = [:]
        for (key, word) in zip(keys, words) {
            guard let word else { continue }
            switch key.kind {
            case .boolean: restored[key.name] = .bool(word == "true")
            case .integer, .number: if let number = Double(word) { restored[key.name] = .number(number) }
            case .text: restored[key.name] = .string(word)
            }
        }
        core.restorePersistent(restored)
    }

    /// Keeps a key's new value, as the act `persistValue` carries it.
    static func keep(_ call: HostActCall, core: CoreLink, context: jobject) {
        guard core.persistentStorage == .preferences, call.arguments.count >= 2,
              let name = call.arguments[0].name,
              let key = core.persistentKeys.first(where: { $0.name == name })
        else { return }

        let value = call.arguments[1]
        let word: String? = switch key.kind {
        case .boolean: value.bool.map { $0 ? "true" : "false" }
        case .integer: value.number.map { String(Int64($0)) }
        case .number: value.number.map { String($0) }
        case .text: value.string
        }
        guard let word else { return }
        Java.frame {
            Java.callStatic(
                JavaAPI.store, JavaAPI.writeStore, .object(context), .object(Java.string(name)), .object(Java.string(word)))
        }
    }
}

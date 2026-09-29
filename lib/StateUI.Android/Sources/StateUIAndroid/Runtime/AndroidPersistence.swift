// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// The application's kept values in the platform's preferences: read before the first scene, written as each
/// changes, as the words every host keeps a value by.
/// Design: docs/design/platforms/android/runtime.md#kept-values
@MainActor
enum AndroidPersistence {
    /// Hands the core every kept value there is, before the first render reads one.
    static func restore(into core: CoreLink, context: jobject) {
        let keys = core.persistentKeys
        guard !keys.isEmpty else { return }

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

        let kept = zip(keys, words).compactMap { key, word in word.map { (key.name, $0) } }
        core.restorePersistent(KeptWord.restored(Dictionary(uniqueKeysWithValues: kept), for: keys))
    }

    /// Keeps a key's new value, as the act `persistValue` carries it.
    static func keep(_ call: HostActCall, core: CoreLink, context: jobject) {
        guard let kept = KeptWord.kept(call.arguments, keys: core.persistentKeys) else { return }
        Java.frame {
            Java.callStatic(
                JavaAPI.store, JavaAPI.writeStore, .object(context), .object(Java.string(kept.name)),
                .object(Java.string(kept.word)))
        }
    }
}

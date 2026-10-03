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

        let kept = zip(keys, words(keys.map(\.name), context: context)).compactMap { key, word in
            word.map { (key.name, $0) }
        }
        core.restorePersistent(KeptWord.restored(Dictionary(uniqueKeysWithValues: kept), for: keys))
    }

    /// The words the preferences keep under `names`, in order; nil for a name they keep nothing under.
    static func words(_ names: [String], context: jobject) -> [String?] {
        Java.frame {
            let array = Java.array(of: JavaAPI.string, names.map { Java.string($0) })
            let read = Java.callStaticObject(JavaAPI.store, JavaAPI.readStore, .object(context), .object(array))
            return read.map { array in
                (0..<names.count).map { index -> String? in
                    let element = Java.jni.GetObjectArrayElement(Java.env, array, jsize(index))
                    defer { Java.release(local: element) }
                    return element.map { Java.text($0) }
                }
            } ?? []
        }
    }

    /// The key the application's scenes are kept under for the next start: the platform restores no windows.
    static let scenesKey = "StateUI.Scenes"

    /// The application's scenes as they stood, for this start.
    static func readScenes(context: jobject) -> KeptScenes {
        KeptScenes((words([scenesKey], context: context).first ?? nil) ?? "")
    }

    /// Writes the scenes' text in place of what was kept.
    static func writeScenes(_ text: String, context: jobject) {
        Java.frame {
            Java.callStatic(
                JavaAPI.store, JavaAPI.writeStore, .object(context), .object(Java.string(scenesKey)),
                .object(Java.string(text)))
        }
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

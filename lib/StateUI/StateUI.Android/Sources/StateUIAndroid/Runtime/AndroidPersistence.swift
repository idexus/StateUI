// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// The application's kept values in the platform's preferences: read as a state under a key is first made, written
/// as each changes, as the words every host keeps a value by.
/// Design: docs/design/platforms/android/runtime.md#kept-values
@MainActor
enum AndroidPersistence {
    /// Gives the core the reader of the preferences, through the application's context, which outlives every
    /// activity.
    static func readKept(into core: CoreLink, context: jobject) {
        guard let local = Java.callObject(context, JavaAPI.getApplicationContext) else { return }
        let application = JavaObject(local)
        core.readsKept { name, kind in
            word(name, context: application.reference).flatMap { KeptWord.restored($0, as: kind) }
        }
    }

    /// The words the preferences keep under `name`; nil where they keep none.
    static func word(_ name: String, context: jobject) -> String? {
        Java.frame {
            Java.callStaticObject(JavaAPI.store, JavaAPI.readStore, .object(context), .object(Java.string(name)))
                .map { Java.text($0) }
        }
    }

    /// The key the application's scenes are kept under for the next start: the platform restores no windows.
    static let scenesKey = "StateUI.Scenes"

    /// The application's scenes as they stood, for this start.
    static func readScenes(context: jobject) -> KeptScenes {
        KeptScenes(word(scenesKey, context: context) ?? "")
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
    static func keep(_ call: HostActCall, context: jobject) {
        guard let kept = KeptWord.kept(call.arguments) else { return }
        Java.frame {
            Java.callStatic(
                JavaAPI.store, JavaAPI.writeStore, .object(context), .object(Java.string(kept.name)),
                .object(Java.string(kept.word)))
        }
    }
}

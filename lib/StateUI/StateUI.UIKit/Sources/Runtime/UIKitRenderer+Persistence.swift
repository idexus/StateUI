// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Kept values in the preferences: read as a state under a key is first made, each written as it changes, as the
/// words every host keeps a value by.
/// Design: docs/design/host/runtime.md#kept-values
extension UIKitRenderer {
    func readKeptFromPreferences() {
        let preferences = preferences
        runtime.core.readsKept { name, kind in
            preferences.string(forKey: name).flatMap { KeptWord.restored($0, as: kind) }
        }
    }

    func savePersistent(_ call: HostActCall) {
        guard let kept = KeptWord.kept(call.arguments) else { return }
        preferences.set(kept.word, forKey: kept.name)
    }
}
#endif

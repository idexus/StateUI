// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// The application's kept values, in a store of the host's own - Windows keeps none for an application that is no
/// package: read before the first scene, written whole as each changes, as the host layer's text
/// (`KeptValuesText`).
/// Design: docs/design/platforms/winui/runtime.md#kept-values
@MainActor
enum WinUIPersistence {
    /// Hands the core every kept value there is, before the first render reads one.
    static func restore(into core: CoreLink) {
        let keys = core.persistentKeys
        guard !keys.isEmpty else { return }
        core.restorePersistent(read().restored(for: keys))
    }

    /// Keeps a key's new value, as the act `persistValue` carries it.
    static func keep(_ call: HostActCall, core: CoreLink) {
        var kept = read()
        guard kept.keep(call.arguments, keys: core.persistentKeys) else { return }
        write(kept)
    }

    /// What the store holds; nothing where there is none.
    static func read() -> KeptValuesText {
        KeptValuesText(WinUIStrings.read { stateui_winui_stored($0, $1) })
    }

    /// Writes `kept` whole in place of the store.
    static func write(_ kept: KeptValuesText) {
        if !stateui_winui_store(kept.text) { WinUIRenderer.log.error("the kept values could not be written") }
    }
}

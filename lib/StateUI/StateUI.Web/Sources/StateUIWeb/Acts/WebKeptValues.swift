// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The application's kept values in the browser's storage for the page's site, under the application's name: a value
/// read as a state under its key is first made, written whole as each changes.
/// Design: docs/design/platforms/web/runtime.md#acts
@MainActor
enum WebKeptValues {
    /// Gives the core the reader of the browser's storage.
    static func readKept(into core: CoreLink, application: String) {
        core.readsKept { name, kind in read(application).value(named: name, as: kind) }
    }

    /// Keeps a key's new value, as the act `persistValue` carries it.
    static func keep(_ call: HostActCall, application: String) {
        var kept = read(application)
        guard kept.keep(call.arguments) else { return }
        if !WebRelay.store(kept.text, under: key(application)) {
            WebRenderer.log.error("the kept values could not be written")
        }
    }

    /// The application's scenes as they stood when the page was left, for this start.
    static func readScenes(_ application: String) -> KeptScenes {
        KeptScenes(WebRelay.stored(scenesKey(application)))
    }

    /// Keeps the scenes' text whole in place of the one kept before.
    static func writeScenes(_ text: String, application: String) {
        if !WebRelay.store(text, under: scenesKey(application)) { WebRenderer.log.error("the kept scenes could not be written") }
    }

    private static func scenesKey(_ application: String) -> String {
        "StateUI kept scenes: " + application
    }

    private static func read(_ application: String) -> KeptValuesText {
        KeptValuesText(WebRelay.stored(key(application)))
    }

    private static func key(_ application: String) -> String {
        "StateUI kept values: " + application
    }
}

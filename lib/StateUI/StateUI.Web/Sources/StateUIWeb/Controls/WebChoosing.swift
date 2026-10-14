// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A picker as the browser shows it - a `<select>`, segments or radio buttons: told the user's choice by its place.
/// Design: docs/design/views/controls.md#a-pickers-presentation
@MainActor
protocol WebChoosing: WebWordsView {
    var onChosen: (Int) -> Void { get set }
    func setChoices(_ choices: [String], chosen: Int, writeChosen: Bool, title words: String?)
}

extension WebPickerView: WebChoosing {}

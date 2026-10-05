// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Picker: the browser's `<select>`, an `<option>` for each choice, saying the choice the user makes.
/// Design: docs/design/platforms/web/controls.md#a-picker
@MainActor
final class WebPickerView: WebDOMView, WebWordsView {
    /// The user chose the choice at this place.
    var onChosen: (Int) -> Void = { _ in }

    private var options: [WebDOMView] = []
    private var written = PickerChoices()

    init() {
        super.init(tag: "select")
        listen("change") { [weak self] in
            guard let self else { return }
            onChosen(Int(WebRelay.number(of: node, "selectedIndex")))
        }
    }

    override var role: String? { nil }

    /// The choices and the tree's choice, each written only where the tree changed it.
    func setChoices(_ choices: [String], chosen: Int, writeChosen: Bool) {
        let write = written.write(choices, chosen: chosen, choiceChanged: writeChosen)
        if let choices = write.choices {
            for option in options { option.detach() }
            options = choices.enumerated().map { index, words in
                let option = WebDOMView(tag: "option")
                WebRelay.setText(option.node, words)
                WebRelay.insert(option.node, into: node, at: index)
                return option
            }
        }
        guard write.writesChoice else { return }
        WebRelay.setNumber(node, "selectedIndex", Double(write.chosen ?? -1))
    }

    override func setEnabled(_ enabled: Bool) {
        attribute("disabled", enabled ? nil : "")
    }

    override func detach() {
        for option in options { option.detach() }
        super.detach()
    }
}

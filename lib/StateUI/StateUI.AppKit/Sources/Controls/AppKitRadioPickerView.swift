// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A picker offering its values as radio buttons: a column of AppKit's radio buttons sharing one action, which
/// AppKit keeps to one turned on.
/// Design: docs/design/views/controls.md#a-pickers-presentation
@MainActor
final class AppKitRadioPickerView: NSStackView, AppKitChoosing {
    var onSelectionChanged: ((Int) -> Void)?
    var onOpened: (() -> Void)?
    var onClosed: (() -> Void)?

    /// The choices and the choice as the tree last wrote them (`PickerChoices`).
    private var written = PickerChoices()

    convenience init() {
        self.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 6
    }

    private var buttons: [NSButton] { arrangedSubviews.compactMap { $0 as? NSButton } }

    var itemTitles: [String] { buttons.map(\.title) }
    var indexOfSelectedItem: Int { buttons.firstIndex { $0.state == .on } ?? -1 }

    var isEnabled: Bool {
        get { buttons.first?.isEnabled ?? true }
        set { for button in buttons { button.isEnabled = newValue } }
    }

    func apply(
        items: [String], selectedIndex: Int, writeSelection: Bool, title: String?, font: NSFont, textColor: NSColor,
        tint: NSColor?, alignment: NSTextAlignment, enabled: Bool, open: Bool, writeOpen: Bool
    ) {
        ProgramWrite.perform {
            let write = written.write(items, chosen: selectedIndex, choiceChanged: writeSelection)
            if let choices = write.choices {
                for button in buttons { removeView(button) }
                for caption in choices {
                    addArrangedSubview(NSButton(radioButtonWithTitle: caption, target: self, action: #selector(chosen)))
                }
            }
            if write.writesChoice {
                for (place, button) in buttons.enumerated() { button.state = place == write.chosen ? .on : .off }
            }
            for (place, button) in buttons.enumerated() {
                button.font = font
                button.contentTintColor = tint
                button.attributedTitle = NSAttributedString(
                    string: written.choices[place], attributes: [.font: font, .foregroundColor: textColor])
            }
            self.alignment = switch alignment {
            case .center: .centerX
            case .right: .trailing
            default: .leading
            }
            isEnabled = enabled
        }
    }

    @objc private func chosen(_ sender: NSButton) {
        guard let place = buttons.firstIndex(of: sender) else { return }
        onSelectionChanged?(place)
    }

    func chooseForTesting(index: Int) {
        guard buttons.indices.contains(index) else { return }
        for (place, button) in buttons.enumerated() { button.state = place == index ? .on : .off }
        chosen(buttons[index])
    }
}
#endif

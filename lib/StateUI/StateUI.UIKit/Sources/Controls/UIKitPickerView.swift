// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Picker: UIKit's own pop-up button - its menu the choices, the chosen one ticked and its caption on the button,
/// the picker's title there while none is chosen. The user's choice is reported; the program's is only shown.
@MainActor
final class UIKitPickerView: UIButton {
    /// What the picker does when the user chose, handed the choice's place.
    var onChosen: ((Int) -> Void)?

    /// What the picker does when its menu opens, and when it closes.
    var onOpened: (() -> Void)?
    var onClosed: (() -> Void)?

    /// The choices and the choice as the tree last wrote them (`PickerChoices`).
    private var written = PickerChoices()

    /// The choice shown, as the tree wrote it or the user made it; nil for none.
    private(set) var chosen: Int?

    /// What the button says while nothing is chosen.
    private(set) var title: String?

    var choices: [String] { written.choices }

    init() {
        super.init(frame: .zero)
        var configuration = UIButton.Configuration.plain()
        configuration.indicator = .popup
        self.configuration = configuration
        followTextSize()
        showsMenuAsPrimaryAction = true
        contentHorizontalAlignment = .leading
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitPickerView is made in code")
    }

    /// The choices, the tree's choice - written only where the tree changed it or the choices - and the title.
    func setChoices(_ choices: [String], chosen: Int, writeChosen: Bool, title: String?) {
        let write = written.write(choices, chosen: chosen, choiceChanged: writeChosen)
        if write.writesChoice { self.chosen = write.chosen }
        self.title = title
        if write.choices != nil || write.writesChoice { showMenu() }
        showCaption()
    }

    /// The user chose the choice at `place` in the menu.
    func userChose(_ place: Int) {
        guard written.choices.indices.contains(place) else { return }
        chosen = place
        showMenu()
        showCaption()
        onChosen?(place)
    }

    /// The words' look - the button's own where it says nothing - and where they stand across it.
    func setLook(_ look: TextLook, alignment: TextAlignment) {
        configuration?.titleTextAttributesTransformer = look.titleTransformer(color: tintColor)
        contentHorizontalAlignment = switch alignment {
        case .start: .leading
        case .center: .center
        case .end: .trailing
        }
    }

    /// The colour of the arrow beside the words; nil for the button's own.
    func setTint(_ tint: UIColor?) {
        configuration?.indicatorColorTransformer = tint.map { tint in UIConfigurationColorTransformer { _ in tint } }
    }

    private func showMenu() {
        menu = UIMenu(children: written.choices.enumerated().map { place, caption in
            UIAction(title: caption, state: place == chosen ? .on : .off) { [weak self] _ in self?.userChose(place) }
        })
    }

    private func showCaption() {
        configuration?.title = chosen.map { written.choices[$0] } ?? title ?? ""
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: (any UIContextMenuInteractionAnimating)?
    ) {
        super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
        onOpened?()
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction, willEndFor configuration: UIContextMenuConfiguration,
        animator: (any UIContextMenuInteractionAnimating)?
    ) {
        super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
        onClosed?()
    }
}
#endif

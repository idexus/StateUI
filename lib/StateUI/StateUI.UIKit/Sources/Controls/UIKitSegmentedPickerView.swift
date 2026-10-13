// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A picker offering its values as segments: UIKit's segmented control, which tells only the user's choice.
/// Design: docs/design/views/controls.md#a-pickers-presentation
@MainActor
final class UIKitSegmentedPickerView: UISegmentedControl, UIKitChoosing {
    var onChosen: ((Int) -> Void)?
    var onOpened: (() -> Void)?
    var onClosed: (() -> Void)?

    /// The choices and the choice as the tree last wrote them (`PickerChoices`).
    private var written = PickerChoices()

    private(set) var title: String?

    var choices: [String] { written.choices }
    var chosen: Int? { selectedSegmentIndex == UISegmentedControl.noSegment ? nil : selectedSegmentIndex }

    init() {
        super.init(frame: .zero)
        addAction(UIAction { [weak self] _ in
            guard let self, let chosen else { return }
            onChosen?(chosen)
        }, for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitSegmentedPickerView is made in code")
    }

    func setChoices(_ choices: [String], chosen: Int, writeChosen: Bool, title: String?) {
        let write = written.write(choices, chosen: chosen, choiceChanged: writeChosen)
        if let shown = write.choices {
            removeAllSegments()
            for (place, caption) in shown.enumerated() { insertSegment(withTitle: caption, at: place, animated: false) }
        }
        if write.writesChoice { selectedSegmentIndex = write.chosen ?? UISegmentedControl.noSegment }
        self.title = title
    }

    func userChose(_ place: Int) {
        guard written.choices.indices.contains(place) else { return }
        selectedSegmentIndex = place
        onChosen?(place)
    }

    func setLook(_ look: TextLook, alignment: TextAlignment) {
        setTitleTextAttributes(look.attributes(color: .label, in: traitCollection), for: .normal)
    }

    func setTint(_ tint: UIColor?) {
        selectedSegmentTintColor = tint
    }
}
#endif

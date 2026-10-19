// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A picker offering its values as segments: AppKit's segmented control, one segment chosen at a time.
/// Design: docs/design/views/controls.md#a-pickers-presentation
@MainActor
final class AppKitSegmentedPickerView: NSSegmentedControl, AppKitChoosing {
    var onSelectionChanged: ((Int) -> Void)?
    var onOpened: (() -> Void)?
    var onClosed: (() -> Void)?

    /// The choices and the choice as the tree last wrote them (`PickerChoices`).
    private var written = PickerChoices()

    convenience init() {
        self.init(labels: [], trackingMode: .selectOne, target: nil, action: nil)
        target = self
        action = #selector(chosen)
    }

    var itemTitles: [String] { (0..<segmentCount).map { label(forSegment: $0) ?? "" } }

    func apply(
        items: [String], selectedIndex: Int, writeSelection: Bool, title: String?, font: NSFont, textColor: NSColor,
        tint: NSColor?, alignment: TextAlignment, enabled: Bool, open: Bool, writeOpen: Bool
    ) {
        ProgramWrite.perform {
            let write = written.write(items, chosen: selectedIndex, choiceChanged: writeSelection)
            if let choices = write.choices {
                segmentCount = choices.count
                for (place, caption) in choices.enumerated() { setLabel(caption, forSegment: place) }
            }
            if write.writesChoice { selectedSegment = write.chosen ?? -1 }
            self.font = font
            selectedSegmentBezelColor = tint
            isEnabled = enabled
        }
    }

    @objc private func chosen() {
        onSelectionChanged?(selectedSegment)
    }

    func chooseForTesting(index: Int) {
        selectedSegment = index
        chosen()
    }
}
#endif

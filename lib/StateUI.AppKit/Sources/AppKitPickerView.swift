// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A native AppKit choice field with StateUI's strict program/reader boundary.
///
/// `NSPopUpButton.title` inserts a real menu item when nothing is selected.
/// The separate pass-through label keeps StateUI's placeholder outside the
/// choice collection, so every native index remains a StateUI item index.
@MainActor
final class AppKitPickerView: NSView, NSMenuDelegate {
    var onSelectionChanged: ((Int) -> Void)?
    var onOpened: (() -> Void)?
    var onClosed: (() -> Void)?

    private let button = NSPopUpButton(frame: .zero, pullsDown: false)
    private let placeholder = AppKitPickerPlaceholder()
    private var applying = false
    private var requestedOpen = false
    private var menuOpen = false
    private var openingScheduled = false
    private var suppressLifecycle = false
    private var sourceItems: [String] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = #selector(changed(_:))
        button.menu?.delegate = self

        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.lineBreakMode = .byTruncatingTail
        placeholder.maximumNumberOfLines = 1

        addSubview(button)
        addSubview(placeholder)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            placeholder.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -25),
            placeholder.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitPickerView is created in code")
    }

    override var intrinsicContentSize: NSSize { button.intrinsicContentSize }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        presentRequestedMenuIfPossible()
    }

    var itemTitles: [String] { button.itemTitles }
    var indexOfSelectedItem: Int { button.indexOfSelectedItem }
    var titleOfSelectedItem: String? { button.titleOfSelectedItem }
    var title: String { placeholder.stringValue }
    var font: NSFont? { button.font }
    var isEnabled: Bool {
        get { button.isEnabled }
        set { button.isEnabled = newValue }
    }

    func apply(
        items: [String],
        selectedIndex: Int,
        writeSelection: Bool,
        title: String?,
        font: NSFont,
        textColor: NSColor,
        tint: NSColor?,
        alignment: NSTextAlignment,
        enabled: Bool,
        open: Bool,
        writeOpen: Bool
    ) {
        applying = true

        let itemsChanged = sourceItems != items
        sourceItems = items
        if itemsChanged {
            button.removeAllItems()
            button.addItems(withTitles: items)
            button.menu?.delegate = self
        }

        button.font = font
        button.alignment = alignment
        button.isEnabled = enabled
        button.contentTintColor = tint
        styleItems(font: font, color: textColor, alignment: alignment)

        if writeSelection || itemsChanged {
            if items.indices.contains(selectedIndex) {
                button.selectItem(at: selectedIndex)
            } else {
                button.select(nil)
            }
        } else if !items.indices.contains(button.indexOfSelectedItem) {
            button.select(nil)
        }

        placeholder.stringValue = title ?? ""
        placeholder.font = font
        placeholder.textColor = .placeholderTextColor
        placeholder.alignment = alignment
        updatePlaceholder()
        applying = false

        if writeOpen { setOpen(open) }
    }

    private func styleItems(font: NSFont, color: NSColor, alignment: NSTextAlignment) {
        for (index, item) in button.itemArray.enumerated() {
            item.attributedTitle = styled(
                sourceItems[index],
                font: font,
                color: color,
                alignment: alignment)
        }
    }

    private func styled(
        _ text: String,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ])
    }

    private func updatePlaceholder() {
        placeholder.isHidden = button.indexOfSelectedItem >= 0
    }

    private func setOpen(_ open: Bool) {
        requestedOpen = open

        if open {
            presentRequestedMenuIfPossible()
        } else if menuOpen {
            suppressLifecycle = true
            button.menu?.cancelTracking()
        }
    }

    /// What opens a picker's menu in a test, in place of the pop-up button's
    /// click: the native menu's tracking holds the run loop until a reader
    /// ends it. Taken when the opening is scheduled, so an opening that runs
    /// late still reaches the test that asked for it.
    static var opensMenuForTesting: ((AppKitPickerView) -> Void)?

    private func presentRequestedMenuIfPossible() {
        guard requestedOpen, window != nil, !menuOpen, !openingScheduled else { return }
        openingScheduled = true
        let opensForTesting = Self.opensMenuForTesting

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.openingScheduled = false
            guard self.requestedOpen, self.window != nil, !self.menuOpen else { return }
            self.suppressLifecycle = true
            if let opensForTesting {
                opensForTesting(self)
            } else {
                self.button.performClick(nil)
            }
        }
    }

    @objc private func changed(_ sender: NSPopUpButton) {
        guard !applying else { return }
        updatePlaceholder()
        onSelectionChanged?(button.indexOfSelectedItem)
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuOpen = true
        if !suppressLifecycle { onOpened?() }
    }

    func menuDidClose(_ menu: NSMenu) {
        menuOpen = false
        requestedOpen = false
        if suppressLifecycle {
            suppressLifecycle = false
        } else {
            onClosed?()
        }
    }

    var contentTintForTesting: NSColor? { button.contentTintColor }

    func chooseForTesting(index: Int) {
        if sourceItems.indices.contains(index) {
            button.selectItem(at: index)
        } else {
            button.select(nil)
        }
        changed(button)
    }
}

private final class AppKitPickerPlaceholder: NSTextField {
    convenience init() {
        self.init(labelWithString: "")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

extension AppKitPickerView: AppKitAccessibilityPresenting {
    var presentedControl: NSView { button }
}

#endif

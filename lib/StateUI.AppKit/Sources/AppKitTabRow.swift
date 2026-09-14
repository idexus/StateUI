// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// The tabs a window shows beneath its toolbar for the tabbed view it serves.
@MainActor
struct AppKitWindowTabs {
    let titles: [String]
    let images: [NSImage?]
    let selected: Int
    let select: (Int) -> Void

    /// Whether two show the same tabs. The selection is written on the
    /// standing control.
    func draws(like other: AppKitWindowTabs) -> Bool {
        titles == other.titles
            && images.count == other.images.count
            && zip(images, other.images).allSatisfy { $0 === $1 }
    }
}

/// Where a window's tabs stand, and what they are.
@MainActor
struct AppKitTabsPlacement {
    let tabs: AppKitWindowTabs

    /// The split view whose detail the tabbed view stands in, if any. On a
    /// system that has column accessories the tabs stand across that column;
    /// otherwise beneath the title bar.
    weak var split: AppKitSplitView?
}

/// A window's tabs as a Mac draws them beneath its toolbar: one row - on
/// macOS 26 and later across the split view detail the tabbed view stands in,
/// as that column's own accessory; otherwise the title bar's bottom
/// accessory, which AppKit lays beside a full-height sidebar. A native
/// select-one segmented control whose tabs share the width equally, each
/// tab's glyph beside its title and the chosen tab a pill.
@MainActor
final class AppKitTabRow: NSView {
    /// How tall a tab's glyph stands beside a label in the system font.
    static let glyphHeight = (NSFont.systemFontSize * 1.25).rounded()

    /// The room between the control and the row's edges.
    private static let inset = NSEdgeInsets(top: 4, left: 8, bottom: 8, right: 8)

    private let control = NSSegmentedControl()
    private var tabs: AppKitWindowTabs?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        control.trackingMode = .selectOne
        control.segmentDistribution = .fillEqually
        control.target = self
        control.action = #selector(chose(_:))
        addSubview(control)
        frame.size.height = rowHeight
        autoresizingMask = [.width]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitTabRow is created in code")
    }

    /// Shows exactly these tabs. The segments are written when they draw
    /// differently; the selection is written on the standing control.
    func apply(_ next: AppKitWindowTabs) {
        let drawsAlike = tabs.map { next.draws(like: $0) } ?? false
        tabs = next

        if !drawsAlike {
            control.segmentCount = next.titles.count
            for index in next.titles.indices {
                control.setLabel(next.titles[index], forSegment: index)
                control.setImage(next.images[index].map(Self.glyph), forSegment: index)
            }
        }

        control.selectedSegment = next.selected
        needsLayout = true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: rowHeight)
    }

    override func layout() {
        super.layout()
        control.frame = NSRect(
            x: Self.inset.left,
            y: Self.inset.bottom,
            width: max(0, bounds.width - Self.inset.left - Self.inset.right),
            height: control.fittingSize.height)
    }

    private var rowHeight: CGFloat {
        Self.inset.top + control.fittingSize.height + Self.inset.bottom
    }

    /// A tab's picture as a glyph: a template the system tints with the
    /// control's state, at a glyph's height. The tab's own picture is left as
    /// it is.
    private static func glyph(_ image: NSImage) -> NSImage {
        guard let copy = image.copy() as? NSImage else { return image }
        copy.isTemplate = true
        if image.size.height > 0 {
            copy.size = NSSize(
                width: image.size.width * glyphHeight / image.size.height,
                height: glyphHeight)
        }
        return copy
    }

    /// The reader chose a tab.
    @objc private func chose(_ sender: NSSegmentedControl) {
        tabs?.select(sender.selectedSegment)
    }

    var controlForTesting: NSSegmentedControl { control }

    func chooseForTesting(_ index: Int) {
        control.selectedSegment = index
        chose(control)
    }
}
#endif

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One split view's sidebar sliding in and out on the runtime's frames, the same on every host that slides it itself:
/// a slide sets out once, stands the sidebar's column each frame as far as it has come - its page at the whole width,
/// the detail beside it taking every width between - and rests shown or folded away; toggled amid its slide, it turns
/// back from where it stands. What the tree says of the sidebar while it slides is the slide's own.
/// Design: docs/design/host/motion.md#a-sidebar-sliding
@_spi(Host) @MainActor public final class SplitSlide {
    private let slide: SidebarSlide
    private let mount: UInt64

    /// The toolkit's own motion where it slides the sidebar itself and the split follows it; nil for the runtime's.
    private let toolkit: Motion?

    /// The column's whole width: as it last stood beside the detail.
    public private(set) var width: Double

    /// Where the sidebar is going while it slides; nil while it stands.
    public private(set) var target: Bool?

    /// What the host does as a slide sets out from rest, the sidebar going in where `shows`.
    public var begin: (_ shows: Bool) -> Void = { _ in }

    /// What the host does each frame: stands the column `pane` wide and the sidebar's page `page` wide, its trailing
    /// edge at the column's.
    public var stand: (_ pane: Double, _ page: Double) -> Void = { _, _ in }

    /// What the host does as the slide rests: the sidebar shown at its whole width, or folded away.
    public var rest: (_ shown: Bool) -> Void = { _ in }

    /// A split's slide on the runtime's `slide`, the split mounted as `mount`, its column `width` wide - `following`
    /// the toolkit's motion where the toolkit slides the sidebar itself.
    public init(slide: SidebarSlide, mount: UInt64, width: Double, following toolkit: Motion? = nil) {
        self.slide = slide
        self.mount = mount
        self.width = width
        self.toolkit = toolkit
    }

    /// Where a toggle sends the sidebar, `shown` as it stands at rest: the other way from where a slide goes.
    public func toggled(shown: Bool) -> Bool {
        !(target ?? shown)
    }

    /// Whether `shown` is where the slide goes: the tree saying so is the slide's own.
    public func carries(_ shown: Bool) -> Bool {
        target == shown
    }

    /// Notes that the column stood `width` wide - unless it slides, passing through every width.
    public func columnStood(_ width: Double) {
        if target == nil, width > 0 { self.width = width }
    }

    /// Slides the sidebar in where `shown`, else out, from where it stands.
    public func slide(to shown: Bool) {
        if target == nil { begin(shown) }
        target = shown
        let width = width
        slide.slide(mount, from: shown ? 0 : 1, shown: shown, following: toolkit) { [weak self] progress, rested in
            guard let self else { return }
            stand(SidebarSlide.paneWidth(progress, of: width), width)
            guard rested else { return }
            target = nil
            rest(shown)
        }
    }

    /// Ends a slide where it stands, as the split leaves the tree.
    public func forget() {
        slide.forget(mount)
        target = nil
    }
}

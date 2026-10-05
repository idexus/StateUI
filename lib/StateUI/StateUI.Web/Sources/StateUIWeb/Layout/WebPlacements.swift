// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Where the children of the page's travelling layouts stand, for the host layer's layout motion: read once before
/// the first change a call from the page makes, and again, for each layout arranged, once the call's changes are
/// all in - then each view drawn where its place stands on the way.
/// Design: docs/design/platforms/web/layout.md#places-that-travel
@MainActor
final class WebPlacements {
    private struct Followed {
        weak var layout: WebLayoutView?
    }

    /// The layouts whose children travel, held weakly.
    private var followed: [ObjectIdentifier: Followed] = [:]

    /// Whether the places as they stood before this call's changes are read.
    private var readBefore = false

    /// The layouts arranged in this call, in their order, and the views whose places moved.
    private var arranged: [WebLayoutView] = []
    private var moved: [ObjectIdentifier: WebDOMView] = [:]

    /// Follows `layout`'s children from now on.
    func follow(_ layout: WebLayoutView) {
        followed[ObjectIdentifier(layout)] = Followed(layout: layout)
    }

    /// Reads where every standing child stands, before the first change of this call moves any.
    func beforeChange() {
        guard !readBefore else { return }
        readBefore = true
        followed = followed.filter { $0.value.layout?.isReleased == false }
        let standing = followed.values.compactMap(\.layout).flatMap { layout in
            layout.children.filter { $0.travelling == nil && !$0.isReleased }.map { (layout, $0) }
        }
        let read = WebRelay.places(standing.map { ($0.0.node, $0.1.node) })
        for ((_, child), place) in zip(standing, read) { child.slot = place }
    }

    /// `layout` arranged its children in this call.
    func arrange(_ layout: WebLayoutView) {
        if !arranged.contains(where: { $0 === layout }) { arranged.append(layout) }
    }

    /// `view`'s place moved: it is drawn there once the call is over.
    func moved(_ view: WebDOMView) {
        moved[ObjectIdentifier(view)] = view
    }

    /// The call is over: each layout arranged places its children where the browser laid them out, travelling there
    /// from where they stood, and every view whose place moved is drawn where it stands.
    func settle() {
        defer { readBefore = false }
        let layouts = arranged.filter { !$0.isReleased }
        arranged = []
        if !layouts.isEmpty { place(layouts) }
        for view in moved.values where !view.isReleased { view.writePlace() }
        moved = [:]
    }

    private func place(_ layouts: [WebLayoutView]) {
        var pairs: [(layout: Int32, child: Int32)] = []
        for layout in layouts {
            pairs.append((layout.node, layout.node))
            for child in layout.children {
                // Where a standing child stood is where its place sets out from.
                if child.travelling == nil { child.travelling = child.slot }
                child.clearSizeOverride()
                pairs.append((layout.node, child.node))
            }
        }
        var read = WebRelay.places(pairs)[...]
        for layout in layouts {
            let room = read.removeFirst()
            layout.places.begin(width: room?.width ?? 0)
            for (index, child) in layout.children.enumerated() {
                child.slot = read.removeFirst()
                moved[ObjectIdentifier(child)] = child
                guard let slot = child.slot else {
                    child.travelling = nil
                    continue
                }
                layout.place(child, at: index, slot: slot)
            }
        }
    }
}

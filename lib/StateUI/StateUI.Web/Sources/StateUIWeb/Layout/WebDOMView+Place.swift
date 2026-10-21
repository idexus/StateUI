// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A view in a layout whose children travel: it stands where the browser lays it out - its slot - or is drawn where
/// its place stands on the way there, the room it takes in its layout the slot's all the while.
/// Design: docs/design/platforms/web/layout.md#places-that-travel
extension WebDOMView: PlacedView {
    var placedFrame: Rect {
        get { traveling ?? slot ?? Rect(x: 0, y: 0, width: 0, height: 0) }
        set {
            let drawn: Rect? = newValue == slot ? nil : newValue
            guard drawn != traveling else { return }
            traveling = drawn
            placingLayout?.placing?.moved(self)
        }
    }

    /// Draws the view where its place stands: moved from its slot, and - but for a view laying out words, which
    /// keeps the size it is bound for - at the size the place passes through.
    func writePlace() {
        guard let traveling, let slot else {
            clearSizeOverride()
            travelOffset = nil
            return writeTransform()
        }
        let sized = !(self is WebWordsView) && (traveling.width != slot.width || traveling.height != slot.height)
        if sized {
            override(width: traveling.width, height: traveling.height, slot: slot)
        } else {
            clearSizeOverride()
        }
        let width = sized ? traveling.width : slot.width
        let fromEnd = isRightToLeft && styled("position") != "absolute"
        travelOffset = (traveling.x - (fromEnd ? slot.x + slot.width - width : slot.x), traveling.y - slot.y)
        writeTransform(size: sized ? LayoutSize(width: traveling.width, height: traveling.height) : nil)
    }

    /// Gives the view its own CSS back where a traveling place wrote over it.
    func clearSizeOverride() {
        for name in overridden { WebRelay.setStyle(node, name, styled(name)) }
        overridden = []
    }

    /// The size the place passes through, its end margins making up the rest of the slot.
    private func override(width: Double, height: Double, slot: Rect) {
        let n: (Double) -> String = WebCSS.signedPixels
        let written = [
            ("width", n(width)), ("height", n(height)), ("min-width", "0"), ("min-height", "0"),
            ("max-width", "none"), ("max-height", "none"),
            ("margin-inline-end", "calc(\(styled("margin-inline-end") ?? "0px") + \(n(slot.width - width)))"),
            ("margin-block-end", "calc(\(styled("margin-block-end") ?? "0px") + \(n(slot.height - height)))"),
        ]
        for (name, value) in written {
            overridden.insert(name)
            WebRelay.setStyle(node, name, value)
        }
    }
}

extension WebDOMView: FadingView {}

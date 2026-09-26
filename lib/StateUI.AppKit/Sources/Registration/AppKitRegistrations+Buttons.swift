// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// The control a user presses: a caption, an icon beside it, and the
    /// three moments of a press.
    ///
    /// The icon is a file NAME, resolved through the picture the host gave the
    /// view, exactly as an `Image`'s is. What is NOT here is the room the
    /// caption is given: a button's padding becomes a size constraint over the
    /// native cell's own measurement, which is the host's arithmetic and not a
    /// value written onto a control.
    static func buttons(_ registry: Registry<NSView>) {
        registry.add(ButtonContract.self, create: { reports in
            let button = AppKitButtonView()
            button.onClicked = { reports.raise(ButtonContract.clicked) }
            button.onPressed = { reports.raise(ButtonContract.pressed) }
            button.onReleased = { reports.raise(ButtonContract.released) }
            return button
        }, members: { button in
            button.applies([
                TextElementContract.text, ButtonContract.icon, ButtonContract.iconPosition,
                ImageElementContract.aspect, ButtonContract.lineBreak,
                TextStyleElementContract.textColor, VisualElementContract.background,
                BorderElementContract.shape, BorderElementContract.stroke,
                BorderElementContract.strokeWidth, VisualElementContract.isEnabled,
                FontElementContract.fontFamily, FontElementContract.fontSize,
                FontElementContract.fontAttributes,
            ]) { view, values in
                // Each value is read into a name of its own: twelve arguments
                // of `flatMap` and `??` in one call is more than the type
                // checker will take.
                let caption: String = values[TextElementContract.text] ?? ""
                let icon: NSImage? = values[ButtonContract.icon]
                    .flatMap { $0.isEmpty ? nil : view.picture?($0.file) }
                let position: NSControl.ImagePosition = caption.isEmpty
                    ? .imageOnly
                    : Self.imagePosition(values[ButtonContract.iconPosition] ?? .leading)
                let scaling: NSImageScaling = Self.imageScaling(
                    values[ImageElementContract.aspect] ?? .fit)
                let textColor: NSColor = values[TextStyleElementContract.textColor]
                    .flatMap { nsColor($0.propValue) } ?? .controlTextColor
                let background: NSColor? = values[VisualElementContract.background]
                    .flatMap { nsColor($0.propValue) }
                let strokeColor: NSColor? = if case .solid(let colour)? = AppKitBrush(
                    values[BorderElementContract.stroke]?.propValue)?.kind { colour } else { nil }
                let breaking: NSLineBreakMode = Self.lineBreakMode(
                    values[ButtonContract.lineBreak] ?? .wordWrap)

                view.apply(
                    text: caption,
                    image: icon,
                    imagePosition: position,
                    imageScaling: scaling,
                    font: Self.font(values),
                    textColor: textColor,
                    backgroundColor: background,
                    strokeColor: strokeColor,
                    strokeWidth: values[BorderElementContract.strokeWidth] ?? 1,
                    shape: AppKitDecoration.Shape(values[BorderElementContract.shape]?.propValue),
                    lineBreakMode: breaking,
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            button.raises(ButtonContract.clicked)
            button.raises(ButtonContract.pressed)
            button.raises(ButtonContract.released)
        })
    }

    /// Where an icon sits beside its caption.
    private static func imagePosition(_ position: IconPosition) -> NSControl.ImagePosition {
        switch position {
        case .top: .imageAbove
        case .trailing: .imageTrailing
        case .bottom: .imageBelow
        case .leading: .imageLeading
        }
    }

    /// How an icon fills the room it is given.
    ///
    /// `.fit` and `.fill` come out the same: a native button has no covering
    /// scale, which is what this host's declaration says about `aspect` on a
    /// button.
    private static func imageScaling(_ aspect: Aspect) -> NSImageScaling {
        switch aspect {
        case .stretch: .scaleAxesIndependently
        case .center: .scaleNone
        case .fit, .fill: .scaleProportionallyUpOrDown
        }
    }

    /// How a caption too long for its room is broken.
    private static func lineBreakMode(_ mode: LineBreak) -> NSLineBreakMode {
        switch mode {
        case .noWrap: .byClipping
        case .wordWrap: .byWordWrapping
        case .characterWrap: .byCharWrapping
        case .headTruncation: .byTruncatingHead
        case .tailTruncation: .byTruncatingTail
        case .middleTruncation: .byTruncatingMiddle
        }
    }
}

#endif

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
                TextualElementContract.text, TextualElementContract.textCase, ButtonContract.icon,
                ButtonContract.iconPosition,
                ImageElementContract.contentMode, ButtonContract.lineBreak,
                TextStyleElementContract.textColor, VisualElementContract.background,
                BorderElementContract.shape, BorderElementContract.stroke,
                BorderElementContract.lineWidth, VisualElementContract.isEnabled,
                FontElementContract.fontFamily, FontElementContract.fontSize,
                FontElementContract.fontAttributes,
            ]) { view, values in
                // Each value is read into a name of its own: twelve arguments
                // of `flatMap` and `??` in one call is more than the type
                // checker will take.
                let caption = (values[TextualElementContract.textCase] ?? .none)
                    .applied(to: values[TextualElementContract.text] ?? "")
                let icon: NSImage? = values[ButtonContract.icon]
                    .flatMap { $0.isEmpty ? nil : view.picture?($0.file) }
                let position: NSControl.ImagePosition = caption.isEmpty
                    ? .imageOnly
                    : Self.imagePosition(values[ButtonContract.iconPosition] ?? .leading)
                let scaling: NSImageScaling = Self.imageScaling(
                    values[ImageElementContract.contentMode] ?? .fit)
                let textColor: NSColor = values[TextStyleElementContract.textColor]
                    .flatMap { nsColor($0.propValue) } ?? .controlTextColor
                let background: NSColor? = values[VisualElementContract.background]
                    .flatMap { nsColor($0.propValue) }
                let stroke = values[BorderElementContract.stroke]?.propValue
                let lineWidth = BoxArithmetic.outlineWidth(
                    stroke: stroke, width: values[BorderElementContract.lineWidth])
                let strokeColor = lineWidth > 0 ? AppKitBrush(stroke).lineColor : nil
                let breaking = NSLineBreakMode(values[ButtonContract.lineBreak] ?? .wordWrap)

                view.apply(
                    text: caption,
                    image: icon,
                    imagePosition: position,
                    imageScaling: scaling,
                    font: Self.font(values),
                    textColor: textColor,
                    backgroundColor: background,
                    strokeColor: strokeColor,
                    lineWidth: lineWidth,
                    shape: BoxArithmetic.outline(values[BorderElementContract.shape]?.propValue),
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
    /// scale, which is what this host's declaration says about `contentMode`
    /// on a button.
    private static func imageScaling(_ aspect: ContentMode) -> NSImageScaling {
        switch aspect {
        case .stretch: .scaleAxesIndependently
        case .center: .scaleNone
        case .fit, .fill: .scaleProportionallyUpOrDown
        }
    }
}

#endif

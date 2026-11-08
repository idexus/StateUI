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
            // A button holding a menu is made as it opens it from the first; another opening is made again.
            let button = AppKitButtonView(
                menu: ButtonMenu.opening(made: reports.made), showsArrow: ButtonMenu.showsArrow(made: reports.made))
            button.onClicked = { reports.raise(ClickElementContract.clicked) }
            button.onPressed = { reports.raise(PressElementContract.pressed) }
            button.onReleased = { reports.raise(PressElementContract.released) }
            return button
        }, members: { button in
            button.applies(
                TextElementContract.text, TextualElementContract.textCase, IconElementContract.icon,
                ButtonContract.iconPosition, ContentModeElementContract.contentMode, LineBreakElementContract.lineBreak,
                TextColorElementContract.textColor, BackgroundElementContract.background, BorderElementContract.shape,
                BorderElementContract.stroke, BorderElementContract.lineWidth, EnabledElementContract.isEnabled,
                FontElementContract.fontFamily, FontElementContract.fontSize, FontElementContract.fontAttributes,
                FontElementContract.fontWeight, FontElementContract.textStyle, TrackingElementContract.tracking,
                ButtonContract.role, TextAndIconElementContract.showsText) { view, values in
                // Each value is read into a name of its own: twelve arguments
                // of `flatMap` and `??` in one call is more than the type
                // checker will take.
                let caption = (values[TextualElementContract.textCase] ?? .none)
                    .applied(to: values[TextElementContract.text] ?? "")
                let source = values[IconElementContract.icon].flatMap { HostPicture($0.propValue) }
                let icon: NSImage? = source.flatMap { view.picture?($0) }
                // Words left out of sight stay the title, which names the button to assistive technology.
                let alone = caption.isEmpty || !TextAndIcon.showsText(
                    values[TextAndIconElementContract.showsText], hasPicture: icon != nil, byDefault: true)
                let position: NSControl.ImagePosition = alone
                    ? .imageOnly
                    : Self.imagePosition(values[ButtonContract.iconPosition] ?? .start)
                // Beside words a picture stands at its own size, smaller where the button is; so does an icon alone.
                let scaling: NSImageScaling = if alone, case .icon? = source {
                    .scaleProportionallyDown
                } else if alone {
                    Self.imageScaling(values[ContentModeElementContract.contentMode] ?? .fit)
                } else {
                    .scaleProportionallyDown
                }
                let background = paintedColor(values[BackgroundElementContract.background]?.propValue)
                // A destructive action's words in the system's red where the tree colors them not.
                let look = ButtonRoleLook(
                    values[ButtonContract.role], fills: background != nil,
                    colorsWords: values[TextColorElementContract.textColor] != nil)
                let textColor: NSColor = values[TextColorElementContract.textColor]
                    .flatMap { nsColor($0.propValue) } ?? (look.wordsInCritical ? .systemRed : .controlTextColor)
                let stroke = values[BorderElementContract.stroke]?.propValue
                let lineWidth = BoxArithmetic.outlineWidth(
                    stroke: stroke, width: values[BorderElementContract.lineWidth])
                let strokeColor = lineWidth > 0 ? AppKitBrush(stroke).lineColor : nil
                let breaking = NSLineBreakMode(values[LineBreakElementContract.lineBreak] ?? .wordWrap)

                view.apply(
                    text: caption,
                    image: icon,
                    imagePosition: position,
                    imageScaling: scaling,
                    font: Self.font(values),
                    textColor: textColor,
                    tracking: values[TrackingElementContract.tracking] ?? 0,
                    backgroundColor: background,
                    strokeColor: strokeColor,
                    lineWidth: lineWidth,
                    shape: BoxArithmetic.outline(values[BorderElementContract.shape]?.propValue),
                    lineBreakMode: breaking,
                    enabled: values[EnabledElementContract.isEnabled] ?? true)
            }
            // AppKit's own key equivalent - the one stated, else the role's - pressing the button while its window is
            // in front, and the role's marks: the accent for the main action, AppKit's mark for a destructive one.
            button.applies(ShortcutElementContract.keyboardShortcut, ButtonContract.role) { control, values in
                let role = values[ButtonContract.role]
                let shortcut = KeyboardShortcuts.pressing(stated: values[ShortcutElementContract.keyboardShortcut], role: role)
                control.applyKeys(shortcut, role: role)
            }
            button.declares(ClickElementContract.clicked)
            button.declares(PressElementContract.pressed)
            button.declares(PressElementContract.released)
        })
    }

    /// Where an icon sits beside its caption.
    private static func imagePosition(_ position: IconPosition) -> NSControl.ImagePosition {
        switch position {
        case .top: .imageAbove
        case .end: .imageTrailing
        case .bottom: .imageBelow
        case .start: .imageLeading
        }
    }

    /// How an icon standing alone fills the room it is given.
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

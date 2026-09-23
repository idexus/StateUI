// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// The contracts this host realizes through the core's registry: how each
/// element's view is made, which of its members the view takes, and what it
/// reports. Families move here from `AppKitElement`'s switch one at a time; an
/// element no registration answers is still made there.
@MainActor
enum AppKitRegistrations {
    /// The registry, built once.
    static let registry: Registry<NSView> = {
        let registry = Registry<NSView>()

        indicators(registry)
        toggles(registry)
        values(registry)
        pickers(registry)
        fields(registry)
        shapes(registry)
        buttons(registry)
        pictures(registry)
        drawing(registry)
        layouts(registry)
        presentation(registry)
        shared(registry)

        return registry
    }()

    /// The acts this host performs, whichever element each is aimed at.
    ///
    /// A registry takes properties and events, never acts: an act names the
    /// view it is aimed at and the session performs it against that identity,
    /// so nothing about the call belongs to one registration. They are said
    /// here, beside the registry, and read where this host's export is
    /// written. `AppKitActPerformer` answers exactly these; every other act
    /// it refuses by name.
    static let acts: [any ContractMember] = [
        VisualElementContract.focus, VisualElementContract.unfocus,
        ApplicationContract.hideOnScreenKeyboard,
        ApplicationContract.persistValue, ApplicationContract.persistSceneValue,
    ]

    /// The members the shared machinery takes on every element wearing the
    /// contract declaring each - the same members `shared(_:)` registers, as a
    /// list something can READ.
    ///
    /// Two readers, one source: the registry takes them typed, one call each,
    /// because it infers the owner from the member; the export takes their
    /// names. `AppKitRegistrationTests` holds the two halves equal, so a
    /// member added to one and not the other fails rather than drifts.
    static let sharedMembers: [any ContractMember] = [
        PropertyContainerContract.accessibilityIdentifier, TintElementContract.tint,

        VisualElementContract.accessibilityHeadingLevel, VisualElementContract.accessibilityHint,
        VisualElementContract.accessibilityLabel,
        VisualElementContract.automationExcludedWithChildren, VisualElementContract.frame,
        VisualElementContract.height, VisualElementContract.ignoresInput,
        VisualElementContract.isAccessibilityHidden, VisualElementContract.isVisible,
        VisualElementContract.maximumHeight, VisualElementContract.maximumWidth,
        VisualElementContract.minimumHeight, VisualElementContract.minimumWidth,
        VisualElementContract.opacity, VisualElementContract.pivotX,
        VisualElementContract.pivotY, VisualElementContract.rotation,
        VisualElementContract.rotationX, VisualElementContract.rotationY,
        VisualElementContract.scale, VisualElementContract.scaleX,
        VisualElementContract.scaleY, VisualElementContract.translationX,
        VisualElementContract.translationY, VisualElementContract.width,

        ViewContract.absoluteLayoutBounds, ViewContract.absoluteLayoutProportions,
        ViewContract.gridColumn, ViewContract.gridColumnSpan, ViewContract.gridRow,
        ViewContract.gridRowSpan, ViewContract.horizontalAlignment, ViewContract.margin,
        ViewContract.verticalAlignment, ViewContract.panXChannel, ViewContract.panYChannel,
        ViewContract.swipeDirection, ViewContract.swipeThreshold, ViewContract.tapCount,

        LayoutContract.letsInputThrough,
    ]

    /// The events the shared machinery raises on every element wearing the
    /// contract declaring each - the reading half of `shared(_:)`.
    static let sharedEvents: [any ContractMember] = [
        ViewContract.frameChanged, ViewContract.panUpdated, ViewContract.pinchUpdated,
        ViewContract.pointerEntered, ViewContract.pointerExited, ViewContract.pointerMoved,
        ViewContract.pointerPressed, ViewContract.pointerReleased, ViewContract.swiped,
        ViewContract.tapped, VisualElementContract.isFocusedChanged,
    ]

    static func edgeInsets(_ value: Insets?) -> NSEdgeInsets {
        guard let numbers = value?.propValue.numbers, numbers.count >= 4 else { return NSEdgeInsets() }

        return NSEdgeInsets(
            top: numbers[1], left: numbers[0], bottom: numbers[3], right: numbers[2])
    }

    /// The six components a render transform travels as - a LIST OF VALUES, not
    /// a list of numbers - or none where it is not six numbers.
    static func transform<Realized: ElementContract>(
        _ values: ElementValues<Realized>
    ) -> [Double]? {
        guard let components = values[ShapeContract.renderTransform]?.propValue.values,
              components.count == 6
        else { return nil }

        let numbers = components.compactMap(\.number)
        return numbers.count == components.count ? numbers : nil
    }

    /// The words to put on a field: NONE where the host carries the text in,
    /// since the control is the source there and the tree describes it only to
    /// read back - and otherwise what the tree says, which is empty where the
    /// tree took the words away, so clearing a field clears the control.
    static func words<Realized: ElementContract>(_ values: ElementValues<Realized>) -> String? {
        values.carriedIn(TextElementContract.text) ? nil : (values[TextElementContract.text] ?? "")
    }

    /// The font a field draws in, composed from the members it wears.
    static func font<Realized: ElementContract>(_ values: ElementValues<Realized>) -> NSFont {
        appKitFont(
            family: values[FontElementContract.fontFamily]?.text,
            size: values[FontElementContract.fontSize],
            attributes: values[FontElementContract.fontAttributes]?.rawValue,
            fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize))
    }
}

#endif

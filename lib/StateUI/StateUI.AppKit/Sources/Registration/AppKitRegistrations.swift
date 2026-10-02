// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

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
        items(registry)
        maps(registry)
        web(registry)
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

    /// The elements whose registration draws their background itself - a field, a button, a colour box - under
    /// which no layer paints another: a search field's rounded field takes no fill colour, and a square painted
    /// under it hid its shape.
    /// Design: docs/design/platforms/appkit/registrations.md#a-background
    static let drawOwnBackground: Set<NodeType> = Set(registry.realization.members
        .filter { $0.owner == VisualElementContract.name && $0.member == VisualElementContract.background.name }
        .map { NodeType($0.element) })

    /// The acts this host performs, whichever element each is aimed at: every host's (`HostActs.performed`), the
    /// scene's kept values, which a Mac keeps in the window it restores, and its own elements' acts. The host layer's performer
    /// (`HostActPerformer`) answers exactly these and the application's own; every other act it refuses by name.
    static let acts: [any ContractMember] =
        HostActs.performed + [ApplicationContract.persistSceneValue, ItemsViewContract.scrollTo, MapContract.moveToRegion]
        + webActs

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
        guard let components = values[ShapeContract.geometryTransform]?.propValue.values,
              components.count == 6
        else { return nil }

        let numbers = components.compactMap(\.number)
        return numbers.count == components.count ? numbers : nil
    }

    /// The words to put on a field: nil where the host carries the text in,
    /// since the control is the source there and the tree describes it only to
    /// read back - and otherwise what the tree says in its case, which is empty
    /// where the tree took the words away, so clearing a field clears the
    /// control.
    static func words<Realized: ElementContract>(_ values: ElementValues<Realized>) -> String? {
        guard !values.carriedIn(TextualElementContract.text) else { return nil }
        return (values[TextualElementContract.textCase] ?? .none).applied(to: values[TextualElementContract.text] ?? "")
    }

    /// The font a field draws in, composed from the members it wears.
    static func font<Realized: ElementContract>(_ values: ElementValues<Realized>) -> NSFont {
        appKitFont(
            family: values[FontElementContract.fontFamily]?.text,
            size: values[FontElementContract.fontSize],
            attributes: values[FontElementContract.fontAttributes],
            fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize))
    }
}

#endif

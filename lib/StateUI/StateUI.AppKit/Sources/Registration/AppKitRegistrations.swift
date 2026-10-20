// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIApple

/// The contracts this host realizes through the core's registry: how each
/// element's view is made, which of its members the view takes, and what it
/// reports. An element no registration answers is made by
/// `AppKitElement.makeView`.
@MainActor
enum AppKitRegistrations {
    /// The registry, built once.
    static let registry: Registry<NSView> = {
        let registry = Registry<NSView>()

        indicators(registry)
        items(registry)
        MapKitView.register(in: registry) { AppKitMapView() }
        WebKitView.register(in: registry)
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

    /// The elements whose registration draws their background itself - a field, a button - under
    /// which no layer paints another: a search field's rounded field takes no fill colour, and a square painted
    /// under it would hide its shape.
    /// Design: docs/design/platforms/appkit/registrations.md#a-background
    static let drawOwnBackground: Set<NodeType> = Set(registry.realization.members
        .filter { $0.owner == VisualElementContract.background.owner
            && $0.member == VisualElementContract.background.token.key }
        .map(\.element))

    /// The acts this host performs, whichever element each is aimed at: every host's (`HostActs.performed`), the files
    /// (`HostActs.files`) and its own elements' acts. The host layer's performer
    /// (`HostActPerformer`) answers exactly these and the application's own; every other act it refuses by name.
    static let acts: [any ContractMember] =
        HostActs.performed + HostActs.files + [ItemsViewContract.scrollTo, MapContract.moveToRegion]
        + WebKitView.acts

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
        appKitFont(TextMembers.look(of: values), fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize))
    }
}

#endif

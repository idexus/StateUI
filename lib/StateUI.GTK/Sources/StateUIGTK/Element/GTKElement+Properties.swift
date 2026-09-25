// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The widget: made, and given the element's properties.
extension GTKElement {
    /// Properties a parent reads into its child's layout item: a change arranges the parent again.
    static let arrangedProperties: Set<Prop> = [
        .margin, .horizontalAlignment, .verticalAlignment,
        .width, .height,
        .minimumWidth, .minimumHeight,
        .maximumWidth, .maximumHeight,
        .isVisible,
        .gridRow, .gridColumn, .gridRowSpan, .gridColumnSpan,
        .area,
    ]

    /// Properties drawn without changing any measurement; any other one measures the element again.
    static let unmeasuredProperties: Set<Prop> = [
        .opacity, .background, .textColor, .isEnabled,
    ]

    /// The arrangements of pages a window shows.
    static let pageTypes: Set<NodeType> = [.page, .navigationStack, .tabbedView, .splitView]

    func makeView() -> GTKView? {
        if let registered = GTKRegistrations.registry.makeView(
            for: type,
            sending: { [weak self] event, values in self?.send(event, values) },
            reporting: { [weak self] property, event, value in self?.report(property, event, value) }
        ) {
            return registered
        }

        switch type {
        case .application, .scene, .window:
            return nil

        case .page, .overlay:
            return GTKSingleChildView()

        case .modalStack, .titleBar, .content, .leadingContent, .trailingContent,
             .titleView, .toolbarItems, .toolbarItem, .menuBar, .contextMenu,
             .menu, .menuItem, .menuSeparator, .spans, .span:
            return nil

        default:
            return GTKUnsupportedView(type)
        }
    }

    /// Puts the changed properties on the widget as the program's write: its registration's first, then what
    /// every element takes.
    /// Design: docs/design/host/patches.md#program-write
    func applyProperties(changed: Set<Prop>) {
        guard let view else {
            if !changed.isDisjoint(with: Self.arrangedProperties) { parent?.invalidateMeasurements() }
            return
        }

        ProgramWrite.perform {
            let taken = GTKRegistrations.registry.apply(
                changed, to: view, of: type,
                reading: { [element] in element.value($0) },
                carriedIn: { [element] in element.driven[$0]?.mode == .in })

            for property in changed.subtracting(taken) {
                switch property {
                case .opacity: view.setOpacity(value(.opacity)?.number ?? 1)
                case .isVisible: view.setShown(isShown)
                case .padding where type == .page:
                    let sides = value(.padding)?.numbers ?? []
                    (view as? GTKSingleChildView)?.padding =
                        sides.count >= 4 ? Insets(sides[0], sides[1], sides[2], sides[3]) : Insets(0)
                default: break
                }
            }
        }

        if !changed.isSubset(of: Self.unmeasuredProperties) { invalidateMeasurements() }
    }

    /// Forgets the sizes kept by this element's layout and every one above it, and asks GTK to measure again.
    func invalidateMeasurements() {
        var element: GTKElement? = self
        while let each = element {
            (each.view as? GTKLayoutView)?.forgetMeasurements()
            element = each.parent
        }

        (view ?? parent?.nearestView)?.invalidateMeasure()
    }

    /// The view of this element or the nearest one above it.
    var nearestView: GTKView? {
        view ?? parent?.nearestView
    }
}

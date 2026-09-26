// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The contracts this host realizes through the core's registry: how each
/// element's view is made, which of its members the view takes, and what it reports.
@MainActor
enum WinUIRegistrations {
    /// The registry, built once.
    static let registry: Registry<WinUIView> = {
        let registry = Registry<WinUIView>()

        text(registry)
        buttons(registry)
        toggles(registry)
        values(registry)
        indicators(registry)
        pickers(registry)
        dates(registry)
        fields(registry)
        pictures(registry)
        shapes(registry)
        drawing(registry)
        layouts(registry)
        shared(registry)

        return registry
    }()

    /// What `WinUIElement` puts on every view wearing each member's contract, and what the host layer's rules realize
    /// on every element WinUI shows. A view is drawn moved, turned and scaled flat: WinUI turns it about no other
    /// axis.
    static func shared(_ registry: Registry<WinUIView>) {
        registry.everyElementMeetsAssistiveTechnology(
            except: unmetByAssistiveTechnology, partsMetOn: partsMetWhenLeftOut)
        registry.everyElementRealizes(VisualElementContract.opacity)
        registry.everyElementRealizes(VisualElementContract.isVisible)
        registry.everyElementTakesItsPlace()
        registry.everyElementRealizes(VisualElementContract.translationX)
        registry.everyElementRealizes(VisualElementContract.translationY)
        registry.everyElementRealizes(VisualElementContract.rotation)
        registry.everyElementRealizes(VisualElementContract.scale)
        registry.everyElementRealizes(VisualElementContract.scaleX)
        registry.everyElementRealizes(VisualElementContract.scaleY)
        registry.everyElementRealizes(VisualElementContract.pivotX)
        registry.everyElementRealizes(VisualElementContract.pivotY)
        registry.everyElementHearsTheUser()
        registry.everyElementRaises(VisualElementContract.isFocusedChanged)
    }

    /// The elements assistive technology meets nothing of: WinUI gives a shape, a colour box and a canvas no
    /// automation peer, and a menu's or a toolbar's item carries no identifier.
    /// Design: docs/design/platforms/winui/controls.md#what-assistive-technology-meets
    static let unmetByAssistiveTechnology: Set<NodeType> = [
        .rectangle, .ellipse, .line, .path, .polygon, .polyline, .colorBox, .canvas, .menuItem, .toolbarItem,
    ]

    /// The controls whose parts WinUI's automation still offers when the control is left out with its children:
    /// the parts of their templates with peers of their own - a thumb, a field, a button, a ring's animation.
    /// Design: docs/design/platforms/winui/controls.md#what-assistive-technology-meets
    static let partsMetWhenLeftOut: Set<NodeType> = [
        .activityIndicator, .datePicker, .searchField, .slider, .stepper, .`switch`, .textEditor, .textField,
        .timePicker,
    ]
}

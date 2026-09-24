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
        fields(registry)
        layouts(registry)
        shared(registry)

        return registry
    }()

    /// What `WinUIElement` puts on every view wearing each member's contract, and what every layout reads of
    /// its children.
    static func shared(_ registry: Registry<WinUIView>) {
        registry.everyElementRealizes(VisualElementContract.opacity)
        registry.everyElementRealizes(VisualElementContract.isVisible)
        registry.everyElementRealizes(VisualElementContract.width)
        registry.everyElementRealizes(VisualElementContract.height)
        registry.everyElementRealizes(VisualElementContract.minimumWidth)
        registry.everyElementRealizes(VisualElementContract.minimumHeight)
        registry.everyElementRealizes(VisualElementContract.maximumWidth)
        registry.everyElementRealizes(VisualElementContract.maximumHeight)
        registry.everyElementRealizes(ViewContract.margin)
        registry.everyElementRealizes(ViewContract.horizontalAlignment)
        registry.everyElementRealizes(ViewContract.verticalAlignment)
        registry.everyElementRealizes(VisualElementContract.translationX)
        registry.everyElementRealizes(VisualElementContract.translationY)
        registry.everyElementRealizes(VisualElementContract.rotation)
        registry.everyElementRealizes(VisualElementContract.scale)
        registry.everyElementRealizes(VisualElementContract.scaleX)
        registry.everyElementRealizes(VisualElementContract.scaleY)
        registry.everyElementRealizes(VisualElementContract.pivotX)
        registry.everyElementRealizes(VisualElementContract.pivotY)
    }

    /// `text` in the case the tree asks for: as written, or in one case throughout.
    static func cased(_ text: String, _ textCase: TextCase?) -> String {
        switch textCase {
        case .lowercase: text.lowercased()
        case .uppercase: text.uppercased()
        default: text
        }
    }
}

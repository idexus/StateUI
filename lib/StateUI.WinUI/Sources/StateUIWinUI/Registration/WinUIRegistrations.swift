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
        pictures(registry)
        layouts(registry)
        shared(registry)

        return registry
    }()

    /// The acts `WinUIActPerformer` performs.
    static let acts: [any ContractMember] = [
        VisualElementContract.focus, VisualElementContract.unfocus,
        ApplicationContract.alert, ApplicationContract.announce, ApplicationContract.chooseAction,
        ApplicationContract.confirm, ApplicationContract.currentTime, ApplicationContract.currentTimeZone,
        ApplicationContract.handlerFailed, ApplicationContract.hideOnScreenKeyboard, ApplicationContract.persistValue,
        ApplicationContract.prompt, ApplicationContract.utcOffset,
    ]

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
        registry.everyElementRealizes(ViewContract.gridRow)
        registry.everyElementRealizes(ViewContract.gridColumn)
        registry.everyElementRealizes(ViewContract.gridRowSpan)
        registry.everyElementRealizes(ViewContract.gridColumnSpan)
        registry.everyElementRealizes(ViewContract.area)
        registry.everyElementRealizes(VisualElementContract.frame)
        registry.everyElementRaises(ViewContract.frameChanged)
        registry.everyElementRaises(ViewContract.tapped)
        registry.everyElementRealizes(ViewContract.tapCount)
        registry.everyElementRealizes(ViewContract.panXChannel)
        registry.everyElementRealizes(ViewContract.panYChannel)
        registry.everyElementRealizes(ViewContract.panTouchCount)
        registry.everyElementRealizes(ViewContract.swipeDirection)
        registry.everyElementRealizes(ViewContract.swipeThreshold)
        registry.everyElementRaises(ViewContract.panUpdated)
        registry.everyElementRaises(ViewContract.pinchUpdated)
        registry.everyElementRaises(ViewContract.swiped)
        registry.everyElementRaises(ViewContract.pointerEntered)
        registry.everyElementRaises(ViewContract.pointerExited)
        registry.everyElementRaises(ViewContract.pointerMoved)
        registry.everyElementRaises(ViewContract.pointerPressed)
        registry.everyElementRaises(ViewContract.pointerReleased)
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

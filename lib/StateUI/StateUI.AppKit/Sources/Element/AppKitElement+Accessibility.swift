// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What assistive technology meets.
extension AppKitElement {
    /// Applies StateUI's semantic surface without replacing the native
    /// control's ordinary role or participation when the author says nothing.
    func applyAccessibility(to view: NSView) {
        let target = accessibilityTarget(of: view)
        if accessibilityDefaults == nil {
            accessibilityDefaults = (
                isElement: target.isAccessibilityElement(),
                role: target.accessibilityRole())
        }
        guard let defaults = accessibilityDefaults else { return }

        target.setAccessibilityIdentifier(string(.accessibilityIdentifier))
        if let toggle = view as? AppKitSwitchView {
            toggle.authoredLabel = string(.accessibilityLabel)
        } else {
            target.setAccessibilityLabel(string(.accessibilityLabel))
        }
        target.setAccessibilityHelp(string(.accessibilityHint))
        // A value said stands over the control's own; unsaid again, the control's own comes back.
        let said = string(.accessibilityValue)
        if said != nil || accessibilityValueSaid { target.setAccessibilityValue(said) }
        accessibilityValueSaid = said != nil

        let excludesChildren = value(.hidesChildrenFromAccessibility)?.bool == true
        if excludesChildren {
            view.setAccessibilityChildren([])
            accessibilityChildrenSuppressed = true
        } else if accessibilityChildrenSuppressed {
            view.setAccessibilityChildren(nil)
            accessibilityChildrenSuppressed = false
        }

        // Met as the host layer says - by the author, or by words of its own or a tap - else as the view is.
        let words = element.accessibilityWords
        target.setAccessibilityElement(words.isElement(standing: defaults.isElement))
        // An element that answers a tap is a button to assistive technology,
        // pressed by the handler a click runs. See `AppKitHitTestView`.
        let pressable = events[.tapped] != nil && view is AppKitHitTestView

        if let role = words.role {
            target.setAccessibilityRole(Self.accessibilityRole(role))
        } else if words.headingLevel > 0 {
            target.setAccessibilityRole(NSAccessibility.Role(rawValue: "AXHeading"))
        } else if pressable {
            target.setAccessibilityRole(.button)
        } else {
            target.setAccessibilityRole(defaults.role)
        }
        applyReaderActions(words, to: target, of: view)
    }

    /// The actions VoiceOver offers on the view, and its steps of a view that says it is adjustable - each heard by
    /// the host layer's rule.
    /// Design: docs/design/platforms/appkit/views.md#accessibility-on-the-control
    private func applyReaderActions(_ words: AccessibilityWords, to target: NSAccessibilityProtocol, of view: NSView) {
        if !words.actions.isEmpty || accessibilityActionsSaid {
            target.setAccessibilityCustomActions(words.actions.isEmpty ? nil : words.actions.map { name in
                NSAccessibilityCustomAction(name: name) { [weak self] in self?.hear(.accessibilityAction(name)) ?? false }
            })
        }
        accessibilityActionsSaid = !words.actions.isEmpty
        (view as? AppKitHitTestView)?.stepAction = words.role == .adjustable
            ? { [weak self] step in self?.hear(.accessibilityAdjustment(step)) ?? false }
            : nil
    }

    /// AppKit's role for a kind the element says it is.
    static func accessibilityRole(_ role: AccessibilityRole) -> NSAccessibility.Role {
        switch role {
        case .button: .button
        case .toggle: .checkBox
        case .adjustable: .slider
        case .link: .link
        case .image: .image
        case .text: .staticText
        }
    }

    /// The object assistive technology meets for `view`: the native control a
    /// wrapping view presents in its place (`AppKitAccessibilityPresenting`),
    /// or the view itself - and for a control AppKit presents through its
    /// cell, a button, a slider or a stepper, that cell. The cell is the
    /// element there and the view is not, so words written on the view would
    /// reach nobody, and making the view the element would hide the control's
    /// own role. Whether it is the cell is decided once, before any authored
    /// word moves it; the control is looked up each time, because a wrapper
    /// may replace it - a text field becoming a password field.
    func accessibilityTarget(of view: NSView) -> NSAccessibilityProtocol {
        let control = (view as? AppKitAccessibilityPresenting)?.presentedControl ?? view
        let cell = (control as? NSControl)?.cell
        if accessibilityThroughCell == nil {
            accessibilityThroughCell = cell?.isAccessibilityElement() == true
        }
        if accessibilityThroughCell == true, let cell {
            return cell
        }
        return control
    }
}
#endif

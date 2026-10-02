// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
@_spi(Host) import StateUIConformance

/// What the AppKit driver reads of every view: its transform as its layer holds it, what assistive technology
/// meets, a control's font and words' colour, and the colour behind it - each from AppKit itself.
/// Design: docs/design/platforms/appkit/conformance.md#what-the-driver-reads
extension AppKitDriver {
    static func viewHolds(_ property: Prop, _ view: NSView, _ native: AppKitElement?) throws -> HostValue? {
        switch property {
        case .translationX, .translationY, .rotation, .rotationX, .rotationY, .scale, .scaleX, .scaleY, .pivotX,
             .pivotY:
            guard let drawn = native?.drawing?.heldTransformForTesting else {
                throw DriverCannot("read a transform: the view's layer holds another")
            }
            return transform(property, drawn)
        case .accessibilityLabel, .accessibilityHint, .accessibilityIdentifier, .isAccessibilityHidden,
             .automationExcludedWithChildren:
            guard let native else { return nil }
            return accessibility(property, native.accessibilityTarget(of: view), view)
        case .accessibilityHeading:
            throw DriverCannot("read a heading's level", because: "AppKit marks a heading, not its level")
        case .fontSize, .fontAttributes, .fontFamily, .textColor:
            return try words(property, view)
        case .background:
            // A field and an editor fill their own; every other view is its layer's colour.
            let fill: NSColor? = switch view {
            case let field as AppKitTextFieldView: field.textField.backgroundColor
            case let editor as AppKitTextEditorView: editor.textView.backgroundColor
            default: view.layer?.backgroundColor.flatMap { NSColor(cgColor: $0) }
            }
            return fill.map { Background.color(color($0)).propValue }
        default:
            return try controlHolds(property, view)
        }
    }

    private static func transform(_ property: Prop, _ drawn: HostDrawingTransform) -> HostValue? {
        switch property {
        case .translationX: drawn.translationX.propValue
        case .translationY: drawn.translationY.propValue
        case .rotation: drawn.rotation.propValue
        case .rotationX: drawn.rotationX.propValue
        case .rotationY: drawn.rotationY.propValue
        case .scale: (drawn.scaleX == drawn.scaleY ? drawn.scaleX : 1).propValue
        case .scaleX: drawn.scaleX.propValue
        case .scaleY: drawn.scaleY.propValue
        case .pivotX: drawn.pivotX.propValue
        case .pivotY: drawn.pivotY.propValue
        default: nil
        }
    }

    /// What assistive technology meets of the view, as its accessibility object says it.
    private static func accessibility(_ property: Prop, _ target: NSAccessibilityProtocol, _ view: NSView) -> HostValue? {
        switch property {
        case .accessibilityLabel: return target.accessibilityLabel().propValue
        case .accessibilityHint: return target.accessibilityHelp().propValue
        case .accessibilityIdentifier: return target.accessibilityIdentifier().propValue
        case .isAccessibilityHidden: return (!target.isAccessibilityElement()).propValue
        case .automationExcludedWithChildren:
            return (!target.isAccessibilityElement() && (view.accessibilityChildren() ?? []).isEmpty).propValue
        default: return nil
        }
    }

    /// A control's words as AppKit draws them: their font's size, bold and italic, family, and their colour.
    private static func words(_ property: Prop, _ view: NSView) throws -> HostValue? {
        // A label draws its words in the attributes of its text; a control, in its own font and colour; a view
        // wrapping one, in its control's.
        let label = (view as? AppKitTextView)?.attributedStringValue
        let attributes = label.flatMap { $0.length > 0 ? $0.attributes(at: 0, effectiveRange: nil) : nil }
        let presented = (view as? AppKitAccessibilityPresenting)?.presentedControl ?? view
        let control = presented as? NSControl
        let text = presented as? NSTextView
        guard let font = attributes?[.font] as? NSFont ?? control?.font ?? text?.font else {
            throw DriverCannot("read the words of a \(type(of: view))")
        }
        switch property {
        case .fontSize: return Double(font.pointSize).propValue
        case .fontFamily: return font.familyName.map { Name($0) }.propValue
        case .fontAttributes:
            let traits = NSFontManager.shared.traits(of: font)
            var attributes: FontAttributes = []
            if traits.contains(.boldFontMask) { attributes.insert(.bold) }
            if traits.contains(.italicFontMask) { attributes.insert(.italic) }
            return attributes.propValue
        case .textColor:
            if let written = attributes?[.foregroundColor] as? NSColor { return color(written).propValue }
            if let field = control as? NSTextField, let written = field.textColor { return color(written).propValue }
            if let written = text?.textColor { return color(written).propValue }
            if let picker = control as? NSDatePicker { return color(picker.textColor).propValue }
            if let button = control as? NSButton, button.attributedTitle.length > 0,
               let written = button.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor {
                return color(written).propValue
            }
            return nil
        default: return nil
        }
    }

    /// What a menu's entry or a toolbar's item holds, as its NSMenuItem or NSToolbarItem holds it.
    func itemHolds(_ property: Prop, _ element: MountedElement) throws -> HostValue? {
        if element.type == .menuItem, let item = (element.native as? AppKitElement)?.platformMenuItem {
            switch property {
            case .text: return item.title.propValue
            case .isEnabled: return item.isEnabled.propValue
            case .accessibilityIdentifier: return item.accessibilityIdentifier().propValue
            default: break
            }
        }
        if element.type == .toolbarItem,
           let item = try controller(of: element).toolbarForTesting
               .itemForTesting(NSToolbarItem.Identifier("StateUI.action.\(element.mount)")) {
            switch property {
            case .text: return item.label.propValue
            case .isEnabled: return item.isEnabled.propValue
            default: break
            }
        }
        throw DriverCannot(reading: property, of: element)
    }

    /// A colour AppKit holds, in sRGB, as StateUI's.
    static func color(_ native: NSColor) -> Color {
        let rgb = native.usingColorSpace(.sRGB) ?? native
        func channel(_ value: CGFloat) -> Int { Int((value * 255).rounded()) }
        return Color(
            red: channel(rgb.redComponent), green: channel(rgb.greenComponent), blue: channel(rgb.blueComponent),
            alpha: channel(rgb.alphaComponent))
    }
}

#endif

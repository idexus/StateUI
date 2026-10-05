// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIConformance
@testable import StateUIWeb

/// What the page holds of a member, read from the element: its attributes and properties, what the browser's own
/// style resolves for it, and what assistive technology meets - each as the page holds it.
/// Design: docs/design/host/conformance.md#the-driver
extension WebDriver {
    /// What `view` holds of `property`; nil for a member this does not read.
    func reads(_ property: Prop, on element: MountedElement, view: WebDOMView) throws -> HostValue?? {
        let e = view.node
        if MountedElement.transformProperties.contains(property) { return .some(Self.transform(property, of: view)) }
        if let assisted = try accessibilityHolds(property, e) { return assisted }
        switch (property, view) {
        case (.isVisible, _):
            return try WebBrowser.truth("e.isConnected && e.checkVisibility({ visibilityProperty: true })", on: e).propValue
        case (.opacity, _): return try WebBrowser.number("Number(getComputedStyle(e).opacity)", on: e)?.propValue
        case (.isEnabled, _):
            return try (!WebBrowser.truth("""
                e.matches(":disabled") || e.getAttribute("aria-disabled") === "true" \
                || (e.getAttribute("role") === "group" && !!e.querySelector(":disabled"))
                """, on: e)).propValue
        case (.layoutDirection, _):
            let rightToLeft = try WebBrowser.truth("getComputedStyle(e).direction === 'rtl'", on: e)
            return (rightToLeft ? LayoutDirection.rightToLeft : .leftToRight).propValue
        case (.isOn, is WebSwitchView): return try WebBrowser.truth("e.querySelector('input').checked", on: e).propValue
        case (.isOn, is WebRadioView): return try WebBrowser.truth("e.querySelector('input').checked", on: e).propValue
        case (.value, is WebSliderView): return try WebBrowser.number("Number(e.value)", on: e)?.propValue
        case (.minimum, is WebSliderView): return try WebBrowser.number("Number(e.min)", on: e)?.propValue
        case (.maximum, is WebSliderView): return try WebBrowser.number("Number(e.max)", on: e)?.propValue
        case (.value, is WebStepperView): return try WebBrowser.number("Number(e.querySelector('input').value)", on: e)?.propValue
        case (.progress, is WebProgressView):
            return .some(try WebBrowser.evaluate("e.hasAttribute('value') ? e.value : null", on: e).flatMap(Double.init)?.propValue)
        case (.isAnimating, is WebActivityView): return try WebBrowser.truth("!!e.querySelector('[data-running]')", on: e).propValue
        case (.selectedIndex, is WebPickerView):
            return .some(try WebBrowser.number("e.selectedIndex", on: e).flatMap { $0 < 0 ? nil : Int($0).propValue })
        case (.options, is WebPickerView): return try words("[...e.options].map((o) => o.text)", on: e).propValue
        case (.source, let image as WebImageView): return .some(try source(of: image))
        case (.contentMode, is WebImageView): return try contentMode(of: e)
        case (.showsSidebar, is WebSplitView): return try WebBrowser.truth("e.dataset.sidebar === 'shown'", on: e).propValue
        case (.selectedTab, is WebTabView):
            let chosen = try WebBrowser.number(
                "[...e.querySelectorAll(':scope > .stateui-tab-strip > [role=tab]')].findIndex((t) => t.ariaSelected === 'true')",
                on: e)
            return .some(chosen.flatMap { $0 < 0 ? nil : Int($0).propValue })
        case (.selectionMode, is WebItemsView):
            let mode = try WebBrowser.evaluate("e.getAttribute('role') === 'list' ? 'none' : e.ariaMultiSelectable === 'true' ? 'multiple' : 'single'", on: e)
            return (mode == "none" ? SelectionMode.none : mode == "multiple" ? .multiple : .single).propValue
        case (.scrollOffset, is WebScrollView):
            let offset = try numbers("[e.scrollLeft, e.scrollTop]", on: e)
            return offset.count == 2 ? Point(x: offset[0], y: offset[1]).propValue : nil
        default: break
        }
        if let input = view as? WebTextInputView, let held = try fieldHolds(property, input) { return held }
        if let held = try wordsHolds(property, e) { return held }
        if let held = try boxHolds(property, view) { return held }
        return nil
    }

    /// What `element` holds that no view of its own holds: a window's name, a span's look, a page's.
    func structureHolds(_ property: Prop, on element: MountedElement) throws -> HostValue?? {
        switch (element.type, property) {
        case (.window, .title): return try WebBrowser.evaluate("document.title", on: 0)?.propValue
        default: return nil
        }
    }

    // MARK: - Assistive technology

    private func accessibilityHolds(_ property: Prop, _ e: Int32) throws -> HostValue?? {
        switch property {
        case .accessibilityLabel: return .some(try WebBrowser.evaluate("e.getAttribute('aria-label')", on: e)?.propValue)
        case .accessibilityHint: return .some(try WebBrowser.evaluate("e.getAttribute('aria-description')", on: e)?.propValue)
        case .accessibilityIdentifier: return .some(try WebBrowser.evaluate("e.dataset.identifier", on: e)?.propValue)
        case .accessibilityHeading:
            let level = try WebBrowser.number("e.getAttribute('role') === 'heading' ? Number(e.ariaLevel) : 0", on: e) ?? 0
            return AccessibilityHeadingLevel(rawValue: Int32(level))?.propValue ?? AccessibilityHeadingLevel.none.propValue
        case .isAccessibilityHidden:
            return try WebBrowser.truth("e.getAttribute('role') === 'none' || e.ariaHidden === 'true'", on: e).propValue
        case .automationExcludedWithChildren: return try WebBrowser.truth("e.ariaHidden === 'true'", on: e).propValue
        default: return nil
        }
    }

    // MARK: - Words

    /// The words of `e` and the look the browser's style resolves for them.
    private func wordsHolds(_ property: Prop, _ e: Int32) throws -> HostValue?? {
        let style = "getComputedStyle(e)"
        switch property {
        case .text: return .some(try WebBrowser.evaluate("e.textContent", on: e)?.propValue)
        case .textColor: return .some(try color("\(style).color", on: e)?.propValue)
        case .fontSize: return try WebBrowser.number("parseFloat(\(style).fontSize)", on: e)?.propValue
        case .fontFamily:
            let family = try WebBrowser.evaluate("\(style).fontFamily.split(',')[0].trim().replace(/^[\"']|[\"']$/g, '')", on: e)
            return .some(family.map { Name($0).propValue })
        case .fontAttributes:
            var attributes: FontAttributes = []
            if try WebBrowser.number("Number(\(style).fontWeight)", on: e) ?? 400 >= 700 { attributes.insert(.bold) }
            if try WebBrowser.truth("\(style).fontStyle === 'italic'", on: e) { attributes.insert(.italic) }
            return attributes.propValue
        case .textDecorations:
            var decorations: TextDecorations = []
            let lines = try WebBrowser.evaluate("\(style).textDecorationLine", on: e) ?? ""
            if lines.contains("underline") { decorations.insert(.underline) }
            if lines.contains("line-through") { decorations.insert(.strikethrough) }
            return decorations.propValue
        case .tracking:
            return try WebBrowser.number("\(style).letterSpacing === 'normal' ? 0 : parseFloat(\(style).letterSpacing)", on: e)?
                .propValue
        case .horizontalTextAlignment:
            let align = try WebBrowser.evaluate("\(style).textAlign", on: e) ?? "start"
            let rightToLeft = try WebBrowser.truth("\(style).direction === 'rtl'", on: e)
            let alignment: TextAlignment = switch align {
            case "center": .center
            case "end": .end
            case "right": rightToLeft ? .start : .end
            case "left": rightToLeft ? .end : .start
            default: .start
            }
            return alignment.propValue
        case .lineBreak:
            let wraps = try WebBrowser.truth("\(style).whiteSpace.includes('wrap')", on: e)
            if wraps {
                return (try WebBrowser.truth("\(style).wordBreak === 'break-all'", on: e) ? LineBreak.characterWrap : .wordWrap)
                    .propValue
            }
            return (try WebBrowser.truth("\(style).textOverflow === 'ellipsis'", on: e) ? LineBreak.tailTruncation : .noWrap)
                .propValue
        case .maximumLines:
            let clamp = try WebBrowser.evaluate("\(style).webkitLineClamp", on: e) ?? "none"
            return .some(Int(clamp).map(\.propValue))
        case .padding:
            let sides = try numbers("['Left', 'Top', 'Right', 'Bottom'].map((s) => parseFloat(\(style)['padding' + s]))", on: e)
            return sides.count == 4 ? Insets(left: sides[0], top: sides[1], right: sides[2], bottom: sides[3]).propValue : nil
        default: return nil
        }
    }

    // MARK: - Fields

    private func fieldHolds(_ property: Prop, _ field: WebTextInputView) throws -> HostValue?? {
        let e = field.node
        switch property {
        case .text: return try WebBrowser.evaluate("e.value", on: e)?.propValue ?? "".propValue
        case .placeholder: return .some(try WebBrowser.evaluate("e.placeholder || null", on: e)?.propValue)
        case .isReadOnly: return try WebBrowser.truth("e.readOnly", on: e).propValue
        case .isPassword: return try WebBrowser.truth("e.type === 'password'", on: e).propValue
        case .cursorPosition: return try WebBrowser.number("e.selectionEnd", on: e).map { Int($0).propValue }
        case .selectionLength: return try WebBrowser.number("e.selectionEnd - e.selectionStart", on: e).map { Int($0).propValue }
        case .isSpellCheckEnabled: return try WebBrowser.truth("e.spellcheck", on: e).propValue
        case .isTextPredictionEnabled: return try WebBrowser.truth("e.autocomplete !== 'off'", on: e).propValue
        case .placeholderColor:
            return .some(try color("getComputedStyle(e, '::placeholder').color", on: e)?.propValue)
        default: return nil
        }
    }

    // MARK: - Boxes

    /// What a box StateUI draws holds: its fill, its outline and its shape, as the page draws them.
    private func boxHolds(_ property: Prop, _ view: WebDOMView) throws -> HostValue?? {
        let e = view.node
        let style = "getComputedStyle(e)"
        switch property {
        case .clipsContent: return try WebBrowser.truth("\(style).overflow === 'hidden'", on: e).propValue
        case .letsInputThrough: return try WebBrowser.truth("e.hasAttribute('data-lets-through')", on: e).propValue
        case .background:
            return .some(try color("\(style).backgroundColor", on: e, unlessClear: true).map { Background.color($0).propValue })
        default: return nil
        }
    }

    // MARK: - Parts

    /// The part of the host's own transform `property` names.
    static func transform(_ property: Prop, of view: WebDOMView) -> HostValue? {
        let transform = view.ownDrawing
        let value: Double? = switch property {
        case .translationX: transform.translationX
        case .translationY: transform.translationY
        case .rotation: transform.rotation
        case .rotationX: transform.rotationX
        case .rotationY: transform.rotationY
        case .scale: transform.scaleX == transform.scaleY ? transform.scaleX : nil
        case .scaleX: transform.scaleX
        case .scaleY: transform.scaleY
        case .pivotX: transform.pivotX
        case .pivotY: transform.pivotY
        default: nil
        }
        return value?.propValue
    }

    /// The picture the `<img>` shows, by its name; nil for none.
    private func source(of image: WebImageView) throws -> HostValue? {
        guard let address = try WebBrowser.evaluate("e.getAttribute('src')", on: image.node), address.hasPrefix("Images/")
        else { return nil }
        return ImageSource(String(address.dropFirst("Images/".count))).propValue
    }

    private func contentMode(of e: Int32) throws -> HostValue?? {
        let fit = try WebBrowser.evaluate("getComputedStyle(e).objectFit", on: e)
        let mode: ContentMode? = switch fit {
        case "contain": .fit
        case "cover": .fill
        case "fill": .stretch
        case "none": .center
        default: nil
        }
        return .some(mode?.propValue)
    }

    /// `script`'s colour on `e`; nil for none - and, `unlessClear`, for one wholly clear.
    func color(_ script: String, on e: Int32, unlessClear: Bool = false) throws -> Color? {
        let channels = try numbers("stateui.channels(\(script))", on: e, separator: ",")
        guard channels.count == 4, !(unlessClear && channels[3] == 0) else { return nil }
        return Color(red: Int(channels[0]), green: Int(channels[1]), blue: Int(channels[2]), alpha: Int(channels[3]))
    }

    /// `script`'s list of numbers on `e`.
    func numbers(_ script: String, on e: Int32, separator: Character = "\u{0}") throws -> [Double] {
        (try WebBrowser.evaluate(script, on: e) ?? "").split(separator: separator).compactMap { Double($0) }
    }

    /// `script`'s list of words on `e`.
    func words(_ script: String, on e: Int32) throws -> [String] {
        guard let joined = try WebBrowser.evaluate(script, on: e), !joined.isEmpty else { return [] }
        return joined.split(separator: "\u{0}", omittingEmptySubsequences: false).map(String.init)
    }
}

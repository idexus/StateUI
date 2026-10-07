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
        if let assisted = try accessibilityHolds(property, view) { return assisted }
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
        case (.step, let stepper as WebStepperView): return stepper.step.propValue
        case (.minimum, is WebStepperView):
            return try WebBrowser.number("Number(e.querySelector('input').getAttribute('aria-valuemin'))", on: e)?.propValue
        case (.maximum, is WebStepperView):
            return try WebBrowser.number("Number(e.querySelector('input').getAttribute('aria-valuemax'))", on: e)?.propValue
        case (.date, is WebDatePickerView): return .some(try day("e.value", on: e)?.propValue)
        case (.minimumDate, is WebDatePickerView): return .some(try day("e.min", on: e)?.propValue)
        case (.maximumDate, is WebDatePickerView): return .some(try day("e.max", on: e)?.propValue)
        case (.time, is WebTimePickerView):
            let parts = (try WebBrowser.evaluate("e.value", on: e) ?? "").split(separator: ":").compactMap { Int($0) }
            return .some(parts.count >= 2 ? ClockTime(hour: parts[0], minute: parts[1], second: parts.count > 2 ? parts[2] : 0).propValue : nil)
        case (.tint, _):
            let painted = "((s) => s.getPropertyValue('--stateui-on').trim() || null)(getComputedStyle(e))"
            return .some(try WebBrowser.evaluate(painted, on: e) == nil ? nil : try color(painted, on: e)?.propValue)
        case (.verticalScrollIndicator, is WebScrollView): return try bars("overflowY", on: e)
        case (.horizontalScrollIndicator, is WebScrollView): return try bars("overflowX", on: e)
        case (.source, let frame as WebFrameView): return .some(try source(of: frame))
        case (.selectedItems, let items as WebItemsView): return .strings(items.cells.selected)
        case (.progress, is WebProgressView):
            let bar = view.named.node
            return .some(try WebBrowser.evaluate("e.hasAttribute('value') ? e.value : null", on: bar).flatMap(Double.init)?.propValue)
        case (.isAnimating, is WebActivityView): return try WebBrowser.truth("!!e.querySelector('[data-running]')", on: e).propValue
        // The title's option stands first: it is no choice.
        case (.selectedIndex, is WebPickerView):
            return .some(try WebBrowser.number("e.selectedIndex - 1", on: e).flatMap { $0 < 0 ? nil : Int($0).propValue })
        case (.options, is WebPickerView): return try words("[...e.options].slice(1).map((o) => o.text)", on: e).propValue
        case (.placeholder, is WebPickerView): return .some(try WebBrowser.evaluate("e.options[0].text || null", on: e)?.propValue)
        case (.source, let image as WebImageView): return .some(try source(of: image))
        case (.contentMode, is WebImageView): return try contentMode(of: e)
        case (.icon, is WebButtonView), (.iconPosition, is WebButtonView), (.iconSpacing, is WebButtonView),
             (.contentMode, is WebButtonView), (.lineBreak, is WebButtonView):
            return try buttonHolds(property, e)
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
        if let shape = view as? WebShapeView, let held = try shapeHolds(property, shape) { return held }
        if let input = view as? WebTextInputView, let held = try fieldHolds(property, input) { return held }
        if let held = try wordsHolds(property, e) { return held }
        if let held = try boxHolds(property, view) { return held }
        return nil
    }

    /// What `element` holds that no view of its own holds: a window's name, what its bar shows of it, a page's
    /// place on a tab.
    func structureHolds(_ property: Prop, on element: MountedElement) throws -> HostValue?? {
        switch (element.type, property) {
        case (.window, .title): return try WebBrowser.evaluate("document.title", on: 0)?.propValue
        case (.window, .background):
            guard let frame = renderer?.roster.controllers.first?.window.frame else { return nil }
            return .some(try color("getComputedStyle(e).backgroundColor", on: frame.node, unlessClear: true)?.propValue)
        case (_, .barTitle): return .some(try barWords(".stateui-bar-name"))
        case (_, .barSubtitle): return .some(try barWords(".stateui-bar-subtitle"))
        case (_, .barBackgroundColor): return .some(try barColor("--stateui-bar-background"))
        case (_, .barForegroundColor): return .some(try barColor("--stateui-bar-foreground"))
        case (.page, .showsNavigationBar):
            guard let bar = try? bar(over: element) else { return nil }
            return try (!WebBrowser.truth("e.hidden", on: bar)).propValue
        case (.page, .showsBackButton):
            guard let bar = try? bar(over: element) else { return nil }
            return try WebBrowser.truth("!e.hidden && !e.querySelector('button[aria-label=Back]').hidden", on: bar).propValue
        case (_, .title) where tab(of: element) != nil:
            guard let (tabs, place) = tab(of: element), let view = (tabs.native as? WebElement)?.view else { return nil }
            let strip = ":scope > .stateui-tab-strip > [role=tab]"
            return .some(try WebBrowser.evaluate("e.querySelectorAll('\(strip)')[\(place)]?.textContent ?? null", on: view.node)?.propValue)
        case (_, .icon) where tab(of: element) != nil:
            guard let (tabs, place) = tab(of: element), let view = (tabs.native as? WebElement)?.view else { return nil }
            let picture = ":scope > .stateui-tab-strip > [role=tab]"
            return .some(try WebBrowser.evaluate(
                "((t) => t && !t.querySelector('img').hidden ? t.querySelector('img').dataset.source : null)(e.querySelectorAll('\(picture)')[\(place)])",
                on: view.node).map { .string($0) })
        default: return nil
        }
    }

    /// The words of the window's bar's part `part`; nil where it shows none.
    private func barWords(_ part: String) throws -> HostValue? {
        guard let bar = renderer?.roster.controllers.first?.window.bar else { throw DriverCannot("find the window's bar") }
        return try WebBrowser.evaluate("((p) => p && !p.hidden && p.textContent ? p.textContent : null)(e.querySelector('\(part)'))", on: bar.node)?
            .propValue
    }

    /// The colour the window's bar is painted with by its variable `variable`; nil for the page's own.
    private func barColor(_ variable: String) throws -> HostValue? {
        guard let bar = renderer?.roster.controllers.first?.window.bar else { throw DriverCannot("find the window's bar") }
        let painted = "getComputedStyle(e).getPropertyValue('\(variable)').trim() || null"
        guard try WebBrowser.evaluate(painted, on: bar.node) != nil else { return nil }
        return try color(painted, on: bar.node)?.propValue
    }

    /// The tabbed view `element` stands on a tab of, and which tab.
    private func tab(of element: MountedElement) -> (MountedElement, Int)? {
        var child = element
        while let parent = child.parent {
            if parent.type == .tabView, let place = parent.children.firstIndex(where: { $0 === child }) { return (parent, place) }
            child = parent
        }
        return nil
    }

    // MARK: - Assistive technology

    /// What assistive technology meets of `view`: its name and what it does on the element it names it by - the
    /// browser's control a toggle stands around - the rest on its own.
    private func accessibilityHolds(_ property: Prop, _ view: WebDOMView) throws -> HostValue?? {
        let (e, named) = (view.node, view.named.node)
        switch property {
        case .accessibilityLabel: return .some(try WebBrowser.evaluate("e.getAttribute('aria-label')", on: named)?.propValue)
        case .accessibilityHint: return .some(try WebBrowser.evaluate("e.getAttribute('aria-description')", on: named)?.propValue)
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

    /// What a run of words of a text holds: its own `<span>` in the text's, in the tree's order, read as words are.
    func spanHolds(_ property: Prop, on element: MountedElement) throws -> HostValue?? {
        var text = element.parent
        while let each = text, (each.native as? WebElement)?.view == nil { text = each.parent }
        guard let text, let view = (text.native as? WebElement)?.view,
              let place = Self.spans(under: text).firstIndex(where: { $0 === element })
        else { return nil }
        guard let span = try WebBrowser.number("((s) => s ? stateui.numberOf(s) : null)(e.children[\(place)])", on: view.node)
        else { return nil }
        if property == .background {
            return .some(try color("getComputedStyle(e).backgroundColor", on: Int32(span), unlessClear: true)?.propValue)
        }
        return try wordsHolds(property, Int32(span))
    }

    /// The runs of words under `element`, in the tree's order.
    private static func spans(under element: MountedElement) -> [MountedElement] {
        element.children.flatMap { $0.type == .textSpan ? [$0] : spans(under: $0) }
    }

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
        case .lineHeight:
            return try WebBrowser.number(
                "\(style).lineHeight === 'normal' ? null : parseFloat(\(style).lineHeight) / parseFloat(\(style).fontSize)", on: e)?
                .propValue
        case .verticalTextAlignment:
            let align = try WebBrowser.evaluate("\(style).alignContent", on: e) ?? ""
            return (align == "center" ? TextAlignment.center : align == "end" || align == "flex-end" ? .end : .start).propValue
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
        case .maximumLength: return .some(try WebBrowser.number("e.maxLength < 0 ? null : e.maxLength", on: e).map { Int($0).propValue })
        case .submitLabel:
            let hint = try WebBrowser.evaluate("e.enterKeyHint", on: e) ?? ""
            let label: SubmitLabel = switch hint {
            case "done": .done
            case "go": .go
            case "next": .next
            case "search": .search
            case "send": .send
            default: .default
            }
            return label.propValue
        case .inputPurpose:
            let mode = try WebBrowser.evaluate("e.inputMode", on: e) ?? ""
            let purpose: InputPurpose = switch mode {
            case "email": .email
            case "url": .url
            case "tel": .telephone
            case "decimal", "numeric": .numeric
            default: .default
            }
            return purpose.propValue
        case .growsWithText: return try WebBrowser.truth("e.hasAttribute('data-grows')", on: e).propValue
        case .placeholderColor:
            // The browser resolves no style of `::placeholder`: the colour is the variable the page paints it with.
            let painted = "((s) => s.getPropertyValue('--stateui-placeholder').trim() || s.getPropertyValue('--stateui-muted').trim())"
            return .some(try color("\(painted)(getComputedStyle(e))", on: e)?.propValue)
        default: return nil
        }
    }

    // MARK: - Shapes

    /// How a shape's path is painted, as its attributes say: its brushes' colours, its outline's width, ends,
    /// joins and dashes - the dashes measured in its width, as StateUI measures them.
    private func shapeHolds(_ property: Prop, _ shape: WebShapeView) throws -> HostValue?? {
        let path = "e.querySelector('path')"
        let attribute = { (name: String) in try WebBrowser.evaluate("\(path).getAttribute('\(name)')", on: shape.node) }
        let width = Double(try attribute("stroke-width") ?? "") ?? 1
        switch property {
        case .fill, .stroke:
            let painted = try attribute(property == .fill ? "fill" : "stroke") ?? "none"
            guard !painted.hasPrefix("url(") else { throw DriverCannot("read a gradient a shape is painted with") }
            return .some(try color("\(path).getAttribute('\(property == .fill ? "fill" : "stroke")')", on: shape.node)
                .map { Brush.solidColor($0).propValue })
        case .lineWidth: return width.propValue
        case .miterLimit: return (Double(try attribute("stroke-miterlimit") ?? "") ?? 4).propValue
        case .lineCap:
            let cap = try attribute("stroke-linecap")
            return (cap == "round" ? LineCap.round : cap == "square" ? .square : .flat).propValue
        case .lineJoin:
            let join = try attribute("stroke-linejoin")
            return (join == "round" ? LineJoin.round : join == "bevel" ? .bevel : .miter).propValue
        case .dash:
            let lengths = (try attribute("stroke-dasharray") ?? "").split(separator: " ").compactMap { Double($0) }
            return lengths.map { width > 0 ? $0 / width : 0 }.propValue
        case .dashPhase: return ((Double(try attribute("stroke-dashoffset") ?? "") ?? 0) / max(width, .leastNonzeroMagnitude)).propValue
        default: return nil
        }
    }

    // MARK: - A button's picture and words

    /// What a button holds of its picture and words: the picture's name and where it stands beside the words, how
    /// far from them, how it fills the button alone, and how the words break.
    private func buttonHolds(_ property: Prop, _ e: Int32) throws -> HostValue?? {
        func part(_ tag: String) throws -> Int32? {
            try WebBrowser.number("((p) => p ? stateui.numberOf(p) : null)(e.querySelector(':scope > \(tag)'))", on: e)
                .map { Int32($0) }
        }
        switch property {
        case .icon:
            return .some(try WebBrowser.evaluate("e.querySelector(':scope > img')?.dataset.source ?? null", on: e)
                .map { .string($0) })
        case .iconPosition:
            let positions: [String: IconPosition] = [
                "row": .leading, "row-reverse": .trailing, "column": .top, "column-reverse": .bottom,
            ]
            return .some(positions[try WebBrowser.evaluate("getComputedStyle(e).flexDirection", on: e) ?? ""]?.propValue)
        case .iconSpacing: return .some(try WebBrowser.number("parseFloat(getComputedStyle(e).gap) || 0", on: e)?.propValue)
        case .contentMode:
            guard let picture = try part("img") else { return .some(nil) }
            return try contentMode(of: picture)
        default:
            guard let words = try part("span") else { return .some(nil) }
            return try wordsHolds(property, words)
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
        case .stroke:
            let drawn = try WebBrowser.truth("\(style).borderTopStyle !== 'none' && parseFloat(\(style).borderTopWidth) > 0", on: e)
            return .some(drawn ? try color("\(style).borderTopColor", on: e, unlessClear: true).map { Brush.solidColor($0).propValue } : nil)
        case .lineWidth:
            return try WebBrowser.number("\(style).borderTopStyle === 'none' ? 0 : parseFloat(\(style).borderTopWidth)", on: e)?.propValue
        case .shape:
            if try WebBrowser.truth("\(style).borderTopLeftRadius.endsWith('%')", on: e) { return ContainerShape.ellipse.propValue }
            let radius = try WebBrowser.number("parseFloat(\(style).borderTopLeftRadius) || 0", on: e) ?? 0
            return (radius == 0 ? ContainerShape.rectangle : .roundedRectangle(radius)).propValue
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

    /// The day `script` writes on `e` - the browser's "YYYY-MM-DD" - nil for none.
    private func day(_ script: String, on e: Int32) throws -> CalendarDate? {
        let parts = (try WebBrowser.evaluate(script, on: e) ?? "").split(separator: "-").compactMap { Int($0) }
        return parts.count == 3 ? CalendarDate(year: parts[0], month: parts[1], day: parts[2]) : nil
    }

    /// Whether the scroller's bars stand along the way `overflow` names: always, never, or where it scrolls.
    private func bars(_ overflow: String, on e: Int32) throws -> HostValue?? {
        if try WebBrowser.truth("getComputedStyle(e).\(overflow) === 'scroll'", on: e) { return ScrollIndicatorVisibility.visible.propValue }
        let never = try WebBrowser.truth("e.dataset.bars === 'never'", on: e)
        return (never ? ScrollIndicatorVisibility.never : .automatic).propValue
    }

    /// The picture the `<img>` shows, by its name; nil for none.
    private func source(of image: WebImageView) throws -> HostValue? {
        try picture("e", on: image.node)
    }

    /// The picture the `<img>` `script` finds on `e` shows, by the name it was given where the file shown is one
    /// that name stands for - a PNG not found gives way to its SVG - else by the file; nil for none shown.
    func picture(_ script: String, on e: Int32) throws -> HostValue? {
        let said = try WebBrowser.evaluate(
            "((i) => i && !i.hidden && i.getAttribute('src') ? i.getAttribute('src') + '\\n' + (i.dataset.source ?? '') : null)(\(script))",
            on: e) ?? ""
        let parts = said.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let address = parts.first, address.hasPrefix("Images/") else { return nil }
        // A drawing's view after `#` is how it fills its room, not its name.
        let shown = String(address.dropFirst("Images/".count).prefix { $0 != "#" })
        let given = parts.count > 1 ? parts[1] : ""
        let name = !given.isEmpty && PictureArithmetic.files(for: given).contains(shown) ? given : shown
        return ImageSource(name).propValue
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

extension WebDriver {
    /// What a web view shows, as its frame holds it: a document of the page's own read back from the address made
    /// for it, its links' base from the `<base>` written before it; else the address the frame was given.
    func source(of frame: WebFrameView) throws -> HostValue? {
        let script = "((f) => { let a; try { a = f.contentWindow.location.href; } catch { return 'url ' + f.src; }"
            + " if (!a.startsWith('blob:')) return a === 'about:blank' ? null : 'url ' + a;"
            + " const x = new XMLHttpRequest(); x.open('GET', a, false); x.send(); return 'html ' + x.responseText; })"
            + "(e.querySelector('iframe'))"
        guard let said = try WebBrowser.evaluate(script, on: frame.node) else { return nil }
        if said.hasPrefix("url ") { return WebViewSource.url(String(said.dropFirst(4))).propValue }
        var document = Substring(said.dropFirst(5))
        var base: String?
        if document.hasPrefix("<base href=\""), let end = document.firstIndex(of: ">") {
            let written = document[document.index(document.startIndex, offsetBy: 12)..<end].dropLast()
            base = String(written).replacingAll("&quot;", with: "\"")
            document = document[document.index(after: end)...]
        }
        return WebViewSource.html(String(document), baseURL: base).propValue
    }
}

extension String {
    /// The words with every `old` in them `new`.
    func replacingAll(_ old: String, with new: String) -> String {
        split(separator: old, omittingEmptySubsequences: false).joined(separator: new)
    }
}

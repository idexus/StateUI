// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
@_spi(Host) import StateUIHostConformance

/// What the WinUI driver reads of a member: from the control WinUI holds, by the relay's reader, never from what the
/// host last wrote.
/// Design: docs/design/platforms/winui/conformance.md#what-the-driver-reads
extension WinUIDriver {
    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        let view = (element.native as? WinUIElement)?.view
        let cannot = DriverCannot(reading: property, of: element)
        switch element.type {
        case .span:
            if let held = try spanHolds(property.name, element) { return held }
            throw cannot
        case .menuItem, .menu:
            if let held = try menuHolds(property.name, element) { return held }
            throw cannot
        case .toolbarItem:
            if let held = try actionHolds(property.name, element) { return held }
            throw cannot
        case .window:
            if let held = try windowHolds(property.name, element) { return held }
            throw cannot
        case .page, .navigationStack, .splitView, .tabbedView:
            if let held = try pageHolds(property.name, element, view) { return held }
        default: break
        }
        guard let view else { throw cannot }
        if let held = try viewHolds(property.name, view) { return held }
        if let held = try wordsHold(property.name, view) { return held }
        if let held = try boxHolds(property.name, view) { return held }
        if let held = try shapeHolds(property.name, view) { return held }
        if let held = try fieldHolds(property.name, view) { return held }
        if let held = try controlHolds(property.name, view) { return held }
        throw cannot
    }

    /// A window's: the name the system shows, its place and size, their bounds, its buttons and its backdrop.
    private func windowHolds(_ name: String, _ element: MountedElement) throws -> HostValue? {
        let window = try window(of: element)
        if name == "title" {
            let length = stateui_winui_window_system_title(window.handle, nil, 0)
            var bytes = [CChar](repeating: 0, count: Int(length) + 1)
            _ = stateui_winui_window_system_title(window.handle, &bytes, Int32(bytes.count))
            return .string(String(decoding: bytes.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self))
        }
        let names = [
            "x", "y", "width", "height", "minimumWidth", "minimumHeight", "maximumWidth", "maximumHeight",
            "isMaximizable", "isMinimizable", "isTranslucent",
        ]
        guard let place = names.firstIndex(of: name) else { return nil }
        var values = [Double](repeating: 0, count: names.count)
        stateui_winui_window_frame(window.handle, &values)
        // A size in pixels is a DIP's fraction off; a request is a whole number of DIPs.
        return place < 8 ? .number(values[place].rounded()) : .bool(values[place] == 1)
    }

    /// What WinUI holds of `view`'s property named `what`, by the relay's reader.
    func read(_ view: WinUIView, _ what: String) throws -> String {
        let length = stateui_winui_read(view.handle, what, nil, 0)
        guard length >= 0 else { throw DriverCannot("read \(what) of a \(type(of: view))") }
        var bytes = [CChar](repeating: 0, count: Int(length) + 1)
        _ = stateui_winui_read(view.handle, what, &bytes, Int32(bytes.count))
        return String(decoding: bytes.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// Every element: shown, how opaque, taking input, what assistive technology meets, how it is moved.
    private func viewHolds(_ name: String, _ view: WinUIView) throws -> HostValue? {
        switch name {
        case "isVisible": return stateui_winui_is_shown(view.handle).propValue
        case "opacity": return stateui_winui_opacity(view.handle).propValue
        case "isEnabled": return stateui_winui_is_enabled(view.handle).propValue
        case "accessibilityLabel" where view is WinUIActivityIndicatorView:
            // A running ring's peer says it is busy before the name its element holds.
            return .string(try read(view, "automationName"))
        case "accessibilityLabel": return .string(view.automationWords.name)
        case "accessibilityHint": return .string(view.automationWords.help)
        case "accessibilityIdentifier": return .string(view.automationWords.identifier)
        case "accessibilityHeadingLevel": return (HeadingLevel(rawValue: view.automationFacts.heading) ?? HeadingLevel.none).propValue
        case "isAccessibilityHidden":
            let facts = view.automationFacts
            return (!facts.isControl && !facts.isContent).propValue
        case "automationExcludedWithChildren":
            let facts = view.automationFacts
            return (!facts.isControl && !facts.isContent && facts.children == 0).propValue
        case "translationX": return view.drawnTransform.translationX.propValue
        case "translationY": return view.drawnTransform.translationY.propValue
        case "rotation": return view.drawnTransform.rotation.propValue
        case "scale":
            let drawn = view.drawnTransform
            return (drawn.scaleX == drawn.scaleY ? drawn.scaleX : 1).propValue
        case "scaleX": return view.drawnTransform.scaleX.propValue
        case "scaleY": return view.drawnTransform.scaleY.propValue
        case "pivotX":
            // A part of the frame StateUI placed the view in, which a control WinUI keeps larger does not change.
            let size = view.placedFrame.width
            return (size > 0 ? view.drawnTransform.centerX / size : 0.5).propValue
        case "pivotY":
            let size = view.placedFrame.height
            return (size > 0 ? view.drawnTransform.centerY / size : 0.5).propValue
        case "ignoresInput" where view is WinUILayoutView: return (try read(view, "hitTestable") == "0").propValue
        case "clipsContent" where view is WinUILayoutView: return (try read(view, "clipped") == "1").propValue
        default: return nil
        }
    }

    /// Words, as a text block or a control shows them.
    private func wordsHold(_ name: String, _ view: WinUIView) throws -> HostValue? {
        switch name {
        case "text":
            switch view {
            case let text as WinUITextView: return .string(text.text)
            case let field as WinUIInputView: return .string(field.text)
            case let button as WinUIButtonView: return .string(button.text)
            case let radio as WinUIRadioButtonView: return .string(radio.text)
            default: return nil
            }
        case "textColor": return try Self.color(read(view, "foreground")).map { $0.propValue }
        case "fontSize": return Double(try read(view, "fontSize"))?.propValue
        case "fontFamily": return Name(try read(view, "fontFamily")).propValue
        case "fontAttributes":
            var attributes: FontAttributes = []
            if (Int(try read(view, "fontWeight")) ?? 400) >= 600 { attributes.insert(.bold) }
            if try read(view, "italic") == "1" { attributes.insert(.italic) }
            return attributes.propValue
        case "characterSpacing":
            // Thousandths of an em on WinUI: back in DIPs, to the tenth WinUI keeps.
            let size = Double(try read(view, "fontSize")) ?? 14
            let spacing = (Double(try read(view, "characterSpacing")) ?? 0) * size / 1000
            return ((spacing * 10).rounded() / 10).propValue
        case "lineHeight":
            // DIPs on WinUI: back to a multiple of the font's own line, as the host writes it.
            let size = Double(try read(view, "fontSize")) ?? 14
            return ((Double(try read(view, "lineHeight")) ?? 0) / (size * WinUITextView.lineHeightOfFont)).propValue
        case "textDecorations": return TextDecorations(rawValue: Int32(try read(view, "decorations")) ?? 0).propValue
        case "maximumLines": return Int(try read(view, "maxLines"))?.propValue
        case "lineBreak":
            let wrapping = Int(try read(view, "wrapping")) ?? 2
            let trimming = Int(try read(view, "trimming")) ?? 0
            let broken: LineBreak = trimming != 0 ? .tailTruncation : wrapping == 1 ? .noWrap : .wordWrap
            return broken.propValue
        case "horizontalTextAlignment":
            if view is WinUIPickerView {
                let across = Int(try read(view, "contentAlignment")) ?? 0
                return (across == 1 ? TextAlignment.center : across == 2 ? .end : .start).propValue
            }
            let across = Int(try read(view, "textAlignment")) ?? 1
            return (across == 0 ? TextAlignment.center : across == 2 ? .end : .start).propValue
        case "padding" where !(view is WinUILayoutView): return try Self.insets(read(view, "padding"))?.propValue
        default: return nil
        }
    }

    /// A layout's own box, or a button's and a toggle's look.
    private func boxHolds(_ name: String, _ view: WinUIView) throws -> HostValue? {
        if view is WinUILayoutView {
            switch name {
            case "background": return try Self.color(read(view, "box.fill")).map { Background.color($0).propValue }
            case "stroke": return try Self.color(read(view, "box.stroke")).map { Brush.solidColor($0).propValue }
            case "strokeWidth": return Double(try read(view, "box.strokeThickness"))?.propValue
            case "shape":
                if try read(view, "box.ellipse") == "1" { return ContainerShape.ellipse.propValue }
                let radius = Double(try read(view, "box.radius")) ?? 0
                return (radius > 0 ? ContainerShape.roundedRectangle(radius) : .rectangle).propValue
            case "padding": return nil
            default: return nil
            }
        }
        switch name {
        case "background": return try Self.color(read(view, "background")).map { Background.color($0).propValue }
        case "stroke" where view is WinUIButtonView:
            return try Self.color(read(view, "borderBrush")).map { Brush.solidColor($0).propValue }
        case "strokeWidth" where view is WinUIButtonView:
            return try Self.insets(read(view, "borderThickness"))?.left.propValue
        case "shape" where view is WinUIButtonView:
            let radius = try Self.insets(read(view, "cornerRadius"))?.left ?? 0
            return (radius > 0 ? ContainerShape.roundedRectangle(radius) : .rectangle).propValue
        default: return nil
        }
    }

    /// A shape's paint: its fill, its outline and how the outline is drawn.
    private func shapeHolds(_ name: String, _ view: WinUIView) throws -> HostValue? {
        guard view is WinUIPathView else { return nil }
        switch name {
        case "fill": return try Self.color(read(view, "fill")).map { Brush.solidColor($0).propValue }
        case "stroke": return try Self.color(read(view, "stroke")).map { Brush.solidColor($0).propValue }
        case "strokeWidth": return Double(try read(view, "strokeThickness"))?.propValue
        case "strokeDashPattern":
            let dashes = try read(view, "dashes")
            return (dashes.isEmpty ? [] : dashes.split(separator: ";").compactMap { Double($0) }).propValue
        case "strokeDashOffset": return Double(try read(view, "dashOffset"))?.propValue
        case "strokeLineCap":
            let cap = Int(try read(view, "cap")) ?? 0
            return (cap == 2 ? LineCap.round : cap == 1 ? .square : .flat).propValue
        case "strokeLineJoin": return LineJoin(rawValue: Int32(try read(view, "join")) ?? 0)?.propValue
        case "strokeMiterLimit": return ((Double(try read(view, "miter")) ?? 0) / 2).propValue
        default: return nil
        }
    }

    /// A field's and an editor's words and how it takes them.
    private func fieldHolds(_ name: String, _ view: WinUIView) throws -> HostValue? {
        guard view is WinUIInputView else { return nil }
        switch name {
        case "placeholder": return .string(try read(view, "placeholder"))
        case "placeholderColor": return try Self.color(read(view, "placeholderForeground")).map { $0.propValue }
        case "isPassword": return (try read(view, "password") == "1").propValue
        default: break
        }
        guard !(view is WinUISearchFieldView) else { return nil }
        var facts = [Int32](repeating: 0, count: 9)
        stateui_winui_field_facts(view.handle, &facts)
        switch name {
        case "isReadOnly": return (facts[0] != 0).propValue
        case "isSpellCheckEnabled": return (facts[1] != 0).propValue
        case "isTextPredictionEnabled": return (facts[2] != 0).propValue
        case "inputPurpose": return InputPurpose(rawValue: Int32(try read(view, "purpose")) ?? 0)?.propValue
        case "cursorPosition": return Int(facts[5]).propValue
        case "selectionLength": return Int(facts[6]).propValue
        default: return nil
        }
    }

    /// What each control holds of its own purpose.
    private func controlHolds(_ name: String, _ view: WinUIView) throws -> HostValue? {
        switch (name, view) {
        case ("isOn", let toggle as WinUIToggleView): return toggle.isOn.propValue
        case ("value", let slider as WinUISliderView): return slider.value.propValue
        case ("minimum", let slider as WinUISliderView): return slider.minimum.propValue
        case ("maximum", let slider as WinUISliderView): return slider.maximum.propValue
        case ("value", let stepper as WinUIStepperView): return stepper.value.propValue
        case ("minimum", let stepper as WinUIStepperView): return Double(try read(stepper, "minimum"))?.propValue
        case ("maximum", let stepper as WinUIStepperView): return Double(try read(stepper, "maximum"))?.propValue
        case ("step", let stepper as WinUIStepperView): return Double(try read(stepper, "step"))?.propValue
        case ("progress", let bar as WinUIProgressBarView): return bar.progress.propValue
        case ("isRunning", let spinner as WinUIActivityIndicatorView): return spinner.isRunning.propValue
        case ("tint", _): return try Self.color(read(view, "tint")).map { $0.propValue }
        case ("selectedIndex", let picker as WinUIPickerView): return picker.chosen < 0 ? nil : picker.chosen.propValue
        case ("options", let picker as WinUIPickerView): return picker.choices.propValue
        case ("title", let picker as WinUIPickerView): return .string(try read(picker, "placeholder"))
        case ("isOpen", let picker as WinUIPickerView): return picker.isOpen.propValue
        case ("isOpen", let picker as WinUIDatePickerView): return picker.isOpen.propValue
        case ("date", let picker as WinUIDatePickerView): return picker.date?.propValue
        case ("minimumDate", let picker as WinUIDatePickerView): return Self.day(try read(picker, "minimumDate"))?.propValue
        case ("maximumDate", let picker as WinUIDatePickerView): return Self.day(try read(picker, "maximumDate"))?.propValue
        case ("format", let picker as WinUIDatePickerView):
            return .string(try read(picker, "longDate") == "1" ? "D" : "d")
        case ("time", let picker as WinUITimePickerView): return picker.time?.propValue
        case ("source", let image as WinUIImageView): return ImageSource(try read(image, "source")).propValue
        case ("aspect", let image as WinUIImageView):
            let stretch = Int(try read(image, "stretch")) ?? 2
            let aspect: Aspect = stretch == 3 ? .fill : stretch == 1 ? .stretch : stretch == 0 ? .center : .fit
            return aspect.propValue
        case ("scrollOffset", let scroll as WinUIScrollView): return scroll.offset.propValue
        case ("verticalScrollBarVisibility", let scroll as WinUIScrollView):
            return Self.bar(try read(scroll.scroller, "verticalBar")).propValue
        case ("horizontalScrollBarVisibility", let scroll as WinUIScrollView):
            return Self.bar(try read(scroll.scroller, "horizontalBar")).propValue
        case ("orientation", let scroll as WinUIScrollView):
            let down = try read(scroll.scroller, "verticalMode") != "0"
            let across = try read(scroll.scroller, "horizontalMode") != "0"
            let orientation: ScrollOrientation = down && across ? .both : across ? .horizontal : down ? .vertical : .neither
            return orientation.propValue
        default: return nil
        }
    }

    /// A page's and an arrangement's: the title the window or its tab shows, its bar, its tab, its sidebar.
    private func pageHolds(_ name: String, _ element: MountedElement, _ view: WinUIView?) throws -> HostValue? {
        switch (name, view) {
        case ("title", _): return .string(try title(of: element))
        case ("hasNavigationBar", _):
            let bar = try window().titleBar
            let back = try read(bar, "back") == "1"
            let actions = try read(bar, "actions") != "|"
            return (back || actions).propValue
        case ("barBackgroundColor", _): return try Self.color(read(window().titleBar, "background")).map { $0.propValue }
        case ("barForegroundColor", _): return try Self.color(read(window().titleBar, "foreground")).map { $0.propValue }
        case ("isSidebarVisible", let split as WinUISplitView): return (try read(split.sidebar, "paneOpen") == "1").propValue
        case ("background", let page?) where element.type == .page:
            return try Self.color(read(page, "box.fill")).map { $0.propValue }
        case ("currentPage", let tabs as WinUITabbedView):
            let row: WinUIView = try tabs.tabsShownByWindow ? window().tabRow : tabs
            return Int(try read(row, "selected"))?.propValue
        default: return nil
        }
    }

    /// The title shown for a page or an arrangement: its tab's, where a tabbed view presents it, else the window's.
    private func title(of element: MountedElement) throws -> String {
        var page = element
        while let parent = page.parent, parent.type != .tabbedView, parent.type != .window { page = parent }
        guard let tabbed = page.parent, tabbed.type == .tabbedView,
              let index = tabbed.children.firstIndex(where: { $0 === page }),
              let tabs = (tabbed.native as? WinUIElement)?.view as? WinUITabbedView
        else { return try read(window().titleBar, "title") }
        let row: WinUIView = try tabs.tabsShownByWindow ? window().tabRow : tabs
        let titles = try read(row, "tabs").split(separator: ";", omittingEmptySubsequences: false)
        return titles.indices.contains(index) ? String(titles[index]) : ""
    }

    /// A span's run of its label's words.
    private func spanHolds(_ name: String, _ element: MountedElement) throws -> HostValue? {
        guard let spans = element.parent, let index = spans.children.firstIndex(where: { $0 === element }),
              let label = (spans.parent?.native as? WinUIElement)?.view as? WinUILabelView
        else { return nil }
        var values = [Double](repeating: 0, count: 6 * 16)
        let count = Int(stateui_winui_text_runs(label.handle, &values, Int32(values.count)))
        guard index < min(count, 16) else { return nil }
        let run = Array(values[6 * index..<6 * index + 6])
        switch name {
        case "text":
            let words = try read(label, "runs").split(separator: "\u{1F}", omittingEmptySubsequences: false)
            return words.indices.contains(index) ? .string(String(words[index])) : nil
        case "textColor": return run[0] == 0 ? nil : Self.color(UInt32(run[0])).propValue
        case "background": return run[5] == 0 ? nil : Self.color(UInt32(run[5])).propValue
        case "fontSize": return run[1] == 0 ? nil : run[1].propValue
        case "fontAttributes":
            var attributes: FontAttributes = []
            if run[2] >= 600 { attributes.insert(.bold) }
            if run[3] != 0 { attributes.insert(.italic) }
            return attributes.propValue
        case "textDecorations": return TextDecorations(rawValue: Int32(run[4])).propValue
        default: return nil
        }
    }

    /// A menu's item or a submenu, as its owner's menu shows it.
    private func menuHolds(_ name: String, _ element: MountedElement) throws -> HostValue? {
        guard let (owner, _) = menuPlace(of: element) else { return nil }
        let entries = Self.entries(of: owner.menus)
        let kind = element.type
        let place = Self.place(of: element, among: kind)
        let shown = entries.filter { $0.submenu == (kind == .menu) }
        guard shown.indices.contains(place) else { return nil }
        switch name {
        case "text": return .string(shown[place].caption)
        case "isEnabled": return shown[place].enabled.propValue
        case "accessibilityIdentifier" where kind == .menuItem:
            let identifiers = WinUIStrings.read { stateui_winui_menus_identifiers(owner.handle, $0, $1) }
                .split(separator: ";", omittingEmptySubsequences: false)
            let index = menuPlace(of: element)?.index ?? 0
            return identifiers.indices.contains(index) ? .string(String(identifiers[index])) : nil
        default: return nil
        }
    }

    /// A toolbar's item, as the window's chrome shows it: its words, whether it can be chosen, where it stands and
    /// its place in its row.
    private func actionHolds(_ name: String, _ element: MountedElement) throws -> HostValue? {
        let caption = element.value(.text)?.string ?? ""
        let rows = try read(window().titleBar, "actions").split(separator: "|", omittingEmptySubsequences: false)
        let bar = rows.first.map { $0.split(separator: ";").map(String.init) } ?? []
        let overflow = rows.count > 1 ? rows[1].split(separator: ";").map(String.init) : []
        let row = bar.contains { $0 == caption || $0 == "!" + caption } ? bar : overflow
        guard let index = row.firstIndex(where: { $0 == caption || $0 == "!" + caption }) else { return nil }
        switch name {
        case "text": return .string(caption)
        case "isEnabled": return (!row[index].hasPrefix("!")).propValue
        case "placement": return (row == bar ? ToolbarItemPlacement.bar : .overflow).propValue
        case "priority": return index.propValue
        case "accessibilityIdentifier":
            let rows = try read(window().titleBar, "actionIdentifiers").split(separator: "|", omittingEmptySubsequences: false)
            let identifiers = (row == bar ? rows.first : rows.last).map {
                $0.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
            } ?? []
            return identifiers.indices.contains(index) ? .string(identifiers[index]) : nil
        default: return nil
        }
    }

    /// The place of the toolbar's item among the actions the chrome shows, as its chrome chooses them.
    func actionPlace(of element: MountedElement) throws -> Int? {
        let caption = element.value(.text)?.string ?? ""
        let rows = try read(window().titleBar, "actions").split(separator: "|", omittingEmptySubsequences: false)
        let all = rows.flatMap { $0.split(separator: ";").map(String.init) }
        return all.firstIndex { $0 == caption || $0 == "!" + caption }
    }

    // MARK: - Words as WinUI's reader writes them

    /// A colour the reader writes as #AARRGGBB; nil for none.
    static func color(_ words: String) -> Color? {
        guard words.hasPrefix("#"), let argb = UInt32(words.dropFirst(), radix: 16) else { return nil }
        return color(argb)
    }

    /// A colour held as 0xAARRGGBB.
    static func color(_ argb: UInt32) -> Color {
        Color(red: Int(argb >> 16 & 0xFF), green: Int(argb >> 8 & 0xFF), blue: Int(argb & 0xFF), alpha: Int(argb >> 24))
    }

    /// Four sides the reader writes as numbers apart by commas.
    static func insets(_ words: String) -> Insets? {
        let sides = words.split(separator: ",").compactMap { Double($0) }
        return sides.count == 4 ? Insets(sides[0], sides[1], sides[2], sides[3]) : nil
    }

    /// A day the reader writes as year-month-day.
    static func day(_ words: String) -> CalendarDate? {
        let parts = words.split(separator: "-").compactMap { Int($0) }
        return parts.count == 3 ? CalendarDate(year: parts[0], month: parts[1], day: parts[2]) : nil
    }

    /// A scroll bar's showing, as WinUI's ScrollBarVisibility says it: 1 as WinUI decides, 3 always, else never.
    static func bar(_ words: String) -> ScrollBarVisibility {
        switch Int(words) {
        case 1: .default
        case 3: .always
        default: .never
        }
    }
}

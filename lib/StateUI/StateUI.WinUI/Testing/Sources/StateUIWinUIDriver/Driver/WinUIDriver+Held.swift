// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@_spi(Host) import StateUIConformance

/// What the WinUI driver reads of a member: from the control WinUI holds, by the relay's reader, never from what the
/// host last wrote.
/// Design: docs/design/platforms/winui/conformance.md#what-the-driver-reads
extension WinUIDriver {
    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        // What WinUI holds nothing of is not read: the case does not apply here.
        if platformHasNone["read \(property.name) of \(element.type.name)"] != nil {
            throw DriverCannot(reading: property, of: element)
        }
        if let value = backendHolds(property, on: element) { return value }
        let view = (element.native as? WinUIElement)?.view
        let cannot = DriverCannot(reading: property, of: element)
        switch element.type {
        case .textSpan:
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
        case .page, .navigationStack, .splitView, .tabView, .modalStack:
            if let held = try pageHolds(property.name, element, view) { return held }
        case .button where property.name == "icon":
            guard let view else { throw cannot }
            return Self.picture(try read(view, "icon"), named: element)
        default: break
        }
        guard let view else { throw cannot }
        if property.name == "layoutDirection" { return try direction(of: view, element) }
        if let held = try viewHolds(property.name, view) { return held }
        if let held = try wordsHold(property.name, view) { return held }
        if let held = try boxHolds(property.name, view) { return held }
        if let held = try shapeHolds(property.name, view) { return held }
        if let held = try fieldHolds(property.name, view) { return held }
        if let held = try controlHolds(property.name, view) { return held }
        throw cannot
    }

    /// A window's: the name the system shows, its place and size, their bounds, its buttons, its backdrop, whether it
    /// floats and stands shown, and the kind and value the host keeps it by for the next start.
    private func windowHolds(_ name: String, _ element: MountedElement) throws -> HostValue? {
        let window = try window(of: element)
        if name == "windowType" || name == "windowValue" {
            let kept = try keptWindow(element)
            return name == "windowType" ? kept.kind.map { .name($0) } : kept.value.map { .string($0) }
        }
        if name == "title" {
            let length = stateui_winui_window_system_title(window.handle, nil, 0)
            var bytes = [CChar](repeating: 0, count: Int(length) + 1)
            _ = stateui_winui_window_system_title(window.handle, &bytes, Int32(bytes.count))
            return .string(String(decoding: bytes.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self))
        }
        let names = [
            "x", "y", "width", "height", "minimumWidth", "minimumHeight", "maximumWidth", "maximumHeight",
            "isMaximizable", "isMinimizable", "isTranslucent", "floatsOnTop", "isVisible",
        ]
        guard let place = names.firstIndex(of: name) else { return nil }
        var values = [Double](repeating: 0, count: names.count)
        stateui_winui_window_frame(window.handle, &values)
        // A size in pixels is a DIP's fraction off; a request is a whole number of DIPs.
        return place < 8 ? .number(values[place].rounded()) : .bool(values[place] == 1)
    }

    /// The window `element` is, as the host keeps it for the next start.
    private func keptWindow(_ element: MountedElement) throws -> KeptScenes.Window {
        let scenes = element.enclosing(type: .application)?.children.filter { $0.type == .scene } ?? []
        guard let scene = element.enclosing(type: .scene), let sceneIndex = scenes.firstIndex(where: { $0 === scene }),
              let index = scene.windows.firstIndex(where: { $0 === element })
        else { throw DriverCannot("find the scene holding the window") }
        let kept = WinUIPersistence.readScenes().scenes
        guard kept.indices.contains(sceneIndex), kept[sceneIndex].windows.indices.contains(index) else {
            throw DriverCannot("find the window among the scenes kept")
        }
        return kept[sceneIndex].windows[index]
    }

    /// What WinUI holds of `view`'s property named `what`, by the relay's reader.
    func read(_ view: WinUIView, _ what: String) throws -> String {
        let length = stateui_winui_read(view.handle, what, nil, 0)
        guard length >= 0 else { throw DriverCannot("read \(what) of a \(type(of: view))") }
        var bytes = [CChar](repeating: 0, count: Int(length) + 1)
        _ = stateui_winui_read(view.handle, what, &bytes, Int32(bytes.count))
        return String(decoding: bytes.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// Whether WinUI holds the tip `laid`, which it keeps at a float's precision; neither for none.
    private static func holds(_ held: HostMatrix?, _ laid: HostMatrix?) -> Bool {
        guard let held, let laid else { return held == nil && laid == nil }
        let pairs = [
            (held.m11, laid.m11), (held.m12, laid.m12), (held.m13, laid.m13), (held.m14, laid.m14),
            (held.m21, laid.m21), (held.m22, laid.m22), (held.m23, laid.m23), (held.m24, laid.m24),
            (held.m31, laid.m31), (held.m32, laid.m32), (held.m33, laid.m33), (held.m34, laid.m34),
            (held.m41, laid.m41), (held.m42, laid.m42), (held.m43, laid.m43), (held.m44, laid.m44),
        ]
        return pairs.allSatisfy { abs($0 - $1) <= 1e-5 * max(1, abs($1)) }
    }

    /// The direction a control writes in, as WinUI holds it; a layout's and a drawing's, which stand left to right in
    /// WinUI, as the host lays them out (`byHost`).
    private func direction(of view: WinUIView, _ element: MountedElement) throws -> HostValue {
        guard let holder = view.directionHolder else {
            return ((view as? WinUILayoutView)?.direction ?? element.layoutDirection).propValue
        }
        return (try read(holder, "flowDirection") == "1" ? LayoutDirection.rightToLeft : .leftToRight).propValue
    }

    /// Every element: shown, how opaque, taking input, what assistive technology meets, how it is moved.
    private func viewHolds(_ name: String, _ view: WinUIView) throws -> HostValue? {
        switch name {
        case "isVisible": return stateui_winui_is_shown(view.handle).propValue
        case "opacity": return stateui_winui_opacity(view.handle).propValue
        case "isEnabled": return stateui_winui_is_enabled(view.answering.handle).propValue
        case "accessibilityLabel" where view is WinUIActivityIndicatorView:
            // A running ring's peer says it is busy before the name its element holds.
            return .string(try read(view, "automationName"))
        case "accessibilityLabel": return .string(view.automationWords.name)
        case "accessibilityHint": return .string(view.automationWords.help)
        case "accessibilityIdentifier": return .string(view.automationWords.identifier)
        case "accessibilityHeading": return (AccessibilityHeadingLevel(rawValue: view.automationFacts.heading) ?? AccessibilityHeadingLevel.none).propValue
        case "isAccessibilityHidden":
            let facts = view.automationFacts
            return (!facts.isControl && !facts.isContent).propValue
        case "automationExcludedWithChildren":
            let facts = view.automationFacts
            return (!facts.isControl && !facts.isContent && facts.children == 0).propValue
        case "translationX": return view.drawnTransform.translationX.propValue
        case "translationY": return view.drawnTransform.translationY.propValue
        case "rotation": return view.drawnTransform.rotation.propValue
        case "rotationX", "rotationY":
            // The host's own tip, held where WinUI draws the projection the host composed of it, else none (`byHost`).
            let drawing = view.drawing
            let size = view.placedFrame
            let drawn = Self.holds(view.drawnTip, drawing.tip(width: size.width, height: size.height))
            return (drawn ? (name == "rotationX" ? drawing.rotationX : drawing.rotationY) : 0).propValue
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
        case "ignoresInput": return (try read(view, "hitTestable") == "0").propValue
        case "clipsContent" where view is WinUILayoutView: return (try read(view, "clipped") == "1").propValue
        default: return nil
        }
    }

    /// Words, as a text block or a control shows them.
    private func wordsHold(_ name: String, _ view: WinUIView) throws -> HostValue? {
        switch name {
        case "text":
            switch view {
            case let text as WinUITextualView: return .string(text.text)
            case let field as WinUITextInputView: return .string(field.text)
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
        case "tracking":
            // Thousandths of an em on WinUI: back in DIPs, to the tenth WinUI keeps.
            let size = Double(try read(view, "fontSize")) ?? 14
            let spacing = (Double(try read(view, "tracking")) ?? 0) * size / 1000
            return ((spacing * 10).rounded() / 10).propValue
        case "lineHeight":
            // DIPs on WinUI: back to a multiple of the font's own line, as the host writes it.
            let size = Double(try read(view, "fontSize")) ?? 14
            return ((Double(try read(view, "lineHeight")) ?? 0) / (size * WinUITextualView.lineHeightOfFont)).propValue
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
        case "verticalTextAlignment" where view is WinUITextView:
            // WinUI's VerticalAlignment: top 0, centre 1, bottom 2, stretched 3 - the words at its top.
            let down = Int(try read(view, "verticalAlignment")) ?? 3
            return (down == 1 ? TextAlignment.center : down == 2 ? .end : .start).propValue
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
            case "lineWidth": return Double(try read(view, "box.strokeThickness"))?.propValue
            case "shape":
                if try read(view, "box.ellipse") == "1" { return ContainerShape.ellipse.propValue }
                let radius = Double(try read(view, "box.radius")) ?? 0
                return (radius > 0 ? ContainerShape.roundedRectangle(radius) : .rectangle).propValue
            case "padding": return nil
            default: return nil
            }
        }
        switch name {
        case "background" where view is WinUICanvasView:
            let ground = stateui_winui_canvas_ground(view.handle)
            return ground == 0 ? nil : Background.color(Self.color(ground)).propValue
        case "background": return try Self.color(read(view, "background")).map { Background.color($0).propValue }
        case "stroke" where view is WinUIButtonView:
            return try Self.color(read(view, "borderBrush")).map { Brush.solidColor($0).propValue }
        case "lineWidth" where view is WinUIButtonView:
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
        case "lineWidth": return Double(try read(view, "strokeThickness"))?.propValue
        case "dash":
            let dashes = try read(view, "dashes")
            return (dashes.isEmpty ? [] : dashes.split(separator: ";").compactMap { Double($0) }).propValue
        case "dashPhase": return Double(try read(view, "dashOffset"))?.propValue
        case "lineCap":
            let cap = Int(try read(view, "cap")) ?? 0
            return (cap == 2 ? LineCap.round : cap == 1 ? .square : .flat).propValue
        case "lineJoin": return LineJoin(rawValue: Int32(try read(view, "join")) ?? 0)?.propValue
        case "miterLimit": return (Double(try read(view, "miter")) ?? 0).propValue
        default: return nil
        }
    }

    /// A field's and an editor's words and how it takes them.
    private func fieldHolds(_ name: String, _ view: WinUIView) throws -> HostValue? {
        guard view is WinUITextInputView else { return nil }
        switch name {
        case "placeholder": return .string(try read(view, "placeholder"))
        case "placeholderColor": return try Self.color(read(view, "placeholderForeground")).map { $0.propValue }
        case "isPassword": return (try read(view, "password") == "1").propValue
        default: break
        }
        var facts = [Int32](repeating: 0, count: 9)
        stateui_winui_field_facts(view.handle, &facts)
        // A search box keeps its caret in its template's text box, which offers none of its own.
        if view is WinUISearchFieldView, name == "cursorPosition" || name == "selectionLength" { return nil }
        switch name {
        case "isReadOnly": return (facts[0] != 0).propValue
        case "isSpellCheckEnabled": return (facts[1] != 0).propValue
        case "isTextPredictionEnabled": return (facts[2] != 0).propValue
        case "inputPurpose":
            return WinUIInputScope(rawValue: Int32(try read(view, "scope")) ?? 0).map(Self.purpose)?.propValue
        case "cursorPosition": return Int(facts[5]).propValue
        case "selectionLength": return Int(facts[6]).propValue
        default: return nil
        }
    }

    /// What each control holds of its own purpose.
    private func controlHolds(_ name: String, _ view: WinUIView) throws -> HostValue? {
        switch (name, view) {
        case ("selectedItems", let items as WinUIItemsView): return .strings(items.selectedForTesting)
        case ("selectionMode", let items as WinUIItemsView): return items.modeForTesting.propValue
        case ("isOn", let toggle as WinUIToggleView): return toggle.isOn.propValue
        case ("value", let slider as WinUISliderView): return slider.value.propValue
        case ("minimum", let slider as WinUISliderView): return slider.minimum.propValue
        case ("maximum", let slider as WinUISliderView): return slider.maximum.propValue
        case ("value", let stepper as WinUIStepperView): return stepper.value.propValue
        case ("minimum", let stepper as WinUIStepperView): return Double(try read(stepper, "minimum"))?.propValue
        case ("maximum", let stepper as WinUIStepperView): return Double(try read(stepper, "maximum"))?.propValue
        case ("step", let stepper as WinUIStepperView): return Double(try read(stepper, "step"))?.propValue
        case ("progress", let bar as WinUIProgressBarView): return bar.progress.propValue
        case ("isAnimating", let spinner as WinUIActivityIndicatorView): return spinner.isAnimating.propValue
        case ("tint", _): return try Self.color(read(view, "tint")).map { $0.propValue }
        case ("selectedIndex", let picker as WinUIPickerView): return picker.chosen < 0 ? nil : picker.chosen.propValue
        case ("options", let picker as WinUIPickerView): return picker.choices.propValue
        case ("placeholder", let picker as WinUIPickerView): return .string(try read(picker, "placeholder"))
        case ("isOpen", let picker as WinUIPickerView): return picker.isOpen.propValue
        case ("isOpen", let picker as WinUIDatePickerView): return picker.isOpen.propValue
        case ("date", let picker as WinUIDatePickerView): return picker.date?.propValue
        case ("minimumDate", let picker as WinUIDatePickerView): return Self.day(try read(picker, "minimumDate"))?.propValue
        case ("maximumDate", let picker as WinUIDatePickerView): return Self.day(try read(picker, "maximumDate"))?.propValue
        case ("format", let picker as WinUIDatePickerView):
            return .string(try read(picker, "longDate") == "1" ? "D" : "d")
        case ("time", let picker as WinUITimePickerView): return picker.time?.propValue
        case ("source", let image as WinUIImageView): return ImageSource(try read(image, "source")).propValue
        case ("iconPosition", let button as WinUIButtonView):
            return IconPosition(rawValue: Int32(try read(button, "iconPosition")) ?? 0)?.propValue
        case ("iconSpacing", let button as WinUIButtonView): return Double(try read(button, "iconSpacing"))?.propValue
        case ("contentMode", _) where view is WinUIImageView || view is WinUIButtonView:
            let stretch = Int(try read(view, "stretch")) ?? 2
            let aspect: ContentMode = stretch == 3 ? .fill : stretch == 1 ? .stretch : stretch == 0 ? .center : .fit
            return aspect.propValue
        case ("scrollOffset", let scroll as WinUIScrollView): return scroll.offset.propValue
        case ("verticalScrollIndicator", let scroll as WinUIScrollView):
            return Self.bar(try read(scroll.scroller, "verticalBar")).propValue
        case ("horizontalScrollIndicator", let scroll as WinUIScrollView):
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
        case ("icon", _): return try tabIcon(of: element).map { Self.picture($0, named: element) }
        case ("showsNavigationBar", _):
            let bar = try window().titleBar
            let back = try read(bar, "back") == "1"
            let actions = try read(bar, "actions") != "||"
            return (back || actions).propValue
        // The window's title bar offers the way back of the page it shows.
        case ("showsBackButton", _): return (try read(window().titleBar, "back") == "1").propValue
        case ("barBackgroundColor", _): return try Self.color(read(window().titleBar, "background")).map { $0.propValue }
        case ("barForegroundColor", _): return try Self.color(read(window().titleBar, "foreground")).map { $0.propValue }
        // The title area its path declares stands in the title's place.
        case ("barTitle", _): return .string(try read(window().titleBar, "title"))
        case ("barSubtitle", _):
            let words = try read(window().titleBar, "subtitle")
            return words.isEmpty ? nil : .string(words)
        case ("barIcon", _): return Self.picture(try read(window().titleBar, "icon"), named: element, by: .barIcon)
        case ("showsSidebar", let split as WinUISplitView): return (try read(split.sidebar, "paneOpen") == "1").propValue
        case ("background", let page?) where element.type == .page:
            return try Self.color(read(page, "box.fill")).map { $0.propValue }
        case ("selectedTab", let tabs as WinUITabView):
            let row: WinUIView = try tabs.tabsShownByWindow ? window().tabRow : tabs
            return Int(try read(row, "selected"))?.propValue
        default: return nil
        }
    }

    /// The title shown for a page or an arrangement: its tab's, where a tabbed view presents it, else the window's.
    private func title(of element: MountedElement) throws -> String {
        guard let (row, index) = try tab(of: element) else { return try read(window().titleBar, "title") }
        let titles = try read(row, "tabs").split(separator: ";", omittingEmptySubsequences: false)
        return titles.indices.contains(index) ? String(titles[index]) : ""
    }

    /// The file the picture on a page's or an arrangement's tab shows; nil where no tabbed view presents it.
    private func tabIcon(of element: MountedElement) throws -> String? {
        guard let (row, index) = try tab(of: element) else { return nil }
        let files = try read(row, "tabIcons").split(separator: ";", omittingEmptySubsequences: false)
        return files.indices.contains(index) ? String(files[index]) : ""
    }

    /// The row showing the tab a tabbed view presents a page or an arrangement on, and the tab's place in it; nil
    /// where no tabbed view presents it.
    private func tab(of element: MountedElement) throws -> (row: WinUIView, index: Int)? {
        var page = element
        while let parent = page.parent, parent.type != .tabView, parent.type != .window { page = parent }
        guard let tabbed = page.parent, tabbed.type == .tabView,
              let index = tabbed.children.firstIndex(where: { $0 === page }),
              let tabs = (tabbed.native as? WinUIElement)?.view as? WinUITabView
        else { return nil }
        return (try tabs.tabsShownByWindow ? window().tabRow : tabs.row, index)
    }

    /// A span's run of its label's words.
    private func spanHolds(_ name: String, _ element: MountedElement) throws -> HostValue? {
        guard let spans = element.parent, let index = spans.children.firstIndex(where: { $0 === element }),
              let label = (spans.parent?.native as? WinUIElement)?.view as? WinUITextView
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
        case "fontFamily":
            let families = try read(label, "runFamilies").split(separator: "\u{1F}", omittingEmptySubsequences: false)
            guard families.indices.contains(index), !families[index].isEmpty else { return nil }
            return Name(String(families[index])).propValue
        case "tracking":
            // Thousandths of an em of the run's size on WinUI: back in DIPs, to the tenth WinUI keeps.
            let spacings = try read(label, "runSpacings").split(separator: "\u{1F}", omittingEmptySubsequences: false)
            guard spacings.indices.contains(index) else { return nil }
            let size = run[1] != 0 ? run[1] : Double(try read(label, "fontSize")) ?? 14
            return (((Double(spacings[index]) ?? 0) * size / 1000 * 10).rounded() / 10).propValue
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
        case "accessibilityIdentifier", "icon", "isDestructive":
            guard kind == .menuItem else { return nil }
            let what = name == "icon" ? "icon" : name == "isDestructive" ? "destructive" : "identifier"
            let items = WinUIStrings.read { stateui_winui_menus_items(owner.handle, what, $0, $1) }
                .split(separator: ";", omittingEmptySubsequences: false).map(String.init)
            let index = menuPlace(of: element)?.index ?? 0
            guard items.indices.contains(index) else { return nil }
            switch name {
            case "icon": return Self.picture(items[index], named: element)
            case "isDestructive": return (items[index] == "1").propValue
            default: return .string(items[index])
            }
        default: return nil
        }
    }

    /// A toolbar's item, as the window's chrome shows it: its words, whether it can be chosen, where it stands,
    /// its place in its row, and whether its words stand beside its picture.
    private func actionHolds(_ name: String, _ element: MountedElement) throws -> HostValue? {
        let titleBar = try window(of: element).titleBar
        guard let place = try actionPlace(of: element),
              let said = try Self.saidActions(read(titleBar, "bar")).first(where: { $0.place == place })
        else { return nil }
        let action = { (what: String) in try self.read(titleBar, "action \(place) \(what)") }
        switch name {
        case "text": return .string(titleBar.drawn[place].title)
        case "isEnabled": return said.enabled.propValue
        case "placement": return (said.edge == .overflow ? ToolbarItemPlacement.overflow : .bar).propValue
        case "icon": return Self.picture(try action("icon"), named: element)
        case "isDestructive": return (try action("destructive") == "1").propValue
        case "showsText": return (try action("wordsShown") == "1").propValue
        case "accessibilityIdentifier": return .string(try action("identifier"))
        default: return nil
        }
    }

    /// The bar `page`'s window shows: its groups at each edge and what stands behind "more", each action by its
    /// item's id, else its words (`BarWords`).
    func bar(of page: MountedElement) throws -> String {
        let titleBar = try window(of: page).titleBar
        var root = page
        while let parent = root.parent { root = parent }
        let read = Self.saidActions(try self.read(titleBar, "bar"))
        let word = { (said: SaidAction) -> String? in
            guard let mount = titleBar.drawn[said.place].mount, let item = Self.element(mounted: mount, in: root)
            else { return nil }
            return BarWords.word(item, enabled: said.enabled)
        }
        let groups = { (edge: SaidAction.Edge) -> [[String]] in
            let atEdge = read.filter { $0.edge == edge }
            let places = Set(atEdge.map(\.group)).sorted()
            return places.map { group in atEdge.filter { $0.group == group }.compactMap(word) }.filter { !$0.isEmpty }
        }
        return BarWords.said(
            leading: groups(.leading), trailing: groups(.trailing),
            overflow: read.filter { $0.edge == SaidAction.Edge.overflow }.compactMap(word))
    }

    /// An action as the chrome's reader says it: its place in the list the chrome was given, its edge, its group
    /// in reading order there, and whether it can be chosen.
    struct SaidAction {
        enum Edge { case leading, trailing, overflow }
        let place: Int
        let edge: Edge
        let group: Int
        let enabled: Bool
    }

    /// The chrome's "bar" read: leading, "|", trailing, "|", overflow - groups apart by a space, a group's actions
    /// by a comma, "!" before one that cannot be chosen.
    static func saidActions(_ words: String) -> [SaidAction] {
        let edges: [SaidAction.Edge] = [.leading, .trailing, .overflow]
        let parts = words.split(separator: "|", omittingEmptySubsequences: false)
        var said: [SaidAction] = []
        for (edge, part) in zip(edges, parts) {
            for (group, run) in part.split(separator: " ").enumerated() {
                for one in run.split(separator: ",") {
                    let enabled = !one.hasPrefix("!")
                    guard let place = Int(one.drop { $0 == "!" }) else { continue }
                    said.append(SaidAction(place: place, edge: edge, group: group, enabled: enabled))
                }
            }
        }
        return said
    }

    /// The element of `mount` in the tree under `root`, its slots included.
    static func element(mounted mount: UInt64, in root: MountedElement) -> MountedElement? {
        if root.mount == mount { return root }
        for child in root.children + root.slots {
            if let found = element(mounted: mount, in: child) { return found }
        }
        return nil
    }

    /// The picture a file shown stands for: the one the tree named - `element`'s `member` - where it is one of the
    /// files that name stands for.
    static func picture(_ shown: String, named element: MountedElement, by member: Prop = .icon) -> HostValue {
        let named = element.value(member)?.string ?? ""
        return ImageSource(PictureArithmetic.files(for: named).contains(shown) ? named : shown).propValue
    }

    /// The place of the toolbar's item among the actions the chrome shows, as its chrome chooses them.
    func actionPlace(of element: MountedElement) throws -> Int? {
        try window(of: element).titleBar.drawn.firstIndex { $0.mount == element.mount }
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
        return sides.count == 4 ? Insets(left: sides[0], top: sides[1], right: sides[2], bottom: sides[3]) : nil
    }

    /// A day the reader writes as year-month-day.
    static func day(_ words: String) -> CalendarDate? {
        let parts = words.split(separator: "-").compactMap { Int($0) }
        return parts.count == 3 ? CalendarDate(year: parts[0], month: parts[1], day: parts[2]) : nil
    }

    /// A scroll bar's showing, as WinUI's ScrollBarVisibility says it: 1 as WinUI decides, 3 always, else never.
    static func bar(_ words: String) -> ScrollIndicatorVisibility {
        switch Int(words) {
        case 1: .automatic
        case 3: .visible
        default: .never
        }
    }

    /// The purpose a text box's input scope is given for.
    static func purpose(_ scope: WinUIInputScope) -> InputPurpose {
        switch scope {
        case .default: .default
        case .text: .text
        case .chat: .chat
        case .email: .email
        case .number: .numeric
        case .telephone: .telephone
        case .url: .url
        }
    }
}

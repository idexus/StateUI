// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CGTKTesting
import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@_spi(Host) import StateUIConformance

/// What GTK holds of a member, read from the widget: a field's words and keys, a label's runs, a font as GTK's own
/// style gives it, a scroller's adjustments, a tab's page, and what assistive technology meets - each through GTK's
/// own reading of it.
/// Design: docs/design/host/conformance.md#the-driver
extension GTKDriver {
    /// What `element` holds of `property`, read from its widget; nil for a member this does not read.
    func reads(_ property: Prop, on element: MountedElement, view: GTKView?) -> HostValue?? {
        if element.type == .span { return spanHolds(property, element) }
        if let assisted = accessibilityHolds(property, element, view) { return assisted }
        if property == .title, let tab = tabTitle(of: element) { return .some(tab.propValue) }
        switch view {
        case let field as GTKTextFieldView: return fieldHolds(property, field)
        case let editor as GTKTextEditorView: return editorHolds(property, editor)
        case let label as GTKTextualView: return labelHolds(property, label.widget.opaque, label.widget)
        case let button as GTKButtonView: return button.captionLabel.flatMap { labelHolds(property, $0, button.widget) }
        case let check as GTKCheckView: return Self.label(in: check.widget).flatMap { labelHolds(property, $0.opaque, $0) }
        case let picker as GTKPickerView: return Self.label(in: picker.widget).flatMap { wordsHolds(property, $0) }
        case let picker as GTKPopoverPickerView: return wordsHolds(property, picker.label)
        case let stepper as GTKStepperView: return stepperHolds(property, stepper)
        case let scroll as GTKScrollView: return scrollHolds(property, scroll)
        case let tabs as GTKTabbedView where property == .selectedTab: return Self.shownTab(of: tabs).map(\.propValue)
        case _ where property == .showsNavigationBar && element.type == .page:
            return (try? frame(of: element)).map { (adw_toolbar_view_get_reveal_top_bars($0.widget.opaque) != 0).propValue }
        case let layout as GTKLayoutView: return layoutHolds(property, layout)
        default: return nil
        }
    }

    // MARK: - Fields

    private func fieldHolds(_ property: Prop, _ field: GTKTextFieldView) -> HostValue?? {
        let editable = field.widget.opaque
        let words = UnsafeMutablePointer<GtkText>(gtk_editable_get_delegate(editable))!
        switch property {
        case .placeholder: return .some(gtk_text_get_placeholder_text(words).map { String(cString: $0).propValue })
        case .cursorPosition: return Int(gtk_editable_get_position(editable)).propValue
        case .selectionLength:
            var (start, end): (Int32, Int32) = (0, 0)
            _ = gtk_editable_get_selection_bounds(editable, &start, &end)
            return Int(end - start).propValue
        case .isReadOnly: return (gtk_editable_get_editable(editable) == 0).propValue
        case .isPassword: return (gtk_text_get_visibility(words) == 0).propValue
        case .horizontalTextAlignment: return Self.alignment(gtk_editable_get_alignment(editable)).propValue
        case .isSpellCheckEnabled, .isTextPredictionEnabled, .inputPurpose:
            return Self.traits(property, gtk_text_get_input_hints(words), gtk_text_get_input_purpose(words))
        default: return wordsHolds(property, field.widget)
        }
    }

    private func editorHolds(_ property: Prop, _ editor: GTKTextEditorView) -> HostValue?? {
        guard let found = GTKTestHost.descendants(of: editor.widget).first(where: {
            GTKTestHost.holds($0, gtk_text_view_get_type())
        }) else { return nil }
        let text = found.of(GtkTextView.self)
        guard let buffer = gtk_text_view_get_buffer(text) else { return nil }
        switch property {
        case .placeholder:
            let placeholder = GTKTestHost.descendants(of: editor.widget).first {
                gtk_widget_has_css_class($0, GTKTextEditorView.placeholderClass) != 0
            }
            return .some(placeholder.map { String(cString: gtk_label_get_text($0.opaque)) }.flatMap {
                $0.isEmpty ? nil : $0.propValue
            })
        case .cursorPosition:
            var cursor = GtkTextIter()
            gtk_text_buffer_get_iter_at_mark(buffer, &cursor, gtk_text_buffer_get_insert(buffer))
            return Int(gtk_text_iter_get_offset(&cursor)).propValue
        case .selectionLength:
            var (start, end) = (GtkTextIter(), GtkTextIter())
            _ = gtk_text_buffer_get_selection_bounds(buffer, &start, &end)
            return Int(gtk_text_iter_get_offset(&end) - gtk_text_iter_get_offset(&start)).propValue
        case .isReadOnly: return (gtk_text_view_get_editable(text) == 0).propValue
        case .horizontalTextAlignment:
            let justified = gtk_text_view_get_justification(text)
            let alignment: TextAlignment = justified == GTK_JUSTIFY_CENTER ? .center : justified == GTK_JUSTIFY_RIGHT ? .end : .start
            return alignment.propValue
        case .isSpellCheckEnabled, .isTextPredictionEnabled, .inputPurpose:
            return Self.traits(property, gtk_text_view_get_input_hints(text), gtk_text_view_get_input_purpose(text))
        default:
            return wordsHolds(property, found)
        }
    }

    /// What typing is given, as GTK tells the input method: spell checking and prediction, and the purpose they and
    /// the keys say together.
    private static func traits(_ property: Prop, _ hints: GtkInputHints, _ purpose: GtkInputPurpose) -> HostValue? {
        let has = { (hint: GtkInputHints) in hints.rawValue & hint.rawValue != 0 }
        switch property {
        case .isSpellCheckEnabled: return has(GTK_INPUT_HINT_SPELLCHECK).propValue
        case .isTextPredictionEnabled: return has(GTK_INPUT_HINT_WORD_COMPLETION).propValue
        default:
            let read: InputPurpose = switch purpose {
            case GTK_INPUT_PURPOSE_EMAIL: .email
            case GTK_INPUT_PURPOSE_NUMBER: .numeric
            case GTK_INPUT_PURPOSE_PHONE: .telephone
            case GTK_INPUT_PURPOSE_URL: .url
            default:
                has(GTK_INPUT_HINT_EMOJI) ? .chat
                    : has(GTK_INPUT_HINT_UPPERCASE_SENTENCES) ? .text
                    : has(GTK_INPUT_HINT_NO_SPELLCHECK) && !has(GTK_INPUT_HINT_WORD_COMPLETION) ? .plain : .default
            }
            return read.propValue
        }
    }

    // MARK: - Words

    /// The words' colour and font GTK's style gives `widget`.
    private func wordsHolds(_ property: Prop, _ widget: GTKWidget) -> HostValue?? {
        guard let description = pango_context_get_font_description(gtk_widget_get_pango_context(widget)) else {
            return nil
        }
        switch property {
        case .textColor: return Self.color(of: widget).propValue
        case .fontSize: return (Double(pango_font_description_get_size(description)) / Double(PANGO_SCALE)).propValue
        case .fontFamily: return .some(pango_font_description_get_family(description).map { Name(String(cString: $0)).propValue })
        case .fontAttributes:
            var attributes: FontAttributes = []
            if pango_font_description_get_weight(description).rawValue >= PANGO_WEIGHT_BOLD.rawValue { attributes.insert(.bold) }
            if pango_font_description_get_style(description) == PANGO_STYLE_ITALIC { attributes.insert(.italic) }
            return attributes.propValue
        default: return nil
        }
    }

    /// What a label holds: its runs' look over all its words, its lines and where they stand.
    private func labelHolds(_ property: Prop, _ label: OpaquePointer, _ widget: GTKWidget) -> HostValue?? {
        let run = PangoRun(gtk_label_get_attributes(label), at: 0)
        switch property {
        case .lineBreak: return Self.lineBreak(of: label).propValue
        case .maximumLines:
            let lines = gtk_label_get_lines(label)
            return .some(gtk_label_get_wrap(label) != 0 && lines > 0 ? Int(lines).propValue : nil)
        case .horizontalTextAlignment: return Self.alignment(gtk_label_get_xalign(label)).propValue
        case .verticalTextAlignment: return Self.alignment(gtk_label_get_yalign(label)).propValue
        case .tracking: return run.holds(property) ?? 0.0.propValue
        case .lineHeight, .textDecorations, .fontSize, .fontAttributes, .fontFamily, .textColor:
            if let held = run.holds(property) { return held }
            return wordsHolds(property, widget)
        default: return nil
        }
    }

    /// What a span of a label holds: its words, and the look its run of them wears.
    private func spanHolds(_ property: Prop, _ span: MountedElement) -> HostValue?? {
        guard let (label, start, end) = Self.run(of: span) else { return nil }
        if property == .text {
            let words = Array(String(cString: gtk_label_get_text(label)).utf8)
            guard end <= words.count else { return nil }
            return String(decoding: words[start..<end], as: UTF8.self).propValue
        }
        let run = PangoRun(gtk_label_get_attributes(label), at: UInt32(start))
        if property == .tracking { return run.holds(property) ?? 0.0.propValue }
        return run.holds(property)
    }

    /// The label a span runs in, and the bytes of its words there: the runs before it, each its words in their case.
    private static func run(of span: MountedElement) -> (OpaquePointer, Int, Int)? {
        var holder = span.parent
        while let each = holder, !((each.native as? GTKElement)?.view is GTKTextualView) { holder = each.parent }
        guard let holder, let label = (holder.native as? GTKElement)?.view?.widget.opaque, let runs = holder.textRuns,
              let index = span.parent?.children.filter({ $0.type == .span }).firstIndex(where: { $0 === span }),
              runs.indices.contains(index)
        else { return nil }
        let start = runs[..<index].reduce(0) { $0 + $1.text.utf8.count }
        return (label, start, start + runs[index].text.utf8.count)
    }

    /// The child label GTK shows a check button's caption in.
    private static func label(in widget: GTKWidget) -> GTKWidget? {
        GTKTestHost.descendants(of: widget).first { GTKTestHost.holds($0, gtk_label_get_type()) }
    }

    private static func alignment(_ share: Float) -> TextAlignment {
        share < 0.25 ? .start : share > 0.75 ? .end : .center
    }

    // MARK: - Values, scrollers and layouts

    private func stepperHolds(_ property: Prop, _ stepper: GTKStepperView) -> HostValue?? {
        var (low, high, step, page) = (0.0, 0.0, 0.0, 0.0)
        gtk_spin_button_get_range(stepper.widget.opaque, &low, &high)
        gtk_spin_button_get_increments(stepper.widget.opaque, &step, &page)
        switch property {
        case .minimum: return low.propValue
        case .maximum: return high.propValue
        case .step: return step.propValue
        default: return nil
        }
    }

    private func scrollHolds(_ property: Prop, _ scroll: GTKScrollView) -> HostValue?? {
        guard let scrolled = GTKTestHost.descendants(of: scroll.widget).first(where: {
            GTKTestHost.holds($0, gtk_scrolled_window_get_type())
        })?.opaque else { return nil }
        var policies = (horizontal: GTK_POLICY_AUTOMATIC, vertical: GTK_POLICY_AUTOMATIC)
        gtk_scrolled_window_get_policy(scrolled, &policies.horizontal, &policies.vertical)
        let visibility = { (policy: GtkPolicyType) -> ScrollIndicatorVisibility in
            policy == GTK_POLICY_ALWAYS ? .visible : policy == GTK_POLICY_NEVER || policy == GTK_POLICY_EXTERNAL ? .never : .automatic
        }
        switch property {
        case .scrollOffset:
            return [gtk_adjustment_get_value(gtk_scrolled_window_get_hadjustment(scrolled)),
                    gtk_adjustment_get_value(gtk_scrolled_window_get_vadjustment(scrolled))].propValue
        case .horizontalScrollIndicator: return visibility(policies.horizontal).propValue
        case .verticalScrollIndicator: return visibility(policies.vertical).propValue
        default: return layoutHolds(property, scroll)
        }
    }

    /// Whether a layout cuts what stands past its edges, and whether a press beside its children goes through it -
    /// GTK's own overflow and its own reading of what the layout's box contains.
    private func layoutHolds(_ property: Prop, _ layout: GTKLayoutView) -> HostValue?? {
        renderer?.layOut()
        switch property {
        case .clipsContent: return (gtk_widget_get_overflow(layout.widget) == GTK_OVERFLOW_HIDDEN).propValue
        case .letsInputThrough:
            let (width, height) = (Double(gtk_widget_get_width(layout.widget)), Double(gtk_widget_get_height(layout.widget)))
            return (gtk_widget_contains(layout.widget, width / 2, height / 2) == 0).propValue
        default: return nil
        }
    }

    /// The title a tabbed view's tab shows for `element`'s page, as GTK's stack holds it; nil where no tab shows it.
    private func tabTitle(of element: MountedElement) -> String? {
        guard element.parent?.type == .tabbedView, var child = (element.native as? GTKElement)?.view?.widget else {
            return nil
        }
        while let parent = gtk_widget_get_parent(child), !GTKTestHost.holds(parent, gtk_stack_get_type()) { child = parent }
        guard let stack = gtk_widget_get_parent(child), let page = gtk_stack_get_page(stack.opaque, child),
              let title = gtk_stack_page_get_title(page)
        else { return nil }
        return String(cString: title)
    }

    /// The tab GTK's stack shows, by its place among the tabs.
    private static func shownTab(of tabs: GTKTabbedView) -> Int? {
        guard let stack = GTKTestHost.descendants(of: tabs.widget).first(where: { GTKTestHost.holds($0, gtk_stack_get_type()) }),
              let shown = gtk_stack_get_visible_child(stack.opaque)
        else { return nil }
        var place = 0
        var child = gtk_widget_get_first_child(stack)
        while let each = child {
            if each == shown { return place }
            place += 1
            child = gtk_widget_get_next_sibling(each)
        }
        return nil
    }

    /// Activates the item `element` stands in, as a double click or Return on its row does: the list's own
    /// `activate`; false where it stands in no item.
    func activateItem(_ element: MountedElement, in items: MountedElement) throws -> Bool {
        guard let view = (items.native as? GTKElement)?.view as? GTKItemsView, let list = view.list else { return false }
        var item = element
        while let parent = item.parent, parent !== items { item = parent }
        guard let identity = view.cells.identity(of: item), let place = view.cells.identities.firstIndex(of: identity)
        else { return false }
        GTKTestHost.emit(list.opaque, "activate", [Double(place)])
        return true
    }

    // MARK: - Assistive technology

    /// What assistive technology meets of the view, as GTK holds it: GTK reads none back, so its own checks are asked
    /// whether it holds what the tree gave; another value, or none, reads as such.
    private func accessibilityHolds(_ property: Prop, _ element: MountedElement, _ view: GTKView?) -> HostValue?? {
        guard let view else { return nil }
        let accessible = view.widget.opaque
        let differs = { (message: UnsafeMutablePointer<CChar>?) -> Bool in
            defer { g_free(message) }
            return message != nil
        }
        switch property {
        case .accessibilityLabel, .accessibilityHint:
            let property = property == .accessibilityLabel ? GTK_ACCESSIBLE_PROPERTY_LABEL : GTK_ACCESSIBLE_PROPERTY_DESCRIPTION
            guard gtk_test_accessible_has_property(accessible, property) != 0 else { return .some(nil) }
            let given = element.value(property == GTK_ACCESSIBLE_PROPERTY_LABEL ? .accessibilityLabel : .accessibilityHint)?
                .string ?? ""
            return differs(stateui_test_accessible_property_is_words(UnsafeMutableRawPointer(accessible), Int32(property.rawValue), given))
                ? "(GTK holds other words)".propValue : given.propValue
        case .accessibilityHeading:
            guard gtk_accessible_get_accessible_role(accessible) == GTK_ACCESSIBLE_ROLE_HEADING,
                  gtk_test_accessible_has_property(accessible, GTK_ACCESSIBLE_PROPERTY_LEVEL) != 0
            else { return AccessibilityHeadingLevel.none.propValue }
            for level in (1...6).compactMap({ AccessibilityHeadingLevel(rawValue: $0) }) {
                if !differs(stateui_test_accessible_property_is_number(
                    UnsafeMutableRawPointer(accessible), Int32(GTK_ACCESSIBLE_PROPERTY_LEVEL.rawValue), Int32(level.rawValue))) {
                    return level.propValue
                }
            }
            return nil
        case .isAccessibilityHidden, .automationExcludedWithChildren:
            return (!differs(stateui_test_accessible_state_is(
                UnsafeMutableRawPointer(accessible), Int32(GTK_ACCESSIBLE_STATE_HIDDEN.rawValue), 1))).propValue
        default: return nil
        }
    }
}

/// The look a label's runs give the words at one place, as Pango holds it.
private struct PangoRun {
    private var attributes: [UnsafeMutablePointer<PangoAttribute>] = []

    init(_ list: OpaquePointer?, at index: UInt32) {
        guard let list else { return }
        var link = pango_attr_list_get_attributes(list)
        let first = link
        while let each = link {
            if let attribute = each.pointee.data?.assumingMemoryBound(to: PangoAttribute.self),
               attribute.pointee.start_index <= index, index < attribute.pointee.end_index {
                attributes.append(attribute)
            }
            link = each.pointee.next
        }
        _ = first
    }

    private func first(_ type: PangoAttrType) -> UnsafeMutablePointer<PangoAttribute>? {
        attributes.last { $0.pointee.klass.pointee.type == type }
    }

    /// What the run holds of `property`; nil where no attribute of the run says it.
    func holds(_ property: Prop) -> HostValue? {
        switch property {
        case .fontSize:
            return first(PANGO_ATTR_ABSOLUTE_SIZE).map {
                (Double($0.withMemoryRebound(to: PangoAttrSize.self, capacity: 1) { $0.pointee.size }) / Double(PANGO_SCALE))
                    .propValue
            }
        case .fontFamily:
            return first(PANGO_ATTR_FAMILY).map {
                Name(String(cString: $0.withMemoryRebound(to: PangoAttrString.self, capacity: 1) { $0.pointee.value })).propValue
            }
        case .fontAttributes:
            var attributes: FontAttributes = []
            if let weight = first(PANGO_ATTR_WEIGHT).map(Self.number), weight >= Int32(PANGO_WEIGHT_BOLD.rawValue) {
                attributes.insert(.bold)
            }
            if first(PANGO_ATTR_STYLE).map(Self.number) == Int32(PANGO_STYLE_ITALIC.rawValue) { attributes.insert(.italic) }
            return first(PANGO_ATTR_WEIGHT) == nil && first(PANGO_ATTR_STYLE) == nil ? nil : attributes.propValue
        case .textColor: return color(PANGO_ATTR_FOREGROUND, PANGO_ATTR_FOREGROUND_ALPHA)?.propValue
        case .background: return color(PANGO_ATTR_BACKGROUND, PANGO_ATTR_BACKGROUND_ALPHA).map { Background.color($0).propValue }
        case .tracking:
            return first(PANGO_ATTR_LETTER_SPACING).map { (Double(Self.number($0)) / Double(PANGO_SCALE)).propValue }
        case .lineHeight:
            return first(PANGO_ATTR_LINE_HEIGHT).map {
                $0.withMemoryRebound(to: PangoAttrFloat.self, capacity: 1) { $0.pointee.value }.propValue
            }
        case .textDecorations:
            var decorations: TextDecorations = []
            if let underline = first(PANGO_ATTR_UNDERLINE).map(Self.number), underline != Int32(PANGO_UNDERLINE_NONE.rawValue) {
                decorations.insert(.underline)
            }
            if let struck = first(PANGO_ATTR_STRIKETHROUGH).map(Self.number), struck != 0 { decorations.insert(.strikethrough) }
            return decorations.propValue
        default: return nil
        }
    }

    private static func number(_ attribute: UnsafeMutablePointer<PangoAttribute>) -> Int32 {
        attribute.withMemoryRebound(to: PangoAttrInt.self, capacity: 1) { $0.pointee.value }
    }

    /// A colour and its alpha, each 0 to 65535 in Pango, as the tree writes a colour.
    private func color(_ type: PangoAttrType, _ alphaType: PangoAttrType) -> Color? {
        guard let attribute = first(type) else { return nil }
        let color = attribute.withMemoryRebound(to: PangoAttrColor.self, capacity: 1) { $0.pointee.color }
        let alpha = first(alphaType).map { Int(Self.number($0)) } ?? 65535
        let channel = { (value: Int) in Int((Double(value) / 65535 * 255).rounded()) }
        return Color(
            red: channel(Int(color.red)), green: channel(Int(color.green)), blue: channel(Int(color.blue)),
            alpha: channel(alpha))
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@_spi(Host) import StateUIConformance

/// The GTK host as the conformance suite drives it: each user's act through the signal or the call GTK's own input
/// takes, and each read from the widget itself.
/// Design: docs/design/host/conformance.md#the-driver
@MainActor
final class GTKDriver: HostDriver {
    let host = "GTK 4"
    let cannot: [String: String] = [:]
    let platformHasNone = GTKDriver.none()

    /// What GTK holds none of: what StateUI draws on GTK's snapshot, where StateUI's layout places the children,
    /// what StateUI measures and what the host cuts - each proven by its effect in another case.
    private static func none() -> [String: String] {
        var none = [
            "read growsWithText of TextEditor":
                "an editor's growing is StateUI's measuring, which no property of GTK's holds; its frames prove it",
            "read maximumLength of TextEditor":
                "GTK's text view keeps no bound: the host cuts what is typed, and typing proves it",
            "read maximumLength of TextField":
                "GTK bounds code points, not characters, so the host cuts what is typed; typing proves it",
            "read maximumLength of SearchField":
                "GTK bounds code points, not characters, so the host cuts what is typed; typing proves it",
            "read format of TimePicker": "GTK's clock holds no format: it writes hours and minutes in the user's own clock",
        ]
        let shapes = ["Ellipse", "Line", "Path", "Polygon", "Polyline", "Rectangle"]
        let shapePaint = [
            "aspect", "renderTransform", "fill", "stroke", "strokeWidth", "strokeDashOffset", "strokeDashPattern",
            "strokeLineCap", "strokeLineJoin", "strokeMiterLimit",
        ]
        for shape in shapes {
            for member in shapePaint {
                none["read \(member) of \(shape)"] =
                    "StateUI draws a shape on GTK's snapshot, which holds none of its \(member); its drawing proves it"
            }
        }
        none["read background of Page"] =
            "StateUI draws a page's box on GTK's snapshot, which holds none of its background; its drawing proves it"
        for layout in ["Grid", "HStack", "VStack", "ZStack", "ScrollView"] {
            for member in ["background", "stroke", "strokeWidth", "shape"] {
                none["read \(member) of \(layout)"] =
                    "StateUI draws a layout's box on GTK's snapshot, which holds none of its \(member); its drawing proves it"
            }
            none["read padding of \(layout)"] =
                "GTK's panel places its children where StateUI's layout says; their frames prove it"
        }
        for stack in ["HStack", "VStack"] {
            none["read spacing of \(stack)"] = "GTK's panel places its children where StateUI's layout says; their frames prove it"
        }
        return none
    }

    /// What the families ask of a driver that GTK's has no path for yet says so, and stays empty in GTK's column
    /// with why, rather than failing: GTK's reads and acts are written on Linux (work-plan.md, ON LINUX).
    func reason(cannot ability: String) -> String? {
        cannot[ability] ?? "GTK's driver has no path for it yet"
    }

    /// What the driver reaches past GTK, through the host's own entry or record - ✓.
    func byHost(_ ability: String) -> String? {
        if Ability(ability).readsATransform { return "the host's own transform: GTK reads back no part of one" }
        // A span's look is its run's Pango attributes, which GTK reads back.
        if !ability.hasSuffix(" of Span"), let member = Self.recordedMembers.first(where: { ability.hasPrefix("read \($0) of ") }) {
            return "the class of the host's style sheet the widget wears: GTK reads back no \(member)"
        }
        return Self.byHostReasons[ability] ?? Self.byHostReasons[Ability(ability).act]
            ?? Self.backends.values.lazy.compactMap { $0.byHost[ability] }.first
    }

    /// The members read from the classes of the host's style sheet a widget wears.
    private static let recordedMembers = ["padding", "background", "stroke", "strokeWidth", "shape", "placeholderColor"]

    private static let byHostReasons = [
        "read source of Image": "the file the host's own panel draws: GTK's snapshot holds no picture's name",
        "read icon of Button": "the file the host's own panel draws: GTK's snapshot holds no picture's name",
        "read aspect of Image": "how the host's own panel fills its room: GTK's snapshot holds no aspect",
        "read aspect of Button": "how the host's own panel fills its room: GTK's snapshot holds no aspect",
        "read tint of ProgressBar": "the tint the host gave the done part's node: GTK's style sheet tells no one",
        "read tint of Switch": "the tint the host gave the track's node: GTK's style sheet tells no one",
        "read tint of CheckBox": "the tint the host gave the box's node: GTK's style sheet tells no one",
        "read tint of Slider": "the tint the host gave the track's node: GTK's style sheet tells no one",
        "read what the screen reader said": "the host's own list of what it asked GTK to announce",
        "switchAway": "the notice GTK's window would give, told by the driver: a desktop moves no window a test shows",
        "switchBack": "the notice GTK's window would give, told by the driver: a desktop moves no window a test shows",
        "bringToFront": "the notice GTK's window would give, told by the driver: a desktop moves no window a test shows",
        "minimize": "the notice GTK's window would give, told by the driver: a desktop moves no window a test shows",
        "restore": "the notice GTK's window would give, told by the driver: a desktop moves no window a test shows",
        "read windowType of Window": "the scenes the host keeps for the next start",
        "read windowValue of Window": "the scenes the host keeps for the next start",
        "pinch": "the fingers' place handed to the host's recognizer as GTK's zoom would: GTK takes no touch a driver puts down",
        "pickTime": "the clock set at once through the host's own, its minute's wheel telling it; a user moves each",
        "read minimumDate of DatePicker": "the range the host holds the day in: GtkCalendar holds none",
        "read maximumDate of DatePicker": "the range the host holds the day in: GtkCalendar holds none",
    ]

    var renderer: GTKRenderer?

    /// The pointer's press the driver holds down.
    let pressed = GTKPress()

    /// The host's log, as the driver listens to it.
    let written = GTKLogLines()

    var register: HostRegister { GTKRealization.register.and(backendRecords) }

    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree {
        written.listen()
        let renderer = GTKRenderer.running(clock: clock, reducesMotion: reducesMotion, page)
        self.renderer = renderer
        return renderer.runtime.tree
    }

    func step() {
        renderer?.step()
    }

    func turn() {
        renderer?.runtime.pump.turn()
    }

    func frame() {
        renderer?.frame()
    }

    func perform(_ act: UserAct, on element: MountedElement) throws {
        if act == .activate, element.type == .toolbarItem { return try chooseAction(element) }
        if act == .activate, element.type == .menuItem { return try chooseMenuItem(element) }
        if act == .close, element.type == .window { return try close(element) }
        if case .answer = act, try windowAct(act, on: element) { return }
        if element.type == .window, try windowAct(act, on: element) { return }
        if try backendPerforms(act, on: element) { return }
        if act == .goBack {
            guard renderer?.goBack() == true else { throw DriverCannot(act, on: element) }
            return
        }
        let view = (element.native as? GTKElement)?.view
        if let picker = view as? GTKPopoverPickerView, perform(act, on: picker) { return }
        if let canvas = view as? GTKCanvasView, ["pressDown", "drag", "lift"].contains(act.description) {
            try press(act, on: canvas, element)
            _ = input(act, on: canvas)
            return
        }
        if let view, input(act, on: view) { return }
        if act == .activate, let items = element.enclosing(type: .itemsView), try activateItem(element, in: items) { return }
        switch (act, view) {
        // GTK lets a click reach no button that cannot be chosen.
        case (.activate, let button as GTKButtonView): if gtk_widget_is_sensitive(button.widget) != 0 { button.click() }
        case (.toggle, let toggle as GTKSwitchView): gtk_switch_set_active(toggle.widget.opaque, toggle.isOn ? 0 : 1)
        case (.toggle, let check as GTKCheckView): gtk_widget_activate(check.widget)
        case (.slide(let value), let slider as GTKSliderView): gtk_range_set_value(slider.widget.of(GtkRange.self), value)
        case (.step(let up), let stepper as GTKStepperView):
            gtk_spin_button_spin(stepper.widget.opaque, up ? GTK_SPIN_STEP_FORWARD : GTK_SPIN_STEP_BACKWARD, 0)
        case (.enterWords(let words), let stepper as GTKStepperView):
            gtk_editable_set_text(stepper.widget.opaque, words)
            gtk_spin_button_update(stepper.widget.opaque)
        case (.type(let words), let field as GTKTextFieldView):
            type(words, into: field, keys: gtk_editable_get_delegate(field.widget.opaque))
        case (.type(let words), let editor as GTKTextEditorView):
            type(words, into: editor, keys: OpaquePointer(gtk_scrolled_window_get_child(editor.widget.opaque)))
        case (.submit, let field as GTKTextFieldView): GTKTestHost.emit(field.widget.opaque, "activate")
        case (.focus, let view?): gtk_widget_grab_focus(view.widget)
        case (.choose(let place), let tabs as GTKTabbedView): try tabs.choose(place, on: element)
        case (.toggle, let split as GTKSplitView): split.toggleAsUser()
        case (.choose(let place), let picker as GTKPickerView): gtk_drop_down_set_selected(picker.widget.opaque, guint(place))
        case (.scroll(let offset), let items as GTKItemsView): try scroll(items, to: offset, on: element, act)
        case (.scroll(let offset), let scrollView as GTKScrollView): try scroll(scrollView, to: offset, on: element, act)
        case (.pressDown, let canvas as GTKCanvasView), (.drag, let canvas as GTKCanvasView),
             (.lift, let canvas as GTKCanvasView):
            try press(act, on: canvas, element)
        case (.choose(let place), let items as GTKItemsView): try choose(place, in: items, on: element)
        default: throw DriverCannot(act, on: element)
        }
    }

    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        if element.type == .toolbarItem { return try actionHolds(property, element) }
        if element.type == .window { return try windowHolds(property, element) }
        if element.type == .menuItem { return try menuItemHolds(property, element) }
        if [.barBackgroundColor, .barForegroundColor, .barSubtitle].contains(property) {
            return try barHolds(property, element)
        }
        if let value = backendHolds(property, on: element) { return value }
        let view = (element.native as? GTKElement)?.view
        if let picker = view as? GTKPopoverPickerView, let value = held(property, on: picker) { return value }
        if let value = try recorded(property, on: element, view: view) { return value }
        if let value = reads(property, on: element, view: view) { return value }
        switch (property, view) {
        case (.isOn, let toggle as GTKToggleView): return toggle.isOn.propValue
        case (.value, let slider as GTKSliderView): return slider.value.propValue
        case (.minimum, let slider as GTKSliderView):
            return gtk_adjustment_get_lower(gtk_range_get_adjustment(slider.widget.of(GtkRange.self))).propValue
        case (.maximum, let slider as GTKSliderView):
            return gtk_adjustment_get_upper(gtk_range_get_adjustment(slider.widget.of(GtkRange.self))).propValue
        case (.value, let stepper as GTKStepperView): return stepper.value.propValue
        case (.progress, let bar as GTKProgressBarView): return bar.progress.propValue
        case (.isAnimating, let spinner as GTKActivityIndicatorView): return spinner.isAnimating.propValue
        case (.text, let label as GTKTextualView): return label.text.propValue
        case (.text, let field as GTKTextFieldView): return field.text.propValue
        case (.text, let editor as GTKTextEditorView): return editor.text.propValue
        case (.text, let button as GTKButtonView): return button.text.propValue
        case (.icon, let button as GTKButtonView), (.source, let button as GTKButtonView):
            return button.picture.flatMap { $0.found ? ImageSource($0.file).propValue : nil }
        case (.iconPosition, let button as GTKButtonView): return Self.position(in: button)?.propValue
        case (.iconSpacing, let button as GTKButtonView):
            return button.pictureAndCaption.map { Double(gtk_box_get_spacing($0.of(GtkBox.self))).propValue }
        case (.lineBreak, let button as GTKButtonView): return button.captionLabel.map { Self.lineBreak(of: $0).propValue }
        case (.aspect, let button as GTKButtonView): return button.picture?.aspect.propValue
        case (.tint, let spinner as GTKActivityIndicatorView): return Self.color(of: spinner.widget).propValue
        case (.tint, let view?): return view.tint.map { Self.color($0).propValue }
        case (.source, let image as GTKImageView): return image.found ? ImageSource(image.file).propValue : nil
        case (.aspect, let image as GTKImageView): return image.aspect.propValue
        case (.text, let check as GTKCheckView): return check.text.propValue
        case (.showsSidebar, let split as GTKSplitView): return split.showsSidebar.propValue
        case (.selectedIndex, let picker as GTKPickerView): return picker.chosen.map(\.propValue)
        case (.options, let picker as GTKPickerView):
            guard let model = gtk_drop_down_get_model(picker.widget.opaque) else { return [String]().propValue }
            return (0..<g_list_model_get_n_items(model)).map { String(cString: gtk_string_list_get_string(model, $0)) }
                .propValue
        // Shown in its window: GTK maps a widget only while it and everything around it show there.
        case (.selectionMode, let items as GTKItemsView): return items.choiceMode.map { $0.propValue }
        case (.selectedItems, let items as GTKItemsView): return items.chosenIdentities.propValue
        case (.isVisible, let view?): return (gtk_widget_get_mapped(view.widget) != 0).propValue
        case (.opacity, let view?): return gtk_widget_get_opacity(view.widget).propValue
        case (.isEnabled, let view?): return (gtk_widget_get_sensitive(view.widget) != 0).propValue
        case (.layoutDirection, let view?):
            return (gtk_widget_get_direction(view.widget) == GTK_TEXT_DIR_RTL ? LayoutDirection.rightToLeft : .leftToRight).propValue
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// The colour GTK draws `widget`'s words and marks in.
    static func color(of widget: GTKWidget) -> Color {
        var color = GdkRGBA()
        gtk_widget_get_color(widget, &color)
        return Self.color(color)
    }

    /// `rgba` as the tree writes a colour.
    static func color(_ rgba: GdkRGBA) -> Color {
        let channel = { (value: Float) in Int((value * 255).rounded()) }
        return Color(red: channel(rgba.red), green: channel(rgba.green), blue: channel(rgba.blue), alpha: channel(rgba.alpha))
    }

    /// Where a button's picture stands by its words: across or down the box, first or last.
    private static func position(in button: GTKButtonView) -> IconPosition? {
        guard let box = button.pictureAndCaption, let picture = button.picture else { return nil }
        let first = gtk_widget_get_first_child(box) == picture.widget
        return gtk_orientable_get_orientation(box.opaque) == GTK_ORIENTATION_HORIZONTAL
            ? (first ? .leading : .trailing) : (first ? .top : .bottom)
    }

    /// How a label's words break, as it wraps them or cuts them.
    static func lineBreak(of label: OpaquePointer) -> LineBreak {
        if gtk_label_get_wrap(label) != 0 {
            return gtk_label_get_wrap_mode(label) == PANGO_WRAP_CHAR ? .characterWrap : .wordWrap
        }
        return switch gtk_label_get_ellipsize(label) {
        case PANGO_ELLIPSIZE_START: .headTruncation
        case PANGO_ELLIPSIZE_MIDDLE: .middleTruncation
        case PANGO_ELLIPSIZE_END: .tailTruncation
        default: .noWrap
        }
    }

    /// Whether a press at `point` reaches `element`: what GTK picks there in the window - through everything laid
    /// over it - is its view or stands in it.
    func reaches(_ element: MountedElement, at point: Point) throws -> Bool {
        guard let view = (element.native as? GTKElement)?.view, let root = gtk_widget_get_root(view.widget) else {
            throw DriverCannot("read what reaches \(element.type.name)")
        }
        renderer?.layOut()
        let window = UnsafeMutableRawPointer(root).assumingMemoryBound(to: GtkWidget.self)
        var from = graphene_point_t(x: Float(point.x), y: Float(point.y))
        var at = graphene_point_t()
        guard gtk_widget_compute_point(view.widget, window, &from, &at) != 0,
              let picked = gtk_widget_pick(window, Double(at.x), Double(at.y), GTK_PICK_DEFAULT)
        else { return false }
        return picked == view.widget || gtk_widget_is_ancestor(picked, view.widget) != 0
    }

    /// Chooses the item at `place` as the user's click does, through the list's own `list.select-item`: alone where
    /// one may be chosen, beside those chosen - as a Ctrl click - where many may.
    private func choose(_ place: Int, in items: GTKItemsView, on element: MountedElement) throws {
        guard let list = items.list, let mode = items.choiceMode, mode != .none else {
            throw DriverCannot(.choose(place), on: element)
        }
        var parts = [g_variant_new_uint32(guint32(place)), g_variant_new_boolean(mode == .multiple ? 1 : 0),
                     g_variant_new_boolean(0)]
        _ = gtk_widget_activate_action_variant(list, "list.select-item", g_variant_new_tuple(&parts, 3))
    }

    /// Moves the scrolled window in `view` to `offset`, as a wheel does: through its adjustments, which hold it
    /// within what it shows - laid out first, as a frame lays out what the user sees before they scroll it.
    private func scroll(_ view: GTKView, to offset: Point, on element: MountedElement, _ act: UserAct) throws {
        renderer?.layOut()
        var child = gtk_widget_get_first_child(view.widget)
        while let each = child, g_type_check_instance_is_a(each.of(GTypeInstance.self), gtk_scrolled_window_get_type()) == 0 {
            child = gtk_widget_get_first_child(each)
        }
        guard let scrolled = child?.opaque else { throw DriverCannot(act, on: element) }
        gtk_adjustment_set_value(gtk_scrolled_window_get_hadjustment(scrolled), offset.x)
        gtk_adjustment_set_value(gtk_scrolled_window_get_vadjustment(scrolled), offset.y)
    }

    /// Types `words` into `input` as the keyboard leaves them - what does not lead to them chosen and deleted, the
    /// rest typed after what does - through the key bindings' signals of `keys`, which a read-only field refuses.
    private func type(_ words: String, into input: any GTKInputView, keys: OpaquePointer) {
        let kept = words.hasPrefix(input.text) ? input.text : ""
        if kept.isEmpty && !input.text.isEmpty {
            input.select(start: 0, length: input.text.unicodeScalars.count)
            GTKTestHost.emit(keys, "delete-from-cursor", [Double(GTK_DELETE_CHARS.rawValue), 1])
        } else {
            input.select(start: kept.unicodeScalars.count, length: 0)
        }
        GTKTestHost.emit(keys, "insert-at-cursor", words: String(words.dropFirst(kept.count)))
    }
}

extension GTKItemsView {
    /// How many items GTK's choice model lets the user choose, by its kind; nil before there is a list.
    var choiceMode: SelectionMode? {
        guard let selection else { return nil }
        let held = UnsafeMutablePointer<GTypeInstance>(selection)
        if g_type_check_instance_is_a(held, gtk_single_selection_get_type()) != 0 { return .single }
        if g_type_check_instance_is_a(held, gtk_multi_selection_get_type()) != 0 { return .multiple }
        return SelectionMode.none
    }

    /// The identities GTK's choice model holds chosen, in the order the list shows them.
    var chosenIdentities: [String] {
        guard let selection else { return [] }
        let count = g_list_model_get_n_items(selection)
        return (0..<count).filter { gtk_selection_model_is_selected(selection, $0) != 0 }.map { identity(at: $0) }
    }
}

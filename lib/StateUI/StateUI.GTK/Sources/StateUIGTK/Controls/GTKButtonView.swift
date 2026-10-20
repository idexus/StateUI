// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A `GtkButton`: its caption, its picture and how they look, whether it takes a press, the press going down and
/// let go, and the click it raises.
/// Design: docs/design/platforms/gtk/controls.md#a-buttons-picture
@MainActor
final class GTKButtonView: GTKView {
    /// What the button does when the user clicks it, presses it and lets the press go.
    var onClicked: (() -> Void)?
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?

    /// The gesture a press and its end come through, wherever it ends.
    let press: OpaquePointer

    /// How the button opens its menu, which makes its control: GTK's button - holding a menu opened as it is held -
    /// its menu button, or libadwaita's split button.
    let opening: ButtonMenuOpening

    /// A button, or one that stays pressed in while what it turns on is on - or, holding a menu, GTK's menu button
    /// opening it, libadwaita's split button, its click its own and its menu behind the arrow, or GTK's button
    /// opening it as it is held.
    /// Design: docs/design/views/controls.md#a-buttons-menu
    init(toggles: Bool = false, menu opening: ButtonMenuOpening = .none) {
        press = gtk_gesture_drag_new()!
        self.opening = opening
        super.init { _ in
            switch opening {
            case .none, .hold: toggles ? gtk_toggle_button_new() : gtk_button_new()
            case .click: gtk_menu_button_new()
            case .arrow: adw_split_button_new()
            }
        }
        if opening == .click { gtk_menu_button_set_always_show_arrow(widget.opaque, 1) }
        if opening != .click {
            connect("clicked") { _, data in
                MainActor.assumeIsolated { GTKView.find(viewNumber(data))?.clicked() }
            }
        }
        connectSignal(UnsafeMutableRawPointer(press), "drag-begin", number: number) { (_, _: Double, _: Double, data) in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKButtonView)?.onPressed?() }
        }
        connectSignal(UnsafeMutableRawPointer(press), "drag-end", number: number) { (_, _: Double, _: Double, data) in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKButtonView)?.onReleased?() }
        }
        gtk_widget_add_controller(widget, press)
    }

    /// The controller holding the button's keyboard shortcut, across its whole window; nil until it states one.
    private(set) var shortcuts: OpaquePointer?

    /// The shortcut the button states, which its controller's action asks of before it presses.
    private var stated: KeyboardShortcut?

    /// libadwaita's class for the button's role; nil for none.
    private var roleClass: String?

    /// What the button stands for, as libadwaita draws it: the suggested action, or a destructive one; the way out
    /// has no look of its own.
    func setRole(_ role: ButtonRole?) {
        swapClass(&roleClass, to: role == .primary ? "suggested-action" : role == .destructive ? "destructive-action" : nil)
    }

    /// The keys pressing the button while its window is in front: GTK's own shortcut, global to the window,
    /// activating the button; nil for none.
    /// Design: docs/design/types/keyboard.md#on-each-platform
    func setShortcut(_ shortcut: KeyboardShortcut?) {
        let controller = shortcuts ?? {
            let made = gtk_shortcut_controller_new()!
            gtk_shortcut_controller_set_scope(made, GTK_SHORTCUT_SCOPE_GLOBAL)
            gtk_widget_add_controller(widget, made)
            return made
        }()
        shortcuts = controller
        while g_list_model_get_n_items(controller) > 0, let first = g_list_model_get_item(controller, 0) {
            gtk_shortcut_controller_remove_shortcut(controller, OpaquePointer(first))
            g_object_unref(first)
        }
        stated = shortcut
        guard let shortcut else { return }
        let spelled = GTKKeys.spelled(shortcut)
        let presses = gtk_callback_action_new({ _, _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKButtonView)?.shortcutPressed() == true ? 1 : 0 }
        }, UnsafeMutableRawPointer(bitPattern: Int(number)), nil)
        gtk_shortcut_controller_add_shortcut(
            controller, gtk_shortcut_new(gtk_keyval_trigger_new(spelled.keyval, spelled.modifiers), presses))
    }

    /// The button pressed by its shortcut, where it can be - unless the shortcut gives way to typing while a field
    /// is typed into, when the key goes on to the field. Whether it took the key.
    private func shortcutPressed() -> Bool {
        guard gtk_widget_is_sensitive(widget) != 0 else { return false }
        if let stated, KeyboardShortcuts.givesWayToTyping(stated), GTKKeys.typing(in: widget) { return false }
        return gtk_widget_activate(widget) != 0
    }

    /// The key value and mask of the shortcut the button's controller holds; nil for none - what a test reads.
    var shortcutForTesting: (keyval: guint, modifiers: GdkModifierType)? {
        guard let shortcut = heldShortcut, let trigger = gtk_shortcut_get_trigger(shortcut) else { return nil }
        return (gtk_keyval_trigger_get_keyval(trigger), gtk_keyval_trigger_get_modifiers(trigger))
    }

    /// Runs the action of the shortcut the button's controller holds, as the controller runs it for its key.
    func runShortcutForTesting() {
        guard let shortcut = heldShortcut else { return }
        _ = gtk_shortcut_action_activate(gtk_shortcut_get_action(shortcut), GTK_SHORTCUT_ACTION_EXCLUSIVE, widget, nil)
    }

    private var heldShortcut: OpaquePointer? {
        guard let shortcuts, g_list_model_get_n_items(shortcuts) > 0, let first = g_list_model_get_item(shortcuts, 0)
        else { return nil }
        g_object_unref(first)
        return OpaquePointer(first)
    }

    /// How the caption's words look.
    private(set) var look = TextLook()

    /// The style sheet's class drawing the button's box.
    private var boxClass: String?

    /// The caption, and how it breaks; nil for GTK's own, one line.
    private var caption = ""
    private var lineBreak: LineBreak?

    /// The picture beside the caption or in its place, where it stands, how far from the words, and how it fills its
    /// room; nil for none.
    private(set) var picture: GTKImageView?
    private var position = IconPosition.start
    private var spacing: Double?

    /// What the button shows: its caption's label, its picture, or the two in a box.
    private var child: GTKWidget? {
        switch opening {
        case .none, .hold: gtk_button_get_child(widget.of(GtkButton.self))
        case .click: gtk_menu_button_get_child(widget.opaque)
        case .arrow: adw_split_button_get_child(widget.opaque)
        }
    }

    private func setChild(_ child: GTKWidget?) {
        switch opening {
        case .none, .hold: gtk_button_set_child(widget.of(GtkButton.self), child)
        case .click: gtk_menu_button_set_child(widget.opaque, child)
        case .arrow: adw_split_button_set_child(widget.opaque, child)
        }
    }

    /// Words alone: GTK's own label for a button, a label of the host's on one holding a menu.
    private func setLabel(_ text: String) {
        guard opening == .click || opening == .arrow else { return gtk_button_set_label(widget.of(GtkButton.self), text) }
        if let label = child, Self.isLabel(label) { return gtk_label_set_text(label.opaque, text) }
        setChild(gtk_label_new(text))
    }

    /// The menu a button holding one opens, its actions on the button.
    private(set) var menu: GTKMenu?

    /// Gives a button holding a menu `menu`, where it stands otherwise than the one it shows.
    func setMenu(_ menu: GTKMenu) {
        if opening == .none || self.menu.map(menu.stands(like:)) == true { return }
        self.menu = menu
        switch opening {
        case .click: gtk_menu_button_set_menu_model(widget.opaque, g_menu_model(menu.model))
        case .arrow: adw_split_button_set_menu_model(widget.opaque, g_menu_model(menu.model))
        case .hold:
            if let held { held.show(menu) } else { held = GTKContextMenu(menu, on: widget, heldByMouse: true) }
        case .none: break
        }
        gtk_widget_insert_action_group(widget, menu.group, OpaquePointer(menu.actions))
    }

    /// The menu a held button opens, where it is held or clicked with the secondary button; one let go is taken off.
    private var held: GTKContextMenu? {
        didSet { if held !== oldValue { oldValue?.remove() } }
    }

    /// Whether a menu button shows the arrow saying its click opens the menu.
    var showsArrow: Bool {
        get { opening == .click && gtk_menu_button_get_always_show_arrow(widget.opaque) != 0 }
        set { if opening == .click { gtk_menu_button_set_always_show_arrow(widget.opaque, newValue ? 1 : 0) } }
    }

    /// The caption's label beside the picture, or the one GTK makes for words alone; nil for a picture alone.
    var captionLabel: OpaquePointer? {
        guard let child else { return nil }
        if Self.isLabel(child) { return child.opaque }
        var each = gtk_widget_get_first_child(child)
        while let widget = each, !Self.isLabel(widget) { each = gtk_widget_get_next_sibling(widget) }
        return each?.opaque
    }

    /// The box holding the picture and the caption; nil where the button shows one alone.
    var pictureAndCaption: GTKWidget? {
        guard picture != nil, !caption.isEmpty else { return nil }
        return child
    }

    /// The caption.
    func setText(_ text: String) {
        let hadWords = !caption.isEmpty
        caption = text
        guard picture != nil else {
            setLabel(text)
            return writeWords()
        }
        if hadWords == text.isEmpty { return compose() }
        if let label = captionLabel { gtk_label_set_text(label, text) }
    }

    /// Changes how the caption's words look.
    func setLook(_ change: (inout TextLook) -> Void) {
        change(&look)
        writeWords()
    }

    /// How a caption too long for the button breaks; nil for GTK's own, one line.
    func setLineBreak(_ lineBreak: LineBreak?) {
        self.lineBreak = lineBreak
        writeWords()
    }

    /// The picture `source` names beside the caption - before it, after it, above or below it, `spacing` apart,
    /// libadwaita's 6 where it is nil - or in its place where there are no words, filling the room as `aspect`
    /// says; none shows the caption alone.
    func setPicture(_ source: HostPicture?, position: IconPosition, spacing: Double?, aspect: ContentMode) {
        guard let source else {
            guard picture != nil else { return }
            picture = nil
            gtk_widget_remove_css_class(widget, "image-button")
            gtk_widget_remove_css_class(widget, "image-text-button")
            setLabel(caption)
            return writeWords()
        }
        let picture = self.picture ?? GTKImageView()
        self.picture = picture
        picture.apply(picture: source, aspect: aspect)
        (self.position, self.spacing) = (position, spacing)
        compose()
    }

    /// Stands the picture alone, or with the caption in a box of their own in the button's middle, however wide it is.
    private func compose() {
        guard let picture else { return }
        setChild(nil)
        let alone = caption.isEmpty
        gtk_widget_remove_css_class(widget, alone ? "image-text-button" : "image-button")
        gtk_widget_add_css_class(widget, alone ? "image-button" : "image-text-button")
        guard !alone else {
            setChild(picture.widget)
            return writeWords()
        }

        let across = position == .start || position == .end
        let box = gtk_box_new(across ? GTK_ORIENTATION_HORIZONTAL : GTK_ORIENTATION_VERTICAL, Int32((spacing ?? 6).rounded()))!
        gtk_widget_set_direction(box, gtk_widget_get_direction(widget))
        gtk_widget_set_halign(box, GTK_ALIGN_CENTER)
        let label = gtk_label_new(caption)!
        let first = position == .start || position == .top
        for part in first ? [picture.widget, label] : [label, picture.widget] {
            gtk_box_append(box.of(GtkBox.self), part)
        }
        setChild(box)
        writeWords()
    }

    /// Writes the look and the break on the label the button shows its caption in, and its colour on the icon.
    private func writeWords() {
        picture?.wordsColor = look.color.flatMap(GTKBrush.rgba)
        guard let label = captionLabel else { return }
        let list = pango_attr_list_new()!
        look.insert(into: list)
        gtk_label_set_attributes(label, list)
        pango_attr_list_unref(list)
        GTKTextualView.setLines(of: label, breaking: lineBreak ?? .noWrap, maximum: nil)
    }

    private static func isLabel(_ widget: GTKWidget) -> Bool {
        g_type_check_instance_is_a(widget.of(GTypeInstance.self), gtk_label_get_type()) != 0
    }

    /// The button's box - its fill, its outline's colour and width, and its shape - as a class of the host's style
    /// sheet; what is nil stays the platform's.
    /// Design: docs/design/platforms/gtk/controls.md#a-buttons-box
    func setBox(fill: HostValue?, stroke: HostValue?, lineWidth: Double?, shape: HostValue?) {
        let drawn = GTKStyleSheet.box(
            fill: fill.flatMap { GTKBrush($0).firstColor }, stroke: stroke.flatMap { GTKBrush($0).firstColor },
            lineWidth: stroke == nil ? nil : BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth),
            shape: shape.map(BoxArithmetic.outline))
        guard drawn != boxClass else { return }
        if let boxClass { gtk_widget_remove_css_class(widget, boxClass) }
        if let drawn { gtk_widget_add_css_class(widget, drawn) }
        boxClass = drawn
    }

    /// A picture in place of the caption, `size` logical pixels across - or before it, where `showsCaption` - the
    /// caption the button's name to assistive technology, and its tooltip while it is not shown. Whether there was
    /// such a picture.
    @discardableResult
    func setIcon(_ picture: HostPicture, size: Int32, caption: String, showsCaption: Bool = false) -> Bool {
        guard let image = GTKPictures.icon(picture, size: size) else { return false }
        if showsCaption {
            let content = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
            gtk_box_append(content.of(GtkBox.self), image)
            gtk_box_append(content.of(GtkBox.self), gtk_label_new(caption))
            setChild(content)
            gtk_widget_add_css_class(widget, "image-text-button")
        } else {
            setChild(image)
            gtk_widget_add_css_class(widget, "image-button")
            gtk_widget_set_tooltip_text(widget, caption)
        }

        var property = GTK_ACCESSIBLE_PROPERTY_LABEL
        var name = GValue()
        g_value_init(&name, g_type_from_name("gchararray"))
        g_value_set_string(&name, caption)
        gtk_accessible_update_property_value(widget.opaque, 1, &property, &name)
        g_value_unset(&name)
        return true
    }

    /// The caption the button shows now, read back from GTK.
    var text: String {
        captionLabel.flatMap { gtk_label_get_text($0) }.map { String(cString: $0) } ?? ""
    }

    /// The picture and the caption stand in the button's direction too.
    override func setDirection(_ direction: GtkTextDirection) {
        super.setDirection(direction)
        if let child { gtk_widget_set_direction(child, direction) }
    }

    override func clicked() {
        onClicked?()
    }

    override func detach() {
        super.detach()
        held = nil
        (onClicked, onPressed, onReleased) = (nil, nil, nil)
    }
}

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

    /// A button, or one that stays pressed in while what it turns on is on.
    init(toggles: Bool = false) {
        press = gtk_gesture_drag_new()!
        super.init { _ in toggles ? gtk_toggle_button_new() : gtk_button_new() }
        connect("clicked") { _, data in
            MainActor.assumeIsolated { GTKView.find(viewNumber(data))?.clicked() }
        }
        connectSignal(UnsafeMutableRawPointer(press), "drag-begin", number: number) { (_, _: Double, _: Double, data) in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKButtonView)?.onPressed?() }
        }
        connectSignal(UnsafeMutableRawPointer(press), "drag-end", number: number) { (_, _: Double, _: Double, data) in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKButtonView)?.onReleased?() }
        }
        gtk_widget_add_controller(widget, press)
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
    private var position = IconPosition.leading
    private var spacing: Double?

    /// The caption's label beside the picture, or the one GTK makes for words alone; nil for a picture alone.
    var captionLabel: OpaquePointer? {
        guard let child = gtk_button_get_child(widget.of(GtkButton.self)) else { return nil }
        if Self.isLabel(child) { return child.opaque }
        var each = gtk_widget_get_first_child(child)
        while let widget = each, !Self.isLabel(widget) { each = gtk_widget_get_next_sibling(widget) }
        return each?.opaque
    }

    /// The box holding the picture and the caption; nil where the button shows one alone.
    var pictureAndCaption: GTKWidget? {
        guard picture != nil, !caption.isEmpty else { return nil }
        return gtk_button_get_child(widget.of(GtkButton.self))
    }

    /// The caption.
    func setText(_ text: String) {
        let hadWords = !caption.isEmpty
        caption = text
        guard picture != nil else {
            gtk_button_set_label(widget.of(GtkButton.self), text)
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
    func setPicture(_ source: ImageSource?, position: IconPosition, spacing: Double?, aspect: ContentMode) {
        guard let source, !source.isEmpty else {
            guard picture != nil else { return }
            picture = nil
            gtk_widget_remove_css_class(widget, "image-button")
            gtk_widget_remove_css_class(widget, "image-text-button")
            gtk_button_set_label(widget.of(GtkButton.self), caption)
            return writeWords()
        }
        let picture = self.picture ?? GTKImageView()
        self.picture = picture
        picture.apply(source: source, aspect: aspect)
        (self.position, self.spacing) = (position, spacing)
        compose()
    }

    /// Stands the picture alone, or with the caption in a box of their own in the button's middle, however wide it is.
    private func compose() {
        guard let picture else { return }
        gtk_button_set_child(widget.of(GtkButton.self), nil)
        let alone = caption.isEmpty
        gtk_widget_remove_css_class(widget, alone ? "image-text-button" : "image-button")
        gtk_widget_add_css_class(widget, alone ? "image-button" : "image-text-button")
        guard !alone else { return gtk_button_set_child(widget.of(GtkButton.self), picture.widget) }

        let across = position == .leading || position == .trailing
        let box = gtk_box_new(across ? GTK_ORIENTATION_HORIZONTAL : GTK_ORIENTATION_VERTICAL, Int32((spacing ?? 6).rounded()))!
        gtk_widget_set_direction(box, gtk_widget_get_direction(widget))
        gtk_widget_set_halign(box, GTK_ALIGN_CENTER)
        let label = gtk_label_new(caption)!
        let first = position == .leading || position == .top
        for part in first ? [picture.widget, label] : [label, picture.widget] {
            gtk_box_append(box.of(GtkBox.self), part)
        }
        gtk_button_set_child(widget.of(GtkButton.self), box)
        writeWords()
    }

    /// Writes the look and the break on the label the button shows its caption in.
    private func writeWords() {
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
        let radius: Double? = switch shape.map(BoxArithmetic.outline) {
        case .roundedRectangle(let radius)?: radius
        case .ellipse?: 9999
        case .rectangle?: 0
        case nil: nil
        }
        let drawn = GTKStyleSheet.box(
            fill: fill.flatMap { GTKBrush($0).firstColor }, stroke: stroke.flatMap { GTKBrush($0).firstColor },
            lineWidth: stroke == nil ? nil : BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth),
            radius: radius)
        guard drawn != boxClass else { return }
        if let boxClass { gtk_widget_remove_css_class(widget, boxClass) }
        if let drawn { gtk_widget_add_css_class(widget, drawn) }
        boxClass = drawn
    }

    /// A picture in place of the caption, `size` logical pixels across - or before it, where `showsCaption` - the
    /// caption the button's name to assistive technology, and its tooltip while it is not shown. Whether there was
    /// such a picture.
    @discardableResult
    func setIcon(_ name: String, size: Int32, caption: String, showsCaption: Bool = false) -> Bool {
        guard let image = GTKPictures.icon(named: name, size: size) else { return false }
        if showsCaption {
            let content = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
            gtk_box_append(content.of(GtkBox.self), image)
            gtk_box_append(content.of(GtkBox.self), gtk_label_new(caption))
            gtk_button_set_child(widget.of(GtkButton.self), content)
            gtk_widget_add_css_class(widget, "image-text-button")
        } else {
            gtk_button_set_child(widget.of(GtkButton.self), image)
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
        if let content = gtk_button_get_child(widget.of(GtkButton.self)) { gtk_widget_set_direction(content, direction) }
    }

    override func clicked() {
        onClicked?()
    }

    override func detach() {
        super.detach()
        (onClicked, onPressed, onReleased) = (nil, nil, nil)
    }
}

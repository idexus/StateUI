// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A link: a `GtkLinkButton` holding no address, its words in the theme's link color or the one the tree gives. Its
/// `activate-link` is the host's: the host layer opens the link's address as the user chooses it.
/// Design: docs/design/platforms/gtk/controls.md#a-link
@MainActor
final class GTKLinkView: GTKView {
    /// What a click does: the host layer opens the link's address.
    var onClicked: (() -> Void)?

    /// How the words look.
    private(set) var look = TextLook()

    init() {
        super.init { _ in gtk_link_button_new("") }
        connectAnswering(UnsafeMutableRawPointer(widget), "activate-link", number: number) { _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKLinkView)?.onClicked?() }
            // Taken: GTK opens nothing of its own.
            return 1
        }
    }

    /// The words the link shows now, read back from GTK.
    var text: String {
        gtk_button_get_label(widget.of(GtkButton.self)).map { String(cString: $0) } ?? ""
    }

    /// The label holding the words.
    var label: GTKWidget? {
        gtk_button_get_child(widget.of(GtkButton.self))
    }

    /// The words, and how they look.
    func setCaption(_ text: String, look: TextLook) {
        self.look = look
        gtk_button_set_label(widget.of(GtkButton.self), text)
        guard let label else { return }
        let list = pango_attr_list_new()!
        look.insert(into: list)
        gtk_label_set_attributes(label.opaque, list)
        pango_attr_list_unref(list)
    }

    override func detach() {
        super.detach()
        onClicked = nil
    }
}

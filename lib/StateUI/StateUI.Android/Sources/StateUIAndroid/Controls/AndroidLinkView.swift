// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A link: Android has no control of its own for one, so a `TextView` in the theme's link colors - or the color the
/// tree gives - underlined, which a touch and the keyboard choose.
/// Design: docs/design/platforms/android/controls.md#a-link
@MainActor
final class AndroidLinkView: AndroidTextualView {
    /// The view's click is its own - a link's - which a press on it leaves be.
    override var ownsClick: Bool { true }

    /// What a click does: the host layer opens the link's address.
    var onClicked: (() -> Void)?

    init() {
        super.init { _ in
            let link = Java.new(JavaAPI.textView, JavaAPI.newTextView, .object(AndroidRenderer.context))
            // Its words in the theme's link color, dimmed while the link cannot be chosen - the theme's link colors
            // dim nothing - which the view then keeps as its own.
            if let theme = Java.callObject(link.reference, JavaAPI.getLinkTextColors) {
                let argb = Java.callInt(theme, JavaAPI.getDefaultColor)
                Java.release(local: theme)
                let colors = Java.callStaticObject(
                    JavaAPI.views, JavaAPI.textColors, .object(AndroidRenderer.context), .int(argb))
                Java.call(link.reference, JavaAPI.setTextColors, .object(colors))
                Java.release(local: colors)
            }
            return link
        }
        let flags = Java.callInt(reference, JavaAPI.getPaintFlags)
        Java.call(reference, JavaAPI.setPaintFlags, .int(flags | Self.underline))
        Java.call(reference, JavaAPI.setFocusable, .bool(true))
        listen(JavaAPI.setOnClickListener)
    }

    /// `Paint.UNDERLINE_TEXT_FLAG`.
    private static let underline: Int32 = 8

    override func clicked() {
        onClicked?()
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIAndroid

/// The Java classes and methods the host calls, each looked up once, on the main thread.
@MainActor
enum JavaAPI {
    // MARK: - android.view

    static let view = Java.findClass("android/view/View")
    static let viewGroup = Java.findClass("android/view/ViewGroup")
    static let setVisibility = Java.method(view, "setVisibility", "(I)V")
    static let setAlpha = Java.method(view, "setAlpha", "(F)V")
    static let setEnabled = Java.method(view, "setEnabled", "(Z)V")
    static let setBackgroundColor = Java.method(view, "setBackgroundColor", "(I)V")
    static let setPadding = Java.method(view, "setPadding", "(IIII)V")
    static let setOnClickListener = Java.method(
        view, "setOnClickListener", "(Landroid/view/View$OnClickListener;)V")
    static let requestLayout = Java.method(view, "requestLayout", "()V")
    static let measure = Java.method(view, "measure", "(II)V")
    static let layout = Java.method(view, "layout", "(IIII)V")
    static let getMeasuredWidth = Java.method(view, "getMeasuredWidth", "()I")
    static let getMeasuredHeight = Java.method(view, "getMeasuredHeight", "()I")
    static let performClick = Java.method(view, "performClick", "()Z")
    static let removeAllViews = Java.method(viewGroup, "removeAllViews", "()V")
    static let addView = Java.method(viewGroup, "addView", "(Landroid/view/View;II)V")

    // MARK: - android.widget

    static let textView = Java.findClass("android/widget/TextView")
    static let newTextView = Java.method(textView, "<init>", "(Landroid/content/Context;)V")
    static let setText = Java.method(textView, "setText", "(Ljava/lang/CharSequence;)V")
    static let getText = Java.method(textView, "getText", "()Ljava/lang/CharSequence;")
    static let setTextSize = Java.method(textView, "setTextSize", "(IF)V")
    static let getTextSize = Java.method(textView, "getTextSize", "()F")
    static let setTextColor = Java.method(textView, "setTextColor", "(I)V")
    static let getTextColors = Java.method(textView, "getTextColors", "()Landroid/content/res/ColorStateList;")
    static let setTextColors = Java.method(
        textView, "setTextColor", "(Landroid/content/res/ColorStateList;)V")
    static let setTypeface = Java.method(textView, "setTypeface", "(Landroid/graphics/Typeface;I)V")
    static let setAllCaps = Java.method(textView, "setAllCaps", "(Z)V")

    static let button = Java.findClass("android/widget/Button")
    static let newButton = Java.method(button, "<init>", "(Landroid/content/Context;)V")

    // MARK: - java.lang

    static let object = Java.findClass("java/lang/Object")
    static let toString = Java.method(object, "toString", "()Ljava/lang/String;")

    // MARK: - The host's own classes

    static let viewGroupHost = Java.findClass("stateui/android/StateUIViewGroup")
    static let newViewGroupHost = Java.method(
        viewGroupHost, "<init>", "(Landroid/content/Context;J)V")
    static let setChildren = Java.method(viewGroupHost, "setChildren", "([Landroid/view/View;)V")

    static let click = Java.findClass("stateui/android/StateUIClick")
    static let newClick = Java.method(click, "<init>", "(J)V")
}

/// The constants of `android.view.View` the host passes.
enum ViewConstants {
    /// `View.VISIBLE`.
    static let visible: Int32 = 0

    /// `View.GONE`.
    static let gone: Int32 = 8

    /// `TypedValue.COMPLEX_UNIT_PX` and `COMPLEX_UNIT_SP`: a text size in pixels, and one the user's font scale applies to.
    static let pixels: Int32 = 0
    static let scaledPixels: Int32 = 2

    /// `MeasureSpec.UNSPECIFIED`, `EXACTLY` and `AT_MOST`, in the spec's two top bits.
    static let unspecified: Int32 = 0
    static let exactly: Int32 = 0x4000_0000
    static let atMost: Int32 = Int32(bitPattern: 0x8000_0000)

    /// The spec's mode and size.
    static func mode(_ spec: Int32) -> Int32 { spec & Int32(bitPattern: 0xC000_0000) }
    static func size(_ spec: Int32) -> Int32 { spec & 0x3FFF_FFFF }

    /// A spec of `mode` and `size`.
    static func spec(_ mode: Int32, _ size: Int32) -> Int32 { mode | (max(0, size) & 0x3FFF_FFFF) }
}

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
    static let getBackground = Java.method(view, "getBackground", "()Landroid/graphics/drawable/Drawable;")
    static let setBackground = Java.method(view, "setBackground", "(Landroid/graphics/drawable/Drawable;)V")
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

    static let setHint = Java.method(textView, "setHint", "(Ljava/lang/CharSequence;)V")
    static let setHintTextColor = Java.method(textView, "setHintTextColor", "(I)V")
    static let getHintTextColors = Java.method(
        textView, "getHintTextColors", "()Landroid/content/res/ColorStateList;")
    static let setHintTextColors = Java.method(
        textView, "setHintTextColor", "(Landroid/content/res/ColorStateList;)V")
    static let setInputType = Java.method(textView, "setInputType", "(I)V")
    static let getSelectionStart = Java.method(textView, "getSelectionStart", "()I")
    static let getSelectionEnd = Java.method(textView, "getSelectionEnd", "()I")
    static let addTextChangedListener = Java.method(
        textView, "addTextChangedListener", "(Landroid/text/TextWatcher;)V")
    static let setOnEditorActionListener = Java.method(
        textView, "setOnEditorActionListener", "(Landroid/widget/TextView$OnEditorActionListener;)V")

    static let button = Java.findClass("android/widget/Button")
    static let newButton = Java.method(button, "<init>", "(Landroid/content/Context;)V")

    static let editText = Java.findClass("android/widget/EditText")
    static let newEditText = Java.method(editText, "<init>", "(Landroid/content/Context;)V")
    static let setSelection = Java.method(editText, "setSelection", "(II)V")

    static let compoundButton = Java.findClass("android/widget/CompoundButton")
    static let setChecked = Java.method(compoundButton, "setChecked", "(Z)V")
    static let isChecked = Java.method(compoundButton, "isChecked", "()Z")
    static let setOnCheckedChangeListener = Java.method(
        compoundButton, "setOnCheckedChangeListener", "(Landroid/widget/CompoundButton$OnCheckedChangeListener;)V")

    static let switchView = Java.findClass("android/widget/Switch")
    static let newSwitch = Java.method(switchView, "<init>", "(Landroid/content/Context;)V")

    static let progressBar = Java.findClass("android/widget/ProgressBar")
    static let setMax = Java.method(progressBar, "setMax", "(I)V")
    static let setProgress = Java.method(progressBar, "setProgress", "(I)V")
    static let getProgress = Java.method(progressBar, "getProgress", "()I")
    static let setProgressTintList = Java.method(
        progressBar, "setProgressTintList", "(Landroid/content/res/ColorStateList;)V")
    static let getProgressTintList = Java.method(
        progressBar, "getProgressTintList", "()Landroid/content/res/ColorStateList;")

    static let seekBar = Java.findClass("android/widget/SeekBar")
    static let newSeekBar = Java.method(seekBar, "<init>", "(Landroid/content/Context;)V")
    static let setOnSeekBarChangeListener = Java.method(
        seekBar, "setOnSeekBarChangeListener", "(Landroid/widget/SeekBar$OnSeekBarChangeListener;)V")
    static let setThumbTintList = Java.method(
        seekBar, "setThumbTintList", "(Landroid/content/res/ColorStateList;)V")
    static let getThumbTintList = Java.method(
        seekBar, "getThumbTintList", "()Landroid/content/res/ColorStateList;")

    // MARK: - android.content.res

    static let colorStateList = Java.findClass("android/content/res/ColorStateList")
    static let colorStateListOf = Java.staticMethod(
        colorStateList, "valueOf", "(I)Landroid/content/res/ColorStateList;")

    // MARK: - java.lang

    static let object = Java.findClass("java/lang/Object")
    static let toString = Java.method(object, "toString", "()Ljava/lang/String;")

    // MARK: - The host's own classes

    static let viewGroupHost = Java.findClass("stateui/android/StateUIViewGroup")
    static let newViewGroupHost = Java.method(
        viewGroupHost, "<init>", "(Landroid/content/Context;J)V")
    static let setChildren = Java.method(viewGroupHost, "setChildren", "([Landroid/view/View;)V")

    static let listener = Java.findClass("stateui/android/StateUIListener")
    static let newListener = Java.method(listener, "<init>", "(J)V")
}

/// The constants of Android's views the host passes.
enum ViewConstants {
    /// `View.VISIBLE`.
    static let visible: Int32 = 0

    /// `View.GONE`.
    static let gone: Int32 = 8

    /// `InputType.TYPE_CLASS_TEXT`, and its variation that hides what is typed.
    static let textInput: Int32 = 0x1
    static let passwordInput: Int32 = 0x80

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

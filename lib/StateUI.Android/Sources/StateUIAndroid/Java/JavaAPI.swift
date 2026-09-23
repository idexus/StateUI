// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIAndroid

/// The Java classes and methods the host calls, each looked up once, on the main thread.
@MainActor
enum JavaAPI {
    // MARK: - android.view

    static let view = Java.findClass("android/view/View")
    static let newView = Java.method(view, "<init>", "(Landroid/content/Context;)V")
    static let viewGroup = Java.findClass("android/view/ViewGroup")
    static let setVisibility = Java.method(view, "setVisibility", "(I)V")
    static let getVisibility = Java.method(view, "getVisibility", "()I")
    static let setAlpha = Java.method(view, "setAlpha", "(F)V")
    static let getAlpha = Java.method(view, "getAlpha", "()F")
    static let setTranslationX = Java.method(view, "setTranslationX", "(F)V")
    static let setTranslationY = Java.method(view, "setTranslationY", "(F)V")
    static let setRotation = Java.method(view, "setRotation", "(F)V")
    static let setRotationX = Java.method(view, "setRotationX", "(F)V")
    static let setRotationY = Java.method(view, "setRotationY", "(F)V")
    static let setScaleX = Java.method(view, "setScaleX", "(F)V")
    static let setScaleY = Java.method(view, "setScaleY", "(F)V")
    static let setPivotX = Java.method(view, "setPivotX", "(F)V")
    static let setPivotY = Java.method(view, "setPivotY", "(F)V")
    static let resetPivot = Java.method(view, "resetPivot", "()V")
    static let getLeft = Java.method(view, "getLeft", "()I")
    static let getTop = Java.method(view, "getTop", "()I")
    static let getWidth = Java.method(view, "getWidth", "()I")
    static let getHeight = Java.method(view, "getHeight", "()I")
    static let setEnabled = Java.method(view, "setEnabled", "(Z)V")
    static let setBackgroundColor = Java.method(view, "setBackgroundColor", "(I)V")
    static let getBackground = Java.method(view, "getBackground", "()Landroid/graphics/drawable/Drawable;")
    static let setBackground = Java.method(view, "setBackground", "(Landroid/graphics/drawable/Drawable;)V")
    static let setPadding = Java.method(view, "setPadding", "(IIII)V")
    static let getPaddingLeft = Java.method(view, "getPaddingLeft", "()I")
    static let getPaddingTop = Java.method(view, "getPaddingTop", "()I")
    static let getPaddingRight = Java.method(view, "getPaddingRight", "()I")
    static let getPaddingBottom = Java.method(view, "getPaddingBottom", "()I")
    static let setForeground = Java.method(view, "setForeground", "(Landroid/graphics/drawable/Drawable;)V")
    static let setClipToOutline = Java.method(view, "setClipToOutline", "(Z)V")
    static let invalidateOutline = Java.method(view, "invalidateOutline", "()V")
    static let invalidate = Java.method(view, "invalidate", "()V")
    static let setOnClickListener = Java.method(
        view, "setOnClickListener", "(Landroid/view/View$OnClickListener;)V")
    static let requestLayout = Java.method(view, "requestLayout", "()V")
    static let measure = Java.method(view, "measure", "(II)V")
    static let layout = Java.method(view, "layout", "(IIII)V")
    static let getMeasuredWidth = Java.method(view, "getMeasuredWidth", "()I")
    static let getMeasuredHeight = Java.method(view, "getMeasuredHeight", "()I")
    static let performClick = Java.method(view, "performClick", "()Z")
    static let choreographer = Java.findClass("android/view/Choreographer")
    static let choreographerInstance = Java.staticMethod(
        choreographer, "getInstance", "()Landroid/view/Choreographer;")
    static let postFrameCallback = Java.method(
        choreographer, "postFrameCallback", "(Landroid/view/Choreographer$FrameCallback;)V")
    static let removeAllViews = Java.method(viewGroup, "removeAllViews", "()V")
    static let addView = Java.method(viewGroup, "addView", "(Landroid/view/View;II)V")
    static let removeView = Java.method(viewGroup, "removeView", "(Landroid/view/View;)V")
    static let setClipChildren = Java.method(viewGroup, "setClipChildren", "(Z)V")
    static let getParent = Java.method(view, "getParent", "()Landroid/view/ViewParent;")
    static let scrollTo = Java.method(view, "scrollTo", "(II)V")
    static let getScrollX = Java.method(view, "getScrollX", "()I")
    static let getScrollY = Java.method(view, "getScrollY", "()I")
    static let getLocationInWindow = Java.method(view, "getLocationInWindow", "([I)V")
    static let setOnScrollChangeListener = Java.method(
        view, "setOnScrollChangeListener", "(Landroid/view/View$OnScrollChangeListener;)V")
    static let setOnTouchListener = Java.method(view, "setOnTouchListener", "(Landroid/view/View$OnTouchListener;)V")
    static let setVerticalScrollBarEnabled = Java.method(view, "setVerticalScrollBarEnabled", "(Z)V")
    static let setHorizontalScrollBarEnabled = Java.method(view, "setHorizontalScrollBarEnabled", "(Z)V")
    static let setScrollbarFadingEnabled = Java.method(view, "setScrollbarFadingEnabled", "(Z)V")
    static let getViewTreeObserver = Java.method(view, "getViewTreeObserver", "()Landroid/view/ViewTreeObserver;")
    static let viewTreeObserver = Java.findClass("android/view/ViewTreeObserver")
    static let addOnGlobalLayoutListener = Java.method(
        viewTreeObserver, "addOnGlobalLayoutListener", "(Landroid/view/ViewTreeObserver$OnGlobalLayoutListener;)V")
    static let addOnScrollChangedListener = Java.method(
        viewTreeObserver, "addOnScrollChangedListener", "(Landroid/view/ViewTreeObserver$OnScrollChangedListener;)V")

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

    static let scrollView = Java.findClass("android/widget/ScrollView")
    static let newScrollView = Java.method(scrollView, "<init>", "(Landroid/content/Context;)V")
    static let setFillViewport = Java.method(scrollView, "setFillViewport", "(Z)V")
    static let horizontalScrollView = Java.findClass("android/widget/HorizontalScrollView")
    static let newHorizontalScrollView = Java.method(horizontalScrollView, "<init>", "(Landroid/content/Context;)V")
    static let setHorizontalFillViewport = Java.method(horizontalScrollView, "setFillViewport", "(Z)V")

    static let imageView = Java.findClass("android/widget/ImageView")
    static let newImageView = Java.method(imageView, "<init>", "(Landroid/content/Context;)V")
    static let setImageBitmap = Java.method(imageView, "setImageBitmap", "(Landroid/graphics/Bitmap;)V")
    static let setScaleType = Java.method(imageView, "setScaleType", "(Landroid/widget/ImageView$ScaleType;)V")
    static let setCropToPadding = Java.method(imageView, "setCropToPadding", "(Z)V")
    static let scaleType = Java.findClass("android/widget/ImageView$ScaleType")

    // MARK: - android.graphics

    static let bitmap = Java.findClass("android/graphics/Bitmap")
    static let bitmapWidth = Java.method(bitmap, "getWidth", "()I")
    static let bitmapHeight = Java.method(bitmap, "getHeight", "()I")
    static let bitmapFactory = Java.findClass("android/graphics/BitmapFactory")
    static let decodeStream = Java.staticMethod(
        bitmapFactory, "decodeStream",
        "(Ljava/io/InputStream;Landroid/graphics/Rect;Landroid/graphics/BitmapFactory$Options;)Landroid/graphics/Bitmap;")
    static let bitmapOptions = Java.findClass("android/graphics/BitmapFactory$Options")
    static let newBitmapOptions = Java.method(bitmapOptions, "<init>", "()V")
    static let inDensity = Java.field(bitmapOptions, "inDensity", "I")
    static let inTargetDensity = Java.field(bitmapOptions, "inTargetDensity", "I")
    static let inScaled = Java.field(bitmapOptions, "inScaled", "Z")

    // MARK: - android.content

    static let contextClass = Java.findClass("android/content/Context")
    static let getAssets = Java.method(contextClass, "getAssets", "()Landroid/content/res/AssetManager;")
    static let assetManager = Java.findClass("android/content/res/AssetManager")
    static let openAsset = Java.method(assetManager, "open", "(Ljava/lang/String;)Ljava/io/InputStream;")
    static let listAssets = Java.method(assetManager, "list", "(Ljava/lang/String;)[Ljava/lang/String;")
    static let inputStream = Java.findClass("java/io/InputStream")
    static let close = Java.method(inputStream, "close", "()V")

    // MARK: - android.animation

    static let valueAnimator = Java.findClass("android/animation/ValueAnimator")
    static let areAnimatorsEnabled = Java.staticMethod(valueAnimator, "areAnimatorsEnabled", "()Z")

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

    static let frameCallback = Java.findClass("stateui/android/StateUIFrameCallback")
    static let newFrameCallback = Java.method(frameCallback, "<init>", "()V")

    static let listener = Java.findClass("stateui/android/StateUIListener")
    static let newListener = Java.method(listener, "<init>", "(J)V")

    static let shapeDrawable = Java.findClass("stateui/android/StateUIShapeDrawable")
    static let newShapeDrawable = Java.method(shapeDrawable, "<init>", "()V")
    static let setShape = Java.method(shapeDrawable, "setShape", "(I[F)V")
    static let setFill = Java.method(shapeDrawable, "setFill", "(I[I[F[F)V")
    static let setStroke = Java.method(shapeDrawable, "setStroke", "(IF)V")
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

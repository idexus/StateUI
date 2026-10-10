// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIAndroid
import StateUI

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
    static let getLeft = Java.method(view, "getLeft", "()I")
    static let getTop = Java.method(view, "getTop", "()I")
    static let getWidth = Java.method(view, "getWidth", "()I")
    static let getHeight = Java.method(view, "getHeight", "()I")
    static let getRight = Java.method(view, "getRight", "()I")
    static let getBottom = Java.method(view, "getBottom", "()I")
    static let setEnabled = Java.method(view, "setEnabled", "(Z)V")
    static let setBackgroundColor = Java.method(view, "setBackgroundColor", "(I)V")
    static let getBackground = Java.method(view, "getBackground", "()Landroid/graphics/drawable/Drawable;")
    static let setBackground = Java.method(view, "setBackground", "(Landroid/graphics/drawable/Drawable;)V")
    static let colorDrawable = Java.findClass("android/graphics/drawable/ColorDrawable")
    static let newColorDrawable = Java.method(colorDrawable, "<init>", "(I)V")
    static let setPadding = Java.method(view, "setPadding", "(IIII)V")
    static let getPaddingLeft = Java.method(view, "getPaddingLeft", "()I")
    static let getPaddingTop = Java.method(view, "getPaddingTop", "()I")
    static let getPaddingRight = Java.method(view, "getPaddingRight", "()I")
    static let getPaddingBottom = Java.method(view, "getPaddingBottom", "()I")
    static let setForeground = Java.method(view, "setForeground", "(Landroid/graphics/drawable/Drawable;)V")
    static let setLayoutDirection = Java.method(view, "setLayoutDirection", "(I)V")
    static let setClipToOutline = Java.method(view, "setClipToOutline", "(Z)V")
    static let invalidateOutline = Java.method(view, "invalidateOutline", "()V")
    static let invalidate = Java.method(view, "invalidate", "()V")
    static let setOnClickListener = Java.method(
        view, "setOnClickListener", "(Landroid/view/View$OnClickListener;)V")
    static let requestLayout = Java.method(view, "requestLayout", "()V")
    static let measure = Java.method(view, "measure", "(II)V")
    static let layout = Java.method(view, "layout", "(IIII)V")
    static let performClick = Java.method(view, "performClick", "()Z")
    static let choreographer = Java.findClass("android/view/Choreographer")
    static let choreographerInstance = Java.staticMethod(
        choreographer, "getInstance", "()Landroid/view/Choreographer;")
    static let postFrameCallback = Java.method(
        choreographer, "postFrameCallback", "(Landroid/view/Choreographer$FrameCallback;)V")
    static let removeAllViews = Java.method(viewGroup, "removeAllViews", "()V")
    static let addView = Java.method(viewGroup, "addView", "(Landroid/view/View;II)V")
    static let removeView = Java.method(viewGroup, "removeView", "(Landroid/view/View;)V")
    static let bringToFront = Java.method(view, "bringToFront", "()V")
    static let setClipChildren = Java.method(viewGroup, "setClipChildren", "(Z)V")
    static let getParent = Java.method(view, "getParent", "()Landroid/view/ViewParent;")
    static let scrollTo = Java.method(view, "scrollTo", "(II)V")
    static let getScrollX = Java.method(view, "getScrollX", "()I")
    static let getScrollY = Java.method(view, "getScrollY", "()I")
    static let getLocationInWindow = Java.method(view, "getLocationInWindow", "([I)V")
    static let setOnScrollChangeListener = Java.method(
        view, "setOnScrollChangeListener", "(Landroid/view/View$OnScrollChangeListener;)V")
    static let setOnTouchListener = Java.method(view, "setOnTouchListener", "(Landroid/view/View$OnTouchListener;)V")
    static let setOnHoverListener = Java.method(view, "setOnHoverListener", "(Landroid/view/View$OnHoverListener;)V")
    static let setOnFocusChangeListener = Java.method(
        view, "setOnFocusChangeListener", "(Landroid/view/View$OnFocusChangeListener;)V")
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
    static let typeface = Java.findClass("android/graphics/Typeface")
    static let createTypeface = Java.staticMethod(
        typeface, "create", "(Ljava/lang/String;I)Landroid/graphics/Typeface;")
    static let setAllCaps = Java.method(textView, "setAllCaps", "(Z)V")

    static let setMaxLines = Java.method(textView, "setMaxLines", "(I)V")
    static let getPaint = Java.method(textView, "getPaint", "()Landroid/text/TextPaint;")
    static let getCompoundPaddingLeft = Java.method(textView, "getCompoundPaddingLeft", "()I")
    static let getCompoundPaddingRight = Java.method(textView, "getCompoundPaddingRight", "()I")
    static let getCompoundDrawablePadding = Java.method(textView, "getCompoundDrawablePadding", "()I")
    static let measureText = Java.method(Java.findClass("android/graphics/Paint"), "measureText", "(Ljava/lang/String;)F")
    static let getCompoundPaddingTop = Java.method(textView, "getCompoundPaddingTop", "()I")
    static let getCompoundPaddingBottom = Java.method(textView, "getCompoundPaddingBottom", "()I")
    static let getIncludeFontPadding = Java.method(textView, "getIncludeFontPadding", "()Z")
    static let paint = Java.findClass("android/graphics/Paint")
    static let getFontMetricsInt = Java.method(paint, "getFontMetricsInt", "()Landroid/graphics/Paint$FontMetricsInt;")
    static let fontMetricsInt = Java.findClass("android/graphics/Paint$FontMetricsInt")
    static let metricsTop = Java.field(fontMetricsInt, "top", "I")
    static let metricsBottom = Java.field(fontMetricsInt, "bottom", "I")
    static let metricsAscent = Java.field(fontMetricsInt, "ascent", "I")
    static let metricsDescent = Java.field(fontMetricsInt, "descent", "I")
    static let setEllipsize = Java.method(textView, "setEllipsize", "(Landroid/text/TextUtils$TruncateAt;)V")
    static let setHorizontallyScrolling = Java.method(textView, "setHorizontallyScrolling", "(Z)V")
    static let setGravity = Java.method(textView, "setGravity", "(I)V")
    static let getGravity = Java.method(textView, "getGravity", "()I")
    static let setLetterSpacing = Java.method(textView, "setLetterSpacing", "(F)V")
    static let setLineSpacing = Java.method(textView, "setLineSpacing", "(FF)V")
    static let getPaintFlags = Java.method(textView, "getPaintFlags", "()I")
    static let setPaintFlags = Java.method(textView, "setPaintFlags", "(I)V")
    static let truncateAt = Java.findClass("android/text/TextUtils$TruncateAt")

    static let setHint = Java.method(textView, "setHint", "(Ljava/lang/CharSequence;)V")
    static let setHintTextColor = Java.method(textView, "setHintTextColor", "(I)V")
    static let getHintTextColors = Java.method(
        textView, "getHintTextColors", "()Landroid/content/res/ColorStateList;")
    static let setHintTextColors = Java.method(
        textView, "setHintTextColor", "(Landroid/content/res/ColorStateList;)V")
    static let setInputType = Java.method(textView, "setInputType", "(I)V")
    static let setKeyListener = Java.method(textView, "setKeyListener", "(Landroid/text/method/KeyListener;)V")
    static let setShowSoftInputOnFocus = Java.method(textView, "setShowSoftInputOnFocus", "(Z)V")
    static let setImeOptions = Java.method(textView, "setImeOptions", "(I)V")
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

    static let setButtonTintList = Java.method(
        compoundButton, "setButtonTintList", "(Landroid/content/res/ColorStateList;)V")
    static let getButtonTintList = Java.method(
        compoundButton, "getButtonTintList", "()Landroid/content/res/ColorStateList;")
    static let dialogs = Java.findClass("stateui/android/StateUIDialogs")
    static let alert = Java.staticMethod(
        dialogs, "alert", "(Landroid/content/Context;JLjava/lang/String;Ljava/lang/String;Ljava/lang/String;)V")
    static let confirm = Java.staticMethod(
        dialogs, "confirm",
        "(Landroid/content/Context;JLjava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V")
    static let chooseAction = Java.staticMethod(
        dialogs, "chooseAction",
        "(Landroid/content/Context;JLjava/lang/String;Ljava/lang/String;Ljava/lang/String;[Ljava/lang/String;)V")
    static let prompt = Java.staticMethod(
        dialogs, "prompt",
        "(Landroid/content/Context;JLjava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;IILjava/lang/String;)V")

    static let drags = Java.findClass("stateui/android/StateUIDrags")
    static let offerDrag = Java.staticMethod(drags, "offer", "(Landroid/view/View;JLjava/lang/String;ZZ)V")

    static let files = Java.findClass("stateui/android/StateUIFiles")
    static let openFiles = Java.staticMethod(files, "open", "(Landroid/content/Context;J[Ljava/lang/String;Z)V")
    static let saveFile = Java.staticMethod(
        files, "save", "(Landroid/content/Context;JLjava/lang/String;Ljava/lang/String;[B)V")
    static let readFile = Java.staticMethod(files, "read", "(Landroid/content/Context;JLjava/lang/String;J)V")
    static let launch = Java.staticMethod(files, "launch", "(Landroid/content/Context;JLjava/lang/String;Z)V")

    static let store = Java.findClass("stateui/android/StateUIStore")
    static let readStore = Java.staticMethod(
        store, "read", "(Landroid/content/Context;[Ljava/lang/String;)[Ljava/lang/String;")
    static let writeStore = Java.staticMethod(
        store, "write", "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)V")

    static let focus = Java.staticMethod(views, "focus", "(Landroid/view/View;Z)Z")
    static let groundSidebar = Java.staticMethod(views, "groundSidebar", "(Landroid/view/View;ZZI)V")
    static let sheet = Java.staticMethod(
        views, "sheet", "(Landroid/content/Context;Landroid/view/View;)Landroid/widget/FrameLayout;")
    static let rise = Java.staticMethod(views, "rise", "(Landroid/view/ViewGroup;Landroid/view/View;ZJ)V")
    static let announceForAccessibility = Java.method(view, "announceForAccessibility", "(Ljava/lang/CharSequence;)V")

    static let dateField = Java.findClass("stateui/android/StateUIDateField")
    static let newDateField = Java.method(dateField, "<init>", "(Landroid/content/Context;JZ)V")
    static let setFieldDate = Java.method(dateField, "setDate", "(III)V")
    static let setFieldTime = Java.method(dateField, "setTime", "(II)V")
    static let setFieldRange = Java.method(dateField, "setRange", "([I[I)V")
    static let setFieldFormat = Java.method(dateField, "setFormat", "(Ljava/lang/String;)V")
    static let setFieldOpen = Java.method(dateField, "setOpen", "(Z)V")

    static let webView = Java.findClass("stateui/android/StateUIWebView")
    static let newWebView = Java.method(webView, "<init>", "(Landroid/content/Context;J)V")
    static let loadWeb = Java.method(webView, "load", "(Ljava/lang/String;Ljava/lang/String;)V")
    static let showWeb = Java.method(webView, "show", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V")
    static let setWebUserAgent = Java.method(webView, "setUserAgent", "(Ljava/lang/String;)V")
    static let webGoBack = Java.method(webView, "goBack", "()Z")
    static let webGoForward = Java.method(webView, "goForward", "()Z")
    static let webReload = Java.method(webView, "reload", "()V")
    static let watchWeb = Java.method(webView, "watch", "(Lstateui/android/StateUIListener;)V")
    static let webEvaluate = Java.method(webView, "evaluate", "(Ljava/lang/String;J)V")
    static let releaseWeb = Java.method(webView, "release", "()V")

    static let canvasView = Java.findClass("stateui/android/StateUICanvasView")
    static let newCanvasView = Java.method(canvasView, "<init>", "(Landroid/content/Context;JF)V")
    static let setDrawing = Java.method(canvasView, "setDrawing", "([I[F[Ljava/lang/String;)V")

    static let shapeView = Java.findClass("stateui/android/StateUIShapeView")
    static let newShapeView = Java.method(shapeView, "<init>", "(Landroid/content/Context;)V")
    static let setShapeGeometry = Java.method(shapeView, "setGeometry", "(I[FZ)V")
    static let setShapeCorners = Java.method(shapeView, "setCorners", "([F)V")
    static let setShapeFill = Java.method(shapeView, "setFill", "(I[I[F[F)V")
    static let setShapeStroke = Java.method(shapeView, "setStroke", "(IF[FFIIF)V")
    static let setShapePlacing = Java.method(shapeView, "setPlacing", "([F)V")
    static let shapeGeometryBounds = Java.method(shapeView, "geometryBounds", "()[F")

    static let picker = Java.findClass("stateui/android/StateUIPicker")
    static let newPicker = Java.method(picker, "<init>", "(Landroid/content/Context;J)V")
    static let setChoices = Java.method(picker, "setChoices", "([Ljava/lang/String;Ljava/lang/String;IZ)V")
    static let setPickerLook = Java.method(picker, "setLook", "(FIILandroid/graphics/Typeface;I)V")
    static let openList = Java.method(picker, "openList", "()V")
    static let setBackgroundTintList = Java.method(
        view, "setBackgroundTintList", "(Landroid/content/res/ColorStateList;)V")
    static let getBackgroundTintList = Java.method(
        view, "getBackgroundTintList", "()Landroid/content/res/ColorStateList;")

    static let radioButton = Java.findClass("android/widget/RadioButton")
    static let newRadioButton = Java.method(radioButton, "<init>", "(Landroid/content/Context;)V")
    static let checkBox = Java.findClass("android/widget/CheckBox")
    static let newCheckBox = Java.method(checkBox, "<init>", "(Landroid/content/Context;)V")

    static let switchView = Java.findClass("android/widget/Switch")
    static let newSwitch = Java.method(switchView, "<init>", "(Landroid/content/Context;)V")

    static let progressBar = Java.findClass("android/widget/ProgressBar")
    static let newProgressBar = Java.method(progressBar, "<init>", "(Landroid/content/Context;)V")
    static let newStyledProgressBar = Java.method(
        progressBar, "<init>", "(Landroid/content/Context;Landroid/util/AttributeSet;I)V")
    static let setIndeterminate = Java.method(progressBar, "setIndeterminate", "(Z)V")
    static let setIndeterminateTintList = Java.method(
        progressBar, "setIndeterminateTintList", "(Landroid/content/res/ColorStateList;)V")
    static let getIndeterminateTintList = Java.method(
        progressBar, "getIndeterminateTintList", "()Landroid/content/res/ColorStateList;")
    static let setMax = Java.method(progressBar, "setMax", "(I)V")
    static let setProgress = Java.method(progressBar, "setProgress", "(IZ)V")
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
    static let setImageDrawable = Java.method(imageView, "setImageDrawable", "(Landroid/graphics/drawable/Drawable;)V")
    static let bitmapDrawable = Java.findClass("android/graphics/drawable/BitmapDrawable")
    static let newBitmapDrawable = Java.method(
        bitmapDrawable, "<init>", "(Landroid/content/res/Resources;Landroid/graphics/Bitmap;)V")
    static let setTargetDensity = Java.method(bitmapDrawable, "setTargetDensity", "(I)V")
    static let setScaleType = Java.method(imageView, "setScaleType", "(Landroid/widget/ImageView$ScaleType;)V")
    static let setCropToPadding = Java.method(imageView, "setCropToPadding", "(Z)V")
    static let scaleType = Java.findClass("android/widget/ImageView$ScaleType")

    // MARK: - android.graphics

    static let bitmap = Java.findClass("android/graphics/Bitmap")
    static let bitmapWidth = Java.method(bitmap, "getWidth", "()I")
    static let bitmapHeight = Java.method(bitmap, "getHeight", "()I")
    static let setBitmapDensity = Java.method(bitmap, "setDensity", "(I)V")
    static let bitmapFactory = Java.findClass("android/graphics/BitmapFactory")
    static let decodeStream = Java.staticMethod(
        bitmapFactory, "decodeStream",
        "(Ljava/io/InputStream;Landroid/graphics/Rect;Landroid/graphics/BitmapFactory$Options;)Landroid/graphics/Bitmap;")
    static let bitmapOptions = Java.findClass("android/graphics/BitmapFactory$Options")
    static let newBitmapOptions = Java.method(bitmapOptions, "<init>", "()V")
    static let inDensity = Java.field(bitmapOptions, "inDensity", "I")
    static let inTargetDensity = Java.field(bitmapOptions, "inTargetDensity", "I")
    static let inScaled = Java.field(bitmapOptions, "inScaled", "Z")
    static let inSampleSize = Java.field(bitmapOptions, "inSampleSize", "I")
    static let inJustDecodeBounds = Java.field(bitmapOptions, "inJustDecodeBounds", "Z")
    static let outWidth = Java.field(bitmapOptions, "outWidth", "I")
    static let outHeight = Java.field(bitmapOptions, "outHeight", "I")

    static let linearLayout = Java.findClass("android/widget/LinearLayout")
    static let newLinearLayout = Java.method(linearLayout, "<init>", "(Landroid/content/Context;)V")
    static let stepper = Java.findClass("stateui/android/StateUIStepper")
    static let newStepper = Java.method(stepper, "<init>", "(Landroid/content/Context;)V")
    static let watchStepper = Java.method(stepper, "watch", "(Lstateui/android/StateUIListener;)V")
    static let setMinWidth = Java.method(textView, "setMinWidth", "(I)V")
    static let setMinimumWidth = Java.method(view, "setMinimumWidth", "(I)V")
    static let setMinHeight = Java.method(textView, "setMinHeight", "(I)V")
    static let setMinimumHeight = Java.method(view, "setMinimumHeight", "(I)V")
    static let setClickable = Java.method(view, "setClickable", "(Z)V")
    static let isLongClickable = Java.method(view, "isLongClickable", "()Z")
    static let getImportantForAccessibility = Java.method(view, "getImportantForAccessibility", "()I")
    static let setLongClickable = Java.method(view, "setLongClickable", "(Z)V")
    static let setOnCreateContextMenuListener = Java.method(
        view, "setOnCreateContextMenuListener", "(Landroid/view/View$OnCreateContextMenuListener;)V")

    // MARK: - android.text

    static let spannableBuilder = Java.findClass("android/text/SpannableStringBuilder")
    static let newSpannableBuilder = Java.method(spannableBuilder, "<init>", "()V")
    static let append = Java.method(
        spannableBuilder, "append", "(Ljava/lang/CharSequence;)Landroid/text/SpannableStringBuilder;")
    static let setSpan = Java.method(spannableBuilder, "setSpan", "(Ljava/lang/Object;III)V")
    static let foregroundSpan = Java.findClass("android/text/style/ForegroundColorSpan")
    static let newForegroundSpan = Java.method(foregroundSpan, "<init>", "(I)V")
    static let backgroundSpan = Java.findClass("android/text/style/BackgroundColorSpan")
    static let newBackgroundSpan = Java.method(backgroundSpan, "<init>", "(I)V")
    static let sizeSpan = Java.findClass("android/text/style/AbsoluteSizeSpan")
    static let newSizeSpan = Java.method(sizeSpan, "<init>", "(IZ)V")
    static let styleSpan = Java.findClass("android/text/style/StyleSpan")
    static let newStyleSpan = Java.method(styleSpan, "<init>", "(I)V")
    static let typefaceSpan = Java.findClass("android/text/style/TypefaceSpan")
    static let newTypefaceSpan = Java.method(typefaceSpan, "<init>", "(Landroid/graphics/Typeface;)V")
    static let underlineSpan = Java.findClass("android/text/style/UnderlineSpan")
    static let newUnderlineSpan = Java.method(underlineSpan, "<init>", "()V")
    static let strikethroughSpan = Java.findClass("android/text/style/StrikethroughSpan")
    static let newStrikethroughSpan = Java.method(strikethroughSpan, "<init>", "()V")

    // MARK: - android.content

    static let contextClass = Java.findClass("android/content/Context")
    static let getResources = Java.method(contextClass, "getResources", "()Landroid/content/res/Resources;")
    static let getClassLoader = Java.method(contextClass, "getClassLoader", "()Ljava/lang/ClassLoader;")
    static let resources = Java.findClass("android/content/res/Resources")
    static let getDisplayMetrics = Java.method(resources, "getDisplayMetrics", "()Landroid/util/DisplayMetrics;")
    static let typedValue = Java.findClass("android/util/TypedValue")
    static let applyDimension = Java.staticMethod(typedValue, "applyDimension", "(IFLandroid/util/DisplayMetrics;)F")
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
    static let string = Java.findClass("java/lang/String")
    static let toString = Java.method(object, "toString", "()Ljava/lang/String;")

    // MARK: - The host's own classes

    static let viewGroupHost = Java.findClass("stateui/android/StateUIViewGroup")
    static let newViewGroupHost = Java.method(
        viewGroupHost, "<init>", "(Landroid/content/Context;J)V")
    static let setChildren = Java.method(viewGroupHost, "setChildren", "([Landroid/view/View;)V")
    static let setIgnoresInput = Java.method(viewGroupHost, "setIgnoresInput", "(Z)V")

    static let itemCell = Java.findClass("stateui/android/StateUIItemCell")
    static let newItemCell = Java.method(itemCell, "<init>", "(Landroid/content/Context;JZ)V")

    static let itemsView = Java.findClass("stateui/android/StateUIItemsView")
    static let newItemsView = Java.method(itemsView, "<init>", "(Landroid/content/Context;J)V")
    static let setItemsEntries = Java.method(itemsView, "setEntries", "([Ljava/lang/String;[I[I[I[I[IZ)V")
    static let setItemsPlacement = Java.method(itemsView, "setPlacement", "(II[I[I)V")
    static let setItemsChoice = Java.method(itemsView, "setChoice", "([Ljava/lang/String;IZ)V")
    static let scrollToItem = Java.method(itemsView, "scrollToItem", "(Ljava/lang/String;IZ)V")
    static let releaseItems = Java.method(itemsView, "release", "()V")
    static let scrollItemsAlong = Java.method(itemsView, "scrollAlong", "(I)V")
    static let itemsScrolled = Java.method(itemsView, "scrolled", "()I")
    static let itemsChosen = Java.method(itemsView, "chosen", "()[Ljava/lang/String;")
    static let itemsMode = Java.method(itemsView, "mode", "()I")

    static let frameCallback = Java.findClass("stateui/android/StateUIFrameCallback")
    static let newFrameCallback = Java.method(frameCallback, "<init>", "()V")

    static let listener = Java.findClass("stateui/android/StateUIListener")
    static let newListener = Java.method(listener, "<init>", "(J)V")
    static let setGestures = Java.method(listener, "setGestures", "(Landroid/view/View;FZZZZ)V")

    static let viewConfiguration = Java.findClass("android/view/ViewConfiguration")
    static let viewConfigurationOf = Java.staticMethod(
        viewConfiguration, "get", "(Landroid/content/Context;)Landroid/view/ViewConfiguration;")
    static let scaledTouchSlop = Java.method(viewConfiguration, "getScaledTouchSlop", "()I")

    static let environment = Java.findClass("stateui/android/StateUIEnvironment")
    static let clock = Java.staticMethod(environment, "clock", "()[I")
    static let zone = Java.staticMethod(environment, "zone", "()Ljava/lang/String;")
    static let utcOffset = Java.staticMethod(environment, "utcOffset", "(Ljava/lang/String;III)I")
    static let hideKeyboard = Java.staticMethod(environment, "hideKeyboard", "(Landroid/view/View;)Z")
    static let useNightMode = Java.staticMethod(environment, "useNightMode", "(Landroid/content/Context;I)V")
    static let accent = Java.staticMethod(environment, "accent", "(Landroid/content/Context;)I")
    static let setWindowBackground = Java.staticMethod(
        environment, "windowBackground", "(Landroid/content/Context;IZ)V")
    static let setWindowTitle = Java.staticMethod(
        environment, "title", "(Landroid/content/Context;Ljava/lang/String;)V")
    static let deviceFacts = Java.staticMethod(environment, "device", "(Landroid/content/Context;)[Ljava/lang/String;")
    static let displayFacts = Java.staticMethod(environment, "display", "(Landroid/app/Activity;)[F")
    static let applicationFacts = Java.staticMethod(
        environment, "application", "(Landroid/content/Context;)[Ljava/lang/String;")
    static let localeFacts = Java.staticMethod(environment, "locale", "(Landroid/content/Context;)[Ljava/lang/String;")
    static let batteryFacts = Java.staticMethod(environment, "battery", "(Landroid/content/Context;)[F")
    static let connectivityFacts = Java.staticMethod(environment, "connectivity", "(Landroid/content/Context;)[I")

    static let bar = Java.findClass("stateui/android/StateUIBar")
    static let newBar = Java.method(bar, "<init>", "(Landroid/content/Context;JI)V")
    static let showBar = Java.method(bar, "show", "(Ljava/lang/String;Ljava/lang/String;II)V")
    static let setBarNavigation = Java.method(
        bar, "setNavigation", "(ILandroid/graphics/Bitmap;ILjava/lang/String;)V")
    static let setBarTitleView = Java.method(bar, "setTitleView", "(Landroid/view/View;)V")
    static let setBarActions = Java.method(
        bar, "setActions", "([I[Ljava/lang/String;[Landroid/graphics/Bitmap;)V")

    static let menus = Java.findClass("stateui/android/StateUIMenus")
    static let fillMenu = Java.staticMethod(
        menus, "fill",
        "(Landroid/content/Context;Landroid/view/Menu;J[I[Ljava/lang/String;[Landroid/graphics/Bitmap;I)V")

    static let androidActivity = Java.findClass("android/app/Activity")
    static let activity = Java.findClass("stateui/android/StateUIActivity")
    static let setHandlesBack = Java.method(activity, "setHandlesBack", "(Z)V")

    static let views = Java.findClass("stateui/android/StateUIViews")
    static let measureView = Java.staticMethod(views, "measure", "(Landroid/view/View;II)J")
    static let placeView = Java.staticMethod(views, "place", "(Landroid/view/View;IIII)V")
    static let pressable = Java.staticMethod(
        views, "pressable",
        "(Landroid/content/Context;Lstateui/android/StateUIShapeDrawable;Landroid/graphics/drawable/Drawable;)Landroid/graphics/drawable/Drawable;")
    static let setAccessibility = Java.staticMethod(
        views, "setAccessibility", "(Landroid/view/View;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;ZI)V")
    static let textColors = Java.staticMethod(
        views, "textColors", "(Landroid/content/Context;I)Landroid/content/res/ColorStateList;")
    static let setIcon = Java.staticMethod(views, "setIcon", "(Landroid/widget/TextView;Landroid/graphics/Bitmap;IIII)V")
    static let transformView = Java.staticMethod(views, "transform", "(Landroid/view/View;FFFFFFFFF)V")
    static let slideView = Java.staticMethod(views, "slide", "(Landroid/view/View;FFJI)V")

    static let tabs = Java.findClass("stateui/android/StateUITabs")
    static let newTabs = Java.method(tabs, "<init>", "(Landroid/content/Context;J)V")
    static let setTabs = Java.method(
        tabs, "setTabs", "([Ljava/lang/String;[Landroid/graphics/Bitmap;IIII)V")
    static let setDrawingOrder = Java.method(viewGroupHost, "setDrawingOrder", "([I)V")

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

    /// `View.INVISIBLE`: not drawn, its room kept.
    static let invisible: Int32 = 4

    /// `View.GONE`.
    static let gone: Int32 = 8

    /// `InputType.TYPE_CLASS_TEXT`, its variation that hides what is typed, and its flag for several lines.
    static let textInput: Int32 = 0x1
    static let passwordInput: Int32 = 0x80
    static let multiLineInput: Int32 = 0x20000

    /// `InputType`'s text variations for an address and a link, and its text flags: capitals at each sentence,
    /// correction as the user types, and no suggestions.
    static let emailInput: Int32 = 0x20
    static let linkInput: Int32 = 0x10
    static let sentenceCapitals: Int32 = 0x4000
    static let autoCorrect: Int32 = 0x8000
    static let noSuggestions: Int32 = 0x80000

    /// `InputType.TYPE_CLASS_NUMBER` with its decimal flag and its hidden variation, and `TYPE_CLASS_PHONE`.
    static let numberInput: Int32 = 0x2
    static let decimalNumber: Int32 = 0x2000
    static let hiddenNumber: Int32 = 0x10
    static let phoneInput: Int32 = 0x3


    /// `TypedValue.COMPLEX_UNIT_PX`, `COMPLEX_UNIT_DIP` and `COMPLEX_UNIT_SP`: a text size in pixels, in points the
    /// user's font scale leaves, and in points it applies to.
    static let pixels: Int32 = 0
    static let independentPixels: Int32 = 1
    static let scaledPixels: Int32 = 2

    /// `MeasureSpec.UNSPECIFIED`, `EXACTLY` and `AT_MOST`, in the spec's two top bits.
    static let unspecified: Int32 = 0
    static let exactly: Int32 = 0x4000_0000
    static let atMost: Int32 = Int32(bitPattern: 0x8000_0000)
    static let modes: Int32 = Int32(bitPattern: 0xC000_0000)

    /// The spec's mode and size.
    static func mode(_ spec: Int32) -> Int32 { spec & Int32(bitPattern: 0xC000_0000) }
    static func size(_ spec: Int32) -> Int32 { spec & 0x3FFF_FFFF }

    /// A spec of `mode` and `size`.
    static func spec(_ mode: Int32, _ size: Int32) -> Int32 { mode | (max(0, size) & 0x3FFF_FFFF) }

    /// `Gravity`'s bits across - `START`, `CENTER_HORIZONTAL`, `END`.
    static func gravity(across alignment: TextAlignment) -> Int32 {
        switch alignment {
        case .start: 0x0080_0003
        case .center: 0x01
        case .end: 0x0080_0005
        }
    }

    /// `Gravity.RELATIVE_HORIZONTAL_GRAVITY_MASK`: every bit across.
    static let acrossGravity: Int32 = 0x0080_0007

    /// `Gravity`'s bits down - `TOP`, `CENTER_VERTICAL`, `BOTTOM`.
    static func gravity(down alignment: TextAlignment) -> Int32 {
        switch alignment {
        case .start: 0x30
        case .center: 0x10
        case .end: 0x50
        }
    }
}

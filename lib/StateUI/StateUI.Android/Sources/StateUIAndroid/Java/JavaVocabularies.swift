// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The closed vocabularies the Java relay numbers and this host alone speaks, each the mirror of its Java constants,
// name for name and number for number - `RelayVocabularyTests` reads both sides.
// Design: docs/design/platforms/android/jni.md#numbers-across

/// What the listener heard (`StateUIGestures`).
enum AndroidGestureKind: Int32 {
    case tapped = 0, pinched = 3, entered = 4, exited = 5, moved = 6, pressed = 7, released = 8, buttonPress = 9
}

/// A press's step the listener tells (`StateUIGestures`).
enum AndroidPressPhase: Int32 {
    case down = 0, move = 1, letGo = 2, taken = 3
}

/// What a drag listener heard (`StateUIDrags`).
enum AndroidDragEvent: Int32 {
    case started = 0, ended = 1, over = 2, left = 3, dropped = 4
}

/// A brush's kind (`StateUIBrush`).
enum AndroidBrushKind: Int32 {
    case none = 0, solid = 1, linear = 2, radial = 3
}

/// A drawable's shape (`StateUIShapeDrawable`).
enum AndroidDrawableShape: Int32 {
    case rectangle = 0, rounded = 1, ellipse = 2
}

/// What a shape view draws (`StateUIShapeView`).
enum AndroidShapeKind: Int32 {
    case rectangle = 0, ellipse = 1, drawn = 2
}

/// What a press of a question answers (`StateUIDialogs.answer`): its accepting button, its cancel, an action of
/// its list.
enum AndroidAnswer: Int32 {
    case accept = 0, cancel = 1, action = 2
}

/// What a bar's navigation button does (`StateUIBar`).
enum AndroidBarNavigation: Int32 {
    case none = 0, back = 1, sidebar = 2, close = 3
}

/// A bar's own button apart from its navigation button, by the place it tells the host (`StateUIBar`).
enum AndroidBarButton: Int32 {
    case afterNavigation = 0, atEnd = 1
}

/// An entry of a list (`StateUIItemsView`).
enum AndroidItemKind: Int32 {
    case item = 0, edge = 1
}

/// How a list's entries stand (`StateUIItemsView`).
enum AndroidItemsShape: Int32 {
    case list = 0, row = 1, grid = 2
}

/// A touch on a canvas (`StateUICanvasView`).
enum AndroidCanvasTouch: Int32 {
    case pressed = 0, dragged = 1, released = 2
}

/// A menu's entry, in its lowest bits (`StateUIMenus`).
enum AndroidMenuEntry: Int32 {
    case item = 0, menu = 1, end = 2, separator = 3
}

/// A menu entry's marks (`StateUIMenus`).
enum AndroidMenuMark: Int32 {
    case disabled = 4, destructive = 8, onBar = 16, withText = 32, checkable = 64, checked = 128, counted = 2048
    case label = 4096
}

/// The modifiers an item's shortcut holds (`StateUIMenus`).
enum AndroidMenuModifier: Int32 {
    case control = 256, shift = 512, alt = 1024
}

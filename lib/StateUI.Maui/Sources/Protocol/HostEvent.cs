// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Protocol;

/// <summary>
/// Every event the library's own controls raise - the MAUI event name
/// camelCased, resolved once when the session announces it.
/// </summary>
/// <remarks>
/// <para>
/// <see cref="None"/> is an event an APPLICATION raises from its own
/// registered control, which keeps its spelling in
/// <c>HostPatch.OwnEvents</c> for the same reason a property does.
/// </para>
/// <para>
/// These numbers never cross the wire; see <see cref="HostNodeType"/>.
/// </para>
/// </remarks>
internal enum HostEvent : ushort
{
    /// <summary>A name this runtime has no member for.</summary>
    None = 0,

    Activated = 1,
    Appearing = 2,
    CanGoBackChanged = 3,
    CanGoForwardChanged = 4,
    Clicked = 6,
    Closed = 7,
    Submitted = 8,
    Created = 9,
    CurrentPageChanged = 11,
    DateChanged = 12,
    Deactivated = 13,
    Destroying = 14,
    Disappearing = 15,
    DragCompleted = 16,
    Dragged = 17,
    DragLeave = 18,
    DragOver = 19,
    DragStarted = 20,
    DragStarting = 21,
    Drop = 22,
    DropCompleted = 23,
    FrameChanged = 25,
    PinDetailsClicked = 27,
    IsFocusedChanged = 29,
    IsSidebarVisibleChanged = 30,
    IsRefreshingChanged = 31,
    MapClicked = 33,
    PinClicked = 34,
    ModalPopped = 35,
    Navigated = 36,
    NavigatedFrom = 37,
    NavigatedTo = 38,
    Navigating = 39,
    NavigatingFrom = 40,
    Opened = 41,
    PanUpdated = 42,
    PinchUpdated = 43,
    PointerEntered = 44,
    PointerExited = 45,
    PointerMoved = 46,
    PointerPressed = 47,
    PointerReleased = 48,
    Popped = 49,
    Pressed = 51,
    ProcessTerminated = 52,
    RefreshRequested = 53,
    Released = 54,
    Resumed = 56,
    ScrollStopped = 76,
    ScrollXChanged = 57,
    ScrollYChanged = 58,
    SelectedIndexChanged = 60,
    Stopped = 62,
    SwipeChanging = 63,
    Swiped = 64,
    SwipeEnded = 65,
    SwipeStarted = 66,
    Tapped = 67,
    TextChanged = 68,
    TimeChanged = 69,
    Toggled = 70,
    ValueChanged = 72,
    VisualStateChanged = 73,
    WindowClosed = 77,
    WindowRestored = 78,
}

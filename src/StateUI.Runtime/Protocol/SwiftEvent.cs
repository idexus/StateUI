namespace StateUI.Runtime.Protocol;

/// <summary>
/// Every event the library's own controls raise - the MAUI event name
/// camelCased, resolved once when the session announces it.
/// </summary>
/// <remarks>
/// <para>
/// <see cref="None"/> is an event an APPLICATION raises from its own
/// registered control, which keeps its spelling in
/// <c>SwiftNode.OwnEvents</c> for the same reason a property does.
/// </para>
/// <para>
/// These numbers never cross the wire; see <see cref="SwiftNodeType"/>.
/// </para>
/// </remarks>
internal enum SwiftEvent : ushort
{
    /// <summary>A name this runtime has no member for.</summary>
    None = 0,

    Activated = 1,
    Appearing = 2,
    CanGoBackChanged = 3,
    CanGoForwardChanged = 4,
    CheckedChanged = 5,
    Clicked = 6,
    Closed = 7,
    Completed = 8,
    Created = 9,
    CreatingWindow = 10,
    CurrentPageChanged = 11,
    DateSelected = 12,
    Deactivated = 13,
    Destroying = 14,
    Disappearing = 15,
    DragCompleted = 16,
    DragInteraction = 17,
    DragLeave = 18,
    DragOver = 19,
    DragStarted = 20,
    DragStarting = 21,
    Drop = 22,
    DropCompleted = 23,
    EndInteraction = 24,
    FrameChanged = 25,
    HeightChanged = 26,
    InfoWindowClicked = 27,
    Invoked = 28,
    IsFocusedChanged = 29,
    IsPresentedChanged = 30,
    IsRefreshingChanged = 31,
    Loaded = 32,
    MapClicked = 33,
    MarkerClicked = 34,
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
    Refreshing = 53,
    Released = 54,
    Resumed = 56,
    ScrollGesture = 75,
    ScrollXChanged = 57,
    ScrollYChanged = 58,
    SearchButtonPressed = 59,
    SelectedIndexChanged = 60,
    StartInteraction = 61,
    Stopped = 62,
    SwipeChanging = 63,
    Swiped = 64,
    SwipeEnded = 65,
    SwipeStarted = 66,
    Tapped = 67,
    TextChanged = 68,
    TimeSelected = 69,
    Toggled = 70,
    Unloaded = 71,
    ValueChanged = 72,
    VisualStateChanged = 73,
    WidthChanged = 74,
}

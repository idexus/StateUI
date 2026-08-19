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
    Completed = 7,
    Created = 8,
    CreatingWindow = 9,
    CurrentPageChanged = 10,
    DateSelected = 11,
    Deactivated = 12,
    Destroying = 13,
    Disappearing = 14,
    DragCompleted = 15,
    DragInteraction = 16,
    DragLeave = 17,
    DragOver = 18,
    DragStarted = 19,
    DragStarting = 20,
    Drop = 21,
    DropCompleted = 22,
    EndInteraction = 23,
    FrameChanged = 24,
    HeightChanged = 25,
    InfoWindowClicked = 26,
    Invoked = 27,
    IsFocusedChanged = 28,
    IsPresentedChanged = 29,
    IsRefreshingChanged = 30,
    Loaded = 31,
    MapClicked = 32,
    MarkerClicked = 33,
    ModalPopped = 34,
    Navigated = 35,
    Navigating = 36,
    PanUpdated = 37,
    PinchUpdated = 38,
    PointerEntered = 39,
    PointerExited = 40,
    Popped = 41,
    PointerMoved = 42,
    PointerPressed = 43,
    PointerReleased = 44,
    PositionChanged = 45,
    Pressed = 46,
    ProcessTerminated = 47,
    Refreshing = 48,
    Released = 49,
    Resumed = 50,
    ScrollXChanged = 51,
    ScrollYChanged = 52,
    SearchButtonPressed = 53,
    SelectedIndexChanged = 54,
    StartInteraction = 55,
    Stopped = 56,
    Swiped = 57,
    Tapped = 58,
    TextChanged = 59,
    TimeSelected = 60,
    Toggled = 61,
    Unloaded = 62,
    ValueChanged = 63,
    VisualStateChanged = 64,
    WidthChanged = 65,
}

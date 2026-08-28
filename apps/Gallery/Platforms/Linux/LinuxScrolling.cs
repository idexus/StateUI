using Microsoft.Maui.Platforms.Linux.Gtk4.Handlers;

namespace Gallery;

/// <summary>
/// Lets a scroller that runs ACROSS be as tall as what is in it.
/// </summary>
/// <remarks>
/// <para>
/// A GTK <c>ScrolledWindow</c> asks for no height of its own unless it is told
/// to propagate its child's, and the backend switches that off for every
/// scroller it makes. For one that scrolls DOWN that is right - it should take
/// the room it is given and scroll what does not fit. For one that scrolls
/// ACROSS it means the height is whatever the layout spares, and the content is
/// cut off at that line.
/// </para>
/// <para>
/// Measured in a MAUI app with none of this library in it: three lines of text
/// drew as three lines on their own and as two and a fraction inside a
/// horizontal scroller. In the gallery that is every code listing, each of which
/// showed its first line and no more.
/// </para>
/// </remarks>
internal static class LinuxScrolling
{
    /// <summary>Arms every scroller in the application.</summary>
    /// <remarks>
    /// On the ORIENTATION, which is the property that decides it and the one
    /// that runs again if an author ever changes their mind.
    /// </remarks>
    internal static void Install() =>
        ScrollViewHandler.Mapper.AppendToMapping<IScrollView, ScrollViewHandler>(
            "Orientation",
            (handler, view) =>
                handler.PlatformView?.SetPropagateNaturalHeight(
                    view.Orientation is ScrollOrientation.Horizontal));
}

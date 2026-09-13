using StateUI.Runtime.Rendering;

namespace Gallery;

/// <summary>
/// The application. Almost nothing lives here on purpose.
/// </summary>
/// <remarks>
/// The scenes, their windows, their pages and everything on them are declared
/// in Swift - see <c>Swift/GalleryApp.swift</c> and
/// <c>Swift/Gallery/GalleryScene.swift</c>. Each window the platform asks for is
/// a <see cref="StateUIWindow"/>, which becomes a scene's main window or, when
/// the system restores it, one a scene had open beside its main one. It asks the
/// Swift side what to show and materializes it as native MAUI controls - so the
/// only thing left to say here is which kind of window to open.
/// </remarks>
public class App : Application
{
    protected override Window CreateWindow(IActivationState? activationState)
    {
        return new StateUIWindow();
    }
}

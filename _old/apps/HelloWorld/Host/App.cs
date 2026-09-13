using StateUI.Runtime.Rendering;

namespace HelloWorld;

/// <summary>
/// The application. Almost nothing lives here on purpose.
/// </summary>
/// <remarks>
/// The window, its pages and everything on them are declared in Swift - see
/// <c>Swift/HelloWorldApp.swift</c>. <see cref="StateUIWindow"/> asks the
/// Swift side what to show and materializes it as native MAUI controls, so the
/// only thing left to say here is which kind of window to open.
/// </remarks>
public class App : Application
{
    protected override Window CreateWindow(IActivationState? activationState)
    {
        return new StateUIWindow();
    }
}

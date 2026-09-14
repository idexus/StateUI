using Foundation;
using Microsoft.Maui;

namespace Gallery;

/// <summary>
/// The scene delegate an app needs once it can open more than one window.
/// </summary>
/// <remarks>
/// <para>
/// Nothing of its own - MAUI's <see cref="MauiUISceneDelegate"/> does all of
/// it. What this class exists for is a NAME the Info.plist can point at:
/// <c>UISceneDelegateClassName</c> takes an Objective-C class name, and a
/// registered subclass in the app is the only reliable way to have one (the
/// framework's own type is trimmed out of the app - measured - because a name
/// in a plist is invisible to the linker).
/// </para>
/// <para>
/// Once <c>UIApplicationSceneManifest</c> is in the plist at all, MAUI hands
/// the WHOLE launch to the scene: <c>MauiUIApplicationDelegate.FinishedLaunching</c>
/// creates no window, and the lifecycle events come from the scene too. Without
/// this class the first window opens BLANK, which is exactly what it did.
/// </para>
/// </remarks>
[Register(nameof(SceneDelegate))]
public class SceneDelegate : MauiUISceneDelegate
{
}

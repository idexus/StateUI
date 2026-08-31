// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Diagnostics.CodeAnalysis;
using System.Runtime.Versioning;
using StateUI.Runtime.Linux;

namespace StateUI.Runtime.Hosting;

/// <summary>
/// Hosts an application on this platform.
/// </summary>
/// <remarks>
/// THE SAME SENTENCE EVERY HEAD WRITES - <c>builder.UseStateUIApp&lt;App&gt;()</c> -
/// answered here by the whole of what Linux needs: MAUI's GTK4 backend, its
/// Essentials, and this library's answers to the gaps that backend leaves.
/// The name is the runtime's own, and which of the two assemblies answers it
/// is decided by the packages a head references - <c>StateUI.Linux</c> here,
/// <c>StateUI</c> alone everywhere else - so an application never writes a
/// platform condition to say it.
/// </remarks>
public static class StateUIApp
{
    /// <summary>
    /// Registers the application, the GTK4 platform under it, and the answers
    /// to that platform's gaps.
    /// </summary>
    /// <typeparam name="TApp">The MAUI application class to host.</typeparam>
    /// <param name="builder">The builder to register it on.</param>
    /// <returns>The same builder, so calls can be chained.</returns>
    [SupportedOSPlatform("linux")]
    public static MauiAppBuilder UseStateUIApp<
        [DynamicallyAccessedMembers(DynamicallyAccessedMemberTypes.PublicConstructors)] TApp>(
        this MauiAppBuilder builder)
        where TApp : class, IApplication =>
        LinuxHost.Use<TApp>(builder)
            // The seven shapes are this library's own controls over MAUI's
            // sealed originals - see Rendering/SwiftShapes.cs - and on this
            // platform the base ShapeViewHandler is the GTK backend's, so the
            // one registration serves here too.
            .ConfigureMauiHandlers(Runtime.Rendering.SwiftShapes.AddHandlers);
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Diagnostics.CodeAnalysis;

namespace StateUI.Runtime.Hosting;

/// <summary>
/// Hosts an application on the platform it is being built for.
/// </summary>
/// <remarks>
/// ONE LINE IN EVERY HEAD, whichever platform is under it. Here that is MAUI's
/// own <c>UseMauiApp</c> and nothing else; on Linux the same call is the
/// <c>StateUI.Linux</c> package's, and it brings a whole platform with it -
/// the GTK4 backend's hosting, its Essentials, and this library's answers to
/// what that backend leaves undone. An application says the same sentence
/// either way and carries no platform files of its own.
/// </remarks>
public static class StateUIApp
{
    /// <summary>Registers the application with MAUI.</summary>
    /// <typeparam name="TApp">The MAUI application class to host.</typeparam>
    /// <param name="builder">The builder to register it on.</param>
    /// <returns>The same builder, so calls can be chained.</returns>
    public static MauiAppBuilder UseStateUIApp<
        [DynamicallyAccessedMembers(DynamicallyAccessedMemberTypes.PublicConstructors)] TApp>(
        this MauiAppBuilder builder)
        where TApp : class, IApplication =>
        builder.UseMauiApp<TApp>();
}

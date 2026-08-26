// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using Microsoft.Maui.Storage;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// The application's own places to keep state - a store registered under a
/// name, which the Swift side then names as its <c>persistentStorage</c>.
/// </summary>
/// <remarks>
/// <para>
/// An application that says nothing keeps its state in
/// <see cref="Preferences.Default"/>, the platform's own settings store, and
/// needs none of this. Register one only when the state belongs somewhere else
/// - a file the application versions itself, an encrypted store, a store shared
/// with a service.
/// </para>
/// <code>
/// // C#, MauiProgram.CreateMauiApp:
/// StateUIStores.Add("Gallery.Json", new JsonPreferences(path));
///
/// // Swift, on the Application:
/// var persistentStorage: PersistentStorage { PersistentStorage("Gallery.Json") }
/// </code>
/// <para>
/// A store is an <see cref="IPreferences"/> - MAUI's own interface, the one
/// <see cref="Preferences.Default"/> implements - so there is nothing of this
/// library's to conform to and a store written against MAUI works here
/// unchanged. Only four value types are ever asked of it, the four a kept key
/// can hold: <c>bool</c>, <c>long</c>, <c>double</c> and <c>string</c>.
/// </para>
/// <para>
/// Registration must happen before the first render, which is what
/// <c>MauiProgram.CreateMauiApp</c> is: the store is read once, before the
/// first view is built, and a name that resolves to nothing by then is
/// reported and the kept state stays at its declared values.
/// </para>
/// </remarks>
public static class StateUIStores
{
    /// <summary>The name the Swift side's <c>.preferences</c> carries - the
    /// platform's own store, and the answer to an application that names
    /// none.</summary>
    internal const string PreferencesName = "preferences";

    private static readonly Lock Guard = new();
    private static readonly Dictionary<string, IPreferences> Stores = [];

    /// <summary>
    /// Registers a store under a name. Registering the same name again
    /// replaces the store.
    /// </summary>
    /// <param name="name">The name Swift's <c>PersistentStorage</c> carries.</param>
    /// <param name="store">Where to keep the state.</param>
    public static void Add(string name, IPreferences store)
    {
        lock (Guard)
        {
            Stores[name] = store;
        }
    }

    /// <summary>
    /// The store a name means: the platform's own for <c>"preferences"</c>,
    /// otherwise whatever was registered - and null for a name nobody
    /// registered.
    /// </summary>
    internal static IPreferences? Find(string name)
    {
        if (name == PreferencesName)
        {
            return Preferences.Default;
        }

        lock (Guard)
        {
            return Stores.GetValueOrDefault(name);
        }
    }
}

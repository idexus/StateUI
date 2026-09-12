// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if IOS || MACCATALYST
using Foundation;
using StateUI.Runtime.Protocol;
using UIKit;
#endif

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Where the platform keeps what this library writes down about a scene
/// session, and what a connecting session said.
/// </summary>
/// <remarks>
/// <para>
/// Apple's alone. A <c>UISceneSession</c> is what the system restores a window
/// by, and its <c>UserInfo</c> - written the moment a window is on screen -
/// comes back with it after a quit that keeps the windows AND after a killed
/// process, which gives no warning to write anything in. Elsewhere nothing is
/// kept and a window arrives with no origin.
/// </para>
/// <para>
/// A session says what it is BEFORE the platform asks the app for its window:
/// MAUI's scene delegate raises <c>SceneWillConnect</c> first, and the app's
/// <c>CreateWindow</c> runs inside the same call. So the hook notes the
/// session here, and the window built a moment later takes it - which is the
/// one moment a window can learn whether it is a new scene's main window, a
/// restored one, or a window another scene owns.
/// </para>
/// </remarks>
internal static class SceneSessions
{
    /// <summary>The session a scene's other window belongs to, by the platform's identity.</summary>
    private const string OwnerKey = "stateui.owner";

    /// <summary>A scene's other window's group's kind.</summary>
    private const string KindKey = "stateui.kind";

    /// <summary>A scene's other window's value, as the tree wrote it.</summary>
    private const string ValueKey = "stateui.value";

    /// <summary>A main window's scene's kept values, by name.</summary>
    private const string KeptKey = "stateui.kept";

    /// <summary>What the session connecting right now said, until a window takes it.</summary>
    private static SceneOrigin? _connecting;

    /// <summary>Notes what a connecting session said, for the window about to be built.</summary>
    /// <param name="origin">What it said.</param>
    internal static void Connecting(SceneOrigin origin) => _connecting = origin;

    /// <summary>
    /// What the session connecting right now said, TAKEN - so the next window
    /// is not handed it as well.
    /// </summary>
    /// <returns>The origin; null where no session is connecting.</returns>
    internal static SceneOrigin? Take()
    {
        SceneOrigin? origin = _connecting;
        _connecting = null;
        return origin;
    }

#if IOS || MACCATALYST
    /// <summary>The lifecycle hook's half: a scene session connecting.</summary>
    /// <param name="session">The session.</param>
    internal static void Connecting(UISceneSession session) => Connecting(Read(session));

    /// <summary>What a session holds of this library's.</summary>
    /// <param name="session">The session.</param>
    private static SceneOrigin Read(UISceneSession session)
    {
        NSDictionary<NSString, NSObject>? info = session.UserInfo;

        string? Text(string key) =>
            info?.ObjectForKey(new NSString(key)) is NSString text ? text.ToString() : null;

        List<(string Name, SwiftWireValue Value)> kept = [];

        if (info?.ObjectForKey(new NSString(KeptKey)) is NSDictionary values)
        {
            foreach (NSObject key in values.Keys)
            {
                if (values[key] is NSString text && SceneOrigin.Read(text.ToString()) is SwiftWireValue value)
                {
                    kept.Add((key.ToString(), value));
                }
            }
        }

        // In name order, whatever order the dictionary answers in - so the
        // same session announces the same bytes.
        kept.Sort((one, other) => string.CompareOrdinal(one.Name, other.Name));

        return new SceneOrigin(session.PersistentIdentifier, Text(OwnerKey), Text(KindKey), Text(ValueKey), kept);
    }

    /// <summary>
    /// Writes down what the platform is to keep for a window's session - the
    /// whole of it, replacing what was there.
    /// </summary>
    /// <param name="window">A window on screen.</param>
    /// <param name="kept">What to keep.</param>
    internal static void Remember(Window window, SceneOrigin kept)
    {
        if (window.Handler?.PlatformView is not UIWindow { WindowScene: UIWindowScene scene })
        {
            return;
        }

        List<NSString> keys = [];
        List<NSObject> values = [];

        void Put(string key, NSObject value)
        {
            keys.Add(new NSString(key));
            values.Add(value);
        }

        if (kept.Owner is string owner)
        {
            Put(OwnerKey, new NSString(owner));
        }

        if (kept.Kind is string kind)
        {
            Put(KindKey, new NSString(kind));
        }

        if (kept.Value is string value)
        {
            Put(ValueKey, new NSString(value));
        }

        if (kept.Kept.Count > 0)
        {
            List<NSString> names = [];
            List<NSObject> texts = [];

            foreach ((string name, SwiftWireValue held) in kept.Kept)
            {
                if (SceneOrigin.Write(held) is string text)
                {
                    names.Add(new NSString(name));
                    texts.Add(new NSString(text));
                }
            }

            Put(KeptKey, new NSDictionary<NSString, NSObject>([.. names], [.. texts]));
        }

        // The two-list constructor: a mutable dictionary does not convert to
        // the type UserInfo takes.
        scene.Session.UserInfo = new NSDictionary<NSString, NSObject>([.. keys], [.. values]);
    }
#else
    /// <summary>Nothing is kept where the platform restores no scenes.</summary>
    /// <param name="window">A window on screen.</param>
    /// <param name="kept">What would be kept.</param>
    internal static void Remember(Window window, SceneOrigin kept)
    {
    }
#endif
}

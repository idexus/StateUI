using Microsoft.Maui.Storage;
using StateUI.Runtime.Interop;
using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// KEPT STATE's host half: reads the application's settings out of a store
/// before the first view is built, and writes each one back as it changes.
/// See <c>Core/Persistence.swift</c> for the other half.
/// </summary>
/// <remarks>
/// <para>
/// Reading a Swift <c>@State</c> is synchronous, so a kept value has to be in
/// memory before anything looks at it - a value fetched at read time would
/// arrive a render late and the reader would watch the default flash past. The
/// whole store is therefore hydrated inside one window at startup, after the
/// app registers and before the first render, which is the only moment where
/// the application exists and no view does.
/// </para>
/// <para>
/// The application NAMES its keys because a settings store cannot be
/// enumerated: <see cref="IPreferences"/> - and every platform store behind it,
/// <c>NSUserDefaults</c>, <c>SharedPreferences</c>,
/// <c>ApplicationDataContainer</c> - reads one key at a time and offers no list
/// of what it holds. So the host asks Swift what to ask the store for.
/// </para>
/// <para>
/// Saving goes the other way as an ordinary act, ONE PER KEY PER DRAIN: the
/// Swift side holds the last value written under each name and hands it over
/// with the next batch of commands, so a key written five times inside one
/// handler is saved once. That is a collapse per drain and not a delay - an
/// event drains, so an <c>Entry</c> bound to kept state does reach the store
/// once a letter; a view that wants the store touched when the typing stops
/// keeps the text in ordinary state and writes the kept one from
/// <c>.onEvent(.completed)</c>.
/// </para>
/// </remarks>
internal static class StateUIPersistence
{
    /// <summary>What the application keeps, by name - filled at startup, and
    /// what tells a save which overload to write with. A store is typed, and
    /// the value on the wire cannot say whether a number was declared whole.</summary>
    private static readonly Dictionary<string, SwiftPersistentKind> Kinds = [];

    /// <summary>The same keys in the order the application declared them, so
    /// what is read back reads in that order too.</summary>
    private static List<SwiftPersistentKey> _keys = [];

    /// <summary>Where it is kept, resolved once from the name Swift
    /// announced.</summary>
    private static IPreferences? _store;

    /// <summary>Whether the store already refused something - a standing
    /// condition, said once, the <see cref="StateUISession.Report"/> rule.</summary>
    private static bool _said;

    /// <summary>
    /// Asks Swift what the application keeps and where, reads exactly those
    /// keys, and hands back what was there.
    /// </summary>
    /// <remarks>
    /// Called from the session's first render, after the app registered and
    /// the wire version matched, and BEFORE the first tree is built. An
    /// application that keeps nothing announces nothing and this returns
    /// having touched no store.
    /// </remarks>
    internal static void Start()
    {
        Forget();

        (string storage, List<SwiftPersistentKey> keys) = Announced();

        if (keys.Count == 0)
        {
            return;
        }

        if (StateUIStores.Find(storage) is not { } store)
        {
            Complain(
                $"the application keeps its state in a store called '{storage}', which " +
                "nothing registered. Call StateUIStores.Add in MauiProgram.CreateMauiApp, " +
                "before the first render. The kept state stays at its declared values.");
            return;
        }

        Adopt(store, keys);

        byte[] bytes = SwiftWire.WritePersistent(Hydrate());

        try
        {
            if (NativeMethods.SetPersistent(bytes, bytes.Length) <= 0)
            {
                Complain(
                    "the library refused what the store held. Usually a native library " +
                    "and a runtime built from different versions.");
            }
        }
        catch (EntryPointNotFoundException)
        {
            // A native library from before kept state existed. It announced no
            // keys either, so this is unreachable in practice - and answering
            // it anyway costs nothing and keeps the pair of exports symmetric
            // with the environment's.
            Complain("the native library predates kept state. Rebuild the Swift side.");
        }
    }

    /// <summary>
    /// Writes one key's new value into the store - what the
    /// <see cref="SwiftAct.PersistValue"/> act asks for.
    /// </summary>
    /// <remarks>
    /// The KIND comes from the announcement rather than from the value, so a
    /// whole number declared as one is written with the store's integer
    /// overload and reads back as one on the next launch. A key that was never
    /// announced cannot be typed and is refused rather than guessed at - which
    /// is the one way an application can get this wrong, and it is said out
    /// loud.
    /// </remarks>
    /// <param name="command">The act, argument 0 the key, argument 1 its value.</param>
    internal static void Save(SwiftCommand command)
    {
        if (command.GetName(0) is not { } name)
        {
            return;
        }

        if (_store is null || !Kinds.TryGetValue(name, out SwiftPersistentKind kind))
        {
            Complain(
                $"'{name}' is kept state that the application does not list in " +
                "persistentKeys, so this side cannot tell what kind of value it is and " +
                "nothing was saved. Add it to the list.");
            return;
        }

        try
        {
            switch (kind)
            {
                case SwiftPersistentKind.Boolean when command.GetBool(1) is { } value:
                    _store.Set(name, value, null);
                    break;

                case SwiftPersistentKind.Integer when command.GetDouble(1) is { } value:
                    _store.Set(name, (long)value, null);
                    break;

                case SwiftPersistentKind.Number when command.GetDouble(1) is { } value:
                    _store.Set(name, value, null);
                    break;

                case SwiftPersistentKind.Text when command.GetString(1) is { } value:
                    _store.Set(name, value, null);
                    break;
            }
        }
        catch (Exception exception)
        {
            // A store that will not take a value - a Windows container over
            // its size limit, a file that cannot be written. The interface
            // goes on working with the value it already holds; only the next
            // launch is poorer for it.
            Complain($"the store refused to keep '{name}': {exception.Message}");
        }
    }

    /// <summary>
    /// Takes the store and the keys the application declared - the half of
    /// <see cref="Start"/> that needs no native library, which is what lets it
    /// be tested against a store of one's own.
    /// </summary>
    /// <param name="store">Where the state is kept.</param>
    /// <param name="keys">Every key, in the order they were declared.</param>
    internal static void Adopt(IPreferences store, IReadOnlyList<SwiftPersistentKey> keys)
    {
        _store = store;
        _keys = [];
        Kinds.Clear();

        foreach (SwiftPersistentKey key in keys)
        {
            // A NAME is a storage, so the same name declared twice is one key
            // however many times it is written down - which is the rule two
            // views sharing a key already rely on. Only the KIND can differ,
            // and then the two declarations disagree about what the one
            // storage holds; the first is kept, because whichever were second
            // would leave the other's state reading its default forever.
            if (Kinds.TryGetValue(key.Name, out SwiftPersistentKind first))
            {
                if (first != key.Kind)
                {
                    // Said straight out rather than through Complain: a
                    // declaration is read once at startup and is not the
                    // standing condition a failing store is, and it must not
                    // spend the one complaint that store is owed.
                    StateUISession.Report(
                        $"the application declares the persistent key '{key.Name}' " +
                        $"as two kinds - {first} and {key.Kind}. A name is one " +
                        "storage and holds one kind of value; the first declaration " +
                        "is the one being kept, and state under the second reads its " +
                        "default and is never saved. Give the second key a name of " +
                        "its own.");
                }

                continue;
            }

            Kinds[key.Name] = key.Kind;
            _keys.Add(key);
        }
    }

    /// <summary>
    /// What the store holds for the declared keys - a name and a value per key
    /// that was THERE, in the order the application declared them.
    /// </summary>
    internal static List<(string Name, SwiftWireValue Value)> Hydrate()
    {
        List<(string Name, SwiftWireValue Value)> found = [];

        foreach (SwiftPersistentKey key in _keys)
        {
            if (Read(key) is { } value)
            {
                found.Add((key.Name, value));
            }
        }

        return found;
    }

    /// <summary>Forgets the store and the keys - what a second session starts
    /// from, and what a test resets between cases.</summary>
    internal static void Forget()
    {
        _store = null;
        _keys = [];
        Kinds.Clear();
        _said = false;
    }

    /// <summary>
    /// What Swift announced: the store's name and every key, or nothing at all
    /// for an application that keeps nothing.
    /// </summary>
    private static (string Storage, List<SwiftPersistentKey> Keys) Announced()
    {
        IntPtr raw;
        int length;

        try
        {
            raw = NativeMethods.PersistentKeys(out length);
        }
        catch (EntryPointNotFoundException)
        {
            // A native library built before kept state. Nothing is kept, which
            // is what such a library described anyway.
            return (string.Empty, []);
        }

        if (raw == IntPtr.Zero || length <= 0)
        {
            return (string.Empty, []);
        }

        try
        {
            unsafe
            {
                return SwiftWire.ReadPersistentKeys(new ReadOnlySpan<byte>((void*)raw, length));
            }
        }
        catch (InvalidDataException exception)
        {
            Complain($"the persistent keys would not read: {exception.Message}");
            return (string.Empty, []);
        }
        finally
        {
            NativeMethods.FreeBuffer(raw);
        }
    }

    /// <summary>
    /// One key's value as the store holds it, or null when the store has
    /// nothing under that name - which is what leaves the Swift state holding
    /// the value written beside it.
    /// </summary>
    private static SwiftWireValue? Read(SwiftPersistentKey key)
    {
        try
        {
            if (_store is not { } store || !store.ContainsKey(key.Name, null))
            {
                return null;
            }

            return key.Kind switch
            {
                SwiftPersistentKind.Boolean => SwiftWireValue.Of(store.Get(key.Name, false, null)),
                SwiftPersistentKind.Integer => SwiftWireValue.Of(
                    (double)store.Get(key.Name, 0L, null)),
                SwiftPersistentKind.Number => SwiftWireValue.Of(store.Get(key.Name, 0d, null)),
                SwiftPersistentKind.Text => SwiftWireValue.Of(
                    store.Get(key.Name, string.Empty, null)),
                _ => null,
            };
        }
        catch (Exception exception)
        {
            // The entry is there under a different type - written by an older
            // version of the application, or by other code sharing the store.
            // Android's SharedPreferences throws rather than converting.
            // Reported and treated as absent, which starts the setting over
            // instead of taking the app down on launch.
            Complain($"'{key.Name}' is in the store as something else: {exception.Message}");
            return null;
        }
    }

    /// <summary>Says something once - a store's trouble is a standing
    /// condition, and one line per render would bury everything else.</summary>
    private static void Complain(string message)
    {
        if (_said)
        {
            return;
        }

        _said = true;
        StateUISession.Report(message);
    }
}

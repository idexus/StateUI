using System.Text;
using Microsoft.Maui.Storage;
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUIRuntime.Tests;

/// <summary>
/// KEPT STATE's host half: what the store is asked for, what comes back, and
/// what a save writes.
/// </summary>
/// <remarks>
/// A store here is an ordinary <see cref="IPreferences"/> of this file's own,
/// which is the whole reason the seam is MAUI's interface rather than one of
/// this library's: the path a real settings store takes is the path a
/// dictionary takes, and no platform has to be running for it.
/// </remarks>
public class PersistenceTests : IDisposable
{
    private readonly FakeStore _store = new();

    public PersistenceTests()
    {
        StateUIPersistence.Forget();
    }

    /// <summary>The store and the keys are one per process, so a case that
    /// inherited the last one's would be reading somebody else's state.</summary>
    public void Dispose()
    {
        StateUIPersistence.Forget();
        GC.SuppressFinalize(this);
    }

    // The four keys the cases below keep, one of each kind.
    private static readonly SwiftPersistentKey Count =
        new("test.count", SwiftPersistentKind.Integer);

    private static readonly SwiftPersistentKey Name =
        new("test.name", SwiftPersistentKind.Text);

    private static readonly SwiftPersistentKey Loud =
        new("test.loud", SwiftPersistentKind.Boolean);

    private static readonly SwiftPersistentKey Level =
        new("test.level", SwiftPersistentKind.Number);

    // MARK: - What Swift announced

    /// <summary>
    /// The announcement says where the state is kept and every key with the
    /// kind it was declared as - the only way this side can learn what to ask
    /// a store for, a settings store offering no list of what it holds.
    /// </summary>
    [Fact]
    public void TheAnnouncementCarriesTheStoreAndEveryKeyWithItsKind()
    {
        List<byte> bytes = [SwiftWire.Version];
        Str(bytes, "preferences");
        bytes.AddRange([2, 0]);
        Str(bytes, "test.count");
        bytes.Add((byte)SwiftPersistentKind.Integer);
        Str(bytes, "test.name");
        bytes.Add((byte)SwiftPersistentKind.Text);

        (string storage, List<SwiftPersistentKey> keys) =
            SwiftWire.ReadPersistentKeys([.. bytes]);

        Assert.Equal("preferences", storage);
        Assert.Equal([Count, Name], keys);
    }

    /// <summary>
    /// A buffer from a half built for another format is refused with a
    /// sentence rather than read as something else.
    /// </summary>
    [Fact]
    public void AnAnnouncementFromAnotherWireVersionIsRefused()
    {
        byte[] bytes = [SwiftWire.Version + 1, 0, 0, 0, 0, 0, 0];

        Assert.Throws<InvalidDataException>(() => SwiftWire.ReadPersistentKeys(bytes));
    }

    // MARK: - Reading the store

    /// <summary>
    /// Each key is read with the overload its declared kind names, so what the
    /// application wrote as a whole number comes back as one.
    /// </summary>
    [Fact]
    public void EveryKeyIsReadAsTheKindItWasDeclared()
    {
        _store.Set("test.count", 7L, null);
        _store.Set("test.name", "Ada", null);
        _store.Set("test.loud", true, null);
        _store.Set("test.level", 0.25, null);

        StateUIPersistence.Adopt(_store, [Count, Name, Loud, Level]);

        Assert.Equal(
            [
                ("test.count", SwiftWireValue.Of(7d)),
                ("test.name", SwiftWireValue.Of("Ada")),
                ("test.loud", SwiftWireValue.Of(true)),
                ("test.level", SwiftWireValue.Of(0.25)),
            ],
            StateUIPersistence.Hydrate());
    }

    /// <summary>
    /// A NAME is a storage, so declaring one twice is one key - which is what
    /// two views sharing a key already rely on, and what makes a second
    /// declaration under a different KIND a contradiction rather than a
    /// choice. The first is kept, and the application is told.
    /// </summary>
    [Fact]
    public void AKeyDeclaredAsTwoKindsIsReadAsTheFirstAndSaidOutLoud()
    {
        var said = new StringWriter();
        TextWriter had = Console.Error;
        Console.SetError(said);

        try
        {
            _store.Set("test.count", 7L, null);

            StateUIPersistence.Adopt(
                _store, [Count, new SwiftPersistentKey("test.count", SwiftPersistentKind.Text)]);

            // Once, as one key, read as the Integer it was first declared -
            // not twice, and not as text.
            Assert.Equal(
                [("test.count", SwiftWireValue.Of(7d))], StateUIPersistence.Hydrate());
        }
        finally
        {
            Console.SetError(had);
        }

        Assert.Contains("'test.count'", said.ToString());
        Assert.Contains("two kinds", said.ToString());
    }

    /// <summary>
    /// The same name declared twice as the SAME kind is simply the one key it
    /// names, read once and said nothing about: that is two views keeping
    /// their state under one name, which is what a key is for.
    /// </summary>
    [Fact]
    public void TheSameKeyDeclaredTwiceIsStillOneKey()
    {
        var said = new StringWriter();
        TextWriter had = Console.Error;
        Console.SetError(said);

        try
        {
            _store.Set("test.count", 7L, null);

            StateUIPersistence.Adopt(_store, [Count, Count]);

            Assert.Equal(
                [("test.count", SwiftWireValue.Of(7d))], StateUIPersistence.Hydrate());
        }
        finally
        {
            Console.SetError(had);
        }

        Assert.Equal("", said.ToString());
    }

    /// <summary>
    /// A key the store has nothing under is simply LEFT OUT, which is what
    /// leaves the Swift state holding the value written beside it. No sentinel
    /// stands in for absence, the wire's rule.
    /// </summary>
    [Fact]
    public void AKeyTheStoreHasNothingUnderIsLeftOut()
    {
        _store.Set("test.name", "Ada", null);

        StateUIPersistence.Adopt(_store, [Count, Name]);

        Assert.Equal([("test.name", SwiftWireValue.Of("Ada"))], StateUIPersistence.Hydrate());
    }

    /// <summary>
    /// An entry the store holds as something ELSE - written by an older
    /// version of the application under the same name, or by other code
    /// sharing the store - is treated as absent rather than taking the launch
    /// down. Android's SharedPreferences throws rather than converting, which
    /// is what this store does.
    /// </summary>
    [Fact]
    public void AnEntryHeldAsAnotherTypeIsTreatedAsAbsent()
    {
        _store.Set("test.count", "seven", null);

        StateUIPersistence.Adopt(_store, [Count]);

        Assert.Empty(StateUIPersistence.Hydrate());
    }

    /// <summary>
    /// What was found is written back as a name and a value per key, in the
    /// order the application declared them.
    /// </summary>
    [Fact]
    public void WhatWasFoundIsWrittenBackByName()
    {
        byte[] bytes = SwiftWire.WritePersistent(
            [("test.count", SwiftWireValue.Of(4d)), ("test.loud", SwiftWireValue.Of(true))]);

        List<byte> expected = [SwiftWire.Version, 2, 0];
        Str(expected, "test.count");
        expected.Add(SwiftWireValue.TagNumber);
        expected.AddRange(BitConverter.GetBytes(4d));
        Str(expected, "test.loud");
        expected.Add(SwiftWireValue.TagTrue);

        Assert.Equal(expected, bytes);
    }

    // MARK: - Writing the store

    /// <summary>
    /// A save writes with the overload the key's declared kind names, so a
    /// whole number goes in as one and reads back as one on the next launch.
    /// The kind cannot come from the VALUE: every number on this wire is a
    /// double, and nothing in it says which were declared whole.
    /// </summary>
    [Fact]
    public void ASaveWritesWithTheOverloadTheKeysKindNames()
    {
        StateUIPersistence.Adopt(_store, [Count, Name, Loud, Level]);

        StateUIPersistence.Save(Saving("test.count", bytes =>
        {
            bytes.Add(SwiftWireValue.TagNumber);
            bytes.AddRange(BitConverter.GetBytes(7d));
        }));

        StateUIPersistence.Save(Saving("test.name", bytes =>
        {
            bytes.Add(SwiftWireValue.TagString);
            Str(bytes, "Grace");
        }));

        StateUIPersistence.Save(Saving("test.loud", bytes => bytes.Add(SwiftWireValue.TagTrue)));

        StateUIPersistence.Save(Saving("test.level", bytes =>
        {
            bytes.Add(SwiftWireValue.TagNumber);
            bytes.AddRange(BitConverter.GetBytes(0.75));
        }));

        Assert.Equal(7L, _store.Held("test.count"));
        Assert.Equal("Grace", _store.Held("test.name"));
        Assert.Equal(true, _store.Held("test.loud"));
        Assert.Equal(0.75, _store.Held("test.level"));
    }

    /// <summary>
    /// A key the application does not list in <c>persistentKeys</c> cannot be
    /// typed and is refused rather than guessed at - the one way an
    /// application can get this wrong, and the reason it is said out loud
    /// instead of silently written as whatever the value looked like.
    /// </summary>
    [Fact]
    public void AKeyTheApplicationDoesNotListIsRefused()
    {
        StateUIPersistence.Adopt(_store, [Count]);

        StateUIPersistence.Save(Saving("test.name", bytes =>
        {
            bytes.Add(SwiftWireValue.TagString);
            Str(bytes, "Grace");
        }));

        Assert.Null(_store.Held("test.name"));
    }

    /// <summary>
    /// A store that will not take a value leaves the interface alone: the
    /// state already holds it, and only the next launch is poorer for it.
    /// </summary>
    [Fact]
    public void AStoreThatRefusesAValueDoesNotTakeTheAppDown()
    {
        var refusing = new FakeStore { Refuses = true };
        StateUIPersistence.Adopt(refusing, [Name]);

        StateUIPersistence.Save(Saving("test.name", bytes =>
        {
            bytes.Add(SwiftWireValue.TagString);
            Str(bytes, "Grace");
        }));

        Assert.Null(refusing.Held("test.name"));
    }

    // MARK: - Where it is kept

    /// <summary>
    /// A store registered under a name is what that name resolves to, and a
    /// name nobody registered resolves to nothing - which is reported rather
    /// than quietly keeping state nowhere.
    /// </summary>
    [Fact]
    public void AStoreIsFoundByTheNameItWasRegisteredUnder()
    {
        StateUIStores.Add("Test.Json", _store);

        Assert.Same(_store, StateUIStores.Find("Test.Json"));
        Assert.Null(StateUIStores.Find("Test.NeverRegistered"));
    }

    // MARK: - Support

    /// <summary>One save act, built the way the wire delivers it - the key as
    /// a NAME through the session's dictionary, which is what
    /// <see cref="SwiftCommand.GetName"/> reads.</summary>
    private static SwiftCommand Saving(string key, Action<List<byte>> value)
    {
        List<byte> bytes = [SwiftWire.Version];

        bytes.AddRange([2, 0]);                 // two announcements:
        bytes.AddRange([1, 0]);
        Str(bytes, "persistValue");             // name #1, the act
        bytes.AddRange([2, 0]);
        Str(bytes, key);                        // name #2, the key

        bytes.AddRange([1, 0]);                 // one command
        bytes.AddRange([1, 0]);                 // name #1
        bytes.AddRange([0, 0, 0, 0]);           // nobody is waiting
        bytes.Add(2);                           // two arguments

        bytes.Add(SwiftWireValue.TagName);
        bytes.AddRange([2, 0]);                 // name #2
        value(bytes);

        return SwiftWire.ReadCommands([.. bytes], new SwiftWireDictionary()).Single();
    }

    private static void Str(List<byte> bytes, string text)
    {
        byte[] utf8 = Encoding.UTF8.GetBytes(text);
        bytes.AddRange(BitConverter.GetBytes((uint)utf8.Length));
        bytes.AddRange(utf8);
    }

    /// <summary>
    /// A settings store that is a dictionary - MAUI's own interface, so this
    /// is the same seam a real one plugs into.
    /// </summary>
    private sealed class FakeStore : IPreferences
    {
        private readonly Dictionary<string, object> _values = [];

        /// <summary>Whether every write fails - a container over its size
        /// limit, a file that cannot be written.</summary>
        public bool Refuses { get; init; }

        public object? Held(string key) => _values.GetValueOrDefault(key);

        public bool ContainsKey(string key, string? sharedName = null) =>
            _values.ContainsKey(key);

        public void Remove(string key, string? sharedName = null) => _values.Remove(key);

        public void Clear(string? sharedName = null) => _values.Clear();

        /// <summary>Reads, and THROWS for an entry held as another type -
        /// which is what Android's SharedPreferences does.</summary>
        public T Get<T>(string key, T defaultValue, string? sharedName = null) =>
            _values.TryGetValue(key, out object? held) ? (T)held : defaultValue;

        public void Set<T>(string key, T value, string? sharedName = null)
        {
            if (Refuses)
            {
                throw new InvalidOperationException("this store is full");
            }

            _values[key] = value!;
        }
    }
}

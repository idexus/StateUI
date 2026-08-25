// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Trying to BREAK the reader rather than to read it.
//
// Every fixture the Swift side wrote, put through every truncation and every
// single-byte change there is. The invariant is NOT that a mangled message is
// refused - a changed byte inside a number is still a number, and the tree
// that comes out is nobody's business - but that the only way this reader ever
// fails is InvalidDataException. That is the one failure the two callers are
// written to survive: `StateUISession.Render` says so to the reader, and
// `PerformCommands` cashes the receipt so every act in an unreadable batch
// fails back to the handler awaiting it. Anything else escaping a reader is a
// failure mode nothing was designed against.
//
// The other direction - the replies and payloads THIS side writes and Swift
// reads - is fuzzed in Swift, in WireFuzzTests.swift.

using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Tests;

public class WireFuzzTests
{
    /// <summary>
    /// What a single byte is changed by: every bit, the low bit alone, and the
    /// high bit alone. Three is enough to reach the interesting places - a
    /// length's top byte, a tag, a count - without turning a one-second suite
    /// into a minute of it.
    /// </summary>
    private static readonly byte[] Changes = [0xFF, 0x01, 0x80];

    /// <summary>
    /// The render fixtures: every `.bin` except the command batches, which are
    /// read by the other entry point, and the payloads, which this side writes.
    /// </summary>
    private static List<string> Messages() => Corpus(under: null);

    /// <summary>The command batches, read by <see cref="SwiftWire.ReadCommands"/>.</summary>
    private static List<string> Commands() => Corpus(under: "commands");

    private static List<string> Corpus(string? under)
    {
        var found = Directory
            .EnumerateFiles(Fixtures.Directory, "*.bin", SearchOption.AllDirectories)
            .Select(path => Path.GetRelativePath(Fixtures.Directory, path).Replace('\\', '/'))
            .Where(name => under is null
                ? !name.StartsWith("commands/") && !name.StartsWith("payloads/")
                : name.StartsWith(under + "/"))
            .OrderBy(name => name, StringComparer.Ordinal)
            .ToList();

        // A corpus that quietly emptied - a moved directory, a renamed suffix -
        // would leave every test here passing while reading nothing.
        Assert.NotEmpty(found);

        return found;
    }

    /// <summary>
    /// Reads, and says what happened: null when the bytes were read, the
    /// exception when they were not. An InvalidDataException is the contract
    /// and is simply absorbed; anything else is named with the byte that
    /// caused it, because that is the only way back to it.
    /// </summary>
    private static void Refused(Action read, bool mustRefuse, string what)
    {
        bool wasRead = false;

        try
        {
            read();
            wasRead = true;
        }
        catch (InvalidDataException)
        {
        }
        catch (Exception ex)
        {
            Assert.Fail($"{what} failed with {ex.GetType().Name}: {ex.Message}");
        }

        if (mustRefuse && wasRead)
        {
            Assert.Fail($"{what} was read as if it were whole");
        }
    }

    /// <summary>
    /// A message that stops early is refused, wherever it stops. Every proper
    /// prefix of every fixture, which is what makes this a statement about the
    /// format rather than about one hand-cut example: the reader bounds-checks
    /// each step AND requires the root to end exactly at the last byte, so
    /// there is no prefix that reads as a smaller, plausible tree.
    /// </summary>
    [Fact]
    public void EveryProperPrefixOfEveryMessageIsRefused()
    {
        foreach (string name in Messages())
        {
            byte[] whole = Fixtures.ReadBytes(name);

            for (int length = 0; length < whole.Length; length++)
            {
                byte[] cut = whole.AsSpan(0, length).ToArray();

                Refused(
                    () => SwiftWire.ReadMessage(cut, new SwiftWireDictionary()),
                    mustRefuse: true,
                    $"{name} cut to {length} of {whole.Length} bytes");
            }
        }
    }

    /// <summary>
    /// Every single-byte change in every fixture is either read or refused,
    /// and never anything else. This is the one that reaches the arithmetic:
    /// a string's length is four bytes wide, so the top byte alone decides
    /// whether the reader is asked for a length no buffer could hold.
    /// </summary>
    [Fact]
    public void EverySingleByteChangeInEveryMessageIsReadOrRefused()
    {
        foreach (string name in Messages())
        {
            byte[] whole = Fixtures.ReadBytes(name);

            for (int at = 0; at < whole.Length; at++)
            {
                foreach (byte change in Changes)
                {
                    byte[] changed = (byte[])whole.Clone();
                    changed[at] ^= change;

                    Refused(
                        () => SwiftWire.ReadMessage(changed, new SwiftWireDictionary()),
                        mustRefuse: false,
                        $"{name} with byte {at} of {whole.Length} changed by 0x{change:X2}");
                }
            }
        }
    }

    /// <summary>
    /// A length no buffer could hold is refused rather than believed. It
    /// crosses UNSIGNED and four bytes wide, so the widest of them does not
    /// fit the int a length is finally used as - and the bounds check has to
    /// happen before that narrowing, or the reader goes on to ask for a
    /// negative slice and fails with something no caller is written for.
    /// </summary>
    [Fact]
    public void ALengthNoBufferCouldHoldIsRefused()
    {
        byte[] bytes =
        [
            SwiftWire.Version,
            1,                          // complete
            0, 0, 0, 0,                 // generation 0
            1, 0,                       // one announcement
            1, 0,                       // id #1
            0xFF, 0xFF, 0xFF, 0xFF,     // whose name is four gigabytes long
        ];

        Assert.Throws<InvalidDataException>(
            () => SwiftWire.ReadMessage(bytes, new SwiftWireDictionary()));
    }

    /// <summary>
    /// The same two statements about a command batch, whose reader is the one
    /// an awaiting handler is hanging off.
    /// </summary>
    [Fact]
    public void EveryProperPrefixOfEveryCommandBatchIsRefused()
    {
        foreach (string name in Commands())
        {
            byte[] whole = Fixtures.ReadBytes(name);

            for (int length = 0; length < whole.Length; length++)
            {
                byte[] cut = whole.AsSpan(0, length).ToArray();

                Refused(
                    () => SwiftWire.ReadCommands(cut, new SwiftWireDictionary()),
                    mustRefuse: true,
                    $"{name} cut to {length} of {whole.Length} bytes");
            }
        }
    }

    [Fact]
    public void EverySingleByteChangeInEveryCommandBatchIsReadOrRefused()
    {
        foreach (string name in Commands())
        {
            byte[] whole = Fixtures.ReadBytes(name);

            for (int at = 0; at < whole.Length; at++)
            {
                foreach (byte change in Changes)
                {
                    byte[] changed = (byte[])whole.Clone();
                    changed[at] ^= change;

                    Refused(
                        () => SwiftWire.ReadCommands(changed, new SwiftWireDictionary()),
                        mustRefuse: false,
                        $"{name} with byte {at} of {whole.Length} changed by 0x{change:X2}");
                }
            }
        }
    }
}

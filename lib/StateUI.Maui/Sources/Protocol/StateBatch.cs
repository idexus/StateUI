// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Protocol;

/// <summary>
/// The batch both directions cross in: a count, then a number, a mask, a length
/// and the bytes.
/// </summary>
/// <remarks>
/// Little-endian throughout and written by hand, for the reason the wire is:
/// there is no endianness to agree about and no framework in the way.
/// </remarks>
internal static class StateBatch
{
    /// <summary>The bytes a batch of writes lies as.</summary>
    /// <param name="batch">The states, each with the lanes being written.</param>
    /// <returns>The bytes.</returns>
    internal static byte[] Bytes(IReadOnlyList<(int Number, ulong Mask, double[] Lanes)> batch)
    {
        List<(int Number, ulong Mask, byte[] Bytes)> raw = new(batch.Count);

        foreach ((int number, ulong mask, double[] lanes) in batch)
        {
            byte[] payload = new byte[lanes.Length * 8];

            for (int lane = 0; lane < lanes.Length; lane++)
            {
                BitConverter.TryWriteBytes(payload.AsSpan(lane * 8, 8), BitConverter.DoubleToUInt64Bits(lanes[lane]));
            }

            raw.Add((number, mask, payload));
        }

        return Bytes(raw);
    }

    /// <summary>
    /// The bytes a batch of writes lies as, each value already in its own
    /// bytes - lanes, or a text.
    /// </summary>
    /// <param name="batch">The states, each with the bytes being written.</param>
    /// <returns>The bytes.</returns>
    internal static byte[] Bytes(IReadOnlyList<(int Number, ulong Mask, byte[] Bytes)> batch)
    {
        List<byte> bytes = new(2 + (batch.Count * 32));

        Add(bytes, (ulong)batch.Count, 2);

        foreach ((int number, ulong mask, byte[] payload) in batch)
        {
            Add(bytes, (uint)number, 4);
            Add(bytes, mask & 0xFFFF_FFFF, 4);
            Add(bytes, mask >> 32, 4);
            Add(bytes, (ulong)payload.Length, 4);
            bytes.AddRange(payload);
        }

        return [.. bytes];
    }

    /// <summary>The bytes a text lies as on the image: its length, then its UTF-8.</summary>
    /// <param name="text">The words.</param>
    /// <returns>The bytes, which <see cref="Text"/> reads back.</returns>
    internal static byte[] Words(string text)
    {
        byte[] utf8 = System.Text.Encoding.UTF8.GetBytes(text);
        byte[] bytes = new byte[4 + utf8.Length];

        BitConverter.TryWriteBytes(bytes.AsSpan(0, 4), utf8.Length);
        utf8.CopyTo(bytes, 4);
        return bytes;
    }

    /// <summary>What a batch says.</summary>
    /// <param name="bytes">The batch.</param>
    /// <returns>The states, each with which lanes moved and its own bytes.</returns>
    internal static List<(int Number, ulong Mask, byte[] Bytes)> Read(ReadOnlySpan<byte> bytes)
    {
        List<(int Number, ulong Mask, byte[] Bytes)> read = [];

        if (bytes.Length < 2)
        {
            return read;
        }

        int count = (int)Number(bytes, 0, 2);
        int at = 2;

        for (int entry = 0; entry < count; entry++)
        {
            if (at + 16 > bytes.Length)
            {
                return read;
            }

            int number = (int)Number(bytes, at, 4);
            ulong mask = Number(bytes, at + 4, 4) | (Number(bytes, at + 8, 4) << 32);
            int length = (int)Number(bytes, at + 12, 4);

            at += 16;

            if (at + length > bytes.Length)
            {
                return read;
            }

            read.Add((number, mask, bytes.Slice(at, length).ToArray()));
            at += length;
        }

        return read;
    }

    /// <summary>A little-endian number of a stated width.</summary>
    private static ulong Number(ReadOnlySpan<byte> bytes, int at, int width)
    {
        ulong value = 0;

        for (int byteAt = 0; byteAt < width; byteAt++)
        {
            value |= (ulong)bytes[at + byteAt] << (byteAt * 8);
        }

        return value;
    }

    /// <summary>The lanes a number's bytes hold.</summary>
    /// <param name="bytes">The bytes.</param>
    /// <returns>One number per eight bytes.</returns>
    internal static double[] Lanes(byte[] bytes)
    {
        double[] lanes = new double[bytes.Length / 8];

        for (int lane = 0; lane < lanes.Length; lane++)
        {
            lanes[lane] = BitConverter.ToDouble(bytes, lane * 8);
        }

        return lanes;
    }

    /// <summary>The text a number's bytes hold: its own length, then its own UTF-8.</summary>
    /// <param name="bytes">The bytes.</param>
    /// <returns>The words.</returns>
    internal static string Text(byte[] bytes)
    {
        if (bytes.Length < 4)
        {
            return string.Empty;
        }

        int length = BitConverter.ToInt32(bytes, 0);

        return System.Text.Encoding.UTF8.GetString(
            bytes, 4, Math.Min(length, bytes.Length - 4));
    }

    private static void Add(List<byte> bytes, ulong value, int width)
    {
        for (int byteAt = 0; byteAt < width; byteAt++)
        {
            bytes.Add((byte)(value >> (byteAt * 8)));
        }
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Protocol;

/// <summary>
/// One piece of state the application keeps between launches: the name it is
/// kept under, and what kind of value it is.
/// </summary>
/// <remarks>
/// Announced by Swift before the first render - see
/// <see cref="SwiftWire.ReadPersistentKeys"/> - because a settings store is
/// read key by key and never enumerated, so the host cannot find out what to
/// ask for by looking. The kind comes with it for the same reason: a store is
/// typed, and reading an entry with the wrong overload is an error rather than
/// a conversion.
/// </remarks>
/// <param name="Name">The name in the store, the application's own.</param>
/// <param name="Kind">Which of the four kinds of value it holds.</param>
internal readonly record struct SwiftPersistentKey(string Name, SwiftPersistentKind Kind);

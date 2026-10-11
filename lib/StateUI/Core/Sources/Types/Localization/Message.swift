// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A message with a typed argument; each language says the whole sentence, in its own order and grammar.
///
///     fileCount: Message { count, context in
///         let number = context.number(count)
///         return context.plural(count, one: "\(number) plik", few: "\(number) pliki",
///                               many: "\(number) plików", other: "\(number) pliku")
///     }
///
/// It is said with `localization.text(res.fileCount, files.count)`, which hands it the context of that
/// localization: the grammar of its language and the formats in effect. Several arguments are a tuple or a
/// struct: `Message<(name: String, count: Int)>`.
///
/// Design: docs/design/types/localization.md#messages
public struct Message<Arguments> {
    let say: @MainActor (Arguments, MessageContext) -> String

    /// A message: what it says for its arguments, in the context it is said in.
    public init(_ say: @escaping @MainActor (Arguments, MessageContext) -> String) {
        self.say = say
    }
}

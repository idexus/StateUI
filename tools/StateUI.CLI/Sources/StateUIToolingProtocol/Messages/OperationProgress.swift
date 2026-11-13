// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How far an operation's work has come, as far as its tools tell; nothing is made up from time.
public struct OperationProgress: Codable, Equatable, Sendable {
    /// The stage, such as `compiling`.
    public var stage: String
    /// What it does, for a person.
    public var message: String?
    /// The steps done, when the tool counts them.
    public var completed: Int?
    /// The steps in all, when the tool knows them.
    public var total: Int?

    /// Progress at `stage`.
    public init(stage: String, message: String? = nil, completed: Int? = nil, total: Int? = nil) {
        self.stage = stage
        self.message = message
        self.completed = completed
        self.total = total
    }
}

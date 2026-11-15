// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// This process's standard input, read on a thread of its own so no wait for bytes holds a task.
enum StandardInput {
    /// The bytes as they arrive, ending at the end of the input.
    static func chunks() -> AsyncStream<Data> {
        AsyncStream { continuation in
            let reader = Thread {
                while true {
                    let bytes = FileHandle.standardInput.availableData
                    if bytes.isEmpty { break }
                    continuation.yield(bytes)
                }
                continuation.finish()
            }
            reader.name = "stateui standard input"
            reader.start()
        }
    }
}

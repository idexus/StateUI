// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The lines a file gains while another process writes it, read from where the last read ended.
struct FileTail {
    let file: URL
    let stream: ProcessOutput.Stream
    private var offset: UInt64 = 0
    private var lines = OutputLines()

    /// A tail of `file`, its lines told as `stream`'s.
    init(_ file: URL, as stream: ProcessOutput.Stream) {
        self.file = file
        self.stream = stream
    }

    /// The lines written since the last read; at `end`, the last one too, though no line feed ended it.
    mutating func read(end: Bool = false) -> [ProcessOutput] {
        var taken: [String] = []
        if let handle = try? FileHandle(forReadingFrom: file) {
            defer { try? handle.close() }
            if (try? handle.seek(toOffset: offset)) != nil, let bytes = try? handle.readToEnd(), !bytes.isEmpty {
                offset += UInt64(bytes.count)
                taken = lines.take(bytes)
            }
        }
        if end, let last = lines.finish() { taken.append(last) }
        return taken.map { ProcessOutput(stream: stream, text: $0) }
    }
}

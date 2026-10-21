// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIFoundation
import Dispatch
import XCTest

/// The standard error, written whole.
final class StandardErrorTests: XCTestCase {
    #if os(macOS) || os(Linux)
    /// EVERY BYTE ARRIVES: a text longer than a pipe holds at once reaches the reader whole.
    func testEveryByteArrives() {
        var ends: [Int32] = [0, 0]
        XCTAssertEqual(pipe(&ends), 0)
        let kept = dup(2)
        dup2(ends[1], 2)

        nonisolated(unsafe) var arrived: [UInt8] = []
        let done = DispatchSemaphore(value: 0)
        let reader = ends[0]
        DispatchQueue(label: "reader").async {
            var chunk = [UInt8](repeating: 0, count: 4_096)
            while true {
                let count = chunk.withUnsafeMutableBytes { read(reader, $0.baseAddress, 4_096) }
                if count <= 0 { break }
                arrived += chunk[0..<count]
            }
            done.signal()
        }

        let text = String(repeating: "StateUI writes every byte. ", count: 10_000)
        writeStandardError(text)

        dup2(kept, 2)
        close(kept)
        close(ends[1])
        done.wait()
        close(ends[0])

        XCTAssertEqual(String(decoding: arrived, as: UTF8.self), text)
    }
    #endif
}

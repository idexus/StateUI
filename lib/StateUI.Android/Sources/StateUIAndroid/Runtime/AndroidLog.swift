// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid

/// The host's lines in logcat, under the tag `StateUI`.
enum AndroidLog {
    /// The tag every line of the host and of the application's `print` carries.
    static let tag = "StateUI"

    /// An ordinary line.
    static func info(_ message: String) {
        _ = __android_log_write(Int32(ANDROID_LOG_INFO.rawValue), tag, message)
    }

    /// A line about something that went wrong.
    static func error(_ message: String) {
        _ = __android_log_write(Int32(ANDROID_LOG_ERROR.rawValue), tag, message)
    }
}

/// An Android application's stdout and stderr go nowhere; this sends them to logcat a line at a time.
/// Design: docs/design/platforms/android/runtime.md#print-reaches-logcat
enum AndroidStandardStreams {
    /// Points stdout and stderr at a pipe that a thread of its own reads into logcat.
    static func redirect() {
        var ends: [Int32] = [0, 0]
        guard pipe(&ends) == 0 else { return }

        dup2(ends[1], 1)
        dup2(ends[1], 2)
        stateui_android_buffer_standard_streams()

        let readEnd = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        readEnd.pointee = ends[0]
        var thread: pthread_t = 0
        pthread_create(&thread, nil, { argument in
            let descriptor = argument!.assumingMemoryBound(to: Int32.self).pointee
            var buffer = [UInt8](repeating: 0, count: 4096)
            var line: [CChar] = []

            while true {
                let count = buffer.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, 4096) }
                if count <= 0 { break }

                for byte in buffer[0..<count] {
                    guard byte == 10 else {
                        line.append(CChar(bitPattern: byte))
                        continue
                    }

                    line.append(0)
                    _ = line.withUnsafeBufferPointer {
                        __android_log_write(Int32(ANDROID_LOG_INFO.rawValue), AndroidLog.tag, $0.baseAddress)
                    }
                    line.removeAll(keepingCapacity: true)
                }
            }
            return nil
        }, readEnd)
    }
}

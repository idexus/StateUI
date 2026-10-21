// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
import CStateUIWeb

/// The requests the application sends, in Swift's words: each answers a listener once.
/// Design: docs/design/core/acts.md#requests
extension WebRelay {
    /// Sends `request` through the browser's `fetch`.
    static func send(_ request: HostRequest, _ listener: Int32) {
        let headers = request.headers.flatMap { [$0.name, $0.value] }.joined(separator: "\u{1F}")
        utf8(request.address) { address, addressLength in
            utf8(request.method) { method, methodLength in
                utf8(headers) { headers, headersLength in
                    request.body.withUnsafeBufferPointer { body in
                        stateui_web_send_request(
                            address, addressLength, method, methodLength, headers, headersLength, body.baseAddress,
                            Int32(body.count), listener)
                    }
                }
            }
        }
    }

    /// Whether the request being heard was answered.
    static var requestAnswered: Bool { stateui_web_event_number(0) != 0 }

    /// The status of the request being heard.
    static var requestStatus: Int { Int(stateui_web_event_number(1)) }

    /// The headers of the request being heard, or why no answer came.
    static var requestWords: String { copyRead(length: stateui_web_request_words()) }

    /// The body of the request being heard.
    static var requestBody: [UInt8] {
        let length = Int(stateui_web_request_body())
        guard length > 0 else { return [] }
        return [UInt8](unsafeUninitializedCapacity: length) { buffer, count in
            buffer.withMemoryRebound(to: CChar.self) { stateui_web_copy_read($0.baseAddress) }
            count = length
        }
    }
}

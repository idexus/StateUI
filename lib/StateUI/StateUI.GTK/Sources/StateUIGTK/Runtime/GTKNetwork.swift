// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK
import CStateUISoup

/// GTK's part of the requests the application sends (`HostActs.network`): libsoup, GNOME's HTTP, on GLib's main
/// context - the system's certificates and proxy hold, a cookie jar keeps what a server sets for the process.
/// Design: docs/design/core/acts.md#requests
@MainActor
final class GTKNetwork: NetworkToolkit {
    /// The session every request goes through, made on the UI thread and only ever used there.
    private nonisolated(unsafe) static let session = {
        let session = soup_session_new()!
        soup_session_add_feature_by_type(session, soup_cookie_jar_get_type())
        return session
    }()

    func send(_ request: HostRequest, answered: @escaping (Result<HostResponse, ActFailure>) -> Void) {
        guard let message = soup_message_new(request.method, request.address) else {
            Task { @MainActor in answered(.failure(ActFailure("'\(request.address)' is no address"))) }
            return
        }
        let headers = soup_message_get_request_headers(message)
        // The body's type stands with the body.
        let type = request.headers.last { $0.name.lowercased() == "content-type" }?.value
        for header in request.headers where header.name.lowercased() != "content-type" {
            soup_message_headers_append(headers, header.name, header.value)
        }
        if !request.body.isEmpty {
            let bytes = request.body.withUnsafeBytes { g_bytes_new($0.baseAddress, gsize($0.count)) }
            soup_message_set_request_body_from_bytes(message, type, bytes)
            g_bytes_unref(bytes)
        } else if let type {
            soup_message_headers_append(headers, "Content-Type", type)
        }

        let sent = Sent { _, result in
            defer { g_object_unref(UnsafeMutableRawPointer(message)) }
            var error: UnsafeMutablePointer<GError>?
            let body = soup_session_send_and_read_finish(Self.session, result, &error)
            let answer: Result<HostResponse, ActFailure>
            if let error {
                answer = .failure(ActFailure(error.pointee.message.map { String(cString: $0) } ?? "no answer came"))
                g_error_free(error)
            } else {
                answer = .success(HostResponse(
                    status: Int(soup_message_get_status(message).rawValue),
                    headers: Self.headers(of: soup_message_get_response_headers(message)), body: Self.bytes(body)))
            }
            if let body { g_bytes_unref(body) }
            MainActor.assumeIsolated { answered(answer) }
        }
        soup_session_send_and_read_async(
            Self.session, message, Int32(G_PRIORITY_DEFAULT), nil, Sent.finished, Unmanaged.passRetained(sent).toOpaque())
    }

    /// Every header of `headers`, in the order libsoup holds them.
    private nonisolated static func headers(of headers: OpaquePointer?) -> [HostHeader] {
        let collected = Collected()
        soup_message_headers_foreach(headers, { name, value, data in
            Unmanaged<Collected>.fromOpaque(data!).takeUnretainedValue().headers.append(
                HostHeader(name: name.map { String(cString: $0) } ?? "", value: value.map { String(cString: $0) } ?? ""))
        }, Unmanaged.passUnretained(collected).toOpaque())
        return collected.headers
    }

    /// The bytes `body` holds.
    private nonisolated static func bytes(_ body: OpaquePointer?) -> [UInt8] {
        guard let body else { return [] }
        var size: gsize = 0
        guard let data = g_bytes_get_data(body, &size), size > 0 else { return [] }
        return Array(UnsafeRawBufferPointer(start: data, count: Int(size)))
    }

    /// The headers libsoup hands over one at a time.
    private final class Collected {
        var headers: [HostHeader] = []
    }

    /// What hears a request's answer, by the data handed libsoup.
    private final class Sent: @unchecked Sendable {
        let finished: (UnsafeMutablePointer<GObject>?, OpaquePointer?) -> Void

        init(_ finished: @escaping (UnsafeMutablePointer<GObject>?, OpaquePointer?) -> Void) {
            self.finished = finished
        }

        static let finished: GAsyncReadyCallback = { source, result, data in
            Unmanaged<Sent>.fromOpaque(data!).takeRetainedValue().finished(source, result)
        }
    }
}

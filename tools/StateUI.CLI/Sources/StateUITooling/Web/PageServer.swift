// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(NIOPosix)
import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import StateUIToolingProtocol

/// A Web head's page served from its artifact's folder while a run lasts: GET and HEAD of the files in it, each answer
/// saying not to keep it, so the build shown is always the last. It listens on this machine alone unless asked to
/// share the page with the network; the default port is the same from run to run, so the page's address - and what
/// a browser keeps for it - stays the same, and another is taken where it is in use.
/// Design: docs/design/tooling/web-heads.md#the-pages-server
public final class PageServer: Sendable {
    /// The port a page is served on where none is asked for.
    public static let defaultPort = 8460

    private let channel: any Channel
    private let group: MultiThreadedEventLoopGroup
    /// The port it listens on.
    public let port: Int

    private init(channel: any Channel, group: MultiThreadedEventLoopGroup, port: Int) {
        self.channel = channel
        self.group = group
        self.port = port
    }

    /// Serves `root` on `port` - the default where none is asked for, another where the default is in use - on the
    /// loopback, or on every interface where `lan`; answers once it listens, every line of a request it refused told
    /// to `said`.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` where a port asked for is in use.
    public static func start(_ root: URL, port: Int?, lan: Bool, said: @escaping @Sendable (String) -> Void = { _ in }) async throws -> PageServer {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let bootstrap = ServerBootstrap(group: group)
            // No address reuse: a port another server holds on any interface is in use, not shared beside it.
            .serverChannelOption(.backlog, value: 64)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(PageHandler(root: root, said: said))
                }
            }
        let host = lan ? "0.0.0.0" : "127.0.0.1"
        do {
            let channel = try await bootstrap.bind(host: host, port: port ?? defaultPort).get()
            return PageServer(channel: channel, group: group, port: channel.localAddress?.port ?? port ?? defaultPort)
        } catch where port == nil {
            do {
                let channel = try await bootstrap.bind(host: host, port: 0).get()
                return PageServer(channel: channel, group: group, port: channel.localAddress?.port ?? 0)
            } catch {
                try? await group.shutdownGracefully()
                throw error
            }
        } catch {
            try? await group.shutdownGracefully()
            throw ToolingError(.invalidConfiguration, "Port \(port ?? defaultPort) is in use: name another, or leave it out.")
        }
    }

    /// Stops serving, its connections closed.
    public func stop() async {
        try? await channel.close().get()
        try? await group.shutdownGracefully()
    }
}

/// One connection's requests answered from the page's folder.
private final class PageHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let root: URL
    private let said: @Sendable (String) -> Void
    private var request: HTTPRequestHead?

    init(root: URL, said: @escaping @Sendable (String) -> Void) {
        self.root = root
        self.said = said
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head): request = head
        case .body: break
        case .end:
            guard let head = request else { return }
            request = nil
            answer(head, context: context)
        }
    }

    private func answer(_ head: HTTPRequestHead, context: ChannelHandlerContext) {
        var headers = HTTPHeaders([("Cache-Control", "no-store")])
        guard head.method == .GET || head.method == .HEAD else {
            return respond(.methodNotAllowed, headers, body: nil, keepAlive: head.isKeepAlive, context: context)
        }
        guard let file = PageRequests.file(for: head.uri, in: root), let data = try? Data(contentsOf: file) else {
            // A picture asked for as a PNG and found as its SVG answers 404 first, which says nothing wrong.
            if !head.uri.contains("/Images/") { said("404 \(head.uri)") }
            return respond(.notFound, headers, body: nil, keepAlive: head.isKeepAlive, context: context)
        }
        headers.add(name: "Content-Type", value: PageRequests.type(of: file))
        headers.add(name: "Content-Length", value: "\(data.count)")
        respond(.ok, headers, body: head.method == .GET ? data : nil, keepAlive: head.isKeepAlive, context: context)
    }

    private func respond(_ status: HTTPResponseStatus, _ headers: HTTPHeaders, body: Data?, keepAlive: Bool, context: ChannelHandlerContext) {
        var headers = headers
        if !headers.contains(name: "Content-Length") { headers.add(name: "Content-Length", value: "0") }
        context.write(wrapOutboundOut(.head(HTTPResponseHead(version: .http1_1, status: status, headers: headers))), promise: nil)
        if let body {
            var buffer = context.channel.allocator.buffer(capacity: body.count)
            buffer.writeBytes(body)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        let done = context.writeAndFlush(wrapOutboundOut(.end(nil)))
        let channel = context.channel
        if !keepAlive { done.whenComplete { _ in channel.close(promise: nil) } }
    }
}
#endif

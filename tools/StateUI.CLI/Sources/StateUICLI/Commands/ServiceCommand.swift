// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui service --listen <address:port>`: the tool's service, which another machine's tool - or this one's -
/// reaches over TCP with the protocol an editor speaks, once paired with the code it shows.
struct ServiceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "service",
        abstract: "Serves the tool's protocol over TCP until stopped, as another machine's tool reaches it."
    )

    @Option(help: "Where it listens: an address and a port, 127.0.0.1:7979 or [::1]:7979; port 0 takes a free one.")
    var listen: String

    func run() async throws {
        do throws(ToolingError) {
            let (address, port) = try Self.place(listen)
            let pairing = ServicePairing(said: { code in
                FileHandle.standardOutput.write(Data("stateui: pairing code \(code), good for ten minutes and one machine\n".utf8))
            })
            let listener = try ServiceListener.open(on: address, port: port, pairing: pairing)
            let place = "\(address.contains(":") ? "[\(address)]" : address):\(listener.port)"
            FileHandle.standardOutput.write(Data("stateui: serving on \(place) - pair another machine with `stateui remote add <name> <address>:\(listener.port) --code <code>`\n".utf8))
            await listener.serve()
        } catch {
            try OutputFormat.text.write(error)
            throw ExitCode(ExitStatus.of(error))
        }
    }

    /// The address and the port `listen` names: `address:port`, an IPv6 address within brackets.
    static func place(_ listen: String) throws(ToolingError) -> (String, UInt16) {
        let bracketed = listen.hasPrefix("[")
        guard let colon = listen.lastIndex(of: ":"), let port = UInt16(listen[listen.index(after: colon)...]) else {
            throw ToolingError(.invalidConfiguration, "--listen is an address and a port, 127.0.0.1:7979 - not \(listen).")
        }
        var address = String(listen[..<colon])
        if bracketed, address.hasSuffix("]") { address = String(address.dropFirst().dropLast()) }
        return (address, port)
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost

/// The HTTP server a driver's cases send to where the driver names none of its own: the suite's own, on the machine's
/// loopback.
@_spi(Host) extension HostDriver {
    /// The suite's server on the machine's loopback.
    public func served() throws -> String {
        guard let server = LoopbackServer.shared else { throw DriverCannot("serve a request") }
        return server.address
    }

    /// The requests for `/held` the suite's server took, and those stopped.
    public func held() throws -> (taken: Int, stopped: Int) {
        guard LoopbackServer.shared != nil else { throw DriverCannot("count the requests held") }
        return (
            LoopbackServer.heldStarted.load(ordering: .sequentiallyConsistent),
            LoopbackServer.heldStopped.load(ordering: .sequentiallyConsistent))
    }
}

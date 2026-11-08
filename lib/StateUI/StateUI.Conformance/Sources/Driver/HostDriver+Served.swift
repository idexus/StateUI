// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost

/// The HTTP server a driver's cases send to, the same on every host: the suite's own, on the machine's loopback.
@_spi(Host) extension HostDriver {
    /// The address of an HTTP server the driver stands up on this machine, no scheme left out: it answers every
    /// request with the status 201, the header `X-Method` naming the request's method, `X-Asked` saying what the
    /// request's own `X-Asked` said, and the request's body.
    public func served() throws -> String {
        guard let server = LoopbackServer.shared else { throw DriverCannot("serve a request") }
        return server.address
    }

    /// How many requests for `/held` the driver's server took, and how many of them their client stopped - the
    /// connection closed before the answer.
    public func held() throws -> (taken: Int, stopped: Int) {
        guard LoopbackServer.shared != nil else { throw DriverCannot("count the requests held") }
        return (
            LoopbackServer.heldStarted.load(ordering: .sequentiallyConsistent),
            LoopbackServer.heldStopped.load(ordering: .sequentiallyConsistent))
    }
}

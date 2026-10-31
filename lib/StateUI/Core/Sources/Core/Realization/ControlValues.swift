// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The values an application's own control takes together, as a host's registration hands them over whole: each by
/// its member, as the type its contract declares, and which of them changed.
///
///     web.applies(WebViewContract.userAgent, WebViewContract.source) { control, values in
///         control.userAgent = values[WebViewContract.userAgent]
///         if values.changed(WebViewContract.source) { control.show(values[WebViewContract.source]) }
///     }
public struct ControlValues<Realized: ElementContract> {
    private let values: ElementValues<Realized>

    /// The values `values` holds, as a control is handed them.
    @_spi(Host) public init(_ values: ElementValues<Realized>) {
        self.values = values
    }

    /// The value of `member`, as the type its contract declares - nil where it is not described.
    public subscript<Owner: Contract, Value: HostRepresentable>(_ member: ElementProperty<Owner, Value>) -> Value? {
        values[member]
    }

    /// Whether `member`'s value changed since the control last took them.
    public func changed<Owner: Contract, Value: HostRepresentable>(_ member: ElementProperty<Owner, Value>) -> Bool {
        values.changed(member)
    }
}

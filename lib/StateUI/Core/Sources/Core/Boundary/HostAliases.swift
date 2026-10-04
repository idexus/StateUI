// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The core's own types, under the names a Swift host reads them by.
// Design: docs/design/core/README.md#the-typed-boundary

/// A property value delivered directly to a native Swift host.
@_spi(Host) public typealias HostValue = PropValue

/// Which way a state crosses at a native-host attachment.
@_spi(Host) public typealias HostStateMode = StateMode

/// Which native-host channel carries an attached state.
@_spi(Host) public typealias HostStateKind = StateKind

/// A state image delivered directly to, or reported by, a native Swift host.
@_spi(Host) public typealias HostStateValue = StateCarried

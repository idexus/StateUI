// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

typealias GTKWidget = UnsafeMutablePointer<GtkWidget>

/// The casts GTK's macros make in C.
/// Design: docs/design/platforms/gtk/c-api.md#casts
extension UnsafeMutablePointer {
    /// The same object as another of its classes.
    func of<Other>(_: Other.Type = Other.self) -> UnsafeMutablePointer<Other> {
        UnsafeMutablePointer<Other>(OpaquePointer(self))
    }

    /// The same object as a final class GTK keeps opaque.
    var opaque: OpaquePointer { OpaquePointer(self) }
}

/// A signal's handler, handed the number of the view it belongs to.
typealias GTKSignalHandler = @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void

/// A property's change notice, handed the number of the view it belongs to.
typealias GTKNotifyHandler = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void

/// Connects `handler` to `signal` of `instance`, handing it `number`.
/// Design: docs/design/platforms/gtk/c-api.md#signals
@discardableResult
func connectSignal(_ instance: UnsafeMutableRawPointer, _ signal: String, number: Int64, _ handler: GTKSignalHandler) -> gulong {
    connect(instance, signal, number, unsafeBitCast(handler, to: GCallback.self))
}

/// Connects `handler` to the `notify::` signal named `signal` of `instance`, handing it `number`.
@discardableResult
func connectSignal(_ instance: UnsafeMutableRawPointer, _ signal: String, number: Int64, _ handler: GTKNotifyHandler) -> gulong {
    connect(instance, signal, number, unsafeBitCast(handler, to: GCallback.self))
}

private func connect(_ instance: UnsafeMutableRawPointer, _ signal: String, _ number: Int64, _ callback: GCallback) -> gulong {
    g_signal_connect_data(instance, signal, callback, UnsafeMutableRawPointer(bitPattern: Int(number)), nil, GConnectFlags(0))
}

/// The view number a signal's data carries.
func viewNumber(_ data: gpointer?) -> Int64 {
    Int64(Int(bitPattern: data))
}

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

/// A signal's handler handed one argument by address - a changed property's description, a gesture's sequence of
/// events - and the number of the view it belongs to.
typealias GTKArgumentHandler = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void

/// A press's handler: its place in a quick run, and where it is in the widget.
typealias GTKPressHandler = @convention(c) (UnsafeMutableRawPointer?, Int32, Double, Double, gpointer?) -> Void

/// A handler handed a point, or how far a drag has come.
typealias GTKPointHandler = @convention(c) (UnsafeMutableRawPointer?, Double, Double, gpointer?) -> Void

/// A handler handed one number: a pinch's scale.
typealias GTKScaleHandler = @convention(c) (UnsafeMutableRawPointer?, Double, gpointer?) -> Void

/// A spin button's reading of its words: it writes the number they say, and answers whether it read them.
typealias GTKInputHandler = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<Double>?, gpointer?) -> Int32

/// Connects `handler` to `signal` of `instance`, handing it `number`.
/// Design: docs/design/platforms/gtk/c-api.md#signals
@discardableResult
func connectSignal(_ instance: UnsafeMutableRawPointer, _ signal: String, number: Int64, _ handler: GTKSignalHandler) -> gulong {
    connect(instance, signal, number, unsafeBitCast(handler, to: GCallback.self))
}

@discardableResult
func connectSignal(_ instance: UnsafeMutableRawPointer, _ signal: String, number: Int64, _ handler: GTKArgumentHandler) -> gulong {
    connect(instance, signal, number, unsafeBitCast(handler, to: GCallback.self))
}

/// Connects `handler` to the change notice of `instance`'s `property`, handing it `number`.
@discardableResult
func connectNotify(_ instance: UnsafeMutableRawPointer, _ property: String, number: Int64, _ handler: GTKArgumentHandler) -> gulong {
    connect(instance, "notify::" + property, number, unsafeBitCast(handler, to: GCallback.self))
}

@discardableResult
func connectSignal(_ instance: UnsafeMutableRawPointer, _ signal: String, number: Int64, _ handler: GTKPressHandler) -> gulong {
    connect(instance, signal, number, unsafeBitCast(handler, to: GCallback.self))
}

@discardableResult
func connectSignal(_ instance: UnsafeMutableRawPointer, _ signal: String, number: Int64, _ handler: GTKPointHandler) -> gulong {
    connect(instance, signal, number, unsafeBitCast(handler, to: GCallback.self))
}

@discardableResult
func connectSignal(_ instance: UnsafeMutableRawPointer, _ signal: String, number: Int64, _ handler: GTKScaleHandler) -> gulong {
    connect(instance, signal, number, unsafeBitCast(handler, to: GCallback.self))
}

@discardableResult
func connectSignal(_ instance: UnsafeMutableRawPointer, _ signal: String, number: Int64, _ handler: GTKInputHandler) -> gulong {
    connect(instance, signal, number, unsafeBitCast(handler, to: GCallback.self))
}

private func connect(_ instance: UnsafeMutableRawPointer, _ signal: String, _ number: Int64, _ callback: GCallback) -> gulong {
    g_signal_connect_data(instance, signal, callback, UnsafeMutableRawPointer(bitPattern: Int(number)), nil, GConnectFlags(0))
}

/// The view number a signal's data carries.
func viewNumber(_ data: gpointer?) -> Int64 {
    Int64(Int(bitPattern: data))
}

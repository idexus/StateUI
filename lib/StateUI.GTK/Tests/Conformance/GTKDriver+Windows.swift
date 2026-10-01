// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@_spi(Host) import StateUIConformance

/// What the GTK driver reads of a window, and does to it as its user does: its title, its size and its smallest size
/// as GTK holds them, and its close button.
/// Design: docs/design/host/conformance.md#the-driver
extension GTKDriver {
    /// The window `element` - a window element - is shown in.
    func window(of element: MountedElement) throws -> GTKWindow {
        guard element.type == .window, let controller = renderer?.windows.first(where: { $0.element === element })
        else { throw DriverCannot("find the window of \(element.type.name)") }
        return controller.window
    }

    /// What the window of `element` holds of `property`: its title, the size it asks of the desktop, its smallest.
    func windowHolds(_ property: Prop, _ element: MountedElement) throws -> HostValue? {
        let window = try window(of: element)
        var size: (width: Int32, height: Int32) = (0, 0)
        switch property {
        case .title:
            return gtk_window_get_title(window.widget.of(GtkWindow.self)).map { String(cString: $0).propValue }
        case .width, .height:
            gtk_window_get_default_size(window.widget.of(GtkWindow.self), &size.width, &size.height)
            return Double(property == .width ? size.width : size.height).propValue
        case .minimumWidth, .minimumHeight:
            gtk_widget_get_size_request(window.widget, &size.width, &size.height)
            return Double(property == .minimumWidth ? size.width : size.height).propValue
        default:
            throw DriverCannot(reading: property, of: element)
        }
    }

    /// Closes the window of `element` as its close button does: GTK's request to close it.
    func close(_ element: MountedElement) throws {
        gtk_window_close(try window(of: element).widget.of(GtkWindow.self))
    }
}

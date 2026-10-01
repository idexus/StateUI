// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@_spi(Host) import StateUIConformance

/// What the GTK driver reads of a page's header bar, and does on it: the groups of actions at each edge and the
/// overflow, an action chosen and what its button shows, the bar's colours and the line under its title - each from
/// the header bar GTK shows.
/// Design: docs/design/host/conformance.md#the-driver
extension GTKDriver {
    /// The bar `page` shows: each edge's groups as their boxes hold them, then the overflow's menu.
    func bar(of page: MountedElement) throws -> String {
        let frame = try frame(of: page)
        let word = { (button: GTKWidget) -> String? in
            guard let item = frame.action(on: button)?.item else { return nil }
            return BarWords.word(item, enabled: gtk_widget_get_sensitive(button) != 0)
        }
        let groups = { (edge: GTKWidget) in
            GTKTestHost.children(of: edge).map { GTKTestHost.children(of: $0).compactMap(word) }.filter { !$0.isEmpty }
        }
        let overflow = zip(frame.overflowButtons, frame.chrome.overflow).compactMap { button, action in
            action.item.map { BarWords.word($0, enabled: gtk_widget_get_sensitive(button.widget) != 0) }
        }
        return BarWords.said(
            leading: groups(frame.leadingGroups), trailing: groups(frame.trailingGroups), overflow: overflow)
    }

    /// Chooses the toolbar item `element` as the user does: its button clicked, on the bar or in the overflow's menu -
    /// which GTK lets reach no button that cannot be chosen.
    func chooseAction(_ element: MountedElement) throws {
        guard let (button, _) = try actionButton(of: element) else { throw DriverCannot(.activate, on: element) }
        if gtk_widget_is_sensitive(button.widget) != 0 { button.click() }
    }

    /// What the button of the toolbar item `element` shows: its words, whether it can be chosen, where it stands,
    /// and whether its words stand beside its picture.
    func actionHolds(_ property: Prop, _ element: MountedElement) throws -> HostValue? {
        guard let (button, inOverflow) = try actionButton(of: element) else { return nil }
        let child = gtk_button_get_child(button.widget.of(GtkButton.self))
        switch property {
        case .text:
            let label = child.flatMap { child in
                ([child] + GTKTestHost.descendants(of: child)).first { GTKTestHost.holds($0, gtk_label_get_type()) }
            }
            if let label { return String(cString: gtk_label_get_text(label.opaque)).propValue }
            return gtk_widget_get_tooltip_text(button.widget).map { String(cString: $0).propValue }
        case .isEnabled: return (gtk_widget_get_sensitive(button.widget) != 0).propValue
        case .isDestructive: return (gtk_widget_has_css_class(button.widget, "destructive-action") != 0).propValue
        case .placement: return (inOverflow ? ToolbarItemPlacement.overflow : .bar).propValue
        case .icon:
            // The file its image shows, standing for the name the tree gave where it is one of that name's files.
            guard let image = child.flatMap({ child in
                      ([child] + GTKTestHost.descendants(of: child)).first { GTKTestHost.holds($0, gtk_image_get_type()) }
                  }),
                  let icon = gtk_image_get_gicon(image.opaque),
                  g_type_check_instance_is_a(UnsafeMutablePointer<GTypeInstance>(icon), g_file_icon_get_type()) != 0,
                  let file = g_file_icon_get_file(icon), let name = g_file_get_basename(file)
            else { return nil }
            defer { g_free(name) }
            let shown = String(cString: name)
            let named = element.value(.icon)?.string ?? ""
            return ImageSource(PictureArithmetic.files(for: named).contains(shown) ? named : shown).propValue
        case .showsText:
            let shown = child.map { GTKTestHost.descendants(of: $0) } ?? []
            let picture = shown.contains { GTKTestHost.holds($0, gtk_image_get_type()) }
            let words = shown.contains { GTKTestHost.holds($0, gtk_label_get_type()) }
            return (picture && words).propValue
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// What the header bar of the page `element` shows: its colour, the colour of what stands on it, and the line
    /// under its title.
    func barHolds(_ property: Prop, _ element: MountedElement) throws -> HostValue? {
        guard let page = element.type == .page ? element : element.visiblePage else {
            throw DriverCannot(reading: property, of: element)
        }
        let frame = try frame(of: page)
        renderer?.layOut()
        switch property {
        case .barBackgroundColor:
            guard let pixel = GTKTestHost.pixels(of: frame.header, at: [(4, 4)]).first, pixel >> 24 != 0 else {
                return nil
            }
            return Color(
                red: Int(pixel >> 16 & 0xFF), green: Int(pixel >> 8 & 0xFF), blue: Int(pixel & 0xFF),
                alpha: Int(pixel >> 24)).propValue
        case .barForegroundColor:
            return Self.color(of: frame.header).propValue
        case .barSubtitle:
            guard let heading = adw_header_bar_get_title_widget(frame.header.opaque),
                  GTKTestHost.holds(heading, adw_window_title_get_type()),
                  let subtitle = adw_window_title_get_subtitle(heading.opaque)
            else { return nil }
            let words = String(cString: subtitle)
            return words.isEmpty ? nil : words.propValue
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// The button of the toolbar item `element`, and whether it stands in the overflow's menu; nil where no bar shows
    /// it.
    private func actionButton(of element: MountedElement) throws -> (GTKButtonView, inOverflow: Bool)? {
        for frame in frames() {
            let onBar = (frame.chrome.leading + frame.chrome.trailing).flatMap { $0 }
            if let at = onBar.firstIndex(where: { $0.item === element }), at < frame.buttons.count {
                return (frame.buttons[at], false)
            }
            if let at = frame.chrome.overflow.firstIndex(where: { $0.item === element }), at < frame.overflowButtons.count {
                return (frame.overflowButtons[at], true)
            }
        }
        return nil
    }

    /// The frame whose header bar stands over `page`: the innermost holding its view.
    func frame(of page: MountedElement) throws -> GTKPageFrame {
        guard let view = (page.native as? GTKElement)?.view else { throw DriverCannot("read the bar of \(page.type.name)") }
        let holding = frames().filter { $0.page === view || gtk_widget_is_ancestor(view.widget, $0.widget) != 0 }
        guard let innermost = holding.first(where: { frame in
            !holding.contains { $0 !== frame && gtk_widget_is_ancestor($0.widget, frame.widget) != 0 }
        }) else { throw DriverCannot("read the bar of \(page.type.name)") }
        return innermost
    }

    /// Every page's frame the window shows: a page by itself, a stack's pages, a split view's panes.
    func frames() -> [GTKPageFrame] {
        guard let renderer else { return [] }
        return (renderer.window?.pageFrame.map { [$0] } ?? []) + renderer.views(GTKNavigationView.self).flatMap(\.frames)
            + renderer.views(GTKSplitView.self).flatMap { [$0.sidebarFrame, $0.detailFrame].compactMap { $0 } }
    }
}

extension GTKPageFrame {
    /// The action whose button on the bar is `button`.
    fileprivate func action(on button: GTKWidget) -> GTKToolbarAction? {
        let onBar = (chrome.leading + chrome.trailing).flatMap { $0 }
        guard let at = buttons.firstIndex(where: { $0.widget == button }), at < onBar.count else { return nil }
        return onBar[at]
    }
}

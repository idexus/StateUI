// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@_spi(Host) import StateUIConformance

/// What the host's own record of a view says, where GTK reads nothing back: the classes of the host's style sheet a
/// widget wears - its padding, its box, its fill, its placeholder's colour - its transform, a window's place among
/// the scenes kept - each ✓.
/// Design: docs/design/host/conformance.md#the-driver
extension GTKDriver {
    /// What the host's record of `element` says of `property`; nil for a member this does not read.
    func recorded(_ property: Prop, on element: MountedElement, view: GTKView?) throws -> HostValue?? {
        if element.type == .window, property == .windowType || property == .windowValue {
            let kept = try keptWindow(element)
            return property == .windowType ? .some(kept.kind.map { .name($0) }) : .some(kept.value.map { .string($0) })
        }
        guard let view else { return nil }
        if MountedElement.transformProperties.contains(property) { return .some(Self.transform(property, of: view)) }
        let classes = GTKTestHost.descendants(of: view.widget).flatMap(Self.classes)
        let named = { (prefix: String) in classes.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) } }
        switch (property, view) {
        case (.padding, is GTKTextualView), (.padding, is GTKButtonView), (.padding, is GTKCheckView):
            guard let sides = named("stateui-padding-")?.split(separator: "-").compactMap({ Self.number($0) }),
                  sides.count == 4
            else { return .some(nil) }
            return Insets(left: sides[3], top: sides[0], right: sides[1], bottom: sides[2]).propValue
        case (.background, is GTKTextualView):
            return .some(named("stateui-fill-").flatMap(Self.color).map { Background.color($0).propValue })
        case (.background, is GTKButtonView), (.stroke, is GTKButtonView), (.lineWidth, is GTKButtonView),
             (.shape, is GTKButtonView):
            return .some(named("stateui-box").flatMap { Self.box(property, of: $0) })
        // Any other view wears its fill on its own widget.
        case (.background, _) where !(view is GTKLayoutView):
            let fill = Self.classes(of: view.widget).first { $0.hasPrefix("stateui-fill-") }
            return .some(fill.map { String($0.dropFirst("stateui-fill-".count)) }.flatMap(Self.color)
                .map { Background.color($0).propValue })
        case (.placeholderColor, _):
            return .some(classes.first { $0.hasPrefix("stateui-words") }.flatMap { name in
                name.split(separator: "-").first { $0.hasPrefix("p") && $0.count == 9 }
                    .flatMap { Self.color(String($0.dropFirst())) }.map(\.propValue)
            })
        default: return nil
        }
    }

    /// What a button's box class says of `property`: its fill, its outline's colour and width, and its corners.
    private static func box(_ property: Prop, of name: String) -> HostValue? {
        let parts = name.split(separator: "-")
        let part = { (letter: Character) in parts.first { $0.first == letter }.map { String($0.dropFirst()) } }
        switch property {
        case .background: return part("f").flatMap(color).map { Background.color($0).propValue }
        case .stroke: return part("s").flatMap(color).map { Brush.solidColor($0).propValue }
        case .lineWidth: return part("w").flatMap { number(Substring($0)) }.map(\.propValue)
        default:
            guard let radius = part("r").flatMap({ number(Substring($0)) }) else { return nil }
            let shape: ContainerShape = radius >= 9999 ? .ellipse : radius == 0 ? .rectangle : .roundedRectangle(radius)
            return shape.propValue
        }
    }

    /// The member of the view's own transform the host last wrote.
    private static func transform(_ property: Prop, of view: GTKView) -> HostValue? {
        let transform = view.transform
        let value: Double? = switch property {
        case .translationX: transform.translationX
        case .translationY: transform.translationY
        case .rotation: transform.rotation
        case .rotationX: transform.rotationX
        case .rotationY: transform.rotationY
        case .scale: transform.scaleX == transform.scaleY ? transform.scaleX : nil
        case .scaleX: transform.scaleX
        case .scaleY: transform.scaleY
        case .pivotX: transform.pivotX
        case .pivotY: transform.pivotY
        default: nil
        }
        return value?.propValue
    }

    /// The classes GTK holds on `widget`.
    /// The colour `widget`'s own fill class paints it; nil where it wears none.
    static func fill(of widget: GTKWidget) -> Color? {
        classes(of: widget).first { $0.hasPrefix("stateui-fill-") }
            .flatMap { color(String($0.dropFirst("stateui-fill-".count))) }
    }

    private static func classes(of widget: GTKWidget) -> [String] {
        guard let names = gtk_widget_get_css_classes(widget) else { return [] }
        defer { g_strfreev(names) }
        var found: [String] = []
        var each = names
        while let name = each.pointee {
            found.append(String(cString: name))
            each += 1
        }
        return found
    }

    /// A number as a class writes it, a point as an underscore.
    private static func number(_ text: Substring) -> Double? {
        Double(text.replacing("_", with: "."))
    }

    /// A colour as a class writes it: red, green, blue and alpha, two hexadecimal digits each.
    private static func color(_ hex: String) -> Color? {
        let digits = Array(hex.prefix(8))
        guard digits.count == 8 else { return nil }
        let channels = stride(from: 0, to: 8, by: 2).compactMap { Int(String(digits[$0..<$0 + 2]), radix: 16) }
        guard channels.count == 4 else { return nil }
        return Color(red: channels[0], green: channels[1], blue: channels[2], alpha: channels[3])
    }

    /// The kind and the value the host keeps the window `element` by for the next start.
    private func keptWindow(_ element: MountedElement) throws -> KeptScenes.Window {
        let scenes = element.enclosing(type: .application)?.children.filter { $0.type == .scene } ?? []
        guard let scene = element.enclosing(type: .scene), let sceneIndex = scenes.firstIndex(where: { $0 === scene }),
              let index = scene.windows.firstIndex(where: { $0 === element })
        else { throw DriverCannot("find the scene holding the window") }
        let kept = GTKKeptValues.readScenes(applicationID: "").scenes
        guard kept.indices.contains(sceneIndex), kept[sceneIndex].windows.indices.contains(index) else {
            throw DriverCannot("find the window among the scenes kept")
        }
        return kept[sceneIndex].windows[index]
    }
}

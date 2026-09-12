// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI

/// Runs a StateUI application as native AppKit controls in the current process.
///
/// This first host slice materializes Application, Scene, Window, ContentPage,
/// vertical stacks, labels, buttons and images. Unsupported controls remain
/// visible as diagnostic labels, so adding the next adapter is incremental.
@MainActor
public enum StateUIAppKit {
    /// Starts `NSApplication` and displays the application already registered
    /// with `stateUIUseApp(_:)`.
    ///
    /// - Parameter resourceDirectory: A directory containing image resources.
    public static func run(resourceDirectory: URL? = nil) {
        let application = NSApplication.shared
        let delegate = AppDelegate(resourceDirectory: resourceDirectory)

        application.setActivationPolicy(.regular)
        application.delegate = delegate
        application.run()

        withExtendedLifetime(delegate) {}
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let host: AppKitRenderer

    init(resourceDirectory: URL?) {
        host = AppKitRenderer(resourceDirectory: resourceDirectory)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        host.start()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

/// The unchecked promise is narrow: every mutation and every AppKit call is in
/// a `@MainActor` method. The only cross-thread capture posts `pump()` onto the
/// main queue after the blocking doorbell returns.
@MainActor
private final class AppKitRenderer: @unchecked Sendable {
    private let resourceDirectory: URL?
    private var baseline: Int32 = 0
    private var root: MountedNode?
    private var window: NSWindow?
    private var doorbellStarted = false

    init(resourceDirectory: URL?) {
        self.resourceDirectory = resourceDirectory
    }

    func start() {
        let appearance = NSApplication.shared.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua])
        StateUIHost.setTheme(appearance == .darkAqua ? .dark : .light)
        pump()
        startDoorbell()
    }

    func dispatch(_ handler: Int32) {
        _ = StateUIHost.dispatch(handler)
        pump()
    }

    func pump() {
        _ = StateUIHost.runJobs()

        let commands = StateUIHost.takeCommands()
        if !commands.isEmpty {
            let names = commands.map { $0.act.name }.joined(separator: ", ")
            let reason = "the AppKit host does not implement these acts yet: \(names)"
            NSLog("StateUI AppKit: %@", reason)
            StateUIHost.failTakenCommands(reason)
        }

        guard root == nil || StateUIHost.needsRender else { return }

        let rendered = StateUIHost.render(baseline: baseline)

        if let root, root.id == rendered.root.id, root.type == rendered.root.type,
           !rendered.root.replace {
            root.apply(rendered.root)
        } else {
            root = MountedNode(rendered.root, host: self, resources: resourceDirectory)
        }

        baseline = rendered.generation
        synchronizeWindow()
    }

    private func startDoorbell() {
        guard !doorbellStarted else { return }
        doorbellStarted = true

        DispatchQueue.global(qos: .userInteractive).async { [self] in
            while true {
                _ = StateUIHost.waitForWork()
                DispatchQueue.main.async { [self] in pump() }
            }
        }
    }

    private func synchronizeWindow() {
        guard let windowNode = root?.first(type: .window),
              let page = windowNode.first(type: .contentPage),
              let content = page.view else { return }

        let window: NSWindow

        if let existing = self.window {
            window = existing
        } else {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false)
            window.center()
            self.window = window
        }

        if window.contentView !== content {
            window.contentView = content
        }

        window.title = page.string(.title) ?? windowNode.string(.title) ?? "StateUI"
        window.makeKeyAndOrderFront(nil)
    }
}

@MainActor
private final class MountedNode: NSObject {
    let id: ElementId
    private(set) var type: NodeType
    private(set) var view: NSView?

    private weak var host: AppKitRenderer?
    private let resources: URL?
    private var properties: [Prop: HostValue] = [:]
    private var events: [Event: Int32] = [:]
    private var children: [MountedNode] = []
    private var sizeConstraints: [NSLayoutConstraint] = []
    private var childConstraints: [NSLayoutConstraint] = []

    init(_ patch: HostPatch, host: AppKitRenderer, resources: URL?) {
        id = patch.id
        type = patch.type
        self.host = host
        self.resources = resources
        super.init()

        view = makeView()
        apply(patch)
    }

    func apply(_ patch: HostPatch) {
        guard let host else { return }

        type = patch.type

        for property in patch.clearedProperties {
            properties[property] = nil
        }

        for (property, value) in patch.properties {
            properties[property] = value
        }

        if case .replace(let events) = patch.events {
            self.events = events
        }

        switch patch.children {
        case .unchanged:
            break

        case .arranged(let childPatches):
            let previous = Dictionary(uniqueKeysWithValues: children.map { ($0.id, $0) })
            children = childPatches.map { childPatch in
                if let child = previous[childPatch.id], child.type == childPatch.type,
                   !childPatch.replace {
                    child.apply(childPatch)
                    return child
                }

                return MountedNode(childPatch, host: host, resources: resources)
            }

        case .changed(let childPatches):
            for childPatch in childPatches {
                if let index = children.firstIndex(where: { $0.id == childPatch.id }) {
                    let child = children[index]

                    if child.type == childPatch.type, !childPatch.replace {
                        child.apply(childPatch)
                    } else {
                        children[index] = MountedNode(
                            childPatch, host: host, resources: resources)
                    }
                } else {
                    children.append(MountedNode(childPatch, host: host, resources: resources))
                }
            }
        }

        applyProperties()
        arrangeChildren()
    }

    func first(type sought: NodeType) -> MountedNode? {
        if type == sought { return self }

        for child in children {
            if let found = child.first(type: sought) { return found }
        }

        return nil
    }

    func string(_ property: Prop) -> String? {
        properties[property]?.string
    }

    @objc private func clicked(_ sender: NSButton) {
        guard let handler = events[.clicked] else { return }
        host?.dispatch(handler)
    }

    private func makeView() -> NSView? {
        switch type {
        case .application, .scene, .window:
            return nil

        case .contentPage:
            let page = NSView()
            page.translatesAutoresizingMaskIntoConstraints = true
            return page

        case .verticalStackLayout:
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .centerX
            stack.distribution = .gravityAreas
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack

        case .label:
            let label = NSTextField(labelWithString: "")
            label.alignment = .center
            label.maximumNumberOfLines = 0
            return label

        case .button:
            let button = NSButton(title: "", target: self, action: #selector(clicked(_:)))
            button.bezelStyle = .rounded
            return button

        case .image:
            let image = NSImageView()
            image.imageScaling = .scaleProportionallyUpOrDown
            return image

        default:
            let unsupported = NSTextField(labelWithString: "AppKit: unsupported \(type.name)")
            unsupported.textColor = .systemRed
            return unsupported
        }
    }

    private func applyProperties() {
        guard let view else { return }

        view.isHidden = properties[.isVisible]?.bool == false
        view.alphaValue = properties[.opacity]?.number ?? 1

        if let label = view as? NSTextField {
            label.stringValue = string(.text) ?? ""
            label.textColor = color(.textColor) ?? .labelColor
            label.font = font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize))
        }

        if let button = view as? NSButton {
            button.title = string(.text) ?? ""
            let buttonFont = font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize))
            button.font = buttonFont
            button.isEnabled = properties[.isEnabled]?.bool ?? true

            let foreground = color(.textColor) ?? .controlTextColor
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [.font: buttonFont, .foregroundColor: foreground])

            let background = color(.backgroundColor)
            button.isBordered = background == nil
            button.wantsLayer = background != nil
            button.layer?.backgroundColor = background?.cgColor
            button.layer?.cornerRadius = properties[.cornerRadius]?.number ?? 0
        }

        if let stack = view as? NSStackView {
            stack.spacing = properties[.spacing]?.number ?? 0

            if let padding = properties[.padding]?.numbers, padding.count >= 4 {
                stack.edgeInsets = NSEdgeInsets(
                    top: padding[1], left: padding[0], bottom: padding[3], right: padding[2])
            } else {
                stack.edgeInsets = NSEdgeInsets()
            }
        }

        if let imageView = view as? NSImageView {
            imageView.image = string(.source).flatMap { image(named: $0) }
        }

        sizeConstraints.forEach { $0.isActive = false }
        sizeConstraints.removeAll(keepingCapacity: true)

        if let width = properties[.widthRequest]?.number {
            sizeConstraints.append(view.widthAnchor.constraint(equalToConstant: width))
        }
        if let height = properties[.heightRequest]?.number {
            sizeConstraints.append(view.heightAnchor.constraint(equalToConstant: height))
        }

        if let button = view as? NSButton,
           let padding = properties[.padding]?.numbers, padding.count >= 4 {
            let intrinsic = button.intrinsicContentSize
            sizeConstraints.append(button.widthAnchor.constraint(
                greaterThanOrEqualToConstant: intrinsic.width + padding[0] + padding[2]))
            sizeConstraints.append(button.heightAnchor.constraint(
                greaterThanOrEqualToConstant: intrinsic.height + padding[1] + padding[3]))
        }

        NSLayoutConstraint.activate(sizeConstraints)
    }

    private func arrangeChildren() {
        guard let view else { return }
        let childViews = children.flatMap(\.presentableViews)

        if let stack = view as? NSStackView {
            for child in stack.arrangedSubviews {
                stack.removeArrangedSubview(child)
                child.removeFromSuperview()
            }

            for child in childViews {
                stack.addArrangedSubview(child)
            }
            return
        }

        guard type == .contentPage else { return }

        NSLayoutConstraint.deactivate(childConstraints)
        childConstraints.removeAll(keepingCapacity: true)

        for child in view.subviews where !childViews.contains(where: { $0 === child }) {
            child.removeFromSuperview()
        }

        guard let child = childViews.first else { return }

        if child.superview !== view {
            view.addSubview(child)
        }

        child.translatesAutoresizingMaskIntoConstraints = false

        // HelloWorld's root stack asks to be centered. Fill is the native
        // fallback for future pages that do not state that preference.
        if childNode?.enumeration(.verticalOptions) == 1 {
            childConstraints = [
                child.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                child.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                child.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
                child.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor),
            ]
        } else {
            childConstraints = [
                child.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                child.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                child.topAnchor.constraint(equalTo: view.topAnchor),
                child.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ]
        }

        NSLayoutConstraint.activate(childConstraints)
    }

    private var childNode: MountedNode? { children.first }

    private var presentableViews: [NSView] {
        if let view { return [view] }
        return children.flatMap(\.presentableViews)
    }

    private func enumeration(_ property: Prop) -> Int32? {
        properties[property]?.enumeration
    }

    private func font(fallback: NSFont) -> NSFont {
        let size = properties[.fontSize]?.number ?? fallback.pointSize
        let traits = properties[.fontAttributes]?.enumeration ?? 0
        let weight: NSFont.Weight = traits & 1 == 1 ? .bold : .regular
        var font = NSFont.systemFont(ofSize: size, weight: weight)

        if traits & 2 == 2,
           let italic = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) as NSFont? {
            font = italic
        }

        return font
    }

    private func color(_ property: Prop) -> NSColor? {
        guard let color = properties[property]?.color else { return nil }
        return NSColor(
            calibratedRed: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: CGFloat(color.alpha) / 255)
    }

    private func image(named name: String) -> NSImage? {
        let url = resources?.appendingPathComponent(name)

        if let url, let image = NSImage(contentsOf: url) {
            return image
        }

        if let url, url.pathExtension.lowercased() == "png" {
            let svg = url.deletingPathExtension().appendingPathExtension("svg")
            if let image = NSImage(contentsOf: svg) { return image }
        }

        return NSImage(systemSymbolName: "swift", accessibilityDescription: name)
    }
}

#endif

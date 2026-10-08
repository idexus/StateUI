// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A surface a view's box draws behind what it holds - no child of it, kept beneath its children - and the
/// background it lays over itself.
@MainActor
protocol AppKitBoxSurface: NSView {
    /// The background laid over the surface.
    var wash: AppKitBoxWash { get }
}

/// A box's background laid over its backdrop, which a colour with an alpha tints; hidden while it paints nothing.
@MainActor
final class AppKitBoxWash: NSView {
    /// What it paints.
    var fill = AppKitBrush() {
        didSet {
            isHidden = !fill.paints
            needsDisplay = true
        }
    }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitBoxWash is made in code")
    }

    override func draw(_ dirtyRect: NSRect) {
        fill.draw(in: NSBezierPath(rect: bounds), bounds: bounds)
    }

    /// Takes no click: what is under it does.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// A material drawn behind what a view holds - no child of it, kept beneath its children - or behind a window's
/// pages, where it lets the desktop through.
/// Design: docs/design/platforms/appkit/views.md#a-layouts-own-box
@MainActor
final class AppKitMaterialView: NSVisualEffectView, AppKitBoxSurface {
    let wash = AppKitBoxWash()

    /// The material AppKit draws for a blur's thickness: the role whose translucency stands in that place, measured,
    /// the one order both themes keep from thin to thick.
    static func role(_ thickness: Blur.Thickness) -> NSVisualEffectView.Material {
        switch thickness {
        case .ultraThin: .fullScreenUI
        case .thin: .popover
        case .regular: .menu
        case .thick: .underWindowBackground
        case .ultraThick: .windowBackground
        }
    }

    /// The thickness a role stands for; nil for a role no thickness names.
    static func thickness(_ role: NSVisualEffectView.Material) -> Blur.Thickness? {
        Blur.Thickness.allCases.first { self.role($0) == role }
    }

    /// A blur within a window - over what the window draws behind it - or behind it, the desktop showing.
    init(_ thickness: Blur.Thickness, behindWindow: Bool) {
        super.init(frame: .zero)
        self.material = Self.role(thickness)
        blendingMode = behindWindow ? .behindWindow : .withinWindow
        state = .followsWindowActiveState
        wantsLayer = true
        addSubview(wash)
    }

    override func layout() {
        super.layout()
        wash.frame = bounds
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitMaterialView is made in code")
    }

    /// Takes no click: what is under it in the view holding it does.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// The platform's glass behind what a view holds - no child of it, kept beneath its children.
/// Design: docs/design/platforms/appkit/views.md#a-layouts-own-box
@MainActor
final class AppKitGlassView: NSGlassEffectView, AppKitBoxSurface {
    let wash = AppKitBoxWash()
    private var isInteractive = false
    var isInteractiveForTesting: Bool { isInteractive }

    /// The colour the glass is tinted with, active or not; nil for none.
    private(set) var tint: NSColor?

    override init(frame: NSRect) {
        super.init(frame: frame)
        contentView = wash
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitGlassView is made in code")
    }

    /// Clear glass or regular, tinted with `tint` where one is given, answering the user where it is interactive -
    /// from macOS 27.
    func show(_ glass: HostMaterial.Glass, tint: NSColor?) {
        style = glass.isClear ? .clear : .regular
        self.tint = tint
        showTint()
        isInteractive = glass.isInteractive
        if #available(macOS 27, *) { effectIsInteractive = glass.isInteractive }
    }

    /// The tint in the glass while its window stands active, else in what the glass holds: macOS draws an inactive
    /// window's glass without its tint, never what the glass holds.
    /// Design: docs/design/platforms/appkit/views.md#a-layouts-own-box
    private func showTint() {
        let active = NSApp.isActive && (window?.isKeyWindow == true || window?.isMainWindow == true)
        tintColor = active ? tint : nil
        wash.layer?.backgroundColor = active ? nil : tint?.cgColor
        wash.isHidden = active || tint == nil
    }

    /// Follows its window's standing - key, main, its application in front - as the window and the application say.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let center = NotificationCenter.default
        center.removeObserver(self)
        let changed = #selector(standingChanged)
        if let window {
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                         NSWindow.didBecomeMainNotification, NSWindow.didResignMainNotification] {
                center.addObserver(self, selector: changed, name: name, object: window)
            }
        }
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            center.addObserver(self, selector: changed, name: name, object: nil)
        }
        showTint()
    }

    @objc private func standingChanged() {
        showTint()
    }

    /// Takes the click where it answers the user, which its view hears as it rises; else what is under it in the
    /// view holding it does.
    override func hitTest(_ point: NSPoint) -> NSView? {
        isInteractive ? super.hitTest(point) : nil
    }
}

#endif

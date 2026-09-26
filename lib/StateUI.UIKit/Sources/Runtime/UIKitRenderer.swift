// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The UIKit host's runtime: the host layer's (`HostRuntime`) over UIKit's windows - each StateUI window in a
/// window scene iOS connected - and the core woken on UIKit's main queue.
/// Design: docs/design/platforms/uikit/runtime.md
@MainActor
final class UIKitRenderer {
    static let log = HostLog(host: "UIKit")

    /// The one runtime of the process, which every scene iOS connects shows a window of.
    static let shared = UIKitRenderer()

    /// Where the application's pictures are.
    static var resourceDirectory: URL?

    let frameClock: UIKitFrameClock
    private let reducesMotion: () -> Bool

    private(set) lazy var runtime = HostRuntime(
        clock: frameClock, reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in UIKitElement(element, host: self) },
        log: { UIKitRenderer.log.error($0) })

    /// Every StateUI window with the controller showing it.
    let roster = WindowRoster<UIKitWindowController>()

    /// The scenes iOS connected that no StateUI window stands in yet, the first first.
    private var waitingScenes: [UIWindowScene] = []

    private var started = false
    private var reportedDisplay = false

    init(clock: (() -> Double)? = nil, reducesMotion: @escaping () -> Bool = { UIAccessibility.isReduceMotionEnabled }) {
        frameClock = clock.map { UIKitFrameClock(now: $0, ticksWithTheDisplay: false) } ?? UIKitFrameClock()
        self.reducesMotion = reducesMotion
        runtime.displayCycle.presenter = self
        runtime.pump.presenter = self
    }

    /// Starts the runtime as the application launches: what the host realizes and what the device is, then the core
    /// woken on the main queue whenever it has work.
    func start() {
        guard !started else { return }
        started = true
        runtime.core.setRealization(UIKitRegistrations.registry.realization, unrealized: UIKitRealization.unrealized)
        reportEnvironment()
        runtime.tree.followTheLanguagesDirection()
        let core = runtime.core
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            core.ringForever { DispatchQueue.main.async { self?.runtime.pump.turn() } }
        }
    }

    /// A scene iOS connected: a StateUI scene of its own, whose window stands in it. The first says what the
    /// display is.
    func connect(_ scene: UIWindowScene) {
        if !reportedDisplay {
            reportedDisplay = true
            let screen = scene.screen
            runtime.core.setDisplayInfo(HostDisplayInfo(
                width: screen.nativeBounds.width, height: screen.nativeBounds.height, density: screen.nativeScale,
                refreshRate: Double(screen.maximumFramesPerSecond)))
        }
        waitingScenes.append(scene)
        runtime.core.connectScene()
        runtime.pump.turn()
    }

    /// A scene iOS let go of.
    func disconnect(_ scene: UIWindowScene) {
        waitingScenes.removeAll { $0 === scene }
    }

    private func reportEnvironment() {
        let device = UIDevice.current
        #if targetEnvironment(simulator)
        let deviceType = DeviceType.virtual
        #else
        let deviceType = DeviceType.physical
        #endif
        runtime.core.setDeviceInfo(HostDeviceInfo(
            formFactor: device.userInterfaceIdiom == .pad ? .tablet : .phone, platform: "iOS", model: device.model,
            manufacturer: "Apple", name: device.name, versionString: device.systemVersion, deviceType: deviceType))
        let bundle = Bundle.main
        runtime.core.setApplicationInfo(HostApplicationInfo(
            name: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ProcessInfo.processInfo.processName,
            packageName: bundle.bundleIdentifier ?? "",
            versionString: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            buildString: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))
    }

    /// Shows every StateUI window in a window scene of its own, the first waiting one; a window the tree no longer
    /// holds lets its scene go.
    func synchronizeWindows() {
        guard let root = runtime.tree.root, root.type == .application else { return }

        roster.update(root: root, make: { [unowned self] element in
            UIKitWindowController(element, scene: waitingScenes.isEmpty ? nil : waitingScenes.removeFirst())
        }, close: { $0.close() })
        for (element, controller) in roster.windows {
            controller.present(element, in: runtime)
        }
        runtime.displayCycle.hold()
    }

    /// A picture the application ships, by its name: its own file, else its drawing (`PictureArithmetic.drawnFiles`),
    /// each at the pixels a point it holds.
    func image(named name: String) -> UIImage? {
        for drawn in PictureArithmetic.drawnFiles(for: name) {
            guard let path = Self.resourceDirectory?.appendingPathComponent(drawn.file).path,
                  let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage
            else { continue }
            return UIImage(cgImage: cgImage, scale: CGFloat(drawn.scale), orientation: image.imageOrientation)
        }
        Self.log.error("no picture named \(name) in the application's images")
        return nil
    }
}

extension UIKitRenderer: TurnPresenter {
    func presentRendered() {
        synchronizeWindows()
    }

    func perform(_ call: HostActCall) {
        runtime.core.fail(call, "the UIKit host does not perform the act '\(call.act.name)' yet", log: { Self.log.error($0) })
    }
}

extension UIKitRenderer: FramePresenter {
    var wantsFrames: Bool {
        runtime.frames.wantsFrames
    }

    func commitUserReports(now: Double) {
        runtime.frames.commit(now: now)
    }

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        let impact = runtime.tree.present(states: states, properties: properties)
        if impact.windowChrome { synchronizeWindows() }
    }

    func renderIfNeeded() {
        if runtime.core.needsRender { runtime.pump.turn() }
    }
}
#endif

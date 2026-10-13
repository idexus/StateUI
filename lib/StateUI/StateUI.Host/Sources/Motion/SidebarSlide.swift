// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Split views' sidebars sliding in and out on the runtime's frames, the same on every host that slides one itself:
/// how far each has come - 0 hidden, 1 shown - so its pane stands that wide each frame, the detail beside it taking
/// every width between, and its page at its whole width, the pane's trailing edge at the page's.
/// Design: docs/design/host/motion.md#a-sidebar-sliding
@_spi(Host) @MainActor public final class SidebarSlide {
    private let animator: Animator
    private let now: () -> Double
    private let reducesMotion: () -> Bool

    /// What each sliding split does with how far its sidebar has come and whether it rests there, by its mount.
    private var followers: [UInt64: (_ shown: Double, _ rested: Bool) -> Void] = [:]

    /// How far each sliding sidebar stood at its last frame.
    private var standing: [UInt64: Double] = [:]

    /// Called when a slide starts, so the frame clock is held while it runs.
    public var onStart: () -> Void = {}

    /// How long a sidebar takes to slide in or out, in milliseconds.
    public static let milliseconds = 250.0

    /// Slides on `animator`, on `now`'s time; with less motion each slide arrives at once.
    public init(animator: Animator, now: @escaping () -> Double, reducesMotion: @escaping () -> Bool) {
        self.animator = animator
        self.now = now
        self.reducesMotion = reducesMotion
    }

    /// Slides the sidebar of the split mounted as `mount` in where `shown`, else out, from where it stands - `from`
    /// where it stands still - telling `follow` at once and each frame how far it has come and whether it rests.
    public func slide(_ mount: UInt64, from: Double, shown: Bool, follow: @escaping (Double, Bool) -> Void) {
        let key = AnimationTarget.slide(mount)
        let destination = shown ? 1.0 : 0.0
        let position = animator.animation(for: key)?.position(at: now())
        let start = position?.value.first ?? standing[mount] ?? from
        let animation = Animation(
            from: [start], destination: [destination], velocity: [position?.velocity.first ?? 0],
            motion: .eased(UInt(Self.milliseconds)), began: now())

        guard !reducesMotion(), !animation.arrives else {
            forget(mount)
            follow(destination, true)
            return
        }
        animator.start(animation, for: key)
        followers[mount] = follow
        standing[mount] = start
        follow(start, false)
        onStart()
    }

    /// Tells each sliding split how far its sidebar has come.
    public func follow(_ steps: [AnimationStep]) {
        for step in steps {
            guard case .slide(let mount) = step.target, let shown = step.value.first else { continue }
            let follow = followers[mount]
            standing[mount] = step.rested ? nil : shown
            if step.rested { followers[mount] = nil }
            follow?(shown, step.rested)
        }
    }

    /// Ends the slide of the split mounted as `mount` where it stands, telling it nothing more.
    public func forget(_ mount: UInt64) {
        animator.halt(.slide(mount))
        followers[mount] = nil
        standing[mount] = nil
    }

    /// The pane's width `shown` of the way to its whole `width`.
    public static func paneWidth(_ shown: Double, of width: Double) -> Double {
        width * min(max(shown, 0), 1)
    }

    /// Where the sidebar's page stands in a pane `pane` wide: at its whole `width`, its trailing edge at the pane's.
    public static func page(inPane pane: Double, width: Double, height: Double) -> Rect {
        Rect(x: pane - width, y: 0, width: width, height: height)
    }
}

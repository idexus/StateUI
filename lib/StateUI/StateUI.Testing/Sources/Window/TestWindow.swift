// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A window an application's test shows a page in, and uses as the application's user does: it finds a view by the
/// identifier automation knows it by, or by an aim, acts on it and reads what it holds.
///
///     @MainActor
///     func testClicksAreCounted() async throws {
///         let window = try await TestWindow(motion: .none) { MainPage() }
///         let button = try window.element("main.click")
///
///         try await button.perform(.activate)
///
///         XCTAssertEqual(try button.value(TextElementContract.text), "Clicked 1 time")
///     }
///
/// The page stands over StateUI's core with no platform's toolkit, where `swift test` runs. One window stands at a
/// time: a new one closes the last. `close()` waits for the page's lifecycle work; dropping the window begins the
/// same cleanup without waiting for it.
@MainActor
public final class TestWindow {
    /// The driver the window acts and reads through.
    let driver: any HostDriver

    /// The tree the page mounted; nil once the window closed.
    private var tree: MountedTree?

    /// The application this window started; an old window never closes a later registration.
    private let registration: UInt64

    /// The one teardown this window began, shared by every caller waiting for its end.
    private var closing: HostTeardown?

    /// The window standing: one at a time.
    private static weak var standing: TestWindow?

    /// Shows `page` in a window, every change in it animating under `motion` - `.none` for a change shown at once,
    /// where a test reads what it changed with no waiting.
    public convenience init(motion: Motion = .standard, @ViewBuilder _ page: @escaping @MainActor () -> some View)
        async throws {
        try await Self.standing?.close()
        self.init(driver: CoreDriver(), motion: motion, page)
        try await settle(since: nil)
    }

    /// Shows `page` through `driver` - a host's own, on its toolkit - every change animating under `motion`, a second
    /// of its frames run: what a host's suite walks a window through (`TestWindowWalk`).
    @_spi(Host) public init(
        driver: any HostDriver, motion: Motion = .standard, @ViewBuilder _ page: @escaping @MainActor () -> some View
    ) {
        self.driver = driver
        Self.standing?.beginClose()
        HostBoundary.application.motion = motion
        tree = driver.start(clock: nil, reducesMotion: false) { page() }
        registration = Renderer.shared.applicationRegistration
        Self.standing = self
        // The page's own work - a service begun as it appears - is the page's, not an act's: a second of frames.
        try? settleNow(since: nil)
    }

    isolated deinit {
        beginClose()
    }

    /// Closes the window, cancels the page's owned work and waits for its disappearing and destroying handlers to
    /// finish. A closed window has no views to find. Calling this again waits for the same cleanup, without running
    /// it twice; it never closes a later window.
    ///
    ///     try await window.close()
    ///
    /// - Throws: `TestFailure` if the page's cleanup is still under way after ten seconds; `CancellationError` if
    ///   the task waiting for it is cancelled. The window remains closed in either case.
    public func close() async throws {
        try await close(until: .now + Self.patience)
    }

    /// Waits for this window's cleanup alone, with a bounded deadline.
    func close(until deadline: ContinuousClock.Instant) async throws {
        let ending = beginClose()
        while !ending.isFinished {
            try Task.checkCancellation()
            try Self.checkCloseDeadline(deadline)
            driver.step()
            await Task.yield()
        }
    }

    /// The same wait in a native host's own loop, whose steps run the UI thread's work.
    @_spi(Host) public func closeNow() throws {
        let ending = beginClose()
        let deadline = ContinuousClock.now + Self.patience
        while !ending.isFinished {
            try Self.checkCloseDeadline(deadline)
            driver.step()
        }
    }

    /// One teardown for explicit closure, replacement and release, scoped to the application this window made.
    /// Design: docs/design/host/testing.md#closing-a-window
    @discardableResult
    private func beginClose() -> HostTeardown {
        if let closing { return closing }
        tree = nil
        let ending = Renderer.shared.clearApplication(expected: registration)
        closing = ending
        if Renderer.shared.applicationRegistration == registration { driver.close() }
        if Self.standing === self { Self.standing = nil }
        return ending
    }

    private static func checkCloseDeadline(_ deadline: ContinuousClock.Instant) throws {
        guard ContinuousClock.now < deadline else {
            throw TestFailure(description: "the window closed, but its lifecycle work did not finish before the deadline")
        }
    }

    /// The view automation knows by `identifier` - its `accessibilityIdentifier`; it fails where no view, or more
    /// than one, has it.
    ///
    ///     let button = try window.element("main.click")
    public func element(_ identifier: String) throws -> TestElement {
        let element = TestElement(window: self, finding: .identifier(identifier))
        _ = try element.mounted()
        return element
    }

    /// The view `aim` is put on; it fails where the aim stands on none.
    ///
    ///     let page = SignInPage()  // holding `@Aim(TextField.self) var name`
    ///     let window = try await TestWindow(motion: .none) { page }
    ///     let field = try window.element(page.name)
    public func element<Target>(_ aim: Aim<Target>) throws -> TestElement {
        let element = TestElement(window: self, finding: .aim { aim.place })
        _ = try element.mounted()
        return element
    }

    /// The elements the page mounted now, searched from the window's root; none once the window closed.
    var root: MountedElement? { tree?.root }

    /// Runs the page's work until nothing more waits: the runs begun since `mark` - the handlers an act raised, the
    /// work they began - to their end, and a second of frames after the last, the UI thread's work run between the
    /// steps; a second of frames alone where `mark` is nil.
    /// - Throws: `TestFailure` where a run begun since `mark` is still under way as the patience runs out.
    func settle(since mark: Int?) async throws {
        var frames = 0
        let deadline = ContinuousClock.now + Self.patience
        while frames < Self.turns {
            if try Self.waiting(since: mark, until: deadline) { frames = 0 }
            driver.step()
            frames += 1
            await Task.yield()
        }
    }

    /// The same, the driver's steps alone running the UI thread's work - a host's own loop, turned by its driver.
    func settleNow(since mark: Int?) throws {
        var frames = 0
        let deadline = ContinuousClock.now + Self.patience
        while frames < Self.turns {
            if try Self.waiting(since: mark, until: deadline) { frames = 0 }
            driver.step()
            frames += 1
        }
    }

    /// Whether a run begun since `mark` is still under way; it fails where `deadline` has passed with one standing.
    private static func waiting(since mark: Int?, until deadline: ContinuousClock.Instant) throws -> Bool {
        guard let mark else { return false }
        let standing = HostBoundary.runsUnderWay(since: mark)
        guard standing > 0 else { return false }
        guard ContinuousClock.now < deadline else {
            throw TestFailure(description: "\(standing) run(s) the act began are still under way after \(patience)")
        }
        return true
    }

    /// How many steps a settling takes after the last run ends: a second of frames, the work waiting between them.
    private static let turns = 60

    /// How long a settling waits on the runs an act began before failing.
    private static let patience = Duration.seconds(10)
}

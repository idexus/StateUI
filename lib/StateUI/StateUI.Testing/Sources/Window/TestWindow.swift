// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIConformance
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
///         XCTAssertEqual(button.value(TextualElementContract.text), "Clicked 1 time")
///     }
///
/// The page stands over StateUI's core with no platform's toolkit, where `swift test` runs. One window stands at a
/// time: a new one closes the last.
@MainActor
public final class TestWindow {
    /// The driver the window acts and reads through.
    let driver: any HostDriver

    /// The tree the page mounted.
    private let tree: MountedTree

    /// Shows `page` in a window, every change in it animating under `motion` - `.none` for a change shown at once,
    /// where a test reads what it changed with no waiting.
    public convenience init(motion: Motion = .standard, @ViewBuilder _ page: @escaping @MainActor () -> some View)
        async throws {
        self.init(driver: CoreDriver(), motion: motion, page)
        await settle()
    }

    /// Shows `page` through `driver` - a host's own, on its toolkit - every change animating under `motion`, the
    /// work it began done: what a host's suite walks a window through (`TestWindowWalk`).
    @_spi(Host) public init(
        driver: any HostDriver, motion: Motion = .standard, @ViewBuilder _ page: @escaping @MainActor () -> some View
    ) {
        self.driver = driver
        HostBoundary.application.motion = motion
        tree = driver.start(clock: nil, reducesMotion: false) { page() }
        settleNow()
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
        let element = TestElement(window: self, finding: .aim { aim.element })
        _ = try element.mounted()
        return element
    }

    /// The elements the page mounted now, searched from the window's root.
    var root: MountedElement? { tree.root }

    /// Runs the page's work until nothing more waits: the handlers an act raised, the work they began, the frames
    /// they asked for - the UI thread's work run between the steps.
    func settle() async {
        for _ in 0..<Self.turns {
            driver.step()
            await Task.yield()
        }
    }

    /// The same, the driver's steps alone running the UI thread's work - a host's own loop, turned by its driver.
    func settleNow() {
        for _ in 0..<Self.turns { driver.step() }
    }

    /// How many steps a settling takes: a second of frames, each with the work waiting between them.
    private static let turns = 60
}

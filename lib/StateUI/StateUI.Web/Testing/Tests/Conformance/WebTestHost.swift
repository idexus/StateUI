// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIConformance
@testable import StateUIWeb
import CWebTesting

/// XCTest's own loop on the page. It runs on Swift's cooperative executor, and awaits MainActor between its tests;
/// once a host runs, MainActor's executor is the UI thread's, which only a host's entry drains - and the cooperative
/// executor, finding nothing left to run, would end the program after the first test. A task of its own keeps it
/// going: it drains the UI thread's jobs - the next test among them - and lets the page go on a frame where none
/// waited.
/// Design: docs/design/platforms/web/runtime.md#the-conformance-run
enum WebTestLoop {
    /// Started once, before any host makes the UI thread's executor MainActor's.
    static let started: Void = {
        Task(executorPreference: globalConcurrentExecutor) {
            while true {
                if HostBoundary.runJobs() == 0 { stateui_web_testing_pause() }
                await Task.yield()
            }
        }
    }()
}

extension WebRenderer {
    /// A host showing `page` in the browser's window, on `clock` where one is given: a first launch, which finds
    /// nothing an earlier host kept.
    static func running(
        clock: TestClock? = nil, reducesMotion: Bool = false, @ViewBuilder _ page: @escaping @MainActor () -> any View
    ) -> WebRenderer {
        let application = OneWindowApplication(page: page)
        return running(clock: clock, reducesMotion: reducesMotion, application: { application })
    }

    /// A host running `application`, on `clock` where one is given: a first launch, which finds nothing an earlier
    /// host kept - or, `keeping`, a launch after the last, which finds what it kept.
    static func running(
        clock: TestClock? = nil, reducesMotion: Bool = false, keeping: Bool = false,
        application: @escaping @MainActor () -> any Application
    ) -> WebRenderer {
        shared?.leave()
        if !keeping { forgetWhatIsKept() }
        Renderer.shared.setApplication(application())
        let renderer = WebRenderer(
            applicationName: "Conformance", clock: clock.map { clock in { clock.now } },
            reducesMotion: { reducesMotion })
        renderer.run()
        renderer.step()
        return renderer
    }

    /// Forgets what the page's store keeps, as an application's first launch finds it.
    static func forgetWhatIsKept() {
        try? WebBrowser.run("localStorage.clear()")
    }

    /// The host leaves the page: what it was told late settles into no window of the next host's.
    func leave() {
        runtime.tree.root?.leave()
        runtime.presenter = nil
        for controller in roster.controllers { controller.close() }
    }

    /// One step as the browser takes it: a frame of the page's - its tasks, its rendering, what its observers say -
    /// then the jobs, a turn, and a display frame while something asks for one.
    func step() {
        WebBrowser.pause()
        _ = runtime.core.runJobs()
        entryEnded()
        if frameClock.held { frame() }
    }

    /// One display frame at the clock's time, and what it placed.
    func frame() {
        runtime.displayCycle.frame(now: frameClock.now())
        entryEnded()
    }
}

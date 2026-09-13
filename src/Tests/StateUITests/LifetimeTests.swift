// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `.onCreated` and `.onDestroying`: what runs as an element comes into the
// tree and as it leaves - its lifetime in the TREE, which the differ knows and
// no platform has to report.

import StateUIWireProbe
import XCTest
@_spi(Host) @testable import StateUI

/// A view that says when it comes and goes, into a log it is lent.
private struct Coming: ContentView {
    @Binding var log: [String]
    let name: String

    var content: any View {
        Label(name)
            .onCreated { log.append("created \(name)") }
            .onDestroying { log.append("destroying \(name)") }
    }
}

/// A view holding another, both saying when they come and go.
private struct Holding: ContentView {
    @Binding var log: [String]

    var content: any View {
        VStack {
            Coming(log: $log, name: "inner")
        }
        .onCreated { log.append("created outer") }
        .onDestroying { log.append("destroying outer") }
    }
}

/// A view whose own state is changed while it stands and read as it leaves.
private struct Drafting: ContentView {
    @Binding var log: [String]
    @State private var draft = "typed"

    var content: any View {
        Button(draft)
            .onClicked { draft = "edited" }
            .onDestroying { log.append("saved \(draft)") }
    }
}

final class LifetimeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
    }

    /// An element runs `.onCreated` ONCE, after the render that brings it into
    /// the tree - and a render that describes it again runs nothing.
    func testAnElementRunsOnCreatedOnceAsItComesIntoTheTree() {
        let log = State(wrappedValue: [String]())
        let renders = Renders()
        let tree = { VStack { Coming(log: log.projectedValue, name: "a") }.body }

        renders.render(tree())
        XCTAssertEqual(log.wrappedValue, ["created a"])

        renders.render(tree(), changed: Renderer.shared.pendingChanges)
        renders.renderFromScratch(tree())
        XCTAssertEqual(log.wrappedValue, ["created a"])
    }

    /// An element runs `.onDestroying` once, after the first render that no
    /// longer describes it.
    func testAnElementRunsOnDestroyingAsItLeaves() {
        let log = State(wrappedValue: [String]())
        let shown = State(wrappedValue: true)
        let renders = Renders()
        let tree = {
            VStack {
                if shown.wrappedValue {
                    Coming(log: log.projectedValue, name: "a")
                }
            }.body
        }

        renders.render(tree())
        shown.wrappedValue = false
        renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(log.wrappedValue, ["created a", "destroying a"])
    }

    /// An element comes in before what is under it, and leaves after it - the
    /// innermost first.
    func testWhatIsUnderAnElementLeavesBeforeIt() {
        let log = State(wrappedValue: [String]())
        let shown = State(wrappedValue: true)
        let renders = Renders()
        let tree = {
            VStack {
                if shown.wrappedValue {
                    Holding(log: log.projectedValue)
                }
            }.body
        }

        renders.render(tree())
        shown.wrappedValue = false
        renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(log.wrappedValue, [
            "created outer", "created inner", "destroying inner", "destroying outer",
        ])
    }

    /// As it leaves, an element's `@State` still answers - holding what it was
    /// last written, not what it started with, which is what saving needs.
    func testAnElementsStateAnswersAsItLeaves() throws {
        let log = State(wrappedValue: [String]())
        let shown = State(wrappedValue: true)
        let renders = Renders()
        let tree = {
            VStack {
                if shown.wrappedValue {
                    Drafting(log: log.projectedValue)
                }
            }.body
        }

        let first = renders.render(tree())
        XCTAssertTrue(renders.fire(try XCTUnwrap(Self.clicked(in: first))))
        renders.render(tree(), changed: Renderer.shared.pendingChanges)

        shown.wrappedValue = false
        renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(log.wrappedValue, ["saved edited"])
    }

    /// The first clicked handler under a patch.
    private static func clicked(in patch: HostPatch) -> Int? {
        patch.events?[.clicked] ?? patch.children.lazy.compactMap { clicked(in: $0) }.first
    }

    /// A new identity is a new element: the one standing goes and the new one
    /// comes - and the one leaving says so first, so what it saves is there
    /// for the one arriving to read.
    func testANewIdentityIsANewElement() {
        let log = State(wrappedValue: [String]())
        let identity = State(wrappedValue: 1)
        let renders = Renders()
        let tree = {
            VStack {
                Coming(log: log.projectedValue, name: "\(identity.wrappedValue)")
                    .id(identity.wrappedValue)
            }.body
        }

        renders.render(tree())
        identity.wrappedValue = 2
        renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(log.wrappedValue, ["created 1", "destroying 1", "created 2"])
    }

    /// What is written ON a composed view runs as well as what its body
    /// writes, the body's first.
    func testWhatIsWrittenOnAComposedViewRunsToo() {
        let log = State(wrappedValue: [String]())
        let renders = Renders()

        renders.render(VStack {
            Coming(log: log.projectedValue, name: "a")
                .onCreated { log.wrappedValue.append("written on it") }
        }.body)

        XCTAssertEqual(log.wrappedValue, ["created a", "written on it"])
    }

    /// A page the library builds runs them too.
    func testAPageRunsThemToo() {
        let log = State(wrappedValue: [String]())
        let path = State(wrappedValue: [Int]())
        let renders = Renders()

        renders.render(
            NavigationPage(path.projectedValue) {
                LifetimePage()
            } destination: { _ in
                LifetimePage()
            }
            .onCreated { log.wrappedValue.append("created stack") }
            .body)

        XCTAssertEqual(log.wrappedValue, ["created stack"])
    }

    // MARK: - In the message that brings it

    /// What `.onCreated` writes is in the message that brings the element -
    /// a window's title given by its page as it comes in reaches the host
    /// with the window, not a render after it.
    func testWhatOnCreatedWritesIsInTheMessageThatBringsTheElement() throws {
        Scenes.shared.reset()
        defer { Scenes.shared.reset() }
        Renderer.shared.setApplication(Titling())

        let first = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: 0))
        let window = try XCTUnwrap(first.root.children.first?.children.first)

        XCTAssertEqual(window.type, "Window")
        XCTAssertTrue(
            window.props.contains { $0.key == "title" && $0.value == .string("Titled") },
            "the title the page wrote as it came in waited for a render of its own")
        XCTAssertFalse(
            Renderer.shared.needsRender,
            "what the handler wrote was sent, and nothing is left to render")
    }

    /// A chain of handlers - each render's write firing the next - is walked
    /// into the message a few times and no more; what is left runs after it,
    /// and nothing is lost.
    func testAChainLongerThanTheSettlingPassesGoesOnAfterTheMessage() throws {
        Scenes.shared.reset()
        defer { Scenes.shared.reset() }
        Renderer.shared.setApplication(Chaining())

        let first = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: 0))

        XCTAssertEqual(
            labels(in: first.root), ["\(Renderer.settleLimit)"],
            "each settling pass walks one step of the chain into the message")

        stateUIRunJobs()

        XCTAssertTrue(
            Renderer.shared.needsRender,
            "the step there was no pass left for ran after the message, and asks for the next")
    }

    /// Every label's text under a node, depth first.
    private func labels(in node: WireProbe.WireNode) -> [String] {
        let own = node.type == "Label"
            ? node.props.compactMap { prop -> String? in
                guard prop.key == "text", case .string(let text) = prop.value else { return nil }
                return text
            }
            : []

        return own + node.children.flatMap { labels(in: $0) }
    }
}

/// An application whose page gives its window a title as it comes in.
private struct Titling: Application {
    var scene: any Scene { TitlingWindow() }
}

/// The window the page names.
private struct TitlingWindow: Window {
    var page: any Page { TitlingPage() }
}

/// A page that names the window it is in as it comes into the tree.
private struct TitlingPage: ContentPage {
    @Environment private var window: WindowSession

    var content: any View {
        Label("hello").onCreated { window.title = "Titled" }
    }
}

/// An application whose page counts itself up, one step per render, for ever.
private struct Chaining: Application {
    var scene: any Scene { ChainingWindow() }
}

/// The window the counting page is in.
private struct ChainingWindow: Window {
    var page: any Page { ChainingPage() }
}

/// A page whose count moves every time it is seen to have moved.
private struct ChainingPage: ContentPage {
    @State private var count = 0

    var content: any View {
        Label("\(count)")
            .onCreated { count += 1 }
            .onChanged(count) { count += 1 }
    }
}

/// A page with nothing on it, for a stack to hold.
private struct LifetimePage: ContentPage {
    var content: any View { Label("page") }
}

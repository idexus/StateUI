// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Which view a presentation is of: where it stands on the page, as StateUI tells one view from another. It names
/// the same view while the page builds again around it, and is kept to ask for that view's presentation later. A
/// view the page names with `.id(_:)` keeps its id when it is taken off the page and shown again; any other is a
/// new view then.
public struct TestPresentationID: Hashable, Sendable {
    /// The keys from the window's root down to the view.
    let place: [ElementID]
}

/// How a view stands in a test's window now: where a movement has got it to, not where it is going.
///
///     try button.send(.activate)
///     try await clock.advance(by: .milliseconds(150))
///
///     let panel = try window.element("panel").presentation()
///     XCTAssertEqual(panel.translation.y, 120, accuracy: 0.5)
///
/// It reads what StateUI decided for the view, the same on every platform; it proves nothing of a platform's
/// pixels.
public struct TestPresentation: Equatable, Sendable {
    /// Which view this is.
    public let id: TestPresentationID

    /// Which mounting of the view this is: a view taken off the page and shown again is another.
    public let generation: UInt64

    /// How opaque the view is drawn, 0 to 1.
    public let opacity: Double

    /// How far the view is drawn from where its layout put it.
    public let translation: Point

    /// How the view is scaled across, `scale` and `scaleX` together.
    public let scaleX: Double

    /// How the view is scaled down, `scale` and `scaleY` together.
    public let scaleY: Double

    /// How far the view is turned, in degrees clockwise.
    public let rotation: Double

    /// Whether the user's hand reaches the view: it stands in no disabled branch and ignores no input.
    public let takesInput: Bool

    /// How assistive technology meets the view; nil where the tree says nothing and the platform decides.
    public let accessibilityPresence: AccessibilityPresence?

    /// The presentation of `element`, standing at `place`.
    /// Design: docs/design/host/testing.md#what-a-view-presents
    @MainActor init(of element: MountedElement, at place: [ElementID]) {
        let drawn = element.drawingTransform
        id = TestPresentationID(place: place)
        generation = element.mount
        opacity = element.number(.opacity) ?? 1
        translation = Point(x: drawn.translationX, y: drawn.translationY)
        scaleX = drawn.scaleX
        scaleY = drawn.scaleY
        rotation = drawn.rotation
        takesInput = element.isEffectivelyEnabled && element.presented(.ignoresInput)?.bool != true
        accessibilityPresence = element.accessibilityWords.presence
    }
}

extension TestWindow {
    /// How the view `id` names stands now; nil where no view stands there - it was taken off the page, or the window
    /// closed.
    ///
    ///     let id = try window.element("card").presentation().id
    ///     try window.element("remove").send(.activate)
    ///     try await window.flush()
    ///     XCTAssertNil(window.presentation(id))
    public func presentation(_ id: TestPresentationID) -> TestPresentation? {
        root?.element(at: id.place).map { TestPresentation(of: $0, at: id.place) }
    }
}

extension TestElement {
    /// How the view stands now. It fails where no view, or two, is the one it names, as `perform` does.
    public func presentation() throws -> TestPresentation {
        let element = try mounted()
        var place: [ElementID] = []
        var next: MountedElement? = element
        while let standing = next {
            place.insert(standing.id, at: 0)
            next = standing.parent
        }
        return TestPresentation(of: element, at: place)
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitMotionTests: XCTestCase {
    func testTransitionSurfaceIsClosedAroundNativePresentations() {
        XCTAssertTrue(AppKitTransitionSurface.presents(.opacity, on: .label))
        XCTAssertTrue(AppKitTransitionSurface.presents(.padding, on: .contentPage))
        XCTAssertTrue(AppKitTransitionSurface.presents(.renderTransform, on: .line))
        XCTAssertTrue(AppKitTransitionSurface.presents(.x, on: .window))

        XCTAssertFalse(AppKitTransitionSurface.presents(.rotationX, on: .label))
        XCTAssertFalse(AppKitTransitionSurface.presents(.value, on: .stepper))
        XCTAssertFalse(AppKitTransitionSurface.presents(.selectedTabColor, on: .tabbedPage))
        XCTAssertFalse(AppKitTransitionSurface.presents(.opacity, on: .indicatorView))
        XCTAssertFalse(AppKitTransitionSurface.presents(Prop("custom"), on: .label))
    }

    @MainActor
    func testAPropertyTransitionBeginsAtItsStandingValueAndLandsExactly() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("label"), type: .label)
        initial.properties[.opacity] = .number(0.25)
        renderer.applyForTesting(initial)

        var changed = HostPatch(id: .manual("label"), type: .label)
        changed.properties[.opacity] = .number(0.75)
        changed.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertEqual(label.alphaValue, 0.25, accuracy: 0.000_001)
        XCTAssertTrue(renderer.propertyMotionsActiveForTesting)

        now = 100
        renderer.advanceMotionsForTesting()
        XCTAssertEqual(label.alphaValue, 0.5, accuracy: 0.000_001)

        now = 200
        renderer.advanceMotionsForTesting()
        XCTAssertEqual(label.alphaValue, 0.75, accuracy: 0.000_001)
        XCTAssertFalse(renderer.propertyMotionsActiveForTesting)

        now = 300
        renderer.advanceMotionsForTesting()
        XCTAssertEqual(label.alphaValue, 0.75, accuracy: 0.000_001)
    }

    @MainActor
    func testANewMovingPropertyStartsAtItsNativeDefault() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(HostPatch(id: .manual("label"), type: .label))

        var changed = HostPatch(id: .manual("label"), type: .label)
        changed.properties[.opacity] = .number(0)
        changed.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertEqual(label.alphaValue, 1, accuracy: 0.000_001)

        now = 100
        renderer.advanceMotionsForTesting()
        XCTAssertEqual(label.alphaValue, 0.5, accuracy: 0.000_001)
    }

    @MainActor
    func testNewPlanarTransformPropertiesStartAtIdentityTogether() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(HostPatch(id: .manual("label"), type: .label))

        var changed = HostPatch(id: .manual("label"), type: .label)
        changed.properties[.translationX] = .number(10)
        changed.properties[.scale] = .number(2)
        changed.transitions[.translationX] = HostTransition(motion: .eased(200, .linear))
        changed.transitions[.scale] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        var transform = try XCTUnwrap(label.layer).affineTransform()
        XCTAssertEqual(transform.tx, 0, accuracy: 0.000_001)
        XCTAssertEqual(transform.a, 1, accuracy: 0.000_001)

        now = 100
        renderer.advanceMotionsForTesting()
        transform = try XCTUnwrap(label.layer).affineTransform()
        XCTAssertEqual(transform.tx, 5, accuracy: 0.000_001)
        XCTAssertEqual(transform.a, 1.5, accuracy: 0.000_001)
    }

    @MainActor
    func testNewStackGeometryStartsAtZeroTogether() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(HostPatch(id: .manual("stack"), type: .verticalStackLayout))

        var changed = HostPatch(id: .manual("stack"), type: .verticalStackLayout)
        changed.properties[.padding] = .numbers([20, 40, 60, 80])
        changed.properties[.spacing] = .number(10)
        changed.transitions[.padding] = HostTransition(motion: .eased(200, .linear))
        changed.transitions[.spacing] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        let stack = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("stack")) as? AppKitStackView)
        XCTAssertEqual(stack.padding.top, 0, accuracy: 0.000_001)
        XCTAssertEqual(stack.padding.left, 0, accuracy: 0.000_001)
        XCTAssertEqual(stack.padding.bottom, 0, accuracy: 0.000_001)
        XCTAssertEqual(stack.padding.right, 0, accuracy: 0.000_001)
        XCTAssertEqual(stack.spacing, 0, accuracy: 0.000_001)

        now = 100
        renderer.advanceMotionsForTesting()
        XCTAssertEqual(stack.padding.top, 20, accuracy: 0.000_001)
        XCTAssertEqual(stack.padding.left, 10, accuracy: 0.000_001)
        XCTAssertEqual(stack.padding.bottom, 40, accuracy: 0.000_001)
        XCTAssertEqual(stack.padding.right, 30, accuracy: 0.000_001)
        XCTAssertEqual(stack.spacing, 5, accuracy: 0.000_001)
    }

    @MainActor
    func testOnePropertyFrameArrangesEachChangedAncestorOnce() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties[.opacity] = .number(0)
        label.properties[.translationX] = .number(0)
        var initial = HostPatch(id: .manual("stack"), type: .verticalStackLayout)
        initial.properties[.padding] = .numbers([0, 0, 0, 0])
        initial.properties[.spacing] = .number(0)
        initial.children = .arranged([label])
        renderer.applyForTesting(initial)

        var movingLabel = HostPatch(id: .manual("label"), type: .label)
        movingLabel.properties[.opacity] = .number(1)
        movingLabel.properties[.translationX] = .number(10)
        movingLabel.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        movingLabel.transitions[.translationX] = HostTransition(
            motion: .eased(200, .linear))
        var moving = HostPatch(id: .manual("stack"), type: .verticalStackLayout)
        moving.properties[.padding] = .numbers([20, 40, 60, 80])
        moving.properties[.spacing] = .number(10)
        moving.transitions[.padding] = HostTransition(motion: .eased(200, .linear))
        moving.transitions[.spacing] = HostTransition(motion: .eased(200, .linear))
        moving.children = .changed([movingLabel])
        renderer.applyForTesting(moving)

        let stack = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("stack")) as? AppKitStackView)
        let nativeLabel = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        let arrangementsBeforeFrame = stack.arrangementCountForTesting

        now = 100
        renderer.advanceMotionsForTesting()

        XCTAssertEqual(
            stack.arrangementCountForTesting - arrangementsBeforeFrame,
            1)
        XCTAssertEqual(stack.padding.top, 20, accuracy: 0.000_001)
        XCTAssertEqual(stack.padding.left, 10, accuracy: 0.000_001)
        XCTAssertEqual(stack.spacing, 5, accuracy: 0.000_001)
        XCTAssertEqual(nativeLabel.alphaValue, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(
            try XCTUnwrap(nativeLabel.layer).affineTransform().tx,
            5,
            accuracy: 0.000_001)
    }

    @MainActor
    func testAnUnrelatedSparsePropertyLeavesMotionRunning() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("label"), type: .label)
        initial.properties[.opacity] = .number(0)
        renderer.applyForTesting(initial)

        var moving = HostPatch(id: .manual("label"), type: .label)
        moving.properties[.opacity] = .number(1)
        moving.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(moving)

        now = 50
        renderer.advanceMotionsForTesting()
        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertEqual(label.alphaValue, 0.25, accuracy: 0.000_001)

        var unrelated = HostPatch(id: .manual("label"), type: .label)
        unrelated.properties[.text] = .string("still moving")
        renderer.applyForTesting(unrelated)
        XCTAssertTrue(renderer.propertyMotionsActiveForTesting)

        now = 100
        renderer.advanceMotionsForTesting()
        XCTAssertEqual(label.alphaValue, 0.5, accuracy: 0.000_001)
    }

    @MainActor
    func testAPropertyMotionDoesNotRewriteTheReadersScrollPosition() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var content = HostPatch(id: .manual("content"), type: .boxView)
        content.properties[.widthRequest] = .number(100)
        content.properties[.heightRequest] = .number(500)
        var initial = HostPatch(id: .manual("scroll"), type: .scrollView)
        initial.properties[.orientation] = .enumeration(1)
        initial.properties[.scroll] = .numbers([0, 0])
        initial.properties[.opacity] = .number(0)
        initial.children = .arranged([content])
        renderer.applyForTesting(initial)

        let scroll = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("scroll")) as? AppKitScrollView)
        scroll.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        scroll.layoutSubtreeIfNeeded()
        scroll.beginMovementForTesting()
        scroll.moveAsReaderForTesting(to: NSPoint(x: 0, y: 120))
        XCTAssertEqual(scroll.offset.y, 120, accuracy: 0.001)

        var moving = HostPatch(id: .manual("scroll"), type: .scrollView)
        moving.properties[.opacity] = .number(1)
        moving.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(moving)
        XCTAssertEqual(scroll.offset.y, 120, accuracy: 0.001)

        now = 100
        renderer.advanceMotionsForTesting()
        XCTAssertEqual(scroll.offset.y, 120, accuracy: 0.001)
    }

    @MainActor
    func testReducedMotionAssignsThePropertyTargetImmediately() throws {
        var initial = HostPatch(id: .manual("label"), type: .label)
        initial.properties[.opacity] = .number(0)
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { 0 },
            reducesMotion: { true })
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(initial)

        var changed = HostPatch(id: .manual("label"), type: .label)
        changed.properties[.opacity] = .number(1)
        changed.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertEqual(label.alphaValue, 1, accuracy: 0.000_001)
        XCTAssertFalse(renderer.propertyMotionsActiveForTesting)
    }

    @MainActor
    func testEnablingReducedMotionLandsAnActivePropertyTransition() throws {
        var now = 0.0
        var reduced = false
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { reduced })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("label"), type: .label)
        initial.properties[.opacity] = .number(0)
        renderer.applyForTesting(initial)

        var changed = HostPatch(id: .manual("label"), type: .label)
        changed.properties[.opacity] = .number(1)
        changed.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        now = 50
        renderer.advanceMotionsForTesting()
        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertEqual(label.alphaValue, 0.25, accuracy: 0.000_001)

        reduced = true
        now = 60
        renderer.advanceMotionsForTesting()

        XCTAssertEqual(label.alphaValue, 1, accuracy: 0.000_001)
        XCTAssertFalse(renderer.propertyMotionsActiveForTesting)
    }

    @MainActor
    func testAPropertyWithoutATransitionInterruptsTheActiveChannel() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("label"), type: .label)
        initial.properties[.opacity] = .number(0)
        renderer.applyForTesting(initial)

        var moving = HostPatch(id: .manual("label"), type: .label)
        moving.properties[.opacity] = .number(1)
        moving.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(moving)

        now = 100
        renderer.advanceMotionsForTesting()
        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertEqual(label.alphaValue, 0.5, accuracy: 0.000_001)

        var snapped = HostPatch(id: .manual("label"), type: .label)
        snapped.properties[.opacity] = .number(0.25)
        renderer.applyForTesting(snapped)
        XCTAssertEqual(label.alphaValue, 0.25, accuracy: 0.000_001)
        XCTAssertFalse(renderer.propertyMotionsActiveForTesting)

        now = 300
        renderer.advanceMotionsForTesting()
        XCTAssertEqual(label.alphaValue, 0.25, accuracy: 0.000_001)
    }

    @MainActor
    func testClearingAPropertyInterruptsMotionAndRestoresItsNativeDefault() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("label"), type: .label)
        initial.properties[.opacity] = .number(0.2)
        renderer.applyForTesting(initial)

        var moving = HostPatch(id: .manual("label"), type: .label)
        moving.properties[.opacity] = .number(0.8)
        moving.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(moving)

        now = 100
        renderer.advanceMotionsForTesting()
        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertEqual(label.alphaValue, 0.5, accuracy: 0.000_001)

        var cleared = HostPatch(id: .manual("label"), type: .label)
        cleared.clearedProperties = [.opacity]
        renderer.applyForTesting(cleared)
        XCTAssertEqual(label.alphaValue, 1, accuracy: 0.000_001)
        XCTAssertFalse(renderer.propertyMotionsActiveForTesting)

        now = 300
        renderer.advanceMotionsForTesting()
        XCTAssertEqual(label.alphaValue, 1, accuracy: 0.000_001)
    }

    @MainActor
    func testAPropertyRetargetCarriesItsCurrentVelocity() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("label"), type: .label)
        initial.properties[.opacity] = .number(0)
        renderer.applyForTesting(initial)

        var first = HostPatch(id: .manual("label"), type: .label)
        first.properties[.opacity] = .number(1)
        first.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(first)

        now = 100
        renderer.advanceMotionsForTesting()
        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertEqual(label.alphaValue, 0.5, accuracy: 0.000_001)

        var second = HostPatch(id: .manual("label"), type: .label)
        second.properties[.opacity] = .number(0.2)
        second.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(second)
        XCTAssertEqual(label.alphaValue, 0.5, accuracy: 0.000_001)

        now = 101
        renderer.advanceMotionsForTesting()
        XCTAssertGreaterThan(label.alphaValue, 0.5)

        now = 300
        renderer.advanceMotionsForTesting()
        XCTAssertEqual(label.alphaValue, 0.2, accuracy: 0.000_001)
        XCTAssertFalse(renderer.propertyMotionsActiveForTesting)
    }

    @MainActor
    func testEqualAuthoredIDsInDifferentBranchesOwnDifferentChannels() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        func label(opacity: Double) -> HostPatch {
            var label = HostPatch(id: .manual("same"), type: .label)
            label.properties[.opacity] = .number(opacity)
            return label
        }

        func branch(_ id: String, child: HostPatch) -> HostPatch {
            var branch = HostPatch(id: .manual(id), type: .horizontalStackLayout)
            branch.children = .arranged([child])
            return branch
        }

        var initial = HostPatch(id: .manual("root"), type: .verticalStackLayout)
        initial.children = .arranged([
            branch("first", child: label(opacity: 0)),
            branch("second", child: label(opacity: 1)),
        ])
        renderer.applyForTesting(initial)

        func changedLabel(opacity: Double) -> HostPatch {
            var label = HostPatch(id: .manual("same"), type: .label)
            label.properties[.opacity] = .number(opacity)
            label.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
            return label
        }

        func changedBranch(_ id: String, child: HostPatch) -> HostPatch {
            var branch = HostPatch(id: .manual(id), type: .horizontalStackLayout)
            branch.children = .changed([child])
            return branch
        }

        var changed = HostPatch(id: .manual("root"), type: .verticalStackLayout)
        changed.children = .changed([
            changedBranch("first", child: changedLabel(opacity: 1)),
            changedBranch("second", child: changedLabel(opacity: 0)),
        ])
        renderer.applyForTesting(changed)

        now = 50
        renderer.advanceMotionsForTesting()
        let labels = renderer.viewsForTesting(id: .manual("same"))
        XCTAssertEqual(labels.count, 2)
        XCTAssertEqual(labels[0].alphaValue, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(labels[1].alphaValue, 0.75, accuracy: 0.000_001)
    }

    @MainActor
    func testRemovingAMovingElementDropsItsHostChannel() {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { 0 },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties[.opacity] = .number(0)
        var initial = HostPatch(id: .manual("root"), type: .verticalStackLayout)
        initial.children = .arranged([label])
        renderer.applyForTesting(initial)

        var movingLabel = HostPatch(id: .manual("label"), type: .label)
        movingLabel.properties[.opacity] = .number(1)
        movingLabel.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        var moving = HostPatch(id: .manual("root"), type: .verticalStackLayout)
        moving.children = .changed([movingLabel])
        renderer.applyForTesting(moving)
        XCTAssertTrue(renderer.propertyMotionsActiveForTesting)

        var removed = HostPatch(id: .manual("root"), type: .verticalStackLayout)
        removed.children = .arranged([])
        renderer.applyForTesting(removed)
        XCTAssertFalse(renderer.propertyMotionsActiveForTesting)
    }

    @MainActor
    func testReplacingAMovingElementDoesNotAdoptItsPresentation() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { 0 },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("label"), type: .label)
        initial.properties[.opacity] = .number(0)
        renderer.applyForTesting(initial)
        let original = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))

        var moving = HostPatch(id: .manual("label"), type: .label)
        moving.properties[.opacity] = .number(1)
        moving.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(moving)
        XCTAssertTrue(renderer.propertyMotionsActiveForTesting)

        var replacement = HostPatch(id: .manual("label"), type: .label)
        replacement.replace = true
        replacement.properties[.opacity] = .number(0.4)
        renderer.applyForTesting(replacement)

        let replaced = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertFalse(replaced === original)
        XCTAssertEqual(replaced.alphaValue, 0.4, accuracy: 0.000_001)
        XCTAssertFalse(renderer.propertyMotionsActiveForTesting)
    }

    @MainActor
    func testANumberListKeepsItsShapeWhileItMoves() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("box"), type: .boxView)
        initial.properties[.cornerRadius] = .numbers([0, 10, 20, 30])
        renderer.applyForTesting(initial)

        var changed = HostPatch(id: .manual("box"), type: .boxView)
        changed.properties[.cornerRadius] = .numbers([20, 30, 40, 50])
        changed.transitions[.cornerRadius] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        now = 100
        renderer.advanceMotionsForTesting()
        let box = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("box")) as? AppKitBoxView)
        XCTAssertEqual(
            box.cornerRadii,
            AppKitCornerRadii(topLeft: 10, topRight: 20, bottomLeft: 30, bottomRight: 40))
    }

    @MainActor
    func testNewStructuredCornerRadiiStartAtZeroWithoutChangingShape() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(HostPatch(id: .manual("box"), type: .boxView))

        var changed = HostPatch(id: .manual("box"), type: .boxView)
        changed.properties[.cornerRadius] = .numbers([10, 20, 30, 40])
        changed.transitions[.cornerRadius] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        let box = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("box")) as? AppKitBoxView)
        XCTAssertEqual(box.cornerRadii, AppKitCornerRadii())

        now = 100
        renderer.advanceMotionsForTesting()
        XCTAssertEqual(
            box.cornerRadii,
            AppKitCornerRadii(topLeft: 5, topRight: 10, bottomLeft: 15, bottomRight: 20))
    }

    @MainActor
    func testASliderTransitionBeginsAtTheReadersLiveNativeValue() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("slider"), type: .slider)
        initial.properties[.value] = .number(0)
        renderer.applyForTesting(initial)

        let slider = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("slider")) as? AppKitSliderView)
        slider.doubleValue = 0.8

        var changed = HostPatch(id: .manual("slider"), type: .slider)
        changed.properties[.value] = .number(1)
        changed.transitions[.value] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(changed)
        XCTAssertEqual(slider.doubleValue, 0.8, accuracy: 0.000_001)

        now = 100
        renderer.advanceMotionsForTesting()
        XCTAssertEqual(slider.doubleValue, 0.9, accuracy: 0.000_001)
    }

    @MainActor
    func testAProgressTransitionBeginsAtItsClampedNativeValue() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("progress"), type: .progressBar)
        initial.properties[.progress] = .number(-1)
        renderer.applyForTesting(initial)

        var changed = HostPatch(id: .manual("progress"), type: .progressBar)
        changed.properties[.progress] = .number(1)
        changed.transitions[.progress] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        let progress = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("progress")) as? AppKitProgressView)
        XCTAssertEqual(progress.doubleValue, 0, accuracy: 0.000_001)

        now = 100
        renderer.advanceMotionsForTesting()
        XCTAssertEqual(progress.doubleValue, 0.5, accuracy: 0.000_001)
    }

    @MainActor
    func testAStructuredShapeTransformIsPresentedAtEachMotionFrame() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        func transform(x: Double, y: Double) -> HostValue {
            .values([
                .number(1), .number(0), .number(0),
                .number(1), .number(x), .number(y),
            ])
        }

        var initial = HostPatch(id: .manual("line"), type: .line)
        initial.properties[.x1] = .number(1)
        initial.properties[.y1] = .number(2)
        initial.properties[.x2] = .number(21)
        initial.properties[.y2] = .number(12)
        initial.properties[.aspect] = .enumeration(Stretch.none.rawValue)
        renderer.applyForTesting(initial)

        var changed = HostPatch(id: .manual("line"), type: .line)
        changed.properties[.renderTransform] = transform(x: 10, y: 20)
        changed.transitions[.renderTransform] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        let shape = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("line")) as? AppKitShapeView)
        var path = shape.pathForTesting(in: NSRect(x: 0, y: 0, width: 50, height: 30))
        XCTAssertEqual(path.bounds.origin, NSPoint(x: 1, y: 2))

        now = 100
        renderer.advanceMotionsForTesting()
        path = shape.pathForTesting(in: NSRect(x: 0, y: 0, width: 50, height: 30))
        XCTAssertEqual(path.bounds.origin, NSPoint(x: 6, y: 12))

        now = 200
        renderer.advanceMotionsForTesting()
        path = shape.pathForTesting(in: NSRect(x: 0, y: 0, width: 50, height: 30))
        XCTAssertEqual(path.bounds.origin, NSPoint(x: 11, y: 22))
        XCTAssertFalse(renderer.propertyMotionsActiveForTesting)
    }

    @MainActor
    func testNewLineGeometryAndStrokeStartAtTheirShapeDefaults() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("line"), type: .line)
        initial.properties[.aspect] = .enumeration(Stretch.none.rawValue)
        initial.properties[.strokeDashArray] = .numbers([1, 1])
        renderer.applyForTesting(initial)

        var changed = HostPatch(id: .manual("line"), type: .line)
        changed.properties[.x2] = .number(20)
        changed.properties[.y2] = .number(10)
        changed.properties[.strokeThickness] = .number(3)
        changed.properties[.strokeDashOffset] = .number(3)
        changed.properties[.strokeMiterLimit] = .number(4)
        for property in [
            Prop.x2, .y2, .strokeThickness, .strokeDashOffset, .strokeMiterLimit,
        ] {
            changed.transitions[property] = HostTransition(motion: .eased(200, .linear))
        }
        renderer.applyForTesting(changed)

        let line = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("line")) as? AppKitShapeView)
        var path = line.pathForTesting(in: NSRect(x: 0, y: 0, width: 40, height: 20))
        XCTAssertEqual(path.bounds, .zero)
        XCTAssertEqual(path.lineWidth, 1, accuracy: 0.000_001)
        XCTAssertEqual(path.miterLimit, 10, accuracy: 0.000_001)
        XCTAssertEqual(line.dashPhaseForTesting, 0, accuracy: 0.000_001)

        now = 100
        renderer.advanceMotionsForTesting()
        path = line.pathForTesting(in: NSRect(x: 0, y: 0, width: 40, height: 20))
        XCTAssertEqual(path.bounds, NSRect(x: 0, y: 0, width: 10, height: 5))
        XCTAssertEqual(path.lineWidth, 2, accuracy: 0.000_001)
        XCTAssertEqual(path.miterLimit, 7, accuracy: 0.000_001)
        XCTAssertEqual(line.dashPhaseForTesting, 3, accuracy: 0.000_001)
    }

    @MainActor
    func testAnUnpresentedPropertyDoesNotCreateAHostMotionChannel() {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { 0 },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("tabs"), type: .tabbedPage)
        initial.properties[.selectedTabColor] = .color(
            red: 255, green: 0, blue: 0, alpha: 255)
        renderer.applyForTesting(initial)

        var changed = HostPatch(id: .manual("tabs"), type: .tabbedPage)
        changed.properties[.selectedTabColor] = .color(
            red: 0, green: 0, blue: 255, alpha: 255)
        changed.transitions[.selectedTabColor] = HostTransition(
            motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        XCTAssertFalse(renderer.propertyMotionsActiveForTesting)
    }

    @MainActor
    func testAStructuredBrushMovesOnlyInsideItsStableShape() throws {
        let engine = AppKitPropertyMotionEngine()
        let key = AppKitPropertyMotionKey(mount: 1, property: .fill)
        let source = HostValue.values([
            .enumeration(2),
            .numbers([0, 0, 1, 0]),
            .number(0), .color(red: 0, green: 0, blue: 0, alpha: 255),
            .number(1), .color(red: 255, green: 255, blue: 255, alpha: 255),
        ])
        let target = HostValue.values([
            .enumeration(2),
            .numbers([0, 1, 1, 1]),
            .number(0.2), .color(red: 255, green: 0, blue: 0, alpha: 255),
            .number(0.8), .color(red: 0, green: 0, blue: 255, alpha: 255),
        ])

        engine.receive(
            key: key,
            standing: source,
            target: target,
            transition: HostTransition(motion: .eased(200, .linear)),
            now: 0,
            reducesMotion: false)
        XCTAssertEqual(engine.presentedValue(for: key), source)

        engine.advance(now: 100)
        XCTAssertEqual(engine.takeOutputs().last?.value, .values([
            .enumeration(2),
            .numbers([0, 0.5, 1, 0.5]),
            .number(0.1), .color(red: 128, green: 0, blue: 0, alpha: 255),
            .number(0.9), .color(red: 128, green: 128, blue: 255, alpha: 255),
        ]))
    }

    @MainActor
    func testChangingAStructuredBrushShapeSnapsInsteadOfInventingAnIntermediate() {
        let engine = AppKitPropertyMotionEngine()
        let key = AppKitPropertyMotionKey(mount: 1, property: .fill)
        let linear = HostValue.values([
            .enumeration(2),
            .numbers([0, 0, 1, 1]),
            .number(0), .color(red: 0, green: 0, blue: 0, alpha: 255),
        ])
        let solid = HostValue.values([
            .enumeration(1),
            .color(red: 255, green: 255, blue: 255, alpha: 255),
        ])

        engine.receive(
            key: key,
            standing: linear,
            target: solid,
            transition: HostTransition(motion: .eased(200, .linear)),
            now: 0,
            reducesMotion: false)

        XCTAssertNil(engine.presentedValue(for: key))
        XCTAssertFalse(engine.isActive)
    }

    func testAnEasedMotionIsAFunctionOfElapsedTime() {
        let halfway = AppKitMotionCurve.sample(
            motion: .eased(200, .cubicOut),
            elapsed: 100,
            from: [0],
            destination: [1],
            velocity: [0])
        let landed = AppKitMotionCurve.sample(
            motion: .eased(200, .cubicOut),
            elapsed: 200,
            from: [0],
            destination: [1],
            velocity: [0])

        XCTAssertEqual(halfway.value[0], 0.875, accuracy: 0.000_001)
        XCTAssertFalse(halfway.rested)
        XCTAssertEqual(landed.value, [1])
        XCTAssertEqual(landed.velocity, [0])
        XCTAssertTrue(landed.rested)
    }

    func testASpringAnswersTheSameValueForTheSameInstant() {
        let first = AppKitMotionCurve.sample(
            motion: .spring(response: 260, damping: 0.8),
            elapsed: 147,
            from: [20, -4],
            destination: [80, 10],
            velocity: [0.03, -0.01])
        let second = AppKitMotionCurve.sample(
            motion: .spring(response: 260, damping: 0.8),
            elapsed: 147,
            from: [20, -4],
            destination: [80, 10],
            velocity: [0.03, -0.01])

        XCTAssertEqual(first, second)
        XCTAssertFalse(first.rested)
    }

    func testASpringRestsWhenStillAndNeverOutlivesItsSafetyLimit() {
        let naturallyRested = AppKitMotionCurve.sample(
            motion: .spring(response: 260, damping: 0.8),
            elapsed: 3_000,
            from: [0],
            destination: [1],
            velocity: [0])
        let capped = AppKitMotionCurve.sample(
            motion: .spring(response: 100_000, damping: 0.01),
            elapsed: 10_000,
            from: [0],
            destination: [1],
            velocity: [0])

        XCTAssertEqual(naturallyRested.value, [1])
        XCTAssertEqual(naturallyRested.velocity, [0])
        XCTAssertTrue(naturallyRested.rested)
        XCTAssertEqual(capped.value, [1])
        XCTAssertEqual(capped.velocity, [0])
        XCTAssertTrue(capped.rested)
    }

    @MainActor
    func testOneStateNumberOwnsOneChannelAcrossControls() throws {
        let engine = AppKitMotionEngine()
        let binding = HostStateBinding(state: 7, mode: .inOut, kind: .property)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(200, .cubicOut),
            completion: nil,
            stopped: 0)
        let carried = StateUIHost.value(of: journey)

        _ = engine.presentedValue(
            for: binding, from: carried, now: 0, reducesMotion: false)
        _ = engine.presentedValue(
            for: binding, from: carried, now: 0, reducesMotion: false)
        XCTAssertEqual(engine.takeOutputs().count, 1, "the second wearer reuses the channel")

        engine.advance(now: 100)
        let frame = try XCTUnwrap(engine.takeOutputs().last)

        XCTAssertEqual(frame.state, 7)
        XCTAssertEqual(frame.journey.value[0], 0.875, accuracy: 0.000_001)
        XCTAssertEqual(frame.report, .frame)
    }

    @MainActor
    func testRetargetingCarriesTheCurrentVelocityIntoTheNewMotion() throws {
        let engine = AppKitMotionEngine()
        let binding = HostStateBinding(state: 9, mode: .inOut, kind: .property)
        let first = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(200, .cubicOut),
            completion: nil,
            stopped: 0)
        _ = engine.presentedValue(
            for: binding,
            from: StateUIHost.value(of: first),
            now: 0,
            reducesMotion: false)
        _ = engine.takeOutputs()

        let second = HostJourney(
            value: [0],
            destination: [0.2],
            velocity: [0],
            motion: .eased(200, .linear),
            completion: nil,
            stopped: 0)
        engine.receive(
            HostStateChange(
                state: 9,
                changed: 1 << 1,
                value: StateUIHost.value(of: second)),
            now: 100,
            reducesMotion: false)

        let aimed = try XCTUnwrap(engine.takeOutputs().last)
        XCTAssertEqual(aimed.journey.value[0], 0.875, accuracy: 0.000_001)
        XCTAssertEqual(aimed.journey.velocity[0], 3.75, accuracy: 0.01)

        engine.advance(now: 101)
        let next = try XCTUnwrap(engine.takeOutputs().last)
        XCTAssertGreaterThan(next.journey.value[0], aimed.journey.value[0])
    }

    @MainActor
    func testACompletedMotionReportsItsExactDestinationOnce() throws {
        let engine = AppKitMotionEngine()
        let binding = HostStateBinding(state: 11, mode: .inOut, kind: .property)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(100, .linear),
            completion: -23,
            stopped: 0)
        _ = engine.presentedValue(
            for: binding,
            from: StateUIHost.value(of: journey),
            now: 0,
            reducesMotion: false)
        _ = engine.takeOutputs()

        engine.advance(now: 100)
        let landed = try XCTUnwrap(engine.takeOutputs().last)

        XCTAssertEqual(landed.journey.value, [1])
        XCTAssertEqual(landed.journey.velocity, [0])
        XCTAssertEqual(landed.report, .position)
        XCTAssertEqual(
            engine.takeCompletions(),
            [AppKitMotionCompletion(id: -23, succeeded: true)])

        engine.advance(now: 200)
        XCTAssertTrue(engine.takeOutputs().isEmpty)
        XCTAssertTrue(engine.takeCompletions().isEmpty)
    }

    @MainActor
    func testEnablingReducedMotionLandsAnActiveJourneyAndItsWaiter() throws {
        let engine = AppKitMotionEngine()
        let binding = HostStateBinding(state: 12, mode: .inOut, kind: .property)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(200, .linear),
            completion: -29,
            stopped: 0)
        _ = engine.presentedValue(
            for: binding,
            from: StateUIHost.value(of: journey),
            now: 0,
            reducesMotion: false)
        _ = engine.takeOutputs()

        engine.advance(now: 50, reducesMotion: true)
        let landed = try XCTUnwrap(engine.takeOutputs().last)

        XCTAssertEqual(landed.journey.value, [1])
        XCTAssertEqual(landed.journey.destination, [1])
        XCTAssertEqual(landed.journey.velocity, [0])
        XCTAssertEqual(landed.report, .position)
        XCTAssertEqual(
            engine.takeCompletions(),
            [AppKitMotionCompletion(id: -29, succeeded: true)])
        XCTAssertFalse(engine.isActive)
    }

    @MainActor
    func testAReaderTakesAnActiveJourneyAtItsOwnPosition() throws {
        let engine = AppKitMotionEngine()
        let binding = HostStateBinding(state: 13, mode: .inOut, kind: .property)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(200, .cubicOut),
            completion: -31,
            stopped: 0)
        _ = engine.presentedValue(
            for: binding,
            from: StateUIHost.value(of: journey),
            now: 0,
            reducesMotion: false)
        _ = engine.takeOutputs()

        XCTAssertTrue(engine.take([0.4], through: binding))
        let taken = try XCTUnwrap(engine.takeOutputs().last)

        XCTAssertEqual(taken.journey.value, [0.4])
        XCTAssertEqual(taken.journey.destination, [0.4])
        XCTAssertEqual(taken.journey.velocity, [0])
        XCTAssertEqual(taken.report, .position)
        XCTAssertFalse(engine.isActive)
        XCTAssertEqual(
            engine.takeCompletions(),
            [AppKitMotionCompletion(id: -31, succeeded: false)])
    }

    @MainActor
    func testAnOutputOnlyBindingCannotTakeItsJourney() {
        let engine = AppKitMotionEngine()
        let binding = HostStateBinding(state: 15, mode: .out, kind: .property)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(200, .linear),
            completion: nil,
            stopped: 0)
        _ = engine.presentedValue(
            for: binding,
            from: StateUIHost.value(of: journey),
            now: 0,
            reducesMotion: false)
        _ = engine.takeOutputs()

        XCTAssertFalse(engine.take([0.4], through: binding))
        XCTAssertTrue(engine.isActive)
        XCTAssertTrue(engine.takeOutputs().isEmpty)
    }

    @MainActor
    func testAStateSnapCancelsItsWaiterOnceWithoutRebookingIt() throws {
        let engine = AppKitMotionEngine()
        let binding = HostStateBinding(state: 17, mode: .inOut, kind: .property)
        let moving = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(100, .linear),
            completion: -41,
            stopped: 0)
        _ = engine.presentedValue(
            for: binding,
            from: StateUIHost.value(of: moving),
            now: 0,
            reducesMotion: false)
        _ = engine.takeOutputs()

        let snapped = HostJourney(
            value: [0.25],
            destination: [0.25],
            velocity: [0],
            motion: moving.motion,
            completion: -41,
            stopped: 0)
        engine.receive(
            HostStateChange(
                state: 17,
                changed: 0b11,
                value: StateUIHost.value(of: snapped)),
            now: 50,
            reducesMotion: false)

        let applied = try XCTUnwrap(engine.takeOutputs().last)
        XCTAssertEqual(applied.journey.value, [0.25])
        XCTAssertEqual(applied.journey.destination, [0.25])
        XCTAssertEqual(applied.journey.velocity, [0])
        XCTAssertEqual(applied.report, .position)
        XCTAssertFalse(engine.isActive)
        XCTAssertEqual(
            engine.takeCompletions(),
            [AppKitMotionCompletion(id: -41, succeeded: false)])

        engine.advance(now: 200)
        XCTAssertTrue(engine.takeOutputs().isEmpty)
        XCTAssertTrue(engine.takeCompletions().isEmpty)
    }

    @MainActor
    func testAnAwaitedRetargetOwnsItsNewCompletion() {
        let engine = AppKitMotionEngine()
        let binding = HostStateBinding(state: 19, mode: .inOut, kind: .property)
        let first = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(100, .linear),
            completion: -41,
            stopped: 0)
        _ = engine.presentedValue(
            for: binding,
            from: StateUIHost.value(of: first),
            now: 0,
            reducesMotion: false)
        _ = engine.takeOutputs()

        let second = HostJourney(
            value: [0],
            destination: [0.25],
            velocity: [0],
            motion: .eased(100, .linear),
            completion: -42,
            stopped: 0)
        engine.receive(
            HostStateChange(
                state: 19,
                changed: (1 << 1) | (1 << 6),
                value: StateUIHost.value(of: second)),
            now: 50,
            reducesMotion: false)

        XCTAssertEqual(
            engine.takeCompletions(),
            [AppKitMotionCompletion(id: -41, succeeded: false)])

        engine.advance(now: 150)
        XCTAssertEqual(
            engine.takeCompletions(),
            [AppKitMotionCompletion(id: -42, succeeded: true)])
    }
}

#endif

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitMotionTests: XCTestCase {
    func testTransitionSurfaceIsClosedAroundNativePresentations() {
        XCTAssertTrue(AppKitTransitionSurface.presents(.opacity, on: .label))
        XCTAssertTrue(AppKitTransitionSurface.presents(.padding, on: .page))
        XCTAssertTrue(AppKitTransitionSurface.presents(.renderTransform, on: .line))
        XCTAssertTrue(AppKitTransitionSurface.presents(.x, on: .window))
        XCTAssertTrue(AppKitTransitionSurface.presents(.background, on: .titleBar))
        XCTAssertTrue(AppKitTransitionSurface.presents(.barForegroundColor, on: .titleBar))

        XCTAssertFalse(AppKitTransitionSurface.presents(.rotationX, on: .label))
        XCTAssertFalse(AppKitTransitionSurface.presents(.value, on: .stepper))
        XCTAssertFalse(AppKitTransitionSurface.presents(.opacity, on: .positionIndicator))
        XCTAssertFalse(AppKitTransitionSurface.presents(Prop("custom"), on: .label))
    }

    @MainActor
    func testAPropertyTransitionBeginsAtItsStandingValueAndLandsExactly() throws {
        var now = 0.0
        let renderer = testRenderer(
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
        XCTAssertTrue(renderer.describedMotionActiveForTesting)

        now = 100
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(label.alphaValue, 0.5, accuracy: 0.000_001)

        now = 200
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(label.alphaValue, 0.75, accuracy: 0.000_001)
        XCTAssertFalse(renderer.describedMotionActiveForTesting)

        now = 300
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(label.alphaValue, 0.75, accuracy: 0.000_001)
    }

    @MainActor
    func testANewMovingPropertyStartsAtItsNativeDefault() throws {
        var now = 0.0
        let renderer = testRenderer(
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
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(label.alphaValue, 0.5, accuracy: 0.000_001)
    }

    @MainActor
    func testNewPlanarTransformPropertiesStartAtIdentityTogether() throws {
        var now = 0.0
        let renderer = testRenderer(
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
        renderer.advanceAnimationsForTesting()
        transform = try XCTUnwrap(label.layer).affineTransform()
        XCTAssertEqual(transform.tx, 5, accuracy: 0.000_001)
        XCTAssertEqual(transform.a, 1.5, accuracy: 0.000_001)
    }

    @MainActor
    func testNewStackGeometryStartsAtZeroTogether() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(HostPatch(id: .manual("stack"), type: .vStack))

        var changed = HostPatch(id: .manual("stack"), type: .vStack)
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
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(stack.padding.top, 20, accuracy: 0.000_001)
        XCTAssertEqual(stack.padding.left, 10, accuracy: 0.000_001)
        XCTAssertEqual(stack.padding.bottom, 40, accuracy: 0.000_001)
        XCTAssertEqual(stack.padding.right, 30, accuracy: 0.000_001)
        XCTAssertEqual(stack.spacing, 5, accuracy: 0.000_001)
    }

    @MainActor
    func testOnePropertyFrameArrangesEachChangedAncestorOnce() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties[.opacity] = .number(0)
        label.properties[.translationX] = .number(0)
        var initial = HostPatch(id: .manual("stack"), type: .vStack)
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
        var moving = HostPatch(id: .manual("stack"), type: .vStack)
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
        renderer.advanceAnimationsForTesting()

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
    func testAnOrdinaryViewMotionFrameDoesNotResynchronizeTheWindowShell() {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        func tree(children: HostChildrenUpdate) -> HostPatch {
            var stack = HostPatch(id: .manual("stack"), type: .vStack)
            stack.children = children
            var page = HostPatch(id: .manual("page"), type: .page)
            page.children = .arranged([stack])
            var window = HostPatch(id: .manual("window"), type: .window)
            window.children = .arranged([page])
            return windowTree(window)
        }

        var initialBox = HostPatch(id: .manual("box"), type: .colorBox)
        initialBox.properties[.width] = .number(120)
        renderer.applyForTesting(tree(children: .arranged([initialBox])))

        var changedBox = HostPatch(id: .manual("box"), type: .colorBox)
        changedBox.properties[.width] = .number(300)
        changedBox.transitions[.width] = HostTransition(
            motion: .eased(200, .linear))
        renderer.applyForTesting(tree(children: .changed([changedBox])))
        let synchronizationsBeforeFrame = renderer.windowSynchronizationCountForTesting

        now = 100
        renderer.advanceAnimationsForTesting()

        XCTAssertEqual(
            renderer.windowSynchronizationCountForTesting,
            synchronizationsBeforeFrame)
    }

    @MainActor
    func testAPropertySizeMotionReusesItsNativeConstraintAcrossFrames() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("box"), type: .colorBox)
        initial.properties[.width] = .number(120)
        renderer.applyForTesting(initial)

        var changed = HostPatch(id: .manual("box"), type: .colorBox)
        changed.properties[.width] = .number(300)
        changed.transitions[.width] = HostTransition(
            motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        let box = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))
        let standing = try XCTUnwrap(box.constraints.first {
            $0.firstAttribute == .width && $0.relation == .equal
        })
        XCTAssertEqual(standing.constant, 120, accuracy: 0.001)

        now = 100
        renderer.advanceAnimationsForTesting()

        let moving = try XCTUnwrap(box.constraints.first {
            $0.firstAttribute == .width && $0.relation == .equal
        })
        XCTAssertTrue(moving === standing)
        XCTAssertEqual(moving.constant, 210, accuracy: 0.001)
    }

    @MainActor
    func testDrivenStatesFromOneFrameArrangeTheirCommonAncestorOnce() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        func child(_ id: String, state: Int32) -> HostPatch {
            var child = HostPatch(id: .manual(id), type: .colorBox)
            child.properties[.height] = .number(40)
            child.driven = .replace([
                .height: HostStateBinding(
                    state: state, mode: .inOut, kind: .property),
            ])
            return child
        }

        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([
            child("first", state: 81),
            child("second", state: 82),
        ])
        renderer.applyForTesting(stack)

        let nativeStack = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("stack")) as? AppKitStackView)
        let arrangementsBeforeFrame = nativeStack.arrangementCountForTesting
        func landed(_ value: Double) -> HostStateValue {
            StateUIHost.value(of: HostJourney(
                value: [value],
                destination: [value],
                velocity: [0],
                motion: .none,
                completion: nil,
                stopped: 0))
        }

        renderer.applyStatesForTesting([81: landed(70), 82: landed(90)])

        XCTAssertEqual(
            nativeStack.arrangementCountForTesting - arrangementsBeforeFrame,
            1)
    }

    @MainActor
    func testAnUnrelatedSparsePropertyLeavesMotionRunning() throws {
        var now = 0.0
        let renderer = testRenderer(
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
        renderer.advanceAnimationsForTesting()
        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertEqual(label.alphaValue, 0.25, accuracy: 0.000_001)

        var unrelated = HostPatch(id: .manual("label"), type: .label)
        unrelated.properties[.text] = .string("still moving")
        renderer.applyForTesting(unrelated)
        XCTAssertTrue(renderer.describedMotionActiveForTesting)

        now = 100
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(label.alphaValue, 0.5, accuracy: 0.000_001)
    }

    @MainActor
    func testAPropertyMotionDoesNotRewriteTheUsersScrollPosition() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var content = HostPatch(id: .manual("content"), type: .colorBox)
        content.properties[.width] = .number(100)
        content.properties[.height] = .number(500)
        var initial = HostPatch(id: .manual("scroll"), type: .scrollView)
        initial.properties[.orientation] = .enumeration(ScrollOrientation.vertical.rawValue)
        initial.properties[.scrollOffset] = .numbers([0, 0])
        initial.properties[.opacity] = .number(0)
        initial.children = .arranged([content])
        renderer.applyForTesting(initial)

        let scroll = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("scroll")) as? AppKitScrollView)
        scroll.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        scroll.layoutSubtreeIfNeeded()
        scroll.beginMovementForTesting()
        scroll.moveAsUserForTesting(to: NSPoint(x: 0, y: 120))
        XCTAssertEqual(scroll.offset.y, 120, accuracy: 0.001)

        var moving = HostPatch(id: .manual("scroll"), type: .scrollView)
        moving.properties[.opacity] = .number(1)
        moving.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(moving)
        XCTAssertEqual(scroll.offset.y, 120, accuracy: 0.001)

        now = 100
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(scroll.offset.y, 120, accuracy: 0.001)
    }

    @MainActor
    func testReducedMotionAssignsThePropertyTargetImmediately() throws {
        var initial = HostPatch(id: .manual("label"), type: .label)
        initial.properties[.opacity] = .number(0)
        let renderer = testRenderer(
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
        XCTAssertFalse(renderer.describedMotionActiveForTesting)
    }

    @MainActor
    func testEnablingReducedMotionLandsAnActivePropertyTransition() throws {
        var now = 0.0
        var reduced = false
        let renderer = testRenderer(
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
        renderer.advanceAnimationsForTesting()
        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertEqual(label.alphaValue, 0.25, accuracy: 0.000_001)

        reduced = true
        now = 60
        renderer.advanceAnimationsForTesting()

        XCTAssertEqual(label.alphaValue, 1, accuracy: 0.000_001)
        XCTAssertFalse(renderer.describedMotionActiveForTesting)
    }

    @MainActor
    func testAPropertyWithoutATransitionInterruptsTheActiveChannel() throws {
        var now = 0.0
        let renderer = testRenderer(
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
        renderer.advanceAnimationsForTesting()
        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertEqual(label.alphaValue, 0.5, accuracy: 0.000_001)

        var snapped = HostPatch(id: .manual("label"), type: .label)
        snapped.properties[.opacity] = .number(0.25)
        renderer.applyForTesting(snapped)
        XCTAssertEqual(label.alphaValue, 0.25, accuracy: 0.000_001)
        XCTAssertFalse(renderer.describedMotionActiveForTesting)

        now = 300
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(label.alphaValue, 0.25, accuracy: 0.000_001)
    }

    @MainActor
    func testClearingAPropertyInterruptsMotionAndRestoresItsNativeDefault() throws {
        var now = 0.0
        let renderer = testRenderer(
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
        renderer.advanceAnimationsForTesting()
        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertEqual(label.alphaValue, 0.5, accuracy: 0.000_001)

        var cleared = HostPatch(id: .manual("label"), type: .label)
        cleared.clearedProperties = [.opacity]
        renderer.applyForTesting(cleared)
        XCTAssertEqual(label.alphaValue, 1, accuracy: 0.000_001)
        XCTAssertFalse(renderer.describedMotionActiveForTesting)

        now = 300
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(label.alphaValue, 1, accuracy: 0.000_001)
    }

    @MainActor
    func testAPropertyRetargetCarriesItsCurrentVelocity() throws {
        var now = 0.0
        let renderer = testRenderer(
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
        renderer.advanceAnimationsForTesting()
        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertEqual(label.alphaValue, 0.5, accuracy: 0.000_001)

        var second = HostPatch(id: .manual("label"), type: .label)
        second.properties[.opacity] = .number(0.2)
        second.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(second)
        XCTAssertEqual(label.alphaValue, 0.5, accuracy: 0.000_001)

        now = 101
        renderer.advanceAnimationsForTesting()
        XCTAssertGreaterThan(label.alphaValue, 0.5)

        now = 300
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(label.alphaValue, 0.2, accuracy: 0.000_001)
        XCTAssertFalse(renderer.describedMotionActiveForTesting)
    }

    @MainActor
    func testEqualAuthoredIDsInDifferentBranchesOwnDifferentChannels() throws {
        var now = 0.0
        let renderer = testRenderer(
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
            var branch = HostPatch(id: .manual(id), type: .hStack)
            branch.children = .arranged([child])
            return branch
        }

        var initial = HostPatch(id: .manual("root"), type: .vStack)
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
            var branch = HostPatch(id: .manual(id), type: .hStack)
            branch.children = .changed([child])
            return branch
        }

        var changed = HostPatch(id: .manual("root"), type: .vStack)
        changed.children = .changed([
            changedBranch("first", child: changedLabel(opacity: 1)),
            changedBranch("second", child: changedLabel(opacity: 0)),
        ])
        renderer.applyForTesting(changed)

        now = 50
        renderer.advanceAnimationsForTesting()
        let labels = renderer.viewsForTesting(id: .manual("same"))
        XCTAssertEqual(labels.count, 2)
        XCTAssertEqual(labels[0].alphaValue, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(labels[1].alphaValue, 0.75, accuracy: 0.000_001)
    }

    @MainActor
    func testRemovingAMovingElementDropsItsHostChannel() {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { 0 },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties[.opacity] = .number(0)
        var initial = HostPatch(id: .manual("root"), type: .vStack)
        initial.children = .arranged([label])
        renderer.applyForTesting(initial)

        var movingLabel = HostPatch(id: .manual("label"), type: .label)
        movingLabel.properties[.opacity] = .number(1)
        movingLabel.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        var moving = HostPatch(id: .manual("root"), type: .vStack)
        moving.children = .changed([movingLabel])
        renderer.applyForTesting(moving)
        XCTAssertTrue(renderer.describedMotionActiveForTesting)

        var removed = HostPatch(id: .manual("root"), type: .vStack)
        removed.children = .arranged([])
        renderer.applyForTesting(removed)
        XCTAssertFalse(renderer.describedMotionActiveForTesting)
    }

    @MainActor
    func testReplacingAMovingElementDoesNotAdoptItsPresentation() throws {
        let renderer = testRenderer(
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
        XCTAssertTrue(renderer.describedMotionActiveForTesting)

        var replacement = HostPatch(id: .manual("label"), type: .label)
        replacement.replace = true
        replacement.properties[.opacity] = .number(0.4)
        renderer.applyForTesting(replacement)

        let replaced = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertFalse(replaced === original)
        XCTAssertEqual(replaced.alphaValue, 0.4, accuracy: 0.000_001)
        XCTAssertFalse(renderer.describedMotionActiveForTesting)
    }

    @MainActor
    func testANumberListKeepsItsShapeWhileItMoves() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("box"), type: .colorBox)
        initial.properties[.cornerRadius] = .numbers([0, 10, 20, 30])
        renderer.applyForTesting(initial)

        var changed = HostPatch(id: .manual("box"), type: .colorBox)
        changed.properties[.cornerRadius] = .numbers([20, 30, 40, 50])
        changed.transitions[.cornerRadius] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        now = 100
        renderer.advanceAnimationsForTesting()
        let box = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("box")) as? AppKitColorBoxView)
        XCTAssertEqual(
            box.cornerRadii,
            AppKitCornerRadii(topLeft: 10, topRight: 20, bottomLeft: 30, bottomRight: 40))
    }

    @MainActor
    func testNewStructuredCornerRadiiStartAtZeroWithoutChangingShape() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(HostPatch(id: .manual("box"), type: .colorBox))

        var changed = HostPatch(id: .manual("box"), type: .colorBox)
        changed.properties[.cornerRadius] = .numbers([10, 20, 30, 40])
        changed.transitions[.cornerRadius] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        let box = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("box")) as? AppKitColorBoxView)
        XCTAssertEqual(box.cornerRadii, AppKitCornerRadii())

        now = 100
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(
            box.cornerRadii,
            AppKitCornerRadii(topLeft: 5, topRight: 10, bottomLeft: 15, bottomRight: 20))
    }

    @MainActor
    func testASliderTransitionBeginsAtTheUsersLiveNativeValue() throws {
        var now = 0.0
        let renderer = testRenderer(
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
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(slider.doubleValue, 0.9, accuracy: 0.000_001)
    }

    @MainActor
    func testAProgressTransitionBeginsAtItsClampedNativeValue() throws {
        var now = 0.0
        let renderer = testRenderer(
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
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(progress.doubleValue, 0.5, accuracy: 0.000_001)
    }

    @MainActor
    func testAWindowWidthTransitionStartsAtTheUsersLiveContentSizeAndPreservesHeight() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = testWindow()
        initial.properties[.width] = .number(600)
        initial.properties[.height] = .number(400)
        renderer.applyForTesting(windowTree(initial))

        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        window.setContentSize(NSSize(width: 800, height: 500))

        var changed = HostPatch(id: .manual("window"), type: .window)
        changed.properties[.width] = .number(1_000)
        changed.transitions[.width] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(windowChange(changed))

        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).size.width, 800, accuracy: 0.001)
        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).size.height, 500, accuracy: 0.001)

        now = 100
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).size.width, 900, accuracy: 0.001)
        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).size.height, 500, accuracy: 0.001)
    }

    @MainActor
    func testAWindowPositionAxisMovesIndependentlyFromTheLiveFrame() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(windowTree(testWindow()))
        let window = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        window.setFrameOrigin(NSPoint(x: 100, y: 200))
        let standingTop = window.frame.maxY

        var changed = HostPatch(id: .manual("window"), type: .window)
        changed.properties[.x] = .number(300)
        changed.transitions[.x] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(windowChange(changed))
        XCTAssertEqual(window.frame.minX, 100, accuracy: 0.001)
        XCTAssertEqual(window.frame.maxY, standingTop, accuracy: 0.001)

        now = 100
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(window.frame.minX, 200, accuracy: 0.001)
        XCTAssertEqual(window.frame.maxY, standingTop, accuracy: 0.001)
    }

    @MainActor
    func testAStructuredShapeTransformIsPresentedAtEachMotionFrame() throws {
        var now = 0.0
        let renderer = testRenderer(
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
        initial.properties[.aspect] = .enumeration(Aspect.center.rawValue)
        renderer.applyForTesting(initial)

        var changed = HostPatch(id: .manual("line"), type: .line)
        changed.properties[.renderTransform] = transform(x: 10, y: 20)
        changed.transitions[.renderTransform] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(changed)

        let shape = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("line")) as? AppKitShapeView)
        var path = shape.pathForTesting(in: NSRect(x: 0, y: 0, width: 22, height: 14))
        XCTAssertEqual(path.bounds.origin, NSPoint(x: 1, y: 2))

        now = 100
        renderer.advanceAnimationsForTesting()
        path = shape.pathForTesting(in: NSRect(x: 0, y: 0, width: 22, height: 14))
        XCTAssertEqual(path.bounds.origin, NSPoint(x: 6, y: 12))

        now = 200
        renderer.advanceAnimationsForTesting()
        path = shape.pathForTesting(in: NSRect(x: 0, y: 0, width: 22, height: 14))
        XCTAssertEqual(path.bounds.origin, NSPoint(x: 11, y: 22))
        XCTAssertFalse(renderer.describedMotionActiveForTesting)
    }

    @MainActor
    func testNewLineGeometryAndStrokeStartAtTheirShapeDefaults() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var initial = HostPatch(id: .manual("line"), type: .line)
        initial.properties[.aspect] = .enumeration(Aspect.center.rawValue)
        initial.properties[.strokeDashPattern] = .numbers([1, 1])
        renderer.applyForTesting(initial)

        var changed = HostPatch(id: .manual("line"), type: .line)
        changed.properties[.x2] = .number(20)
        changed.properties[.y2] = .number(10)
        changed.properties[.strokeWidth] = .number(3)
        changed.properties[.strokeDashOffset] = .number(3)
        changed.properties[.strokeMiterLimit] = .number(4)
        for property in [
            Prop.x2, .y2, .strokeWidth, .strokeDashOffset, .strokeMiterLimit,
        ] {
            changed.transitions[property] = HostTransition(motion: .eased(200, .linear))
        }
        renderer.applyForTesting(changed)

        let line = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("line")) as? AppKitShapeView)
        var path = line.pathForTesting(in: NSRect(x: 0, y: 0, width: 10, height: 5))
        XCTAssertEqual(path.bounds, .zero)
        XCTAssertEqual(path.lineWidth, 1, accuracy: 0.000_001)
        XCTAssertEqual(path.miterLimit, 10, accuracy: 0.000_001)
        XCTAssertEqual(line.dashPhaseForTesting, 0, accuracy: 0.000_001)

        now = 100
        renderer.advanceAnimationsForTesting()
        path = line.pathForTesting(in: NSRect(x: 0, y: 0, width: 10, height: 5))
        XCTAssertEqual(path.bounds, NSRect(x: 0, y: 0, width: 10, height: 5))
        XCTAssertEqual(path.lineWidth, 2, accuracy: 0.000_001)
        XCTAssertEqual(path.miterLimit, 7, accuracy: 0.000_001)
        XCTAssertEqual(line.dashPhaseForTesting, 3, accuracy: 0.000_001)
    }

    @MainActor
    private func testWindow() -> HostPatch {
        var page = HostPatch(id: .manual("page"), type: .page)
        page.children = .arranged([])
        var window = HostPatch(id: .manual("window"), type: .window)
        window.children = .arranged([page])
        return window
    }

    @MainActor
    private func windowTree(_ window: HostPatch) -> HostPatch {
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }

    @MainActor
    private func windowChange(_ window: HostPatch) -> HostPatch {
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .changed([window])
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .changed([scene])
        return application
    }
}

#endif

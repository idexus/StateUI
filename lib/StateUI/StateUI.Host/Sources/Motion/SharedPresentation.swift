// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One presentation the views of one id share on a page while one comes and others leave: where they are drawn - a
/// rectangle in the window, moved by one run - and their corner. Each view of the id still drawn is drawn from it
/// every frame, so the two are one by what they read, not by being moved alike; a view coming again during the
/// movement sends the same run on onto its own place, from where it is and as fast as it goes.
/// Design: docs/design/host/motion.md#a-shared-presentation
@MainActor
final class SharedPresentation {
    /// A view drawn from the presentation, as it stood when it joined: its own place in its window with no transform
    /// in it, the transforms of what holds it up to the scope, innermost first, and the one its layout's program
    /// places it with.
    struct Wearer {
        weak var element: MountedElement?
        let place: Rect
        let above: [(transform: HostDrawingTransform, frame: Rect)]
        let placing: HostDrawingTransform?
    }

    /// A view kept as it left, released as the last presentation it lends a view to lands.
    private struct Kept {
        weak var element: MountedElement?
    }

    /// The mount its run stands under in the tree's described motion - none of an element's - and its scope's.
    let runMount: UInt64
    let scope: UInt64
    private weak var tree: MountedTree?

    /// The view coming, which it lands on; those kept for it as they left, the newest last - drawn only the newest.
    private(set) var coming: Wearer?
    private var leaving: [Wearer] = []
    private var kept: [Kept] = []

    /// Where the run set out and where it lands, as lanes: the middle across and down, the width and the height.
    private var from: [Double] = [0, 0, 0, 0]
    private var to: [Double] = [0, 0, 0, 0]

    /// The corner drawn as the run set out and as it lands; nil where none is carried.
    private var corner: (from: Double, to: Double)?

    /// The part of the way the two cross over in, and whether the view coming crosses - drawn in front, fading in -
    /// else the newest leaving one, fading out.
    private var crossing: ClosedRange<Double> = 0...1
    private(set) var comingCrosses = true

    /// The share of its opacity each of the two drawn was drawn with as the run was last sent on, by its element:
    /// each crosses from there.
    private var setOutShares: [ObjectIdentifier: Double] = [:]

    /// How many times the run was sent: a run sent on ends the one before, and only the last one's landing counts.
    private var sends = 0
    private var finished = false

    init(runMount: UInt64, scope: UInt64, tree: MountedTree) {
        self.runMount = runMount
        self.scope = scope
        self.tree = tree
    }

    // MARK: - Sending

    /// Sends the run onto where `coming` lands as drawn, `target`, under `law`: from where it is drawn now, as fast
    /// as it goes, where it already runs - else from `source`, at `speed`, its corner from `cornerFrom` - with
    /// `keyed`, kept for it as it left, the newest leaving view. False where nothing moves.
    func send(
        coming new: Wearer, to target: Rect, from source: Rect, speed: RectSpeed, cornerFrom: Double?,
        leaving keyed: Wearer?, under law: Motion
    ) -> Bool {
        guard let tree, !finished, let element = new.element else { return false }

        let runs = tree.standingProperty(mount: runMount, property: .area) != nil
        let setsOut = runs ? drawn : source
        let cornerNow = runs ? corner.map { $0.from + ($0.to - $0.from) * progress } : cornerFrom
        setOutShares = [:]
        if runs {
            for each in [coming, leaving.last].compactMap({ $0?.element }) {
                setOutShares[ObjectIdentifier(each)] = opacity(of: each)
            }
        }
        if let keyed { leaving.append(keyed) }
        coming = new
        from = Self.lanes(setsOut)
        to = Self.lanes(target)
        corner = cornerNow.flatMap { from in element.ownCorner.map { (from: from, to: $0 * element.scaleInScope) } }
        crossing = Self.crossing(from: setsOut, to: target)
        comingCrosses = target.width * target.height >= setsOut.width * setsOut.height
        sends += 1
        let send = sends
        return tree.receiveProperty(
            mount: runMount, property: .area, standing: .numbers(from), target: .numbers(to), motion: law,
            landed: { [weak self] in if self?.sends == send { self?.finish() } },
            velocity: runs ? [] : [speed.x, speed.y, speed.width, speed.height])
    }

    /// `root`, kept as it left, waits for the landing to be released.
    func keeps(_ root: MountedElement) {
        kept.append(Kept(element: root))
    }

    /// The run lands, or is ended: the view coming stands as it declares, the views that left are drawn no more,
    /// and those kept for it are released as the last presentation they lend a view to lands.
    func finish() {
        guard let tree, !finished else { return }
        finished = true
        tree.receiveProperty(mount: runMount, property: .area, standing: nil, target: nil, motion: nil)
        let drawn = Self.drawnProperties
        if let element = coming?.element, element.presentation === self {
            element.presentation = nil
            element.native.presentFrame(drawn.union(element.roundingProperty.map { [$0] } ?? []))
            element.entryLanded()
        }
        for wearer in leaving {
            guard let element = wearer.element, element.presentation === self else { continue }
            element.presentation = nil
            element.exitEnds[.opacity] = 0
            element.native.presentFrame([.opacity])
        }
        for root in kept { root.element?.exitLanded() }
        tree.shared.finished(self)
    }

    // MARK: - What it draws

    /// The numbers a view drawn from a presentation is drawn with.
    static let drawnProperties: Set<Prop> = [.translationX, .translationY, .scaleX, .scaleY, .opacity]

    /// The views drawn from it now, the one coming first.
    var wearers: [MountedElement] {
        ([coming].compactMap { $0 } + leaving).compactMap(\.element)
    }

    /// The rectangle drawn now: where the run stands, else where it lands.
    var drawn: Rect {
        guard case .numbers(let lanes)? = tree?.presentedPropertyValue(mount: runMount, property: .area), lanes.count == 4
        else { return Self.rect(to) }
        return Self.rect(lanes)
    }

    /// How fast the rectangle drawn moves and grows; still where nothing runs.
    var speed: RectSpeed {
        guard let lanes = tree?.standingProperty(mount: runMount, property: .area)?.velocity, lanes.count == 4
        else { return .still }
        return RectSpeed(x: lanes[0], y: lanes[1], width: lanes[2], height: lanes[3])
    }

    /// How far the way has got, from 0 to 1: read off the size that changes most, else the middle that does.
    var progress: Double {
        let now = Self.lanes(drawn)
        let size = abs(to[2] - from[2]) >= abs(to[3] - from[3]) ? 2 : 3
        let middle = abs(to[0] - from[0]) >= abs(to[1] - from[1]) ? 0 : 1
        let lane = abs(to[size] - from[size]) > 0.5 ? size : middle
        guard abs(to[lane] - from[lane]) > 0.5 else { return 1 }
        return min(max((now[lane] - from[lane]) / (to[lane] - from[lane]), 0), 1)
    }

    /// What `element`, one of its views, is drawn with for `property`: its move and scale onto the rectangle drawn,
    /// its opacity as the two cross over, its corner; nil for anything else.
    func value(_ property: Prop, of element: MountedElement) -> HostValue? {
        guard let wearer = ([coming].compactMap { $0 } + leaving).first(where: { $0.element === element }) else { return nil }
        switch property {
        case .translationX, .translationY, .scaleX, .scaleY:
            return transform(of: wearer, element).first { $0.0 == property }.map { .number($0.1) }
        case .opacity:
            return .number((element.plainValue(.opacity)?.number ?? 1) * opacity(of: element))
        case .cornerRadius, .shape:
            guard let corner, property == element.roundingProperty else { return nil }
            let radius = (corner.from + (corner.to - corner.from) * progress) / max(element.scaleInScope, 0.01)
            return property == .cornerRadius ? .number(radius) : ContainerShape.roundedRectangle(radius).propValue
        default:
            return nil
        }
    }

    /// Whether the corner is carried on its way.
    var carriesACorner: Bool { corner != nil }

    /// The numbers of `element`'s own transform that draw it in the rectangle drawn, as it stands in `wearer`.
    private func transform(of wearer: Wearer, _ element: MountedElement) -> [(Prop, Double)] {
        let undone = wearer.above.reversed().reduce(drawn) { $1.transform.place(drawnAs: $0, within: $1.frame) }
        let local = wearer.placing?.place(drawnAs: undone, within: wearer.place) ?? undone
        let place = wearer.place
        guard place.width > 0, place.height > 0 else { return [] }
        let pivot = Point(
            x: place.x + place.width * (element.number(.pivotX) ?? 0.5),
            y: place.y + place.height * (element.number(.pivotY) ?? 0.5))
        let (wide, tall) = (local.width / place.width, local.height / place.height)
        let uniform = element.number(.scale) ?? 1
        return [
            (.translationX, local.x + local.width / 2 - pivot.x - wide * (place.x + place.width / 2 - pivot.x)),
            (.translationY, local.y + local.height / 2 - pivot.y - tall * (place.y + place.height / 2 - pivot.y)),
            (.scaleX, wide / uniform), (.scaleY, tall / uniform),
        ]
    }

    /// The share of its opacity `element` is drawn with: the one in front crosses over, the one behind stands whole,
    /// and a view that left before the newest is drawn no more. Each of the two goes there from the share it was
    /// drawn with as the run was sent on - a view coming back while it crosses goes on from where it stood.
    private func opacity(of element: MountedElement) -> Double {
        let length = crossing.upperBound - crossing.lowerBound
        let part = length > 0 ? min(max((progress - crossing.lowerBound) / length, 0), 1) : (progress < 1 ? 0 : 1)
        let crossed = part * part * (3 - 2 * part)
        let isComing = coming?.element === element
        guard isComing || leaving.last?.element === element else { return 0 }

        let crossesIn = isComing && comingCrosses
        let end = isComing || comingCrosses ? 1.0 : 0
        let start = setOutShares[ObjectIdentifier(element)] ?? (crossesIn ? 0 : 1)
        return start + (end - start) * crossed
    }

    // MARK: - Lanes and crossing

    static func lanes(_ rect: Rect) -> [Double] {
        [rect.x + rect.width / 2, rect.y + rect.height / 2, rect.width, rect.height]
    }

    static func rect(_ lanes: [Double]) -> Rect {
        Rect(x: lanes[0] - lanes[2] / 2, y: lanes[1] - lanes[3] / 2, width: lanes[2], height: lanes[3])
    }

    /// Where two partners cross over: in the part of the way nearest the smaller - early as the view grows from
    /// `source` to `destination`, late as it shrinks, midway between two of a size.
    static func crossing(from source: Rect, to destination: Rect) -> ClosedRange<Double> {
        let grows = destination.width * destination.height / max(source.width * source.height, 1)
        return grows > 1.25 ? 0...0.45 : grows < 0.8 ? 0.55...1 : 0.25...0.75
    }
}

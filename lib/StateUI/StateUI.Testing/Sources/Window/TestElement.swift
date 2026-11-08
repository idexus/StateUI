// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A view of a test's window, found again each time it is used - by its identifier or its aim - so it stays the same
/// view while the page builds again around it.
@MainActor
public struct TestElement {
    /// How the element is found.
    enum Finding {
        /// By the identifier automation knows it by.
        case identifier(String)
        /// By the aim put on it: where the view stands, the keys from the root down.
        case aim(@MainActor () -> [ElementID]?)
    }

    let window: TestWindow
    let finding: Finding

    /// Acts on the view as its user does - `.activate` clicks a button, `.type("Ada")` types into a field - then
    /// waits for what the act began: the handlers it raised, their work and the frames they asked for. It fails
    /// where the act cannot be made, and where a run the act began is still under way after ten seconds.
    ///
    ///     try await button.perform(.activate)
    public func perform(_ act: UserAct) async throws {
        let begun = HostBoundary.runsBegun
        try does(act)
        try await window.settle(since: begun)
    }

    /// The same, the driver's steps alone running the work it began - on a host's own loop.
    @_spi(Host) public func performNow(_ act: UserAct) throws {
        let begun = HostBoundary.runsBegun
        try does(act)
        try window.settleNow(since: begun)
    }

    /// Does `act` to the view standing now, through the window's driver.
    private func does(_ act: UserAct) throws {
        let element = try mounted()
        do {
            try window.driver.perform(act.driven(on: element), on: element)
        } catch let cannot as DriverCannot {
            throw TestFailure(description: "\(self) cannot \(act): \(cannot.because ?? cannot.ability)")
        }
    }

    /// What the view holds of `member` now - its words, its value, whether it is enabled - as the window shows it;
    /// nil where it holds none. It fails where no view, or two, is the one it names, as `perform` does, and where
    /// the view wears no contract of the member's.
    ///
    ///     XCTAssertEqual(try button.value(TextElementContract.text), "Clicked 1 time")
    public func value<Owner: WornContract, Value: HostRepresentable>(
        _ member: ElementProperty<Owner, Value>
    ) throws -> Value? {
        let element = try mounted()
        if Wearing.element(element.type, wears: Owner.self) == false {
            throw TestFailure(description: "\(self) wears no \(Owner.name): it holds no `\(Owner.name).\(member.name)`")
        }
        do {
            return try window.driver.held(member.token, on: element).flatMap { Value(propValue: $0) }
        } catch let cannot as DriverCannot {
            throw TestFailure(description: "\(self) cannot read \(member.name): \(cannot.because ?? cannot.ability)")
        }
    }

    /// The view standing now: the one element the finding names.
    func mounted() throws -> MountedElement {
        let found: [MountedElement] = switch finding {
        case .identifier(let identifier):
            window.root.map { Self.all(in: $0) { $0.value(.accessibilityIdentifier)?.string == identifier } } ?? []
        case .aim(let place):
            place().flatMap { keys in window.root?.element(at: keys) }.map { [$0] } ?? []
        }
        guard found.count == 1 else {
            throw TestFailure(description: found.isEmpty ? "no view is \(self)" : "\(found.count) views are \(self)")
        }
        return found[0]
    }

    /// Every element under `element`, itself first, that `matches` - its children and the parts it holds.
    private static func all(in element: MountedElement, _ matches: (MountedElement) -> Bool) -> [MountedElement] {
        (matches(element) ? [element] : []) + (element.children + element.slots).flatMap { all(in: $0, matches) }
    }
}

extension TestElement: @MainActor CustomStringConvertible {
    /// How a failure names the element: by its identifier, or as the view its aim is on.
    public var description: String {
        switch finding {
        case .identifier(let identifier): "the view \"\(identifier)\""
        case .aim: "the view the aim is on"
        }
    }
}

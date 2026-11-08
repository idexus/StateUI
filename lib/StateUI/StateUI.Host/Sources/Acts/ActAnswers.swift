// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// How a host answers the acts the application calls, the same on every host: a reply with its values, or a failure
/// with the reason - so a caller never waits on an act nobody performs.
/// Design: docs/design/host/runtime.md#acts
extension CoreLink {
    /// Answers `call` with `values`, where a caller waits on it.
    public func reply(_ call: HostActCall, _ values: [HostValue]) {
        if let completion = call.completion { reply(completion, with: values) }
    }

    /// Fails `call` with `reason`: a caller waiting on it throws the reason, and one nobody waits on is told to `log`.
    public func fail(_ call: HostActCall, _ reason: String, log: (String) -> Void) {
        if let completion = call.completion {
            fail(completion, reason: reason)
        } else {
            log(reason)
        }
    }
}

/// Why an act could not be performed, which fails it.
@_spi(Host) public struct ActFailure: Error, Equatable, CustomStringConvertible {
    /// The reason the caller hears.
    public let reason: String

    /// A failure for `reason`.
    public init(_ reason: String) {
        self.reason = reason
    }

    /// The reason.
    public var description: String { reason }
}

extension MountedTree {
    /// The element an act is aimed at, which its first argument names: where it stands, the keys from the root
    /// down - what an aim sends - or an element's own id or number alone, the first such from the root.
    /// - Throws: `ActFailure` where the act names none, or none such is on screen.
    public func aimed(_ call: HostActCall) throws(ActFailure) -> MountedElement {
        if case .values(let keys)? = call.arguments.first {
            let place = keys.compactMap(Self.key)
            guard !place.isEmpty, place.count == keys.count else {
                throw ActFailure("\(call.act.name) has to say which view it is for")
            }
            guard let element = root?.element(at: place) else {
                throw ActFailure("there is no view \(place.map { "\($0)" }.joined(separator: "/")) on screen")
            }
            return element
        }
        guard let target = call.arguments.first.flatMap(Self.key) else {
            throw ActFailure("\(call.act.name) has to say which view it is for")
        }
        guard let element = root?.first(id: target) else { throw ActFailure("there is no view \(target) on screen") }
        return element
    }

    /// The key `value` names: an author's name as text, a number; nil for anything else.
    private static func key(_ value: HostValue) -> ElementID? {
        switch value {
        case .string(let name): .manual(name)
        case .number: Int(propValue: value).map(ElementID.auto)
        default: nil
        }
    }
}

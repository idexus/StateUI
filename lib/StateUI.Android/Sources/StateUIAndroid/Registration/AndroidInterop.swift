// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What an application registers with this host beside the elements the host realizes itself: the acts it performs
/// and the events it raises, said before the host starts.
/// Design: docs/design/platforms/android/runtime.md#the-applications-own-acts
@MainActor
enum AndroidInterop {
    /// The application's acts, performed where no act of the library's answers the call (`InteropActs`).
    static let acts = InteropActs<AndroidView>()
}

/// The acts an application performs on this host - what its own `stateUICall` reaches.
///
/// Said once, from the application's Android head as its library loads - `JNI_OnLoad` runs on the UI thread -
/// before `StateUIAndroid.load(_:)`.
@MainActor
public enum StateUIActs {
    /// Performs an act of the application's - one no control stands behind - when the application calls it with
    /// `stateUICall`.
    ///
    /// The values are the act's own, as its contract declares them, so a performer of another shape does not
    /// compile and a call carrying anything else fails with the reason rather than running on a guess. A second
    /// registration of an act replaces the first.
    ///
    /// - Parameters:
    ///   - act: the member, written with its contract.
    ///   - perform: given the arguments the contract declares, answering the values it declares. What it throws
    ///     fails the call, and the caller throws that reason. A performer may await, and the call is answered once
    ///     it returns.
    public static func add<
        Owner: ApplicationTier, each Argument: HostRepresentable, each Answer: HostRepresentable
    >(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        _ perform: @escaping @MainActor (repeat each Argument) async throws -> (repeat each Answer)
    ) {
        AndroidInterop.acts.add(act, perform)
    }
}

/// The events an application raises on this host, which every `HostEvents.on` of the event hears.
public enum StateUIEvents {
    /// Says the application raises `event`, so the host declares it realized.
    ///
    /// Said once, where the application registers its acts.
    @MainActor
    public static func raises<Owner: ApplicationTier, Payload>(_ event: ElementEvent<Owner, Payload>) {
        AndroidRegistrations.registry.raises(event)
    }

    /// Raises `event` with the values its contract declares, from any thread; how many handlers heard it.
    @discardableResult
    public nonisolated static func raise<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ value: repeat each Value
    ) -> Int {
        CoreLink().raise(event, repeat each value)
    }
}

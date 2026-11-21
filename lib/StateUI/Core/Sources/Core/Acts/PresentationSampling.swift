// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a view stands, asked of the host as an act of its aim.
// Design: docs/design/core/acts.md#where-a-view-stands-asked

extension Aim where Target: ViewProperties {
    /// Asks how this view stands on the page now: where its layout puts it, the rectangle around what is drawn of
    /// it, and how it is drawn - mid-movement, where the movement has got it to.
    ///
    ///     @Aim(Rectangle.self) private var panel
    ///
    ///     Rectangle().translationX($offset).aim(panel)
    ///     Button("Where is it?").onClicked(policy: .ignoreWhileRunning) {
    ///         let sample = try await panel.presentationSample()
    ///         log("drawn at \(sample.frame.x), \(sample.translation.x) from its place")
    ///     }
    ///
    /// It is a reading of one moment, and starts nothing: what must follow a view as it moves reads its frame
    /// (`layoutFrame`, `presentationFrame`) or follows the state that moves it.
    ///
    /// - Returns: the view as it stands.
    /// - Throws: `StateUIError` when the aim is on no view or on two, or its view is no longer shown or not yet
    ///   laid out.
    public func presentationSample() async throws -> PresentationSample {
        try await call(ViewContract.presentationSample)
    }
}

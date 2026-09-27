// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The gallery's own controls, as this host realizes them.
///
/// The contracts and the Swift halves are shared by every host - see
/// Sources/Samples/Interop. What each control IS on screen is its view's, and
/// so is its registration: `register()` at the end of the view's own file.
/// This is the list of them, and nothing else.
enum GalleryControls {
    /// Registers every control this host realizes. Said once, before the
    /// application runs.
    @MainActor
    static func register() {
        TrafficLightView.register()
        RatingBarView.register()
        MetalCube3DView.register()
    }
}

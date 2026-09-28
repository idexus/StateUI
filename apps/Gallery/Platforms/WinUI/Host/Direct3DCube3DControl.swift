// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CGalleryWinUI
import GalleryUI
import StateUIWinUI

/// A cube drawn by Direct3D 11.1 in a SwapChainPanel the gallery's relay makes - Platforms/WinUI/Relay/Cube3D.cpp,
/// an element that knows nothing of StateUI. It turns on WinUI's frames only while it spins and stands on screen.
/// The Swift half is Sources/Samples/Interop/Cube3D.swift.
@MainActor
final class Direct3DCube3DControl: WinUIControl {
    let element: OpaquePointer

    /// How long the cube's edge is, as a share of the panel.
    var cubeSize = 0.6 {
        didSet { if cubeSize != oldValue { tell() } }
    }

    /// Which colour it is painted.
    var color = CubeColor.teal {
        didSet { if color != oldValue { tell() } }
    }

    /// Whether it turns. Stopped, it holds the angle it had.
    var isSpinning = true {
        didSet { if isSpinning != oldValue { tell() } }
    }

    init() {
        element = gallery_cube_make()!
    }

    isolated deinit {
        gallery_cube_close(element)
        gallery_winui_release(element)
    }

    /// The Direct3D feature level its device stands at, 0xb100 for 11_1; 0 before it drew.
    var featureLevel: Int32 {
        gallery_cube_feature_level(element)
    }

    private func tell() {
        gallery_cube_set(element, cubeSize, color.rawValue, isSpinning)
    }
}

// MARK: - Registration

extension Direct3DCube3DControl {
    /// Adds the cube for `Cube3DContract`. Said once, before the application runs.
    @MainActor
    static func register() {
        StateUIControls.add(Cube3DContract.self, create: { _ in Direct3DCube3DControl() }) { cube in
            cube.property(Cube3DContract.size) { control, size in control.cubeSize = size ?? 0.6 }
            cube.property(Cube3DContract.color) { control, color in control.color = color ?? .teal }
            cube.property(Cube3DContract.isSpinning) { control, spinning in control.isSpinning = spinning ?? true }
        }
    }
}

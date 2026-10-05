// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIWeb

/// A cube drawn by WebGL 2 in the page: the gallery's own element, `<gallery-cube3d>` of Page/cube3d.js, which knows
/// nothing of StateUI - told what it is through its attributes. The Swift half is Sources/Samples/Interop/Cube3D.swift.
@MainActor
final class WebGLCube3DView: WebControl {
    let element = WebPageElement(tag: "gallery-cube3d")

    /// How long the cube's edge is, as a share of the element.
    var cubeSize = 0.6 {
        didSet { if cubeSize != oldValue { element.setAttribute("size", String(cubeSize)) } }
    }

    /// Which colour it is painted, as the element reads it: the vocabulary's member number.
    var color = CubeColor.teal {
        didSet { if color != oldValue { element.setAttribute("color", String(color.rawValue)) } }
    }

    /// Whether it turns. Stopped, it holds the angle it had.
    var isSpinning = true {
        didSet { if isSpinning != oldValue { element.setAttribute("spinning", isSpinning ? "" : nil) } }
    }

    init() {
        element.setAttribute("size", String(cubeSize))
        element.setAttribute("color", String(color.rawValue))
        element.setAttribute("spinning", "")
    }
}

// MARK: - Registration

extension WebGLCube3DView {
    /// Adds the cube for `Cube3DContract`. Said once, before the application runs.
    static func register() {
        StateUIControls.add(Cube3DContract.self, create: { _ in WebGLCube3DView() }) { cube in
            cube.property(Cube3DContract.size) { control, size in control.cubeSize = size ?? 0.6 }
            cube.property(Cube3DContract.color) { control, color in control.color = color ?? .teal }
            cube.property(Cube3DContract.isSpinning) { control, spinning in control.isSpinning = spinning ?? true }
        }
    }
}

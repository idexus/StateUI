// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a host that blurs nothing showed, read back as the material it stands for: the blur whose colour of the
/// theme in force it painted, else the colour itself.
@_spi(Host) public enum StandIns {
    /// The material a view painting `painted` shows: a blur, where `painted` is the colour a host that blurs nothing
    /// draws for one, else the colour.
    @MainActor public static func material(painted: Color) -> Material {
        let drawn = painted.propValue
        let blur = Blur.Thickness.allCases.first { HostMaterial(Material.blur(Blur($0)).propValue).standIn == drawn }
        return blur.map { .blur(Blur($0)) } ?? .color(painted)
    }
}

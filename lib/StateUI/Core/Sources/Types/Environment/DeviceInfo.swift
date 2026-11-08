// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The kind of machine the interface is showing on, as the host reports it
/// before the first render - so the first tree already knows. Read it as the
/// device's `info`:
///
///     @Environment(\.device) private var device
///
///     var body: some View {
///         device.info.formFactor == .desktop ? wideLayout : phoneLayout
///     }
///
/// The formFactor distinguishes form factors that share an operating system. A
/// headless host leaves values at their documented defaults.
@MainActor
public final class DeviceInfo {
    /// Phone, tablet, desktop, television, or watch.
    public internal(set) var formFactor: FormFactor {
        get { _formFactor }
        set { _formFactor = newValue }
    }

    @State private var _formFactor: FormFactor = .unknown

    /// The host platform's name, such as "macOS", "iOS", "Android",
    /// "Windows", "Linux", or "Web" - text, since a host may name a platform
    /// this library does not know.
    public internal(set) var platform: String {
        get { _platform }
        set { _platform = newValue }
    }

    @State private var _platform = ""

    /// The hardware model, where the platform shares it.
    public internal(set) var model: String {
        get { _model }
        set { _model = newValue }
    }

    @State private var _model = ""

    /// Who made the device, where the platform shares it.
    public internal(set) var manufacturer: String {
        get { _manufacturer }
        set { _manufacturer = newValue }
    }

    @State private var _manufacturer = ""

    /// The device's own name, where the platform shares it.
    public internal(set) var name: String {
        get { _name }
        set { _name = newValue }
    }

    @State private var _name = ""

    /// The operating system version as displayable text.
    public internal(set) var platformVersion: String {
        get { _platformVersion }
        set { _platformVersion = newValue }
    }

    @State private var _platformVersion = ""

    /// Whether this is an emulator, a simulator or a virtual machine; nil where the host has not said.
    public internal(set) var isVirtual: Bool? {
        get { _isVirtual }
        set { _isVirtual = newValue }
    }

    @State private var _isVirtual: Bool?

    /// The processor architecture the application was compiled for and runs as - "arm64", "x86_64", "wasm32" -
    /// compiled in, never from a host.
    public let architecture = DeviceInfo.compiledArchitecture

    /// A device as a test or a preview fakes it; what is not said starts as a headless host's does.
    public init(
        formFactor: FormFactor = .unknown, platform: String = "", model: String = "", manufacturer: String = "",
        name: String = "", platformVersion: String = "", isVirtual: Bool? = nil
    ) {
        self.formFactor = formFactor
        self.platform = platform
        self.model = model
        self.manufacturer = manufacturer
        self.name = name
        self.platformVersion = platformVersion
        self.isVirtual = isVirtual
    }
}

extension DeviceInfo {
    /// The architecture this build of the library was compiled for.
    nonisolated static var compiledArchitecture: String {
        #if arch(arm64)
            "arm64"
        #elseif arch(x86_64)
            "x86_64"
        #elseif arch(arm)
            "arm"
        #elseif arch(i386)
            "i386"
        #elseif arch(wasm32)
            "wasm32"
        #else
            "unknown"
        #endif
    }
}

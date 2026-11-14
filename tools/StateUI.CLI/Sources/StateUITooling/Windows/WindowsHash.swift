// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol
#if os(Windows)
import WinSDK
#endif

/// A digest by the system's own cryptography - Windows' CNG, `bcrypt.dll` - which checks what WinUI's build fetches.
enum WindowsHash {
    /// The SHA-512 of `data`.
    static func sha512(_ data: Data) throws -> Data {
        #if os(Windows)
        typealias Hash = @convention(c) (
            UnsafeMutableRawPointer?, UnsafeMutablePointer<UInt8>?, UInt32, UnsafeMutablePointer<UInt8>?, UInt32,
            UnsafeMutablePointer<UInt8>?, UInt32
        ) -> Int32
        guard let library = "bcrypt.dll".withCString(encodedAs: UTF16.self, { LoadLibraryW($0) }),
              let symbol = GetProcAddress(library, "BCryptHash")
        else { throw ToolingError(.missingToolchain, "Windows' bcrypt.dll offers no BCryptHash.") }
        let hash = unsafeBitCast(symbol, to: Hash.self)
        // BCRYPT_SHA512_ALG_HANDLE, CNG's own handle of the algorithm.
        let algorithm = UnsafeMutableRawPointer(bitPattern: 0x61)
        var input = [UInt8](data)
        var digest = [UInt8](repeating: 0, count: 64)
        let status = hash(algorithm, nil, 0, &input, UInt32(input.count), &digest, 64)
        guard status == 0 else { throw ToolingError(.toolFailed, "BCryptHash answered \(String(UInt32(bitPattern: status), radix: 16)).") }
        return Data(digest)
        #else
        throw ToolingError(.invalidConfiguration, "A WinUI head's packages are checked on Windows.")
        #endif
    }
}

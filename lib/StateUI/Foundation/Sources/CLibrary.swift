// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The platform's C library, one import on every platform: `exp`, `sin`, `pow` and the rest of its arithmetic.
// Design: docs/design/foundation/c-library.md
#if canImport(Darwin)
@_exported import Darwin
#elseif canImport(Android)
@_exported import Android
#elseif canImport(Glibc)
@_exported import Glibc
#elseif canImport(CRT)
@_exported import CRT
#elseif canImport(WASILibc)
@_exported import WASILibc
#else
#error("StateUIFoundation knows no C library on this platform")
#endif

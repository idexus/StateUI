// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(Windows)
import WinSDK
#endif

/// Which thread this code runs on, as a number to compare with another: the same on one thread, another on
/// another thread alive at the same time - the thread's own number, as the debugger shows it; nought on the Web,
/// where one thread runs everything.
///
///     let uiThread = currentThreadNumber()
///     assert(currentThreadNumber() == uiThread, "called from the UI thread")
///
/// Design: docs/design/foundation/c-library.md#which-thread
public func currentThreadNumber() -> UInt64 {
    #if os(Windows)
    return UInt64(GetCurrentThreadId())
    #elseif os(WASI)
    return 0
    #elseif canImport(Darwin)
    var number: UInt64 = 0
    pthread_threadid_np(nil, &number)
    return number
    #elseif os(Android)
    return UInt64(UInt(bitPattern: pthread_self()))
    #else
    return UInt64(pthread_self())
    #endif
}

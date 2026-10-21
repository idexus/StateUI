// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the host layer takes of libdispatch beyond its public headers, where no run loop of the platform's turns its
// main queue: the queue's handle, which signals while the queue holds work, and the drain that runs that work - the
// two entry points a run loop takes. Apple's own run loop turns the queue, and the Web has none.
#if !defined(__APPLE__) && !defined(__wasi__)
#if defined(_WIN32)
/// An event, set while the main queue holds work.
typedef void *StateUIMainQueueHandle;
#else
/// An eventfd, readable while the main queue holds work.
typedef int StateUIMainQueueHandle;
#endif

StateUIMainQueueHandle _dispatch_get_main_queue_handle_4CF(void);
void _dispatch_main_queue_callback_4CF(void *message);
#endif

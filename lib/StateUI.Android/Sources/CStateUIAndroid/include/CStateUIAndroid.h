// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The NDK's C surface the Android Views host calls: JNI, the main thread's
// looper, the display's frames, the log, and an eventfd for the doorbell.
#pragma once

#include <android/choreographer.h>
#include <android/log.h>
#include <android/looper.h>
#include <jni.h>
#include <pthread.h>
#include <stdio.h>
#include <sys/eventfd.h>
#include <time.h>
#include <unistd.h>

/// Line-buffers stdout and unbuffers stderr once they point at a pipe - C's
/// own globals, which Swift 6 refuses to touch.
void stateui_android_buffer_standard_streams(void);

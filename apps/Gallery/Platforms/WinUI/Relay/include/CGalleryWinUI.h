// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The gallery's own WinUI elements, made by the gallery's relay: C++/WinRT behind these C functions, which the
// gallery's Swift halves call. Each element is handed over as a WinUI host's handle is - its default interface,
// AddRef'd - and each tells what the user did by the number its Swift half gave it.
#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// A WinUI element of the gallery's own: its default interface, AddRef'd; let go with `gallery_winui_release`.
typedef struct GalleryObject *GalleryObjectRef;

/// What the gallery's elements tell their Swift halves, each naming the control by the number it was made with.
typedef struct {
    /// A lamp of a traffic light was tapped: its index, top to bottom.
    void (*lampTapped)(int64_t control, int32_t lamp);

    /// The user chose a rating: how many stars.
    void (*rated)(int64_t control, double rating);
} GalleryWinUICallbacks;

/// Hands the relay what it tells; said once, before any element is made.
void gallery_winui_set_callbacks(GalleryWinUICallbacks const *callbacks);

/// Lets go of an element.
void gallery_winui_release(GalleryObjectRef object);

/// A housing of three lamps, the one `signal` names lit; a tap on a lamp is told as `lampTapped`.
GalleryObjectRef gallery_traffic_light_make(int64_t control);
void gallery_traffic_light_set_signal(GalleryObjectRef light, int32_t signal);

/// WinUI's rating control, five stars; the user's choice is told as `rated`, a program's is not.
GalleryObjectRef gallery_rating_bar_make(int64_t control);
void gallery_rating_bar_set_rating(GalleryObjectRef bar, double rating);

/// Flashes the rating: its opacity down and back, twice.
void gallery_rating_bar_flash(GalleryObjectRef bar);

/// A cube Direct3D 11.1 draws into a SwapChainPanel, turning on WinUI's frames while it spins and is on screen.
GalleryObjectRef gallery_cube_make(void);

/// Its edge as a share of the panel, 0 through 1; its colour, 0 teal, 1 amber, 2 violet; whether it turns.
void gallery_cube_set(GalleryObjectRef cube, double size, int32_t color, bool spinning);

/// Lets go of the cube's device and frames; its element is let go with `gallery_winui_release`.
void gallery_cube_close(GalleryObjectRef cube);

/// The Direct3D feature level the cube's device stands at, 0xb100 for 11_1; 0 before it drew.
int32_t gallery_cube_feature_level(GalleryObjectRef cube);

/// The battery's charge, 0 through 1, and whether the power is plugged in - 0 and false where there is no battery.
void gallery_battery(double *level, bool *charging);

/// Calls `changed`, on a thread of Windows' own, whenever the battery's charge or the power source changes.
void gallery_battery_watch(void (*changed)(void));

#ifdef __cplusplus
}
#endif

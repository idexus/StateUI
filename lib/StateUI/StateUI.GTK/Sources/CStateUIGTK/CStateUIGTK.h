// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// GTK 4 and libadwaita, as Swift imports them.
#include <adwaita.h>

// GLib marks its flags as flag enumerations from 2.86, which Swift then imports as option sets naming their members
// itself - G_SIGNAL_MATCH_DATA is no longer in scope. The flags Swift passes stand here under one name on every GLib.
static const GApplicationFlags STATEUI_APPLICATION_DEFAULT_FLAGS = G_APPLICATION_DEFAULT_FLAGS;
static const GApplicationFlags STATEUI_APPLICATION_NON_UNIQUE = G_APPLICATION_NON_UNIQUE;
static const GSignalMatchType STATEUI_SIGNAL_MATCH_ID = G_SIGNAL_MATCH_ID;
static const GSignalMatchType STATEUI_SIGNAL_MATCH_DATA = G_SIGNAL_MATCH_DATA;
static const GDBusProxyFlags STATEUI_DBUS_PROXY_FLAGS_NONE = G_DBUS_PROXY_FLAGS_NONE;
static const GDBusProxyFlags STATEUI_DBUS_PROXY_FLAGS_DO_NOT_AUTO_START = G_DBUS_PROXY_FLAGS_DO_NOT_AUTO_START;
static const GFileTest STATEUI_FILE_TEST_IS_REGULAR = G_FILE_TEST_IS_REGULAR;

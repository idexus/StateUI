// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A tier the application element wears: acts and events with no control
/// behind them - an alert, the clock, a battery that reports.
///
///     enum NotesContract: ApplicationTier {
///         static let name = "Notes"
///
///         static let readClipboard = ElementAct<Self, Void, String>("Notes.ReadClipboard")
///         static let batteryChanged = ElementEvent<Self, (Double, Bool)>("Notes.BatteryChanged")
///
///         static let members: [any ContractMember] = [readClipboard, batteryChanged]
///     }
///
///     let text = try await stateUICall(NotesContract.readClipboard)
///
/// Its acts are called with `stateUICall` and `stateUISend` and its events
/// heard with `HostEvents.on`: none of them aims at a control. An act of an
/// element's own is called through the element's aim instead, `Aim.call`.
public protocol ApplicationTier: Contract {}

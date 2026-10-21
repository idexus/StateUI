// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A contract of acts and events with no control behind them - an alert,
/// the clock, a battery that reports - which belong to the application.
///
///     enum NotesContract: ApplicationTier {
///         static let name = "Notes"
///
///         static let batteryLevel = ElementAct<Self, Void, Double>("Notes.BatteryLevel")
///         static let batteryChanged = ElementEvent<Self, (Double, Bool)>("Notes.BatteryChanged")
///
///         static let members: [any ContractMember] = [batteryLevel, batteryChanged]
///     }
///
///     let level = try await stateUICall(NotesContract.batteryLevel)
///
/// Its acts are called with `stateUICall` and `stateUISend` and its events
/// heard with `HostEvents.on`: none of them aims at a control. An act of an
/// element's own is called through the element's aim instead, `Aim.call`.
public protocol ApplicationTier: Contract {}

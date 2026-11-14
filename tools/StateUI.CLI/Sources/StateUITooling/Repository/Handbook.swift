// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// What the handbook holds that the repository's own tests write: the control dictionary and the platform contract,
/// rendered from the marks (`ControlDictionaryTests`), and the samples' listings with their review
/// (`SampleListingsTests`, `SampleReviewTests`) - held to what stands, or written by their owners.
/// Design: docs/design/tooling/repository.md#the-handbooks-own-outputs
struct Handbook {
    let checkout: URL
    let tools: ToolResolver

    /// The dictionary and the platform contract held to the marks, or rendered from them where `update`.
    func documents(update: Bool, reporter: BuildReporter) async throws -> SuiteResult.Phase {
        let base = ProcessEnvironment.inherited.removing("STATEUI_HOST", "STATEUI_UPDATE_EXPORTS", "STATEUI_STALE_ONLY")
        let environment = update ? base.setting("STATEUI_UPDATE_DOCS", to: "1") : base.removing("STATEUI_UPDATE_DOCS")
        reporter.progress(update ? "rendering the control dictionary and the platform contract" : "holding the documents to the marks")
        let passed = try await TestRun.swift(
            tools.swift, ["test", "--package-path", checkout.path, "--filter", "ControlDictionaryTests"], environment, reporter)
        return SuiteResult.Phase(name: update ? "documents rendered" : "documents held", passed: passed)
    }

    /// The samples' listings and the handbook's held to the code they are cut from, every sample's review standing -
    /// or the listings and the review's fingerprints written where `update`, once the notes were read.
    func samples(update: Bool, reporter: BuildReporter) async throws -> SuiteResult.Phase {
        let base = ProcessEnvironment.inherited.removing("STATEUI_HOST")
        let environment = update ? base.setting("STATEUI_UPDATE_SAMPLES", to: "1") : base.removing("STATEUI_UPDATE_SAMPLES")
        reporter.progress(update ? "writing the samples' listings and their review" : "holding the samples' listings to their code")
        let tests = update ? "SampleListingsTests|SampleReviewTests" : "SampleListingsTests|SampleReviewTests|SampleCodeTests"
        let passed = try await TestRun.swift(
            tools.swift, ["test", "--package-path", checkout.appendingPathComponent("apps/Gallery").path, "--filter", tests], environment, reporter)
        return SuiteResult.Phase(name: update ? "samples written" : "samples held", passed: passed)
    }
}

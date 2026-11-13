// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser

/// The options every command writing a result takes.
struct OutputOptions: ParsableArguments {
    @Option(help: "How the result is written: text, json or jsonl.")
    var format: OutputFormat = .text
}

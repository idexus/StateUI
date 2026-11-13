// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui serve --stdio`: an editor's JSON-RPC connection over standard input and output.
struct ServeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Answers an editor's JSON-RPC requests."
    )

    @Flag(help: "Speak over standard input and output.")
    var stdio = false

    func validate() throws {
        guard stdio else { throw ValidationError("serve speaks over --stdio.") }
    }

    func run() async throws {
        let output = StandardOutput()
        let connection = Connection(
            server: ToolingService.identity,
            apiVersions: Release.apiVersions,
            methods: ToolingService().methods,
            send: output.write,
            diagnose: StandardOutput.diagnose
        )
        for await bytes in StandardInput.chunks() {
            guard await connection.receive(bytes) else { break }
        }
        await connection.end()
        output.flush()
        throw ExitCode(await connection.shutDown ? 0 : ExitStatus.lostClient)
    }
}

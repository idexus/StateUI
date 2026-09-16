// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Runs the integration suite in a real VS Code: the one installed, with the
// extensions installed, on a profile of its own - so nothing the user has set is
// read or written - opened on this repository.

import { spawn } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

const extension = path.resolve(__dirname, "..", "..");
const repository = path.resolve(extension, "..", "..");
const code = process.env.STATEUI_VSCODE ?? "/Applications/Visual Studio Code.app/Contents/MacOS/Code";
const profile = fs.mkdtempSync(path.join(os.tmpdir(), "stateui-vscode-"));
const results = path.join(profile, "results.txt");

// Every run starts from no index at all, so no run inherits what an earlier one
// left behind.
for (const app of fs.readdirSync(path.join(repository, "apps"))) {
    for (const build of [".build-appkit", ".build-maui"]) {
        fs.rmSync(path.join(repository, "apps", app, build, "index-build"), { recursive: true, force: true });
    }
}

const env: NodeJS.ProcessEnv = { ...process.env, STATEUI_TEST_RESULTS: results };
// The suite starts from no host at all; an inherited one would decide the first answer.
delete env.STATEUI_APPKIT;
delete env.ELECTRON_RUN_AS_NODE;

const child = spawn(code, [
    repository,
    `--extensionDevelopmentPath=${extension}`,
    `--extensionTestsPath=${path.join(extension, "out", "Tests", "suite")}`,
    `--user-data-dir=${path.join(profile, "data")}`,
    `--extensions-dir=${path.join(os.homedir(), ".vscode", "extensions")}`,
    "--disable-workspace-trust", "--skip-welcome", "--skip-release-notes", "--new-window",
    // The suite asks the Swift side and resolves a MAUI launch without running
    // one. The .NET extensions only load the solution - which, on a profile
    // bound to no SDK, they report as "Project load blocked".
    ...["ms-dotnettools.csdevkit", "ms-dotnettools.csharp", "ms-dotnettools.dotnet-maui", "ms-dotnettools.vscode-dotnet-runtime"]
        .map((id) => `--disable-extension=${id}`),
], { env, stdio: "ignore" });

child.on("exit", (status) => {
    process.stdout.write(fs.existsSync(results) ? fs.readFileSync(results, "utf8") : "no results written\n");
    process.stdout.write(`exit ${status}\n`);
    process.exit(status ?? 1);
});

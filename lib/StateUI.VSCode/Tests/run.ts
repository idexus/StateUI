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
const code = process.env.STATEUI_VSCODE ?? installedCode();
const profile = fs.mkdtempSync(path.join(os.tmpdir(), "stateui-vscode-"));
const results = path.join(profile, "results.txt");

// The index directories are NOT cleared first: an editor open on this
// repository with the extension installed indexes in the same ones. The
// extension's own switches wait for any build running there.

const env: NodeJS.ProcessEnv = { ...process.env, STATEUI_TEST_RESULTS: results };
// The suite starts from no host at all; an inherited one would decide the first answer.
delete env.STATEUI_APPKIT;
delete env.STATEUI_ANDROID;
delete env.STATEUI_WINUI;
delete env.STATEUI_GTK;
delete env.ELECTRON_RUN_AS_NODE;

const child = spawn(code, [
    repository,
    `--extensionDevelopmentPath=${extension}`,
    `--extensionTestsPath=${path.join(extension, "out", "Tests", "suite")}`,
    `--user-data-dir=${path.join(profile, "data")}`,
    `--extensions-dir=${path.join(os.homedir(), ".vscode", "extensions")}`,
    "--disable-workspace-trust", "--skip-welcome", "--skip-release-notes", "--new-window",
], { env, stdio: "ignore" });

child.on("exit", (status) => {
    process.stdout.write(fs.existsSync(results) ? fs.readFileSync(results, "utf8") : "no results written\n");
    process.stdout.write(`exit ${status}\n`);
    process.exit(status ?? 1);
});

/** The VS Code this machine has installed, where each platform puts it; `STATEUI_VSCODE` names another. */
function installedCode(): string {
    const candidates = process.platform === "darwin"
        ? ["/Applications/Visual Studio Code.app/Contents/MacOS/Code"]
        : process.platform === "win32"
            ? [path.join(process.env.LOCALAPPDATA ?? "", "Programs", "Microsoft VS Code", "Code.exe"),
                path.join(process.env.ProgramFiles ?? "C:\\Program Files", "Microsoft VS Code", "Code.exe")]
            : ["/usr/share/code/code", "/snap/code/current/usr/share/code/code"];
    return candidates.find((each) => fs.existsSync(each)) ?? candidates[0];
}

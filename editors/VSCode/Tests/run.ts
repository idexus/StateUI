// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Runs the integration suite in a real VS Code: the one installed, with the
// extensions installed, on a profile of its own - so nothing the user has set is
// read or written - opened on this repository, its stateui.cliPath naming the
// stateui tool of this checkout.

import { execFileSync, spawn } from "child_process";
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

// The tool the suite drives, named by the profile's settings - the editor's search path is the login shell's, whose
// stateui may be another build: the one STATEUI_SUITE_CLI names, an installed one, else the one built from this checkout.
const program = process.env.STATEUI_SUITE_CLI ?? (() => {
    const tool = path.join(repository, "tools", "StateUI.CLI");
    execFileSync("swift", ["build", "--package-path", tool, "--product", "stateui"], { stdio: "inherit" });
    const bin = execFileSync("swift", ["build", "--package-path", tool, "--show-bin-path"], { encoding: "utf8" }).trim();
    return path.join(bin, process.platform === "win32" ? "stateui.exe" : "stateui");
})();
const settings = path.join(profile, "data", "User", "settings.json");
fs.mkdirSync(path.dirname(settings), { recursive: true });
fs.writeFileSync(settings, JSON.stringify({ "stateui.cliPath": program }));

// The tool's state of its own - its index leases and build permit - so the suite switches hosts on this checkout's
// packages while a window of the user's works on them: as before, it rewrites that window's index configuration.
const env: NodeJS.ProcessEnv = { ...process.env, STATEUI_TEST_RESULTS: results, STATEUI_STATE: path.join(profile, "stateui") };
delete env.ELECTRON_RUN_AS_NODE;

// Nor from anything chosen: the checkout's own choices - its workspace's and each application's `.stateui/`
// settings, out of git - stand aside while the suite chooses, and are put back as they were.
const chosenFiles = [
    path.join(repository, ".stateui", "workspace-settings.json"),
    ...fs.readdirSync(path.join(repository, "apps"), { withFileTypes: true })
        .filter((each) => each.isDirectory() && !each.name.startsWith("."))
        .map((each) => path.join(repository, "apps", each.name, ".stateui", "settings.json")),
];
const kept = new Map(chosenFiles.filter((each) => fs.existsSync(each)).map((each) => [each, fs.readFileSync(each)]));
const putBack = (): void => {
    for (const file of chosenFiles) {
        fs.rmSync(file, { force: true });
        const content = kept.get(file);
        if (content) {
            fs.writeFileSync(file, content);
        } else if (fs.existsSync(path.dirname(file)) && fs.readdirSync(path.dirname(file)).length === 0) {
            fs.rmdirSync(path.dirname(file));
        }
    }
};
for (const file of chosenFiles) {
    fs.rmSync(file, { force: true });
}

const child = spawn(code, [
    repository,
    `--extensionDevelopmentPath=${extension}`,
    `--extensionTestsPath=${path.join(extension, "out", "Tests", "suite")}`,
    `--user-data-dir=${path.join(profile, "data")}`,
    `--extensions-dir=${path.join(os.homedir(), ".vscode", "extensions")}`,
    "--disable-workspace-trust", "--skip-welcome", "--skip-release-notes", "--new-window",
], { env, stdio: "ignore" });

child.on("exit", (status) => {
    putBack();
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

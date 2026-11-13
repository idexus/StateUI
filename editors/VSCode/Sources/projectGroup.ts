// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A project group: a workspace the stateui tool makes (`workspace/create`) - its
// stateui.json, the StateUI it builds with, its applications - and the editor's
// own files beside it.

import * as fs from "fs";
import * as path from "path";

const settings = {
    "swift.searchSubfoldersForPackages": true,
    "swift.ignoreSearchingForPackagesInSubfolders": [".", ".build", "Packages", "out", "bazel-out", "bazel-bin", "StateUI"],
    "swift.autoGenerateLaunchConfigurations": false,
    "files.exclude": { "**/.build": true },
};

const launch = {
    version: "0.2.0",
    configurations: [
        { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug", presentation: { group: "0 StateUI", order: 1 } },
        { name: "StateUI: Release", type: "stateui", request: "launch", configuration: "release", presentation: { group: "0 StateUI", order: 2 } },
    ],
};

/**
 * Writes the editor's files of the group at `group`: Swift packages searched in
 * its folders but not in a release cloned into StateUI/, and StateUI: Debug and
 * StateUI: Release on F5.
 */
export function writeEditorFiles(group: string): void {
    fs.mkdirSync(path.join(group, ".vscode"), { recursive: true });
    fs.writeFileSync(path.join(group, ".vscode", "settings.json"), `${JSON.stringify(settings, null, 2)}\n`);
    fs.writeFileSync(path.join(group, ".vscode", "launch.json"), `${JSON.stringify(launch, null, 2)}\n`);
}

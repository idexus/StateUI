// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A project group: a folder of applications outside a checkout - apps/, and
// what git and the editor need beside it. Each application names the StateUI
// it builds with in its Package.swift: a release cloned into the group's
// StateUI/, or a local checkout.

import { execFile } from "child_process";
import * as fs from "fs";
import * as path from "path";
import { atLeast } from "./toolchain";

/** Why `name` cannot name a project group, or undefined where it can. */
export function groupNameProblem(name: string): string | undefined {
    // The group's path reaches every build tool, and not all of them take a space.
    return /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(name)
        ? undefined
        : "Letters, digits, dots, hyphens and underscores, starting with a letter or a digit.";
}

/** Where a release is cloned in `group`: the StateUI its applications then name `../../StateUI`. */
export function releaseDirectory(group: string): string {
    return path.join(group, "StateUI");
}

const ignored = (repository: string): string => `# SwiftPM's build directories: .build, and one per host's builds.
.build*/
# What Gradle keeps beside a head an editor opens; the scripts keep theirs in .build/android.
.gradle/
# The language server's own settings, written by the StateUI editor extension.
.sourcekit-lsp/
# A StateUI release cloned into the group: git clone --depth 1 --branch <release> ${repository} StateUI
/StateUI/
# What StateUI: Deploy lays: each application built for release, per platform.
/artifacts/

*.dSYM/
*.pdb
.DS_Store
`;

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
 * Makes the group's folder: an empty apps/, a .gitignore - which names how
 * StateUI/ is cloned again from `repository` - and the editor's settings:
 * Swift packages searched under apps/ but not in StateUI/, and StateUI: Debug
 * and StateUI: Release on F5.
 */
export function makeProjectGroup(group: string, repository: string): void {
    fs.mkdirSync(path.join(group, "apps"), { recursive: true });
    fs.mkdirSync(path.join(group, ".vscode"));
    fs.writeFileSync(path.join(group, ".gitignore"), ignored(repository));
    fs.writeFileSync(path.join(group, ".vscode", "settings.json"), `${JSON.stringify(settings, null, 2)}\n`);
    fs.writeFileSync(path.join(group, ".vscode", "launch.json"), `${JSON.stringify(launch, null, 2)}\n`);
}

/** The releases `git ls-remote --tags --refs` lists, `minimum` or newer, the newest first. */
export function releasesIn(listed: string, minimum: string): string[] {
    return listed.split(/\r?\n/)
        .map((line) => line.match(/refs\/tags\/(\d+\.\d+\.\d+)$/)?.[1])
        .filter((tag): tag is string => tag !== undefined && atLeast(tag, minimum))
        .sort((a, b) => Number(atLeast(b, a)) - Number(atLeast(a, b)));
}

/** The releases of the StateUI at `repository`, `minimum` or newer, the newest first - or why none were read. */
export function listReleases(repository: string, minimum: string): Promise<{ releases: string[]; problem?: string }> {
    return new Promise((resolve) => execFile("git", ["ls-remote", "--tags", "--refs", repository], (error, stdout, stderr) =>
        resolve(error ? { releases: [], problem: `${stderr}`.trim() || error.message } : { releases: releasesIn(stdout, minimum) })));
}

/** The command line that clones `release` of the StateUI at `repository` into `group`'s StateUI/, its tree alone. */
export function cloneCommand(repository: string, release: string, group: string): { command: string; args: string[] } {
    return {
        command: "git",
        args: ["-c", "advice.detachedHead=false", "clone", "--depth", "1", "--branch", release, repository, releaseDirectory(group)],
    };
}

/** Clones `release` into `group`'s StateUI/; whether it was cloned, and what git said. */
export function cloneRelease(repository: string, release: string, group: string): Promise<{ cloned: boolean; output: string }> {
    const { command, args } = cloneCommand(repository, release, group);
    return new Promise((resolve) => execFile(command, args, { cwd: group }, (error, stdout, stderr) =>
        resolve({ cloned: error === null, output: `${stdout}${stderr}` })));
}

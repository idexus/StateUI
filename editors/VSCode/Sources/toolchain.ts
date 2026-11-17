// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What only the editor knows of what a Debug launch needs - the LLDB DAP extension, and whether the lldb-dap
// `lldb-dap.executable-path` names starts - beside the stateui tool's own findings (`toolchain/check`), and the
// findings as StateUI: Check Toolchain shows them.

import { execFile } from "child_process";
import { onPath } from "./Tooling/locate";

/** A component the machine needs, and what was found of it. */
export interface Finding {
    /** The component, with the least of it that serves: "Swift 6.4 or newer". */
    readonly component: string;

    /** Who needs it: "every host", "GTK", "Debug". */
    readonly neededBy: string;

    /** What was found - its version, where it stands; undefined where nothing serves. */
    readonly found?: string;

    /** The version found that does not serve, older than the least the component names; undefined where none was. */
    readonly tooOld?: string;

    /** How to get it, where it is missing. */
    readonly advice: string;

    /** The machine it was looked for on - a guest of this one - where not this one. */
    readonly machine?: string;
}

/** Below 0, 0 or above 0 as version `a` is older than, the same as or newer than `b`, part by part. */
export function compareVersions(a: string, b: string): number {
    const first = a.split(".").map((each) => parseInt(each, 10) || 0);
    const second = b.split(".").map((each) => parseInt(each, 10) || 0);
    for (let index = 0; index < Math.max(first.length, second.length); index += 1) {
        const difference = (first[index] ?? 0) - (second[index] ?? 0);
        if (difference !== 0) {
            return difference;
        }
    }
    return 0;
}

/** The oldest release of Apple's systems StateUI runs on - iOS, Mac Catalyst and macOS alike: the manifests' floor. */
export const appleFloor = "26.4";

/** Whether `version` is `minimum` or newer: "6.4.1" is at least "6.4", "26.0" at least "26". */
export function atLeast(version: string, minimum: string): boolean {
    return compareVersions(version, minimum) >= 0;
}

/** The output of `command` run with `args` - its standard output and error together - or undefined where it did not run. */
function run(command: string, args: readonly string[]): Promise<string | undefined> {
    return new Promise((resolve) => {
        execFile(command, [...args], { timeout: 30_000, windowsHide: true }, (error, stdout, stderr) => {
            const text = `${stdout ?? ""}${stderr ?? ""}`;
            resolve(error && (error as NodeJS.ErrnoException).code === "ENOENT" ? undefined : error && !text ? undefined : text);
        });
    });
}

/** The LLDB DAP extension, which a Debug launch hands the head to, found among the debugger types the editor has. */
export function debuggerFinding(types: readonly string[]): Finding {
    return {
        component: "the LLDB DAP extension", neededBy: "Debug", found: types.includes("lldb-dap") ? "installed" : undefined,
        advice: "Install LLDB DAP (llvm-vs-code-extensions.lldb-dap) from the Extensions view.",
    };
}

/** Why an lldb-dap did not start, read from what it said to `--version` - the library its loader found missing - or
 *  undefined where it started. */
export function lldbDapFailure(output: string | undefined): string | undefined {
    if (output === undefined) {
        return "it did not run";
    }
    const missing = output.match(/error while loading shared libraries: ([^:\s]+)/);
    if (missing) {
        return `${missing[1]} is missing`;
    }
    return /LLVM version/.test(output) ? undefined : output.split(/\r?\n/)[0].trim();
}

/** The Python library `lldb-dap --check-python` printed as the one it resolved, or undefined where it found none. */
export function checkedPythonIn(output: string | undefined): string | undefined {
    return output?.split(/\r?\n/).map((line) => line.trim()).find((line) => /^[A-Za-z]:\\.*\.dll$/i.test(line));
}

/** On Linux and Windows, whether the lldb-dap a Debug launch starts - the one LLDB DAP's `lldb-dap.executable-path`
 *  names, else the search path's - starts with the Python its LLDB loads: on Linux the distribution's a swift.org
 *  toolchain was built for, which another may not have; on Windows the one the Swift installer lays beside the
 *  toolchain. Undefined on macOS, where Xcode's matches its system. */
export async function lldbDapFinding(configured?: string): Promise<Finding | undefined> {
    if (process.platform === "win32") {
        return windowsLldbDapFinding(configured || onPath("lldb-dap"));
    }
    if (process.platform !== "linux") {
        return undefined;
    }
    const executable = configured || onPath("lldb-dap");
    const output = executable ? await run(executable, ["--version"]) : undefined;
    const failure = executable ? lldbDapFailure(output) : "none is on the search path";
    return {
        component: "an lldb-dap that starts", neededBy: "Debug",
        found: failure === undefined ? `${output?.match(/LLVM version \S+/)?.[0] ?? "it starts"} (${executable})` : undefined,
        advice: `${executable ?? "lldb-dap"}: ${failure}. A swift.org toolchain's LLDB takes the Python library of the`
            + " distribution it was built for: install that library - libpython3.9 is python39 from the AUR on Arch - or"
            + " set lldb-dap.executable-path to an lldb-dap that starts.",
    };
}

/** Windows' lldb-dap asked which Python library it loads (`--check-python`): `--version` answers before it looks. */
async function windowsLldbDapFinding(executable: string | undefined): Promise<Finding> {
    const output = executable ? await run(executable, ["--check-python"]) : undefined;
    const python = checkedPythonIn(output);
    const failure = !executable ? "none is on the search path" : output?.split(/\r?\n/)[0].trim() || "it did not run";
    return {
        component: "an lldb-dap that starts", neededBy: "Debug",
        found: python && `its Python ${python} (${executable})`,
        advice: `${executable ?? "lldb-dap"}: ${failure}. A swift.org toolchain's LLDB loads the Python its installer lays`
            + " beside the toolchain (Programs\\Swift\\Python-<version>): repair the Swift installation, or set"
            + " lldb-dap.executable-path to an lldb-dap that starts.",
    };
}

/** The findings as the output shows them: a line each, found, too old or missing, and what to install for each not found. */
export function report(findings: readonly Finding[]): string[] {
    return findings.flatMap((each, index) => [
        // A heading wherever the machine changes - none while every finding is this machine's.
        ...(each.machine !== (index === 0 ? undefined : findings[index - 1].machine) ? [`${each.machine ?? "This machine"}:`] : []),
        each.found !== undefined
            ? `✓ ${each.component} - ${each.found} [${each.neededBy}]`
            : `✗ ${each.component} - ${each.tooOld !== undefined ? `${each.tooOld} found, too old` : "not found"} [${
                each.neededBy}]. ${each.advice}`,
    ]);
}

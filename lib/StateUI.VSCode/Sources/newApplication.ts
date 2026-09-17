// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A new application: in a checkout's apps/, by the checkout's own scaffolder,
// or in a directory of its own, written from the StateUIStarter template.
//
// THE TEMPLATE IS READ HERE, not handed to `dotnet new`: a release need not
// have published a template package, and one installed on this machine may be
// another release's. The template's own files are the one source - a
// checkout's, or the copy this extension carries - and what is written from
// them is what `dotnet new stateui-maui` writes, which the suite compares.

import { execFile } from "child_process";
import * as fs from "fs";
import * as path from "path";

/** Where the Swift and C# halves of StateUI come from. */
export type StarterSource =
    /** A checkout on disk, named by path in both halves. */
    | { readonly kind: "checkout"; readonly checkout: string }
    /** A release: the NuGet packages and the repository's tag of `version`. */
    | { readonly kind: "release"; readonly version: string };

/** What a new application is written from and where. */
export interface Starter {
    readonly name: string;
    /** The directory the application's own directory is made in. */
    readonly parent: string;
    readonly source: StarterSource;
    /** Adds the AppKit head, which needs a checkout. */
    readonly appKit: boolean;
}

/** The repository whose tags name the Swift half's releases. */
export const repository = "https://github.com/idexus/StateUI.git";

/** The NuGet package whose versions name the C# half's releases. */
const runtimePackage = "stateui.maui";

/** The token the template writes as the application's name. */
const token = "StateUIStarter";

/**
 * Why `name` cannot name an application, or undefined where it can. Letters
 * and digits, starting with a letter: the name becomes a C# namespace, a
 * Swift module, a process name and a directory, and the strictest wins.
 */
export function nameProblem(name: string): string | undefined {
    if (!/^[A-Za-z][A-Za-z0-9]*$/.test(name)) {
        return "Letters and digits only, starting with a letter.";
    }
    if (name === "StateUI") {
        return "StateUI is the library. Pick a name of the application's own.";
    }
    return undefined;
}

/** Whether `directory` is a StateUI checkout with apps/ and its scaffolder. */
export function isCheckout(directory: string): boolean {
    return fs.existsSync(path.join(directory, ".scripts", "new-app.sh"))
        && fs.existsSync(templateIn(directory).template);
}

/**
 * Why `directory` cannot be the checkout an application is built against, or
 * undefined where it can. Its directory is named StateUI: SwiftPM names a path
 * dependency after its last component, and the application's manifest asks
 * for the StateUI package by that name.
 */
export function checkoutProblem(directory: string): string | undefined {
    if (!fs.existsSync(templateIn(directory).template)) {
        return `${directory} is not a StateUI checkout: it has no lib/StateUI.Maui/Template.`;
    }
    if (path.basename(directory) !== "StateUI") {
        return `${directory} is not named StateUI - SwiftPM names a package on disk after its directory.`;
    }
    return undefined;
}

/** The template and the build it ships with, laid out as in a checkout. */
export function templateIn(root: string): { template: string; scripts: string } {
    return {
        template: path.join(root, "lib", "StateUI.Maui", "Template", "templates", token),
        scripts: path.join(root, ".scripts", "Maui"),
    };
}

/** Where this extension carries its copy of the template: `out/Template/`, laid out as in a checkout. */
export function carriedTemplate(extensionPath: string): string {
    return path.join(extensionPath, "out", "Template");
}

/** What a template directory holds that is never an application's. */
export const leftOut = new Set([".template.config", ".scripts", ".build", "bin", "obj", ".vs", ".sourcekit-lsp", ".DS_Store", "Package.resolved"]);

/** The command line that makes `name` in a checkout's apps/. */
export function inAppsCommand(checkout: string, name: string, platform: NodeJS.Platform = process.platform): { command: string; args: string[] } {
    return platform === "win32"
        ? { command: "powershell", args: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", path.join(checkout, ".scripts", "new-app.ps1"), "-Name", name] }
        : { command: "bash", args: [path.join(checkout, ".scripts", "new-app.sh"), name] };
}

/**
 * Writes the application `starter` describes from the template under
 * `templateRoot` - a checkout, or the copy this extension carries - and
 * answers its directory.
 */
export function writeStarter(starter: Starter, templateRoot: string): string {
    const { template, scripts } = templateIn(templateRoot);
    const destination = path.join(starter.parent, starter.name);
    if (fs.existsSync(destination)) {
        throw new Error(`${destination} already exists.`);
    }

    // Forward slashes on every platform: the path is written into a Swift
    // string literal, where a backslash is an escape.
    const checkout = starter.source.kind === "checkout" ? starter.source.checkout.split(path.sep).join("/") : "";
    const symbols: Record<string, boolean> = { AppKit: starter.appKit, UseCheckout: starter.source.kind === "checkout" };
    const pinned = starter.source.kind === "release" ? pinnedRelease(templateRoot) : undefined;

    const rename = (text: string): string => text
        .split(token).join(starter.name)
        .split(token.toLowerCase()).join(starter.name.toLowerCase())
        .split("STATEUI_CHECKOUT").join(checkout);

    const walk = (from: string, to: string): void => {
        for (const entry of fs.readdirSync(from).sort()) {
            const source = path.join(from, entry);
            const relative = path.relative(template, source).split(path.sep).join("/");
            if (leftOut.has(entry) || entry.endsWith(".user") || (!starter.appKit && relative === "Platforms/AppKit")) {
                continue;
            }

            const target = path.join(to, rename(entry));
            if (fs.statSync(source).isDirectory()) {
                fs.mkdirSync(target, { recursive: true });
                walk(source, target);
                continue;
            }

            const bytes = fs.readFileSync(source);
            if (bytes.includes(0)) {
                fs.copyFileSync(source, target);
                continue;
            }

            let text = rename(conditioned(bytes.toString("utf8"), symbols, relative));
            if (pinned && starter.source.kind === "release") {
                text = repinned(text, pinned, starter.source.version);
            }
            fs.writeFileSync(target, text);
            fs.chmodSync(target, fs.statSync(source).mode);
        }
    };

    fs.mkdirSync(destination, { recursive: true });
    walk(template, destination);

    // The build, byte for byte: nothing in it names the application.
    fs.cpSync(scripts, path.join(destination, ".scripts", "Maui"), { recursive: true });
    for (const found of listFiles(path.join(destination, ".scripts"))) {
        if (path.basename(found) === ".DS_Store") {
            fs.rmSync(found);
        }
    }

    return destination;
}

/**
 * `text` with the template's conditional blocks resolved: a line that is a
 * directive - `//#if (AppKit && !UseCheckout)`, `<!--#else -->` - is dropped,
 * and so is every line under a condition that does not hold.
 */
export function conditioned(text: string, symbols: Record<string, boolean>, file: string): string {
    const directive = /^\s*(?:\/\/|<!--)#(if|elseif|else|endif)\b\s*(?:\((.*)\))?\s*(?:-->)?\s*$/;
    // One frame per open block: whether its parent writes, whether a branch
    // has already been taken, and whether the current branch writes.
    const frames: { parent: boolean; taken: boolean; writing: boolean }[] = [];
    const writing = (): boolean => frames.length === 0 || frames[frames.length - 1].writing;

    const kept: string[] = [];
    for (const line of text.split("\n")) {
        const found = directive.exec(line.replace(/\r$/, ""));
        if (!found) {
            if (writing()) {
                kept.push(line);
            }
            continue;
        }

        const [, keyword, condition] = found;
        if (keyword === "if") {
            const parent = writing();
            const holds = evaluate(condition ?? "", symbols, file);
            frames.push({ parent, taken: holds, writing: parent && holds });
        } else {
            const frame = frames[frames.length - 1];
            if (!frame) {
                throw new Error(`${file}: #${keyword} with no #if.`);
            }
            if (keyword === "endif") {
                frames.pop();
            } else {
                const holds = keyword === "else" || evaluate(condition ?? "", symbols, file);
                frame.writing = frame.parent && !frame.taken && holds;
                frame.taken = frame.taken || holds;
            }
        }
    }
    if (frames.length > 0) {
        throw new Error(`${file}: an #if is never closed.`);
    }
    return kept.join("\n");
}

/** A condition of symbols joined by `&&`, `||` and `!`. */
function evaluate(condition: string, symbols: Record<string, boolean>, file: string): boolean {
    return condition.split("||").some((any) => any.split("&&").every((all) => {
        const term = all.trim();
        const negated = term.startsWith("!");
        const name = negated ? term.slice(1).trim() : term;
        if (!(name in symbols)) {
            throw new Error(`${file}: the condition names ${name}, which the template does not declare.`);
        }
        return symbols[name] !== negated;
    }));
}

/** The release the template under `templateRoot` pins: its Package.swift's `exact:`. */
export function pinnedRelease(templateRoot: string): string {
    const manifest = fs.readFileSync(path.join(templateIn(templateRoot).template, "Package.swift"), "utf8");
    const found = /exact: "([^"]+)"/.exec(manifest);
    if (!found) {
        throw new Error("the template's Package.swift pins no release.");
    }
    return found[1];
}

/** `text` naming `version` wherever the template pins its own release. */
function repinned(text: string, pinned: string, version: string): string {
    return text
        .split(`exact: "${pinned}"`).join(`exact: "${version}"`)
        .replace(/(<PackageReference Include="StateUI\.Maui(?:\.Linux)?" Version=")([^"]+)(")/g,
            (_whole, before: string, _old: string, after: string) => `${before}${version}${after}`);
}

function listFiles(directory: string): string[] {
    return fs.existsSync(directory)
        ? fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
            const full = path.join(directory, entry.name);
            return entry.isDirectory() ? listFiles(full) : [full];
        })
        : [];
}

/**
 * The releases an application can be made against, newest first: a version
 * of the StateUI.Maui package on NuGet that the repository also tags. Either
 * half missing leaves the release out - the other half would not resolve.
 */
export async function releases(): Promise<string[]> {
    const [published, tagged] = await Promise.all([nugetVersions(), repositoryTags()]);
    return published.filter((version) => tagged.has(version)).sort(compareVersions).reverse();
}

async function nugetVersions(): Promise<string[]> {
    const response = await fetch(`https://api.nuget.org/v3-flatcontainer/${runtimePackage}/index.json`);
    if (response.status === 404) {
        return [];
    }
    if (!response.ok) {
        throw new Error(`NuGet answered ${response.status} for ${runtimePackage}.`);
    }
    return ((await response.json()) as { versions: string[] }).versions;
}

function repositoryTags(): Promise<Set<string>> {
    return new Promise((resolve, reject) => execFile("git", ["ls-remote", "--tags", repository], (error, stdout) => {
        if (error) {
            reject(new Error(`git could not list the tags of ${repository}: ${error.message}`));
            return;
        }
        resolve(new Set(stdout.split("\n").flatMap((line) => {
            const found = /refs\/tags\/([^\^]+)$/.exec(line.trim());
            return found ? [found[1]] : [];
        })));
    }));
}

/** Orders `0.2.1` before `0.10.0`, and a pre-release before its release. */
export function compareVersions(a: string, b: string): number {
    const [coreA, preA] = a.split("-", 2);
    const [coreB, preB] = b.split("-", 2);
    const partsA = coreA.split(".").map(Number);
    const partsB = coreB.split(".").map(Number);
    for (let index = 0; index < Math.max(partsA.length, partsB.length); index++) {
        const difference = (partsA[index] ?? 0) - (partsB[index] ?? 0);
        if (difference !== 0) {
            return difference;
        }
    }
    if (preA === preB) {
        return 0;
    }
    return preA === undefined ? 1 : preB === undefined ? -1 : preA.localeCompare(preB);
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The applications the stateui tool finds in a folder (`project/describe`): the nearest application up from it, else
// the ones its workspace's stateui.json lists.

import * as fs from "fs";
import * as path from "path";
import * as vscode from "vscode";
import { pathToFileUri, ToolingClient, toolingErrorCode, ToolRequestError } from "./Tooling/client";
import { Project } from "./Tooling/protocol";
import { Host } from "./hosts";

/** One application, and the heads it has. */
export interface Application {
    /** The application's name - `Gallery` - which its products are named after. */
    readonly name: string;

    /** The directory holding its Package.swift. */
    readonly directory: string;

    /** The hosts it has a head for: `Platforms/<Host>/main.swift`, Android's `Platforms/Android/build.gradle.kts`. */
    readonly hosts: readonly Host[];

    /** The workspace listing it - the folder of its stateui.json - where one does. */
    readonly workspace?: string;

    /**
     * The StateUI checkout its Package.swift names by path - the library it
     * builds with, whose `.scripts` build and run its heads - where it names one.
     */
    readonly checkout?: string;
}

/** The folder a file URI of the tool's names, spelled as the editor spells its folders - `c:\…` on Windows. */
export function pathOf(uri: string): string {
    return vscode.Uri.parse(uri).fsPath;
}

/** The applications of `project`, as the tool described them. */
export function applicationsOf(project: Project): Application[] {
    const workspace = project.workspaceUri && pathOf(project.workspaceUri);
    return project.applications.map((each) => {
        const directory = pathOf(each.packageUri);
        const checkout = each.libraryUri && pathOf(each.libraryUri);
        return {
            name: each.name, directory, hosts: each.declaredHosts,
            workspace, checkout,
        };
    });
}

/** The applications in or above `folder` - or its workspace's - by `client`; none where the tool finds none. */
export async function readApplications(client: ToolingClient, folder?: string): Promise<Project | undefined> {
    try {
        return await client.request("project/describe", folder ? { projectUri: pathToFileUri(folder) } : {});
    } catch (error) {
        if (error instanceof ToolRequestError && error.code === toolingErrorCode && error.tooling?.code === "PROJECT_NOT_FOUND") {
            return undefined;
        }
        throw error;
    }
}

/** Whether `application` has a head for `host`. */
export function hasHead(application: Application, host: Host): boolean {
    return application.hosts.includes(host);
}

/** Where an application's GTK head is, once `.scripts/GTK/run-app.sh` built it in `configuration`. */
export function gtkProgram(application: Application, configuration: "debug" | "release"): string {
    return path.join(application.directory, ".build", "gtk", configuration, `${application.name}GTK`);
}

/** Where an application's Web page is laid out, once `.scripts/Web/run-app.sh` built it in `configuration`. */
export function webSite(application: Application, configuration: "debug" | "release"): string {
    return path.join(application.directory, ".build", "web", "site", configuration);
}

/**
 * Where an application's WinUI head is, once `.scripts/WinUI/run-app.ps1` built it in `configuration`: where that build
 * says it laid it - `.build/winui/<configuration>` is a link the last build of any architecture moved - else there.
 */
export function winUIProgram(application: Application, configuration: "debug" | "release"): string {
    const build = path.join(application.directory, ".build", "winui");
    const said = path.join(build, `${configuration}.program`);
    return fs.existsSync(said) ? fs.readFileSync(said, "utf8").trim() : path.join(build, configuration, `${application.name}WinUI.exe`);
}

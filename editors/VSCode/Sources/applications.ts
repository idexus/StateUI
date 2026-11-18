// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The applications the stateui tool finds in a folder (`project/describe`): the nearest application up from it, else
// the ones its workspace's stateui-workspace.json lists.

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

    /** The workspace listing it - the folder of its stateui-workspace.json - where one does. */
    readonly workspace?: string;

    /**
     * The StateUI checkout its Package.swift names by path - the library it
     * builds with - where it names one.
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
/**
 * The folder of `folders` that `directory` stands in - the deepest where several hold it - else the first: the folder
 * a window's hosts and machines are read for, an application's project.
 */
export function folderHolding(directory: string | undefined, folders: readonly string[]): string | undefined {
    const holding = directory === undefined ? [] : folders.filter((folder) => {
        const inside = path.relative(folder, directory);
        return inside === "" || (!inside.startsWith("..") && !path.isAbsolute(inside));
    });
    return holding.sort((a, b) => b.length - a.length)[0] ?? folders[0];
}

export function hasHead(application: Application, host: Host): boolean {
    return application.hosts.includes(host);
}

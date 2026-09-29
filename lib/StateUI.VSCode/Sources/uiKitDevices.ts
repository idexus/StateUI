// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a UIKit head runs: the iPhones and iPads paired with this Mac, and the iOS simulators - what `xcrun
// devicectl list devices` and `xcrun simctl list` list, on the iOS a head installs on - and the one chosen for the
// workspace. .scripts/UIKit/run-app.sh boots a simulator, and signs for a device.

import { execFile } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import * as vscode from "vscode";

/** An iPhone or an iPad a UIKit head can run on, a real one or a simulator. */
export interface UIKitDevice {
    /** A device's identifier, as devicectl gives it; a simulator's UDID. */
    readonly id: string;
    readonly name: string;
    readonly kind: "device" | "simulator";

    /** Its iOS, as its version: `27.0`. */
    readonly os: string;

    /** How it is reached - `USB`, `Wi-Fi` - or, for a simulator, whether it is booted. */
    readonly state: string;
}

/** The device chosen for a workspace. */
export type ChosenUIKitDevice = Pick<UIKitDevice, "id" | "name">;

const chosenKey = "stateui.uiKitDevice";

/** The oldest iOS a head installs on - the deployment target .scripts/UIKit/tools.sh builds for. */
export const oldestIOS = 26;

/** One of the scripts in `root`/.scripts/UIKit, which build and run the UIKit host. */
export function uiKitScript(root: string, script: "run-app.sh" | "test-uikit.sh"): string {
    return path.join(root, ".scripts", "UIKit", script);
}

function supported(version: string | undefined): boolean {
    return Number(version?.split(".")[0] ?? 0) >= oldestIOS;
}

/**
 * What `xcrun devicectl list devices --json-output` wrote as `json`: the real iPhones and iPads paired with this Mac,
 * of an iOS a head installs on, in the order listed.
 */
export function parseDevices(json: string): UIKitDevice[] {
    type Listed = {
        identifier: string;
        connectionProperties?: { pairingState?: string; transportType?: string };
        deviceProperties?: { name?: string; osVersionNumber?: string };
        hardwareProperties?: { platform?: string; reality?: string };
    };
    let listed: { result?: { devices?: Listed[] } };
    try {
        listed = JSON.parse(json);
    } catch {
        return [];
    }
    const transports: Record<string, string> = { wired: "USB", localNetwork: "Wi-Fi" };
    return (listed.result?.devices ?? []).flatMap((device): UIKitDevice[] => {
        const hardware = device.hardwareProperties ?? {};
        const properties = device.deviceProperties ?? {};
        const connection = device.connectionProperties ?? {};
        if (hardware.reality !== "physical" || hardware.platform !== "iOS" || connection.pairingState !== "paired"
            || !supported(properties.osVersionNumber)) {
            return [];
        }
        return [{
            id: device.identifier, name: properties.name ?? device.identifier, kind: "device",
            os: properties.osVersionNumber ?? "", state: transports[connection.transportType ?? ""] ?? connection.transportType ?? "",
        }];
    });
}

/**
 * What `xcrun simctl list devices available -j` printed as `json`: the iPhones and iPads of the iOS runtimes a head
 * installs on, the newest runtime first, each runtime's in the order listed.
 */
export function parseSimulators(json: string): UIKitDevice[] {
    let listed: { devices?: Record<string, { udid: string; name: string; state: string }[]> };
    try {
        listed = JSON.parse(json);
    } catch {
        return [];
    }

    const runtimes = Object.entries(listed.devices ?? {}).flatMap(([runtime, devices]) => {
        const version = runtime.match(/\.iOS-(\d+)-(\d+)$/);
        return version && supported(version[1]) ? [{ version: `${version[1]}.${version[2]}`, devices }] : [];
    });
    const newestFirst = runtimes.sort((a, b) => b.version.localeCompare(a.version, undefined, { numeric: true }));
    return newestFirst.flatMap(({ version, devices }) => devices.map((device): UIKitDevice => ({
        id: device.udid, name: device.name, kind: "simulator", os: version, state: device.state === "Booted" ? "booted" : "",
    })));
}

/** The device chosen for the workspace, where one is. */
export function chosenUIKitDevice(state: vscode.Memento): ChosenUIKitDevice | undefined {
    return state.get<ChosenUIKitDevice>(chosenKey);
}

/** Chooses `device` for the workspace. */
export async function chooseUIKitDevice(state: vscode.Memento, device: ChosenUIKitDevice): Promise<void> {
    await state.update(chosenKey, { id: device.id, name: device.name } satisfies ChosenUIKitDevice);
}

/**
 * The device a launch or a suite runs on: the one chosen, while it is still listed, else asked for - or nothing,
 * where none is picked.
 */
export async function uiKitDeviceToRunOn(state: vscode.Memento): Promise<string | undefined> {
    const listed = await listUIKitDevices();
    const chosen = chosenUIKitDevice(state);

    if (chosen && listed?.some((each) => each.id === chosen.id)) {
        return chosen.id;
    }
    return listed ? askForUIKitDevice(state, listed) : undefined;
}

/**
 * Chooses the device `wanted` names - its id, or its name - as it is listed, so what the status bar says is its
 * name; answers that name, or nothing where none is listed so.
 */
export async function chooseListedUIKitDevice(state: vscode.Memento, wanted: string): Promise<string | undefined> {
    const found = (await listUIKitDevices())?.find((each) => each.id === wanted || each.name === wanted);
    if (found) {
        await chooseUIKitDevice(state, found);
    }
    return found?.name;
}

/** Asks for a device among the iPhones and iPads paired and the simulators, remembers it, and answers its id. */
export async function askForUIKitDevice(state: vscode.Memento, listed?: UIKitDevice[]): Promise<string | undefined> {
    listed ??= await listUIKitDevices();
    if (!listed) {
        return undefined;
    }
    if (listed.length === 0) {
        void vscode.window.showErrorMessage(
            `StateUI: no iPhone or iPad of iOS ${oldestIOS} or later is paired, and no simulator of it is available - connect a device, or add a simulator in Xcode's Devices and Simulators.`);
        return undefined;
    }

    const current = chosenUIKitDevice(state)?.id;
    type Item = vscode.QuickPickItem & { device?: UIKitDevice };
    const entry = (device: UIKitDevice): Item => ({
        label: `$(${device.name.startsWith("iPad") ? "device-tablet" : "device-mobile"}) ${device.name}`,
        description: [`iOS ${device.os}`, device.state || undefined, device.id === current ? "current" : undefined]
            .filter(Boolean).join(" · "),
        device,
    });
    const devices = listed.filter((each) => each.kind === "device");
    const simulators = listed.filter((each) => each.kind === "simulator");
    const items: Item[] = [
        ...(devices.length > 0 ? [{ label: "Devices", kind: vscode.QuickPickItemKind.Separator }] : []),
        ...devices.map(entry),
        ...(simulators.length > 0 ? [{ label: "Simulators", kind: vscode.QuickPickItemKind.Separator }] : []),
        ...simulators.map(entry),
    ];

    const device = (await vscode.window.showQuickPick(items,
        { placeHolder: "Which iPhone or iPad do StateUI: Debug, StateUI: Release and StateUI: Run Tests run on?", ignoreFocusOut: true }))?.device;
    if (!device) {
        return undefined;
    }

    await chooseUIKitDevice(state, device);
    return device.id;
}

/** The devices paired and the simulators available, or nothing, said, where neither could be listed. */
async function listUIKitDevices(): Promise<UIKitDevice[] | undefined> {
    const run = (args: string[]): Promise<{ failed: boolean; stdout: string; output: string }> => new Promise((resolve) =>
        execFile("xcrun", args, { maxBuffer: 16 * 1024 * 1024 },
            (error, out, err) => resolve({ failed: error !== null, stdout: out, output: `${out}${err}` })));

    const answer = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "stateui-devices-")), "devices.json");
    const [paired, available] = await Promise.all([
        run(["devicectl", "list", "devices", "--json-output", answer]),
        run(["simctl", "list", "devices", "available", "-j"]),
    ]);
    const devices = !paired.failed && fs.existsSync(answer) ? parseDevices(fs.readFileSync(answer, "utf8")) : [];
    fs.rmSync(path.dirname(answer), { recursive: true, force: true });
    if (available.failed && paired.failed) {
        void vscode.window.showErrorMessage(`StateUI: the iPhones, iPads and simulators could not be listed - ${available.output.trim()}`);
        return undefined;
    }
    return [...devices, ...parseSimulators(available.stdout)];
}

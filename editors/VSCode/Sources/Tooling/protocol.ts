// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The stateui tool's API as the extension reads it: each message type the Swift tool declares
// (tools/StateUI.CLI, StateUIToolingProtocol), written again here by hand and held to the tool's recorded examples
// (tools/StateUI.CLI/exports/protocol) by the protocol tests.

import { array, boolean, Decoder, DecodingError, dictionary, json, number, object, oneOf, optional, string } from "./decoding";

export interface ToolIdentity { name: string; version: string }
export const ToolIdentity = object<ToolIdentity>({ name: string, version: string });

export interface APIVersionRange { major: number; minMinor: number; maxMinor: number }
export const APIVersionRange = object<APIVersionRange>({ major: number, minMinor: number, maxMinor: number });

export interface Machine { system: string; architecture: string }
export const Machine = object<Machine>({ system: string, architecture: string });


export interface InitializeParameters { apiVersions: APIVersionRange[]; client: ToolIdentity; workspaceUri: string }
export const InitializeParameters = object<InitializeParameters>({
    apiVersions: array(APIVersionRange), client: ToolIdentity, workspaceUri: string,
});

export interface ServerCapabilities { methods: string[]; notifications: string[] }
export interface ConnectionLimits { maxFrameBytes: number; maxEventChunkBytes: number }
export interface InitializeResult {
    apiVersion: string;
    serverInstanceId: string;
    server: ToolIdentity;
    workspace: { uri: string };
    capabilities: ServerCapabilities;
    limits: ConnectionLimits;
}
export const InitializeResult = object<InitializeResult>({
    apiVersion: string,
    serverInstanceId: string,
    server: ToolIdentity,
    workspace: object<{ uri: string }>({ uri: string }),
    capabilities: object<ServerCapabilities>({ methods: array(string), notifications: array(string) }),
    limits: object<ConnectionLimits>({ maxFrameBytes: number, maxEventChunkBytes: number }),
});

export interface ToolingError { code: string; message: string; retryable: boolean }
export const ToolingError = object<ToolingError>({ code: string, message: string, retryable: boolean });

export interface RPCError { code: number; message: string; data?: ToolingError }
export const RPCError = object<RPCError>({ code: number, message: string, data: optional(ToolingError) });

export type NoParameters = Record<string, never>;
export const NoParameters: Decoder<NoParameters> = object<NoParameters>({});

export type OperationState = "queued" | "running" | "cancelling" | "succeeded" | "failed" | "cancelled" | "interrupted";
export const OperationState = oneOf<OperationState>(
    "queued", "running", "cancelling", "succeeded", "failed", "cancelled", "interrupted");
export const terminalStates: ReadonlySet<OperationState> = new Set(["succeeded", "failed", "cancelled", "interrupted"]);

export interface OperationHandle { operationId: string; state: OperationState }
export const OperationHandle = object<OperationHandle>({ operationId: string, state: OperationState });

export interface OperationReference { operationId: string }
export const OperationReference = object<OperationReference>({ operationId: string });

export interface CancelResult { accepted: boolean; state: OperationState }
export const CancelResult = object<CancelResult>({ accepted: boolean, state: OperationState });

export interface OperationProgress { stage: string; message?: string; completed?: number; total?: number }
const progressFields = { stage: string, message: optional(string), completed: optional(number), total: optional(number) };
export const OperationProgress = object<OperationProgress>(progressFields);

export interface OperationSnapshot {
    id: string;
    kind: string;
    requestToken: string;
    state: OperationState;
    createdAt: string;
    startedAt?: string;
    finishedAt?: string;
    lastSequence: number;
    progress?: OperationProgress;
    result?: unknown;
    failure?: ToolingError;
}
export const OperationSnapshot = object<OperationSnapshot>({
    id: string, kind: string, requestToken: string, state: OperationState, createdAt: string,
    startedAt: optional(string), finishedAt: optional(string), lastSequence: number,
    progress: optional(OperationProgress), result: optional(json), failure: optional(ToolingError),
});

export type StandardStream = "stdout" | "stderr";
export interface OutputChunk { stream: StandardStream; encoding: "utf8" | "base64"; data: string; cursor: string }
export interface OutputGap { stream: StandardStream; fromCursor: string; toCursor: string; replayAvailable: boolean }

export type OperationEventBody =
    | { kind: "state"; state: OperationState }
    | ({ kind: "progress" } & OperationProgress)
    | ({ kind: "output" } & OutputChunk)
    | ({ kind: "outputGap" } & OutputGap)
    | { kind: "started"; application: LaunchedApplication };

const stream = oneOf<StandardStream>("stdout", "stderr");
const eventBodies: Record<OperationEventBody["kind"], Decoder<OperationEventBody>> = {
    state: object({ kind: oneOf("state"), state: OperationState }),
    progress: object({ kind: oneOf("progress"), ...progressFields }),
    output: object({ kind: oneOf("output"), stream, encoding: oneOf("utf8", "base64"), data: string, cursor: string }),
    outputGap: object({ kind: oneOf("outputGap"), stream, fromCursor: string, toCursor: string, replayAvailable: boolean }),
    // Read when an event comes: the run's types stand below.
    started: (value, path) => object({ kind: oneOf("started"), application: LaunchedApplication })(value, path),
};
/** An event by its `kind`; a kind the extension does not know is an error its caller may pass over. */
export const OperationEventBody: Decoder<OperationEventBody> = (value, path) => {
    const kind = (value as { kind?: unknown } | null)?.kind;
    const decoder = typeof kind === "string" ? eventBodies[kind as OperationEventBody["kind"]] : undefined;
    if (!decoder) {
        throw new DecodingError(`${path}/kind`, `no event kind ${String(kind)}`);
    }
    return decoder(value, path);
};

export interface OperationEvent { operationId: string; sequence: number; timestamp: string; event: OperationEventBody }
export const OperationEvent = object<OperationEvent>({
    operationId: string, sequence: number, timestamp: string, event: OperationEventBody,
});

export type HostFamily = "appkit" | "uikit" | "android" | "winui" | "gtk" | "web";
export const HostFamily = oneOf<HostFamily>("appkit", "uikit", "android", "winui", "gtk", "web");

export type Place = "machine" | "device" | "browser" | "guest";
export const Place = oneOf<Place>("machine", "device", "browser", "guest");

export interface HostPlace { host: HostFamily; place: Place }
export const HostPlace = object<HostPlace>({ host: HostFamily, place: Place });

export interface ServerInfo { server: ToolIdentity; apiVersions: APIVersionRange[]; machine: Machine; hosts: HostPlace[] }
export const ServerInfo = object<ServerInfo>({
    server: ToolIdentity, apiVersions: array(APIVersionRange), machine: Machine, hosts: array(HostPlace),
});

export interface Application {
    id: string;
    name: string;
    identifier: string;
    displayName: string;
    version: string;
    build: number;
    packageUri: string;
    declaredHosts: HostFamily[];
    products: string[];
    testSuites: string[];
    libraryUri?: string;
}
export const Application = object<Application>({
    id: string, name: string, identifier: string, displayName: string, version: string, build: number, packageUri: string,
    declaredHosts: array(HostFamily), products: array(string), testSuites: array(string), libraryUri: optional(string),
});

export interface Library { rootUri: string; release?: string; revision?: string; dirty?: boolean }
export const Library = object<Library>({
    rootUri: string, release: optional(string), revision: optional(string), dirty: optional(boolean),
});

export interface Project {
    rootUri: string; applications: Application[]; libraries: Library[]; workspaceUri?: string; startupUri?: string;
}
export const Project = object<Project>({
    rootUri: string, applications: array(Application), libraries: array(Library), workspaceUri: optional(string),
    startupUri: optional(string),
});

export interface ProjectReference { projectUri?: string }
export const ProjectReference = object<ProjectReference>({ projectUri: optional(string) });

export interface ApplicationRequest {
    name: string; identifier?: string; platforms?: HostFamily[]; parentUri: string; checkoutUri?: string;
}
export const ApplicationRequest = object<ApplicationRequest>({
    name: string, identifier: optional(string), platforms: optional(array(HostFamily)), parentUri: string,
    checkoutUri: optional(string),
});

export interface FolderMirrorRequest { sourcePath: string; targetPath: string; files?: string[] }
export const FolderMirrorRequest = object<FolderMirrorRequest>({
    sourcePath: string, targetPath: string, files: optional(array(string)),
});
export interface FolderMirrorResult { copied: number; removed: number; unchanged: number }
export const FolderMirrorResult = object<FolderMirrorResult>({ copied: number, removed: number, unchanged: number });

export type Architecture = "arm64" | "x86_64" | "armv7" | "x86" | "wasm32";
export const Architecture = oneOf<Architecture>("arm64", "x86_64", "armv7", "x86", "wasm32");

export type BuildConfiguration = "debug" | "release";
export const BuildConfiguration = oneOf<BuildConfiguration>("debug", "release");

export type DestinationKind = "machine" | "device" | "simulator" | "emulator" | "browser" | "guest";
export const DestinationKind = oneOf<DestinationKind>("machine", "device", "simulator", "emulator", "browser", "guest");

export interface Destination {
    id: string;
    udid: string;
    name: string;
    kind: DestinationKind;
    version: string;
    booted: boolean;
    connection?: string;
    architecture?: Architecture;
    emulated: Architecture[];
    debugger: boolean;
    programUri?: string;
}
export const Destination = object<Destination>({
    id: string, udid: string, name: string, kind: DestinationKind, version: string, booted: boolean,
    connection: optional(string), architecture: optional(Architecture), emulated: array(Architecture), debugger: boolean,
    programUri: optional(string),
});

export interface DestinationQuery { host: HostFamily }
export const DestinationQuery = object<DestinationQuery>({ host: HostFamily });

export interface DestinationList { host: HostFamily; destinations: Destination[] }
export const DestinationList = object<DestinationList>({ host: HostFamily, destinations: array(Destination) });

export interface BuildRequest {
    projectUri?: string;
    application?: string;
    host?: HostFamily;
    configuration?: BuildConfiguration;
    architecture?: Architecture;
    device?: string;
    outputUri?: string;
}
export const BuildRequest = object<BuildRequest>({
    projectUri: optional(string), application: optional(string), host: optional(HostFamily), configuration: optional(BuildConfiguration),
    architecture: optional(Architecture), device: optional(string), outputUri: optional(string),
});

export interface BuildResult {
    application: string;
    host: HostFamily;
    configuration: BuildConfiguration;
    architecture: Architecture;
    folderUri: string;
    programUri: string;
    bundleUri?: string;
    destination?: Destination;
    identifier?: string;
    symbolsUri?: string;
}
export const BuildResult = object<BuildResult>({
    application: string, host: HostFamily, configuration: BuildConfiguration, architecture: Architecture, folderUri: string,
    programUri: string, bundleUri: optional(string), destination: optional(Destination), identifier: optional(string),
    symbolsUri: optional(string),
});

export interface RunRequest { build: BuildRequest; debugger: boolean; port?: number; lan?: boolean }
export const RunRequest = object<RunRequest>({ build: BuildRequest, debugger: boolean, port: optional(number), lan: optional(boolean) });

export interface LaunchedApplication { build: BuildResult; process?: number; held: boolean; debuggerSocket?: string; url?: string }
export const LaunchedApplication = object<LaunchedApplication>({
    build: BuildResult, process: optional(number), held: boolean, debuggerSocket: optional(string), url: optional(string),
});

export interface RunResult { launched: LaunchedApplication; exitStatus?: number }
export const RunResult = object<RunResult>({ launched: LaunchedApplication, exitStatus: optional(number) });

export interface InstallRequest { artifactUri: string }
export const InstallRequest = object<InstallRequest>({ artifactUri: string });

export interface InstallResult { artifactUri: string; writtenUris: string[] }
export const InstallResult = object<InstallResult>({ artifactUri: string, writtenUris: array(string) });

export type NameKind = "application" | "workspace";
export const NameKind = oneOf<NameKind>("application", "workspace");

export interface NameCheck { kind: NameKind; name: string; parentUri?: string }
export const NameCheck = object<NameCheck>({ kind: NameKind, name: string, parentUri: optional(string) });

export interface NameVerdict { problem?: string }
export const NameVerdict = object<NameVerdict>({ problem: optional(string) });

export interface ProjectCreation { project: Project; createdUris: string[] }
export const ProjectCreation = object<ProjectCreation>({ project: Project, createdUris: array(string) });

export interface ToolFinding {
    component: string;
    neededBy: string;
    hosts: HostFamily[];
    found?: string;
    tooOld?: string;
    advice: string;
    machine?: string;
}
export const ToolFinding = object<ToolFinding>({
    component: string, neededBy: string, hosts: array(HostFamily), found: optional(string), tooOld: optional(string),
    advice: string, machine: optional(string),
});

export interface ToolchainQuery { host?: HostFamily; device?: string; projectUri?: string }
export const ToolchainQuery = object<ToolchainQuery>({ host: optional(HostFamily), device: optional(string), projectUri: optional(string) });

export interface ToolchainReport { findings: ToolFinding[] }
export const ToolchainReport = object<ToolchainReport>({ findings: array(ToolFinding) });

export interface ReleaseQuery { minimum?: string; repository?: string }
export const ReleaseQuery = object<ReleaseQuery>({ minimum: optional(string), repository: optional(string) });

export interface ReleaseList { repository: string; releases: string[] }
export const ReleaseList = object<ReleaseList>({ repository: string, releases: array(string) });

export interface WorkspaceRequest {
    name: string;
    parentUri: string;
    checkoutUri?: string;
    release?: string;
    repository?: string;
    application?: string;
}
export const WorkspaceRequest = object<WorkspaceRequest>({
    name: string, parentUri: string, checkoutUri: optional(string), release: optional(string),
    repository: optional(string), application: optional(string),
});

export interface LibraryRequest { projectUri?: string; checkoutUri?: string; release?: string; repository?: string }
export const LibraryRequest = object<LibraryRequest>({
    projectUri: optional(string), checkoutUri: optional(string), release: optional(string), repository: optional(string),
});

export interface SettingsRequest { projectUri?: string; application?: string }
export const SettingsRequest = object<SettingsRequest>({ projectUri: optional(string), application: optional(string) });

export interface SettingsChange {
    projectUri?: string; application?: string; startup?: string; host?: HostFamily; devices?: Record<string, string>;
}
export const SettingsChange = object<SettingsChange>({
    projectUri: optional(string), application: optional(string), startup: optional(string), host: optional(HostFamily),
    devices: optional(dictionary(string)),
});

export interface Settings {
    workspaceUri?: string; startup?: string; applicationUri?: string; host?: HostFamily; devices: Record<string, string>;
}
export const Settings = object<Settings>({
    workspaceUri: optional(string), startup: optional(string), applicationUri: optional(string), host: optional(HostFamily),
    devices: dictionary(string),
});

export interface LibraryChange { projectUri: string; library: string; changedUris: string[] }
export const LibraryChange = object<LibraryChange>({ projectUri: string, library: string, changedUris: array(string) });

export interface WorkspaceChange { workspaceUri: string; library: string; changedUris: string[] }
export const WorkspaceChange = object<WorkspaceChange>({ workspaceUri: string, library: string, changedUris: array(string) });

/** A method answered at once: its parameters and its result. */
export interface Query<P, R> { readonly kind: "query"; readonly params: Decoder<P>; readonly result: Decoder<R> }
/** A method starting an operation: its parameters, beside a request token, and the operation's result. */
export interface Mutation<P, R> { readonly kind: "mutation"; readonly params: Decoder<P>; readonly result: Decoder<R> }

const query = <P, R>(params: Decoder<P>, result: Decoder<R>): Query<P, R> => ({ kind: "query", params, result });
const mutation = <P, R>(params: Decoder<P>, result: Decoder<R>): Mutation<P, R> => ({ kind: "mutation", params, result });

export interface IndexQuery { host?: HostFamily; rootUris?: string[] }
export const IndexQuery = object<IndexQuery>({ host: optional(HostFamily), rootUris: optional(array(string)) });

export interface IndexContext {
    host?: HostFamily;
    trait?: string;
    scratchPath: string;
    triple?: string;
    sdk?: string;
    swiftSDK?: string;
    fallback?: string;
}
export const IndexContext = object<IndexContext>({
    host: optional(HostFamily), trait: optional(string), scratchPath: string, triple: optional(string), sdk: optional(string),
    swiftSDK: optional(string), fallback: optional(string),
});

export interface IndexConflict { rootUri: string; host?: HostFamily }
export const IndexConflict = object<IndexConflict>({ rootUri: string, host: optional(HostFamily) });

export interface IndexLease { host?: HostFamily; rootUris: string[]; conflict?: IndexConflict }
export const IndexLease = object<IndexLease>({ host: optional(HostFamily), rootUris: array(string), conflict: optional(IndexConflict) });

export interface IndexCleaning { removedUris: string[]; conflicts?: IndexConflict[] }
export const IndexCleaning = object<IndexCleaning>({ removedUris: array(string), conflicts: optional(array(IndexConflict)) });

export interface TestDiscoveryQuery { host?: HostFamily; folderUri?: string }
export const TestDiscoveryQuery = object<TestDiscoveryQuery>({ host: optional(HostFamily), folderUri: optional(string) });

export type TestSuiteKind = "package" | "host";
export interface TestSuiteDescription {
    id: string;
    detail: string;
    kind: TestSuiteKind;
    packageUri: string;
    host?: HostFamily;
    onDevice: boolean;
}
export const TestSuiteDescription = object<TestSuiteDescription>({
    id: string, detail: string, kind: oneOf<TestSuiteKind>("package", "host"), packageUri: string, host: optional(HostFamily),
    onDevice: boolean,
});

export interface TestSuiteList { host?: HostFamily; suites: TestSuiteDescription[] }
export const TestSuiteList = object<TestSuiteList>({ host: optional(HostFamily), suites: array(TestSuiteDescription) });

export interface TestRunRequest { suite: string; host?: HostFamily; device?: string; folderUri?: string; filter?: string }
export const TestRunRequest = object<TestRunRequest>({
    suite: string, host: optional(HostFamily), device: optional(string), folderUri: optional(string), filter: optional(string),
});

export interface SuitePhase { name: string; passed: boolean }
export interface SuiteResult { suite: string; phases: SuitePhase[]; artifactUri?: string }
export const SuiteResult = object<SuiteResult>({
    suite: string, phases: array(object<SuitePhase>({ name: string, passed: boolean })), artifactUri: optional(string),
});

/** Which families a conformance run takes, whole: the stale ones, the ones named, or every one. */
export type ConformanceSelection = { changed: true } | { families: string[] } | { all: true };
export const ConformanceSelection: Decoder<ConformanceSelection> = (value, path) => {
    const read = object<{ changed?: boolean; families?: string[]; all?: boolean }>({
        changed: optional(boolean), families: optional(array(string)), all: optional(boolean),
    })(value, path);
    if (read.families) {
        return { families: read.families };
    } else if (read.all) {
        return { all: true };
    } else if (read.changed) {
        return { changed: true };
    }
    throw new DecodingError(path, "a selection is changed, families or all");
};

export interface ConformanceRequest { host: HostFamily; selection: ConformanceSelection; record: boolean; device?: string }
export const ConformanceRequest = object<ConformanceRequest>({
    host: HostFamily, selection: ConformanceSelection, record: boolean, device: optional(string),
});

export type Editor = "vscode";
export const Editor = oneOf<Editor>("vscode");

export interface IntegrationPackageRequest { editor: Editor }
export const IntegrationPackageRequest = object<IntegrationPackageRequest>({ editor: Editor });

export interface EditorExtension { artifactUri: string; extensionId: string; version: string }
export const EditorExtension = object<EditorExtension>({ artifactUri: string, extensionId: string, version: string });

export interface IntegrationInstallRequest { editorExtension: EditorExtension; editorExecutableUri: string }
export const IntegrationInstallRequest = object<IntegrationInstallRequest>({ editorExtension: EditorExtension, editorExecutableUri: string });

/** The tool's methods the extension calls, by name. */
export const methods = {
    "server/info": query(NoParameters, ServerInfo),
    "project/describe": query(ProjectReference, Project),
    "settings/get": query(SettingsRequest, Settings),
    "toolchain/check": query(ToolchainQuery, ToolchainReport),
    "name/check": query(NameCheck, NameVerdict),
    "devices/list": query(DestinationQuery, DestinationList),
    "index/describe": query(IndexQuery, IndexContext),
    "index/clean": query(IndexQuery, IndexCleaning),
    "index/acquire": query(IndexQuery, IndexLease),
    "tests/discover": query(TestDiscoveryQuery, TestSuiteList),
    "releases/list": query(ReleaseQuery, ReleaseList),
    "operation/get": query(OperationReference, OperationSnapshot),
    "operation/cancel": query(OperationReference, CancelResult),
    "project/create": mutation(ApplicationRequest, ProjectCreation),
    "folder/mirror": mutation(FolderMirrorRequest, FolderMirrorResult),
    "application/build": mutation(BuildRequest, BuildResult),
    "application/package": mutation(BuildRequest, BuildResult),
    "application/run": mutation(RunRequest, RunResult),
    "application/install": mutation(InstallRequest, InstallResult),
    "workspace/create": mutation(WorkspaceRequest, WorkspaceChange),
    "project/useLibrary": mutation(LibraryRequest, LibraryChange),
    "settings/set": mutation(SettingsChange, Settings),
    "tests/run": mutation(TestRunRequest, SuiteResult),
    "repository/conformance": mutation(ConformanceRequest, SuiteResult),
    "repository/integrationPackage": mutation(IntegrationPackageRequest, EditorExtension),
    "repository/integrationInstall": mutation(IntegrationInstallRequest, EditorExtension),
};

export type Methods = typeof methods;
export type QueryName = { [K in keyof Methods]: Methods[K] extends Query<unknown, unknown> ? K : never }[keyof Methods];
export type MutationName = { [K in keyof Methods]: Methods[K] extends Mutation<unknown, unknown> ? K : never }[keyof Methods];
export type ParamsOf<K extends keyof Methods> = Methods[K] extends Query<infer P, unknown> | Mutation<infer P, unknown> ? P : never;
export type ResultOf<K extends keyof Methods> = Methods[K] extends Query<unknown, infer R> | Mutation<unknown, infer R> ? R : never;

/** The API versions the extension speaks. */
export const apiVersions: APIVersionRange[] = [{ major: 1, minMinor: 0, maxMinor: 0 }];

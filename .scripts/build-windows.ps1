# Copyright 2026 the StateUI project authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ---------------------------------------------------------------------------
# Builds the StateUI native library for Windows.
#
# REQUIREMENTS:
#   - Swift toolchain for Windows (https://www.swift.org/install/windows/)
#   - Visual Studio Build Tools (Swift links through the MSVC linker)
#
# USAGE:
#   .\build-windows.cmd                          release, host architecture
#   .\build-windows.cmd -Config debug
#   .\build-windows.cmd -Config debug -Arch x64
#   .\build-windows.cmd -OutDir <path>           where to place the output
#
# Pure ASCII on purpose: Windows PowerShell 5.1 reads BOM-less .ps1 files as
# ANSI, which corrupts non-ASCII characters and can break string parsing.
# ---------------------------------------------------------------------------
param(
    [ValidateSet("debug", "release")]
    [string]$Config = $(if ($env:SWIFT_CONFIG) { $env:SWIFT_CONFIG } else { "release" }),

    # A native library is not portable across architectures: loading an ARM64
    # DLL into an x64 process (or the reverse) fails with BadImageFormatException,
    # reported as "the DLL format is invalid" - an error that points at the file
    # rather than at the mismatch.
    [ValidateSet("x64", "arm64")]
    [string]$Arch = $(if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64" }),

    # Which debugger is meant to read this library. Both formats work; they are
    # read by different tools, and NEITHER tool reads the other's.
    #
    #   dwarf     -> LLDB, and so VS Code through lldb-dap. THE DEFAULT.
    #                Needs lld-link, which is why -use-ld=lld goes with it:
    #                link.exe does emit the .debug_* sections, but truncates
    #                their names to the 8 characters a PE image allows
    #                (".debug_info" becomes ".debug_i"), and no DWARF reader
    #                recognizes them. Measured both ways round: lld-link with
    #                /DEBUG:DWARF gives LLDB line tables down to the column,
    #                link.exe gives it nothing.
    #
    #   codeview  -> Visual Studio, which reads only CodeView, from a .pdb
    #                written by link.exe.
    #
    # Set SwiftDebugFormat=codeview in the app project to debug in Visual Studio
    # instead - see the Windows section of StateUI.targets.
    [ValidateSet("codeview", "dwarf")]
    [string]$DebugFormat = $(if ($env:SWIFT_DEBUG_FORMAT) { $env:SWIFT_DEBUG_FORMAT } else { "dwarf" }),

    [string]$OutDir = "",

    # Which Swift module to build. Called once for the StateUI library and
    # again for the application's UI module, which links against it - nothing
    # here is specific to either.
    [Parameter(Mandatory=$true)]
    [string]$Module,

    # Directory globbed for .swift files (recursively).
    [Parameter(Mandatory=$true)]
    [string]$Sources,

    # Directory holding .swiftmodule files and import libraries this module
    # depends on. Empty for the library itself.
    [string]$Deps = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir   = Split-Path -Parent $scriptDir
$sourceDir = $Sources

if (-not $OutDir) {
    # MSBuild passes an explicit directory (the app's obj/stateui/...). A
    # manual run has none, and defaulting to a separate artifacts/ folder is a
    # trap: the script reports success while the app still finds nothing,
    # because it looks under obj/. Default to the sample app's obj/ when that
    # project is present.
    $sampleObj = Join-Path $rootDir "apps\Gallery\obj\stateui\windows"
    $ownObj = Join-Path $rootDir "obj\stateui\windows"
    if (Test-Path (Join-Path $rootDir "apps\Gallery")) {
        $OutDir = $sampleObj
    } elseif (Get-ChildItem -Path $rootDir -Filter *.csproj -File -ErrorAction SilentlyContinue) {
        # A scaffolded app: the project file sits beside .scripts, so its own
        # obj/ is where the app will look.
        $OutDir = $ownObj
    } else {
        $OutDir = Join-Path $rootDir "artifacts\windows"
    }
}
$Out = Join-Path $OutDir $Arch
$Dll = Join-Path $Out "$Module.dll"
$Pdb = Join-Path $Out "$Module.pdb"
$Def = Join-Path $Out "$Module.def"

$hostArch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64" }

Write-Host "module:        $Module"
Write-Host "configuration: $Config"
Write-Host "architecture:  $Arch (host: $hostArch)"
if ($Config -eq "debug") {
    $reader = if ($DebugFormat -eq "dwarf") { "LLDB / VS Code" } else { "Visual Studio" }
    Write-Host "debug format:  $DebugFormat (for $reader)"
}

if (-not (Get-Command swiftc -ErrorAction SilentlyContinue)) {
    Write-Error "swiftc not found on PATH. Install the Swift toolchain for Windows and open a new shell."
}

# lld-link ships with the Swift toolchain, so this normally cannot fail - but
# DWARF depends on it entirely, and a missing linker would otherwise surface as
# a link error that says nothing about debug info.
if ($Config -eq "debug" -and $DebugFormat -eq "dwarf" -and -not (Get-Command lld-link -ErrorAction SilentlyContinue)) {
    Write-Error "DWARF debug info needs lld-link, which was not found on PATH. Use -DebugFormat codeview, or install a Swift toolchain that ships lld."
}

# --- MSVC environment -----------------------------------------------------
# Swift links through the MSVC linker, which finds the C runtime and Windows SDK
# libraries via LIB / INCLUDE. Those are set per architecture by vcvarsall.bat.
# Without them the link fails with a wall of LNK4272 warnings about mismatched
# machine types, followed by unresolved memcpy and _DllMainCRTStartup - errors
# that talk about symbols and never mention the environment.
#
# A plain PowerShell window has none of this, and neither does MSBuild when it
# runs this script, so it is set up here rather than requiring a developer
# prompt.
function Import-VisualStudioEnvironment {
    param([string]$TargetArch, [string]$HostArch)

    $vcvarsArg = if ($HostArch -eq $TargetArch) { $TargetArch } else { "${HostArch}_${TargetArch}" }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        Write-Warning "vswhere.exe not found - cannot locate Visual Studio automatically."
        return $false
    }

    $vsPath = & $vswhere -latest -products * -property installationPath
    if (-not $vsPath) {
        Write-Warning "No Visual Studio installation found."
        return $false
    }

    $vcvarsall = Join-Path $vsPath "VC\Auxiliary\Build\vcvarsall.bat"
    if (-not (Test-Path $vcvarsall)) {
        Write-Warning "vcvarsall.bat not found under $vsPath"
        return $false
    }

    Write-Host "  initializing MSVC environment: vcvarsall.bat $vcvarsArg"
    $output = & cmd /c "`"$vcvarsall`" $vcvarsArg > nul 2>&1 && set"
    if ($LASTEXITCODE -ne 0 -or -not $output) {
        Write-Warning "vcvarsall.bat $vcvarsArg failed. Is the $TargetArch toolset installed?"
        return $false
    }

    foreach ($line in $output) {
        if ($line -match "^([^=]+)=(.*)$") {
            Set-Item -Path "env:$($matches[1])" -Value $matches[2] -ErrorAction SilentlyContinue
        }
    }
    return $true
}

Write-Host ""
Write-Host "== MSVC environment =="
if ($env:VSCMD_ARG_TGT_ARCH -eq $Arch) {
    Write-Host "  already initialized for $Arch"
} else {
    if (-not (Import-VisualStudioEnvironment -TargetArch $Arch -HostArch $hostArch)) {
        Write-Warning "Could not set up the MSVC environment automatically."
        Write-Warning "Run from an '$($Arch.ToUpper()) Native Tools Command Prompt for VS' instead."
    }
}

New-Item -ItemType Directory -Force -Path $Out | Out-Null
if (Test-Path $Pdb) { Remove-Item $Pdb -Force }

# --- sources --------------------------------------------------------------
# Discovered, never listed: adding a .swift file anywhere under the sources
# folder picks it up with no change here.
#
# Two exclusions, the same two SwiftPM applies on its own: the app module is
# compiled from its whole Swift/ folder, where Package.swift is the MANIFEST
# and .build/ is SwiftPM's scratch - SourceKit fills it with checkouts whose
# .swift files belong to other packages entirely.
#
# THE .build EXCLUSION IS ANCHORED to the source directory, and it was not: a
# pattern matching .build anywhere in the path threw away everything when the
# LIBRARY was the thing being compiled, because in an app that consumes
# StateUI as a dependency its sources sit under
# Swift\.build\checkouts\StateUI\src\StateUI\Sources - inside a .build, and
# nobody's scratch. What it read as was "No .swift files found under <a
# directory plainly full of them>".
#
# NOT named $sources. PowerShell variable names are CASE-INSENSITIVE, so that is
# the same variable as the [string]$Sources parameter - and a type-constrained
# variable COERCES what is assigned to it. The FileInfo array would silently
# become one string of file names: Count reads as 1, .FullName as $null, and the
# build dies further down in Select-String with "Cannot bind argument to
# parameter 'Path' because it is null" - an error that says nothing about where
# it came from.
$sourceRoot = (Resolve-Path $sourceDir).Path.TrimEnd('\')
$scratch = Join-Path $sourceRoot ".build"
$sourceFiles = Get-ChildItem -Path $sourceDir -Filter "*.swift" -Recurse -File |
    Where-Object { $_.Name -ne "Package.swift" -and -not $_.FullName.StartsWith($scratch, [System.StringComparison]::OrdinalIgnoreCase) } |
    Sort-Object FullName
if ($sourceFiles.Count -eq 0) {
    Write-Error "No .swift files found under $sourceDir"
}
$sourcePaths = $sourceFiles | ForEach-Object { $_.FullName }

Write-Host ""
Write-Host "== $Module -> Windows ($Arch) =="
Write-Host "sources: $($sourceFiles.Count) file(s) under $sourceDir"
Write-Host "output:  $Dll"

# --- export list ----------------------------------------------------------
# GENERATED, not maintained by hand.
#
# On Windows, symbol visibility in a DLL does not follow from a function being
# public the way it does on Unix: the linker exports only what is explicitly
# requested. Swift has no __declspec(dllexport) equivalent for @_cdecl, so the
# list goes in a .def file passed to the linker with /DEF:.
#
# Scanning the sources for @_cdecl means a new export cannot be forgotten here -
# which would otherwise surface much later as EntryPointNotFoundException, with
# the DLL building perfectly.
#
# COMMENT LINES ARE DROPPED FIRST, and that is not tidiness: a doc example is
# PROSE, and exporting a name nobody declares stops the linker dead. The library
# documents `stateUIUseApp` by showing an application the one line it has to
# write - `@_cdecl("stateui_app_register")`, in a `///` block in
# Views/Application.swift - and a scan that reads it puts that name in the
# library's .def, where nothing defines it. lld-link then says
# `<root>: undefined symbol: stateui_app_register` and NO DLL IS PRODUCED.
#
#
# The guard tests already dropped comments for this exact reason -
# `testEveryExportLivesInTheBridgeFile` says a doc example "is prose" in as many
# words - so this is the scanner being taught what the tests already knew.
#
# NOT $matches: that is a PowerShell automatic variable, written by every -match
# operator, so a later regex elsewhere in the script would overwrite it.
$exports = @()
foreach ($file in $sourceFiles) {
    $cdecls = Get-Content -LiteralPath $file.FullName |
        Where-Object { -not $_.TrimStart().StartsWith("//") } |
        Select-String -Pattern '@_cdecl\("([^"]+)"\)' -AllMatches
    foreach ($m in $cdecls) {
        foreach ($group in $m.Matches) {
            $exports += $group.Groups[1].Value
        }
    }
}
$exports = $exports | Sort-Object -Unique

if ($exports.Count -eq 0) {
    Write-Error "No @_cdecl exports found in the sources - the library would be unusable."
}

Write-Host "exports: $($exports.Count) found by scanning for @_cdecl"

$defLines = @("LIBRARY $Module", "", "EXPORTS")
foreach ($e in $exports) { $defLines += "    $e" }
Set-Content -Path $Def -Value $defLines -Encoding ASCII

# --- compile --------------------------------------------------------------
$optFlags = if ($Config -eq "debug") {
    @("-Onone", "-g", "-debug-info-format=$DebugFormat")
} else {
    @("-O")
}

# -I locates .swiftmodule files for imported modules; the .lib is the import
# library the linker needs to resolve their symbols.
#
# THIS MODULE'S OWN .lib IS EXCLUDED. The dependency directory is the same
# directory this build writes to, so after one successful build it also holds
# $Module.lib - and feeding a module its own import library makes link.exe stop
# with LNK1149, "output filename matches input filename". A first build from a
# clean obj/ therefore worked and every rebuild after it failed, which reads as
# an intermittent linker problem rather than as the build handing itself its own
# output.
#
# SPLIT IN TWO, because the build is now compile-then-link and each half takes
# a different one. -I is for the compiler, which needs the .swiftmodule to
# resolve `import StateUI`; the .lib files are for the linker. Handing a .lib
# to the compile step stops it with "unexpected input file", since swiftc reads
# a bare path there as another source to compile.
$importFlags = @()
$importLibs = @()
if ($Deps -and (Test-Path $Deps)) {
    $importFlags += @("-I", $Deps)
    Get-ChildItem -Path $Deps -Filter "*.lib" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -ne $Module } |
        ForEach-Object { $importLibs += $_.FullName }
}

$linkFlags = @("-Xlinker", "/DEF:$Def")

# DWARF is selected at the LINKER, not just the compiler. swiftc emits the
# .debug_* sections either way; what differs is who links them.
#
# link.exe keeps the sections but truncates their names to the 8 characters a PE
# image allows, so ".debug_info" reaches the debugger as ".debug_i" and no DWARF
# reader finds it. The library looks fully symbolised and LLDB reports "No source
# filenames matched" - which reads as a missing-source problem, not a linker one.
#
# lld-link writes the names in full, and /DEBUG:DWARF is what tells it to keep
# the sections at all (without it lld strips them, measured). It also leaves
# Swift's .sw5* metadata sections standing rather than folding them into .rdata.
if ($Config -eq "debug" -and $DebugFormat -eq "dwarf") {
    $optFlags += "-use-ld=lld"
    $linkFlags += @("-Xlinker", "/DEBUG:DWARF")
}

if ($Config -eq "debug" -and $DebugFormat -eq "codeview") {
    # The compiler emits debug info, but only the LINKER writes the .pdb file.
    # Without /DEBUG no PDB is produced whatever the compiler flags say.
    #
    # /INCREMENTAL:NO comes WITH it, and is not optional. /DEBUG turns
    # incremental linking ON by default, and incremental linking is not safe for
    # Swift: it reaches functions through thunks and pads sections to leave room
    # for the next link, which moves the targets of the RELATIVE POINTERS that
    # Swift's metadata sections (.sw5*) are built from. Nothing detects this. The
    # DLL links, loads, and exports everything; it dies later inside
    # swift_getTypeByMangledName, reading an address that no longer holds what
    # the metadata says - reported as an access violation in swiftCore.dll, a
    # module with no bug in it.
    #
    # Only debug builds are affected, which makes it look like a
    # configuration problem: -O resolves most metadata statically, so a release
    # build barely touches the machinery that the relative pointers feed. The
    # .pdb is still produced - measured, same size to the kilobyte.
    $linkFlags += @("-Xlinker", "/DEBUG", "-Xlinker", "/PDB:$Pdb", "-Xlinker", "/INCREMENTAL:NO")
}

# Only cross-compilation needs an explicit -target. Passing one that merely
# restates the host was found to make swiftc hang with no output.
$targetFlags = @()
if ($Arch -ne $hostArch) {
    $triple = if ($Arch -eq "arm64") { "aarch64-unknown-windows-msvc" } else { "x86_64-unknown-windows-msvc" }
    $targetFlags = @("-target", $triple)
    Write-Host "cross-compiling for $Arch (target: $triple)"
}

# --- the macro plugin -----------------------------------------------------
# @StateClass is a macro, and a macro is an EXECUTABLE the compiler starts and
# talks to - so it has to exist before any Swift here compiles, and it is built
# for THIS machine rather than for the target. SwiftPM is what builds one;
# swiftc only knows how to load it.
#
# The first build compiles swift-syntax and takes minutes. Every build after
# that finds it and does nothing, which is what the timestamp check is for: this
# script runs twice per platform, and a second each for an answer that never
# changed adds up.
#
# The executable's NAME is SwiftPM's business and has changed - recent versions
# add a "-tool" suffix - so both are looked for rather than one assumed. Guessing
# wrong fails much later, as a macro that "cannot be resolved", with nothing in
# the message about a file name.
#
# WHICH PACKAGE IS BUILT is the APP's, and it is passed in rather than worked out
# here. It is the one package that exists in both layouts: in this repository the
# library sits a few directories up, while an app made by "dotnet new stateui"
# has it as a SwiftPM dependency checked out under its own Swift\.build - and
# building the library's package THERE would fetch and compile swift-syntax a
# second time for a plugin the app already has. The defaults are this
# repository's answers, so running this by hand needs no environment at all.
$defaultPluginPackage = $rootDir
if (Test-Path (Join-Path $rootDir "apps\Gallery\Package.swift")) {
    $defaultPluginPackage = Join-Path $rootDir "apps\Gallery"
}

$pluginPackage = if ($env:STATEUI_PLUGIN_PACKAGE) { $env:STATEUI_PLUGIN_PACKAGE } else { $defaultPluginPackage }
$macroSources  = if ($env:STATEUI_MACRO_SOURCES) { $env:STATEUI_MACRO_SOURCES } else { Join-Path $rootDir "src\StateUI\Macros" }
$pluginModule = "StateUIMacros"

function Find-MacroPlugin {
    $bin = & swift build --package-path $pluginPackage -c release --show-bin-path 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $bin) { return $null }

    $bin = ($bin | Select-Object -Last 1).ToString().Trim()
    foreach ($name in @("$pluginModule-tool.exe", "$pluginModule.exe")) {
        $candidate = Join-Path $bin $name
        if (Test-Path $candidate) { return $candidate }
    }

    return $null
}

$plugin = Find-MacroPlugin
$newestMacroSource = Get-ChildItem $macroSources -Filter *.swift -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

# The whole package, not "--target StateUIMacros". A macro target on its own is
# COMPILED and never LINKED - SwiftPM produces the module and stops, leaving a
# .build directory with no executable in it - so the plugin only appears once
# something that uses it is built. Measured; the flag that looks like it should
# do this does not.
if ((-not $plugin) -or ($newestMacroSource -and $newestMacroSource.LastWriteTime -gt (Get-Item $plugin).LastWriteTime)) {
    Write-Host "building the macro plugin (a first build compiles swift-syntax, which takes minutes)..."
    & swift build --package-path $pluginPackage -c release
    if ($LASTEXITCODE -ne 0) { Write-Error "the macro plugin failed to build." }
    $plugin = Find-MacroPlugin
}

if (-not $plugin) {
    Write-Error "the macro plugin was not produced. Run it by hand to see why: swift build --package-path $pluginPackage -c release"
}

Write-Host "macro plugin:  $plugin"

# --- incremental compilation ----------------------------------------------
# The build is TWO steps - compile to .o, then link them - rather than the one
# -emit-library step that does both. That is the price of -incremental, and it
# buys the difference between recompiling a module and recompiling a file:
# changing one line of one file went from 123s to 3s, measured on this tree.
#
# -incremental needs somewhere to record what it learned, which is the output
# file map: for every source file, where its .o goes and where its .swiftdeps
# goes. The entry under "" is the module-wide one. Without the map swiftc
# silently compiles everything, every time - which is what it was doing.
$ObjDir = Join-Path $Out "$Module.objs"
New-Item -ItemType Directory -Force -Path $ObjDir | Out-Null

# The stamp records the configuration the .o files were built with. A build that
# changes -Onone to -O, or DWARF to CodeView, leaves objects that are wrong in a
# way -incremental cannot see: it tracks SOURCES, not flags. So a configuration
# change throws the objects away and starts over.
$ConfigStamp = Join-Path $ObjDir ".config"
$ConfigNow = "$Config-$DebugFormat-$Arch"
if ((-not (Test-Path $ConfigStamp)) -or ((Get-Content $ConfigStamp -Raw).Trim() -ne $ConfigNow)) {
    Write-Host "configuration changed - recompiling from scratch"
    Get-ChildItem $ObjDir -File -Force -ErrorAction SilentlyContinue | Remove-Item -Force
}

# Object names come from the path relative to the source root, not the file
# name: two files called Button.swift in different folders would otherwise
# share one Button.o, and the second would quietly overwrite the first.
$ofm = [ordered]@{}
$ofm[""] = [ordered]@{ "swift-dependencies" = (Join-Path $ObjDir "master.swiftdeps") }
foreach ($f in $sourcePaths) {
    $rel = $f.Substring($sourceRoot.Length).TrimStart('\')
    $flat = ($rel -replace '[\\/]', '_') -replace '\.swift$', ''
    $ofm[$f] = [ordered]@{
        "object"             = (Join-Path $ObjDir "$flat.o")
        "swift-dependencies" = (Join-Path $ObjDir "$flat.swiftdeps")
    }
}
$OfmPath = Join-Path $ObjDir "output-file-map.json"
($ofm | ConvertTo-Json -Depth 4) | Set-Content -Path $OfmPath -Encoding UTF8

Write-Host ""
Write-Host "running swiftc..."

# NOTE: -emit-module-path is EXPLICIT here, and the compiler runs with $Out as
# its working directory.
#
# "Next to the -o file" is Apple behaviour, not swiftc's rule: on Windows a bare
# -emit-module writes StateUI.swiftmodule into the CURRENT DIRECTORY - which,
# under MSBuild, is the project or repository root. The library's DLL then
# builds perfectly while its .swiftmodule is nowhere the next compilation looks,
# and the APP module fails with "no such module 'StateUI'" - which is why the
# path is stated rather than left to the compiler.
#
# Push-Location is what keeps the intermediate $Module.o out of the source tree
# for the same reason - it too lands in the working directory. Every path passed
# below is absolute, so moving the working directory changes nothing else.
#
# NOTE: $flags, not @flags. Splatting with @ is for cmdlets; PowerShell already
# expands a plain array for native commands, and with an EMPTY array @ can pass
# an empty argument - which swiftc reads as "no input file" and then waits on
# stdin, hanging the build silently.
#
# NOTE the upcoming feature.
#
# Android goes through SwiftPM, where the flag is in each Package.swift; Apple
# and Windows call swiftc directly, so it has to be repeated here or the same
# sources would compile with different concurrency defaults per platform. See
# the note in the repository's Package.swift for what it does.
Push-Location $Out
try {
    # STEP 1 - compile only (-c). Rebuilds just the files that changed and the
    # ones depending on them; the rest are reused from $ObjDir.
    & swiftc `
        -c `
        -incremental `
        -output-file-map $OfmPath `
        -emit-module -emit-module-path (Join-Path $Out "$Module.swiftmodule") `
        -module-name $Module `
        -parse-as-library `
        -enable-upcoming-feature NonisolatedNonsendingByDefault `
        -load-plugin-executable "$plugin#$pluginModule" `
        $targetFlags `
        $importFlags `
        $optFlags `
        $sourcePaths

    if ($LASTEXITCODE -ne 0) {
        Write-Error "swiftc failed to compile (exit code $LASTEXITCODE)."
    }

    # STEP 2 - link. Every .o in the map, whether or not this run rebuilt it.
    #
    # Read from the MAP rather than by globbing $ObjDir: a source file deleted
    # since the last build leaves its .o behind, and globbing would go on
    # linking code whose source is gone.
    $objects = @($ofm.Keys | Where-Object { $_ -ne "" } | ForEach-Object { $ofm[$_]["object"] })
    $missing = @($objects | Where-Object { -not (Test-Path $_) })
    if ($missing.Count -gt 0) {
        Write-Error "compilation reported success but $($missing.Count) object file(s) are missing, e.g. $($missing[0])."
    }

    # -emit-module is NOT repeated here. The module was written by step 1, and
    # asking for it again would rebuild it from .o files that do not carry what
    # it needs.
    & swiftc `
        -emit-library `
        -module-name $Module `
        $targetFlags `
        $importFlags `
        $importLibs `
        $optFlags `
        -o $Dll `
        $linkFlags `
        $objects
} finally {
    Pop-Location
}

if ($LASTEXITCODE -ne 0) {
    if (-not (Get-Command link -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Host "HINT: link.exe is not on PATH. If the failure above mentions the linker,"
        Write-Host "retry from an 'x64/ARM64 Native Tools Command Prompt for VS'."
    }
    Write-Error "swiftc failed with exit code $LASTEXITCODE."
}

# Written only after both steps succeed, so a failed build does not leave a
# stamp claiming these objects match the current configuration.
Set-Content -Path $ConfigStamp -Value $ConfigNow -Encoding ASCII

if (-not (Test-Path $Dll)) {
    Write-Error "swiftc reported success but $Dll does not exist."
}

# The .swiftmodule is checked as well as the DLL: it is what the NEXT
# compilation finds via -I, and a missing one does not fail this run at all - it
# fails the module that imports this one, one step later and somewhere else.
$SwiftModule = Join-Path $Out "$Module.swiftmodule"
if (-not (Test-Path $SwiftModule)) {
    Write-Error "swiftc produced $Dll but no $Module.swiftmodule in $Out - anything importing $Module would fail with 'no such module'."
}

Write-Host ""
Write-Host "OK: $Dll"

if ($Config -eq "debug" -and $DebugFormat -eq "codeview") {
    if (Test-Path $Pdb) {
        Write-Host "OK: $Pdb ($([math]::Round((Get-Item $Pdb).Length / 1KB)) KB)"
    } else {
        Write-Warning "Debug build, but no .pdb was produced - symbols will not load."
    }
}

# DWARF has no separate file to look for, so the check is that the section names
# survived in full. Searching for the LONG name is what makes this meaningful:
# link.exe truncates to ".debug_i", so a build that quietly fell back to it
# fails here rather than three steps later, when a breakpoint does not bind and
# nothing says why.
if ($Config -eq "debug" -and $DebugFormat -eq "dwarf") {
    $image = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($Dll))
    if ($image.Contains(".debug_info")) {
        Write-Host "OK: DWARF sections present (LLDB / VS Code can read line tables)"
    } else {
        Write-Warning "Debug build, but $Module.dll carries no full-length .debug_info section."
        Write-Warning "Breakpoints in .swift files will not bind. Was it linked with link.exe instead of lld-link?"
    }
}

# Configuration stamp, so MSBuild rebuilds when the configuration or debug
# format changes (the file name stays the same, so it cannot tell otherwise).
Get-ChildItem -Path $Out -Filter ".stamp-$Module-*" -Force -ErrorAction SilentlyContinue | Remove-Item -Force
New-Item -ItemType File -Force -Path (Join-Path $Out ".stamp-$Module-$Config-$DebugFormat") | Out-Null

# --- Swift runtime --------------------------------------------------------
# Windows has no Swift runtime, so swiftCore.dll and friends must sit next to
# the library. When they are missing, .NET reports DllNotFoundException for
# StateUI.dll itself - Windows cannot say that a dependency failed to load,
# which makes the error deeply misleading.
Write-Host ""
Write-Host "== Swift runtime =="

function Find-SwiftRuntimeDir {
    param([string]$TargetArch)

    # Bounded search: an unbounded walk up the tree, recursing at each level,
    # can end up scanning the whole drive and look like a hang.
    $swiftc = (Get-Command swiftc -ErrorAction SilentlyContinue).Source
    if (-not $swiftc) { return $null }

    $bin = Split-Path -Parent $swiftc
    $swiftRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $bin)))

    $candidates = @()
    if ($swiftRoot) { $candidates += Join-Path $swiftRoot "Runtimes" }
    $candidates += $bin
    $candidates += "$env:LOCALAPPDATA\Programs\Swift\Runtimes"
    $candidates += "$env:ProgramFiles\Swift\Runtimes"

    foreach ($root in $candidates) {
        if (-not $root -or -not (Test-Path $root)) { continue }
        Write-Host "  probing: $root"
        $hits = Get-ChildItem -Path $root -Filter "swiftCore.dll" -Recurse -Depth 5 -File -ErrorAction SilentlyContinue
        if ($hits) {
            $archHit = $hits | Where-Object { $_.FullName -match $TargetArch } | Select-Object -First 1
            if ($archHit) { return $archHit.DirectoryName }
            return ($hits | Select-Object -First 1).DirectoryName
        }
    }
    return $null
}

$runtimeDir = Find-SwiftRuntimeDir -TargetArch $Arch
if ($runtimeDir) {
    Write-Host "  found: $runtimeDir"
    Copy-Item -Path (Join-Path $runtimeDir "*.dll") -Destination $Out -Force
    Write-Host "  copied $((Get-ChildItem -Path $Out -Filter '*.dll' -File).Count) DLL(s) into the output folder"
} else {
    Write-Warning "Could not locate swiftCore.dll. Copy the Swift runtime DLLs into $Out manually."
}

Write-Host ""
Write-Host "Done."

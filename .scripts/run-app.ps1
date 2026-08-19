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
# Builds and launches the app WITHOUT a debugger, then returns.
#
# The Windows counterpart of run-app.sh, and the preLaunchTask of "Debug app
# (Swift)". Launching first and attaching second buys less here than on Apple -
# Windows has no watchdog to kill an app a debugger stopped - but the attach
# still needs a process to find, and this is the ONLY route to a Swift debugger
# on Windows: the compound cannot run there, since Windows gives a process one
# native debugger and VS Code runs the two languages as two adapters. The full
# account is in .vscode/launch.json.
#
# USAGE:
#   .\run-app.ps1
#   .\run-app.ps1 -Configuration Release
#   .\run-app.ps1 -Project path\to\App.csproj
#
# Pure ASCII on purpose: Windows PowerShell 5.1 reads BOM-less .ps1 files as
# ANSI, which corrupts non-ASCII characters and can break string parsing.
# ---------------------------------------------------------------------------
param(
    [string]$Configuration = "Debug",

    # Matches the app project's TargetFrameworks for Windows. Passed in rather
    # than discovered so a framework bump is a one-line change in tasks.json.
    [string]$Framework = "net10.0-windows10.0.19041.0",

    # Which project to run, when it is not the obvious one.
    [string]$Project = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir   = Split-Path -Parent $scriptDir

# WHICH PROJECT, and it is FOUND rather than spelled out - because this script
# ships in two layouts. In the StateUI repository the apps live under apps\ and
# the gallery is the one to run; in an app made by "dotnet new stateui" the
# project file sits beside .scripts and is the only one there.
if (-not $Project) {
    $gallery = Join-Path $rootDir "apps\Gallery\Gallery.csproj"
    if (Test-Path $gallery) {
        $Project = $gallery
    } else {
        $found = @(Get-ChildItem -Path $rootDir -Filter *.csproj -File -ErrorAction SilentlyContinue)
        if ($found.Count -gt 1) {
            Write-Error "More than one .csproj in $rootDir - name the one to run with -Project."
        }
        if ($found.Count -eq 1) { $Project = $found[0].FullName }
    }
}

if (-not $Project -or -not (Test-Path $Project)) {
    Write-Error "No project to run. Expected one .csproj beside $rootDir."
}

$appDir = Split-Path -Parent $Project

# The project name, which is also the assembly and therefore the PROCESS name -
# what the debugger matches on. Note that LLDB on Windows wants it WITH the
# .exe extension; see the note in .vscode/launch.json.
$appName = [System.IO.Path]::GetFileNameWithoutExtension($Project)

# An app left over from a previous run would be attached to instead of the new
# one - the attach matches by name, and it would silently be the wrong process.
$stale = Get-Process -Name $appName -ErrorAction SilentlyContinue
if ($stale) {
    Write-Host "Stopping a previous instance of $appName..."
    $stale | Stop-Process -Force
    Start-Sleep -Seconds 1
}

Write-Host "== Building for Windows =="

# -nodeReuse:false is NOT optional here, and the reason has nothing to do with
# building. MSBuild keeps its worker processes alive between builds, and those
# workers inherit the console handles of whatever started them. Started from a
# VS Code task, they hold that task's terminal open after the build is done - so
# the task never reports completion, the preLaunchTask never returns, and the
# debug session that was waiting on it never starts. It looks like a hang with
# no error anywhere.
#
# The trap: a build started while workers are already running REUSES them
# instead of spawning new ones under the task's terminal, and the terminal is
# free to close - which is what masks this whenever another build ran just
# before.
& dotnet build $Project -c $Configuration -f $Framework -nodeReuse:false
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed with exit code $LASTEXITCODE."
}

# The RID subdirectory is not spelled out: the project defaults RuntimeIdentifier
# to the host, so hardcoding win-x64 would look right on one machine and find
# nothing on an ARM64 one. Whatever single RID folder the build produced is the
# one to run.
$outRoot = Join-Path $appDir "bin\$Configuration\$Framework"
if (-not (Test-Path $outRoot)) {
    Write-Error "Nothing was built - $outRoot does not exist."
}

$exe = Get-ChildItem -Path $outRoot -Filter "$appName.exe" -Recurse -File |
       Sort-Object LastWriteTime -Descending |
       Select-Object -First 1
if (-not $exe) {
    Write-Error "No $appName.exe under $outRoot."
}

Write-Host ""
Write-Host "== Launching (no debugger) =="
Write-Host $exe.FullName
$process = Start-Process -FilePath $exe.FullName -PassThru

# Wait for the process to actually be there before returning, so the debug
# session that follows has something to attach to.
Write-Host "Waiting for $appName to start..."
$elapsed = 0
while ($elapsed -lt 60) {
    if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) {
        Write-Host "Running (PID $($process.Id)) after ${elapsed}s."
        # A moment to get past startup before a debugger stops the process.
        Start-Sleep -Seconds 1
        exit 0
    }
    Start-Sleep -Seconds 1
    $elapsed++
}

Write-Error "$appName did not start within 60s."

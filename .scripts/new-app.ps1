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
# Creates a new StateUI application in apps/ - the Windows half of
# new-app.sh, and the same contract:
#
#   .\new-app.ps1 -Name MyApp [-AppsDir <dir>]
#
# It makes apps/HelloWorld under another name: Package.swift, Sources/,
# Resources/, Platforms/AppKit/ and Platforms/Maui/ with <Name>.csproj, Host/
# and one folder per platform. What HelloWorld's builds wrote is left behind.
# Only the default AppsDir also registers the MAUI project in StateUI.slnx.
# ---------------------------------------------------------------------------
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$AppsDir
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir   = Split-Path -Parent $scriptDir
$model     = Join-Path $rootDir "apps/HelloWorld"

if (-not $AppsDir) { $AppsDir = Join-Path $rootDir "apps" }

# Letters and digits, starting with a letter - the same rule as new-app.sh,
# for the same reasons: the name becomes a C# namespace, a Swift module, a
# process name and a directory. No dots - Finder reads Name.App as a bundle.
if ($Name -notmatch '^[A-Za-z][A-Za-z0-9]*$') {
    throw "'$Name' cannot name an application: letters and digits only, starting with a letter."
}
if ($Name -eq "StateUI") {
    throw "'StateUI' is the library. Pick a name of the app's own."
}

$app = Join-Path $AppsDir $Name
if (Test-Path $app) { throw "$app already exists." }
if (-not (Test-Path $model)) { throw "HelloWorld is not at $model - it is what a new application is made from." }

$lower = $Name.ToLowerInvariant()

New-Item -ItemType Directory -Path $app -Force | Out-Null
foreach ($item in @("Package.swift", "Sources", "Resources", "Platforms")) {
    Copy-Item -Recurse (Join-Path $model $item) (Join-Path $app $item)
}

# What HelloWorld's own builds wrote - its MAUI head's output and whatever
# Finder left behind.
foreach ($built in @("Platforms/Maui/bin", "Platforms/Maui/obj")) {
    $path = Join-Path $app $built
    if (Test-Path $path) { Remove-Item -Recurse -Force $path }
}
Get-ChildItem -Path $app -Recurse -Force -Filter ".DS_Store" | Remove-Item -Force

# The rename, in names and then in contents: the model's name is a plain token
# wherever it appears, and the application identifier carries it lowercased.
Get-ChildItem -Path $app -Recurse -Filter "*HelloWorld*" |
    Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object { Rename-Item $_.FullName ($_.Name.Replace("HelloWorld", $Name)) }

$extensions = @(".swift", ".cs", ".csproj", ".plist", ".xml", ".json", ".xaml", ".manifest")
Get-ChildItem -Path $app -Recurse -File |
    Where-Object { $extensions -contains $_.Extension } |
    ForEach-Object {
        $text = [System.IO.File]::ReadAllText($_.FullName)
        $text = $text.Replace("HelloWorld", $Name).Replace("helloworld", $lower)
        [System.IO.File]::WriteAllText($_.FullName, $text)
    }

# The title is SET rather than renamed: it is the one property whose value need
# not be the project name, and setting it outright is what carries the new
# application's own name into its bundle and its window.
$csprojPath = Join-Path $app "Platforms/Maui/$Name.csproj"
$csproj = [System.IO.File]::ReadAllText($csprojPath)
$csproj = $csproj -replace "<ApplicationTitle>[^<]*</ApplicationTitle>", "<ApplicationTitle>$Name</ApplicationTitle>"
[System.IO.File]::WriteAllText($csprojPath, $csproj)

# Into the solution, so the IDE sees the MAUI head - only in the real apps/,
# never twice.
$slnx = Join-Path $rootDir "StateUI.slnx"
$defaultApps = Join-Path $rootDir "apps"
$project = "apps/$Name/Platforms/Maui/$Name.csproj"
if (($AppsDir -eq $defaultApps) -and (Test-Path $slnx)) {
    $solution = [System.IO.File]::ReadAllText($slnx)
    if (-not $solution.Contains($project)) {
        $solution = $solution.Replace("</Solution>", "  <Project Path=`"$project`" />`n</Solution>")
        [System.IO.File]::WriteAllText($slnx, $solution)
        Write-Host "Registered in StateUI.slnx."
    }
}

Write-Host "Created $app"
Write-Host ""
Write-Host "Next, from the repository root:"
Write-Host "  dotnet build apps/$Name/Platforms/Maui -f net10.0-windows10.0.19041.0    # or net10.0-android"

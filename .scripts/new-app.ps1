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
# Resources/, Platforms/AppKit/, Platforms/Android/ and Platforms/WinUI/. What HelloWorld's
# builds wrote is left behind.
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
# for the same reasons: the name becomes a Swift module, a process name, a
# package identifier and a directory. No dots - Finder reads Name.App as a
# bundle.
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

New-Item -ItemType Directory -Path (Join-Path $app "Platforms/Android") -Force | Out-Null
foreach ($item in @("Package.swift", "Sources", "Resources", "Platforms/AppKit", "Platforms/WinUI")) {
    Copy-Item -Recurse (Join-Path $model $item) (Join-Path $app $item)
}

# The Android head without Gradle's .gradle/, which an editor that opens the
# head writes beside it.
Get-ChildItem -Path (Join-Path $model "Platforms/Android") -Force |
    Where-Object { $_.Name -ne ".gradle" } |
    ForEach-Object { Copy-Item -Recurse $_.FullName (Join-Path $app "Platforms/Android") }

# And whatever Finder left behind.
Get-ChildItem -Path $app -Recurse -Force -Filter ".DS_Store" | Remove-Item -Force

# The rename, in names and then in contents: the model's name is a plain token
# wherever it appears, and the application identifier carries it lowercased.
Get-ChildItem -Path $app -Recurse -Filter "*HelloWorld*" |
    Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object { Rename-Item $_.FullName ($_.Name.Replace("HelloWorld", $Name)) }

$extensions = @(".swift", ".xml", ".kts")
Get-ChildItem -Path $app -Recurse -File |
    Where-Object { $extensions -contains $_.Extension } |
    ForEach-Object {
        $text = [System.IO.File]::ReadAllText($_.FullName)
        $text = $text.Replace("HelloWorld", $Name).Replace("helloworld", $lower)
        [System.IO.File]::WriteAllText($_.FullName, $text)
    }

Write-Host "Created $app"
Write-Host ""
Write-Host "Next, from the repository root:"
Write-Host "  swift build --package-path apps/$Name    # the application's module; its AppKit and Android heads build on macOS"
Write-Host "  .scripts\WinUI\run-app.ps1 -App apps\$Name    # the WinUI head"

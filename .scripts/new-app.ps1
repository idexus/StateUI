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
# It makes the layout every app in apps/ has, and apps/HelloWorld is the worked
# example of: <Name>.csproj, Host/ for the C# side, Platforms/, Resources/, and
# Swift/ holding the application, its pages and Styles/ for its look.
#
# The project file, the platform heads, Host/ and the artwork (AppIcon, Splash,
# the logo mark) come from the gallery, renamed throughout; the Swift files come
# from .scripts/new-app-template/. The gallery's samples, its catalog and their
# artwork stay behind - they are what makes it the gallery. Only the default
# AppsDir also registers the project in StateUI.slnx.
# ---------------------------------------------------------------------------
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$AppsDir
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir   = Split-Path -Parent $scriptDir
$gallery   = Join-Path $rootDir "apps/Gallery"
$templates = Join-Path $scriptDir "new-app-template"

if (-not $AppsDir) { $AppsDir = Join-Path $rootDir "apps" }

# Letters and digits, starting with a letter - the same rule as new-app.sh,
# for the same reasons: the name becomes a C# namespace, a Swift module, a
# process name and a directory. No dots - Finder reads Name.App as a bundle.
if ($Name -notmatch '^[A-Za-z][A-Za-z0-9]*$') {
    throw "'$Name' cannot name a project: letters and digits only, starting with a letter."
}
if ($Name -eq "StateUI") {
    throw "'StateUI' is the library. Pick a name of the app's own."
}

$app = Join-Path $AppsDir $Name
if (Test-Path $app) { throw "$app already exists." }
if (-not (Test-Path $gallery)) { throw "the gallery is not at $gallery - it is where the project file, Host/ and the artwork come from." }
foreach ($t in @("App", "MainPage", "AppStyles")) {
    $path = Join-Path $templates "$t.swift.template"
    if (-not (Test-Path $path)) { throw "the $t template is not at $path." }
}

$lower = $Name.ToLowerInvariant()

# An explicit list, not a copy of the whole directory - see the header.
New-Item -ItemType Directory -Path (Join-Path $app "Resources/Images") -Force | Out-Null
Copy-Item -Recurse (Join-Path $gallery "Host")                (Join-Path $app "Host")
Copy-Item -Recurse (Join-Path $gallery "Platforms")           (Join-Path $app "Platforms")
Copy-Item -Recurse (Join-Path $gallery "Properties")          (Join-Path $app "Properties")
Copy-Item -Recurse (Join-Path $gallery "Resources/AppIcon")   (Join-Path $app "Resources/AppIcon")
Copy-Item -Recurse (Join-Path $gallery "Resources/Splash")    (Join-Path $app "Resources/Splash")
Copy-Item (Join-Path $gallery "Resources/Images/stateui_mark.svg") (Join-Path $app "Resources/Images/stateui_mark.svg")
Copy-Item (Join-Path $gallery "Gallery.csproj")      (Join-Path $app "$Name.csproj")

# The app's own Swift module: the gallery's manifest, the application, its one
# page, and the styles under Styles/ - the folder the manifest compiles
# whole (path: "Swift"), so nothing here is listed anywhere.
New-Item -ItemType Directory -Path (Join-Path $app "Swift/Styles") -Force | Out-Null
# The manifest sits beside the .csproj, so SwiftPM's .build/ lands where
# bin/ and obj/ do and Swift/ stays nothing but source.
Copy-Item (Join-Path $gallery "Package.swift") (Join-Path $app "Package.swift")
Copy-Item (Join-Path $templates "App.swift.template")          (Join-Path $app "Swift/$($Name)App.swift")
Copy-Item (Join-Path $templates "MainPage.swift.template")     (Join-Path $app "Swift/MainPage.swift")
Copy-Item (Join-Path $templates "AppStyles.swift.template") (Join-Path $app "Swift/Styles/AppStyles.swift")

# The page's artwork: the mark on its gradient as ONE image, so the page needs
# no drawing code. It is drawn big, so it gets a BaseSize of its own beside the
# mark's - the wildcard's 24x24 would rasterize it blurry.
Copy-Item (Join-Path $templates "stateui_tile.svg") (Join-Path $app "Resources/Images/stateui_tile.svg")
$csprojPath = Join-Path $app "$Name.csproj"
$csproj = [System.IO.File]::ReadAllText($csprojPath)
$markLine = '<MauiImage Update="Resources/Images/stateui_mark.svg" BaseSize="96,96" />'
$tileLine = '<MauiImage Update="Resources/Images/stateui_tile.svg" BaseSize="128,128" />'
$csproj = $csproj.Replace($markLine, "$markLine`n    $tileLine")
[System.IO.File]::WriteAllText($csprojPath, $csproj)

# The rename: the gallery's name is a plain token wherever it appears, the
# ApplicationId carries it lowercased, and the templates say __NAME__.
$extensions = @(".cs", ".csproj", ".plist", ".xml", ".json", ".xaml", ".manifest", ".swift")
Get-ChildItem -Path $app -Recurse -File |
    Where-Object { $extensions -contains $_.Extension } |
    ForEach-Object {
        $text = [System.IO.File]::ReadAllText($_.FullName)
        $text = $text.Replace("Gallery", $Name).Replace("gallery", $lower).Replace("__NAME__", $Name)
        [System.IO.File]::WriteAllText($_.FullName, $text)
    }

# The title is SET rather than renamed, because it is the one property whose
# value need not be the project name. The token pass above gets it right only
# while the source project is titled after itself; setting it outright is what
# makes every app scaffolded here carry its OWN name into its bundle and its
# window, whatever the source happens to be called.
$csproj = [System.IO.File]::ReadAllText($csprojPath)
$csproj = $csproj -replace "<ApplicationTitle>[^<]*</ApplicationTitle>", "<ApplicationTitle>$Name</ApplicationTitle>"
[System.IO.File]::WriteAllText($csprojPath, $csproj)

# Into the solution, so the IDE sees it - only in the real apps/, never twice.
$slnx = Join-Path $rootDir "StateUI.slnx"
$defaultApps = Join-Path $rootDir "apps"
if (($AppsDir -eq $defaultApps) -and (Test-Path $slnx)) {
    $solution = [System.IO.File]::ReadAllText($slnx)
    $entry = "  <Project Path=`"apps/$Name/$Name.csproj`" />"
    if (-not $solution.Contains("apps/$Name/$Name.csproj")) {
        $solution = $solution.Replace("</Solution>", "$entry`n</Solution>")
        [System.IO.File]::WriteAllText($slnx, $solution)
        Write-Host "Registered in StateUI.slnx."
    }
}

Write-Host "Created $app"
Write-Host ""
Write-Host "Next:"
Write-Host "  cd `"$app`""
Write-Host "  dotnet build -c Debug -f net10.0-windows10.0.19041.0    # or net10.0-android"

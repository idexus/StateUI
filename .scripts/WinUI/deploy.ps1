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
# Builds an application's WinUI head for release and lays it in a folder of its
# own with everything it runs with - StateUI, the Windows App SDK, the Swift and
# C++ runtimes of its architecture, its pictures - so the folder runs on a
# Windows machine with nothing of them installed.
#
#   .\deploy.ps1 -App apps\Gallery -Destination artifacts\Gallery\WinUI\x64 [-Architecture arm64|x64]
#
#   -Architecture  this machine's own by default; an ARM64 machine builds x64
#                  too, which Windows runs emulated
#
# The destination is made anew. What only a build reads - modules, import
# libraries, object libraries - stays behind.
# ---------------------------------------------------------------------------
param(
    [Parameter(Mandatory = $true)][string]$App,
    [Parameter(Mandatory = $true)][string]$Destination,
    [ValidateSet('arm64', 'x64')][string]$Architecture
)
. (Join-Path $PSScriptRoot 'tools.ps1')
if (-not $Architecture) { $Architecture = $StateUIArchitecture }

& (Join-Path $PSScriptRoot 'run-app.ps1') -App $App -Configuration release -Architecture $Architecture -BuildOnly
if ($LASTEXITCODE) { throw "the WinUI head of $App did not build" }

$application = (Resolve-Path $App).Path
$env:STATEUI_HOST = 'winui'
$arch = Get-StateUIArchitectureArguments $Architecture
$bin = (swift build --package-path $application -c release --scratch-path (Join-Path $application '.build\winui') `
    --show-bin-path @arch).Trim()

Write-Host "laying $(Split-Path $application -Leaf), $Architecture, in $Destination"
if (Test-Path $Destination) { Remove-Item -Recurse -Force $Destination }
New-Item -ItemType Directory -Force $Destination | Out-Null
robocopy $bin $Destination /E /XD *.objlib *.swiftmodule /XF *.lib *.exp *.ilk *.pdb plutil.exe swift-runtime.txt `
    /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "the head could not be copied from $bin" }
Add-StateUISwiftRuntime -Directory $Destination -Architecture $Architecture
Remove-Item (Join-Path $Destination 'swift-runtime.txt') -ErrorAction SilentlyContinue
Add-StateUICppRuntime -Directory $Destination -Architecture $Architecture
Write-Host "deployed $(Join-Path $Destination "$(Split-Path $application -Leaf)WinUI.exe")"
$global:LASTEXITCODE = 0

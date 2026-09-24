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
# Builds an application's WinUI head, lays the Windows App SDK beside it and
# starts it.
#
#   .\run-app.ps1 -App apps\HelloWorld [-Configuration debug|release] [-Detach]
#
#   -App        the application's folder: Package.swift, and Platforms\WinUI
#   -Detach     returns once the application has started, instead of waiting
#               for it and passing on what it writes
#
# Everything a build writes stays under <App>\.build-winui. Every STATEUI_
# variable of the calling shell - STATEUI_TALLY=1, STATEUI_INSPECT=1 - reaches
# the application's environment.
# ---------------------------------------------------------------------------
param(
    [Parameter(Mandatory = $true)][string]$App,
    [ValidateSet('debug', 'release')][string]$Configuration = 'debug',
    [switch]$Detach
)
. (Join-Path $PSScriptRoot 'tools.ps1')

$application = (Resolve-Path $App).Path
$name = Split-Path $application -Leaf
$scratch = Join-Path $application '.build-winui'

# A running head holds its executable, which the build writes again: it stops first.
Get-Process -Name "${name}WinUI" -ErrorAction SilentlyContinue | Stop-Process -Force
$global:LASTEXITCODE = 0

Initialize-StateUIProjection
$env:STATEUI_WINUI = '1'
swift build --package-path $application -c $Configuration --product "${name}WinUI" --scratch-path $scratch
if ($LASTEXITCODE) { throw "the WinUI head of $name did not build" }
$bin = (swift build --package-path $application -c $Configuration --scratch-path $scratch --show-bin-path).Trim()
$executable = Join-Path $bin "${name}WinUI.exe"
Set-StateUISelfContained -Directory $bin -Executables $executable

Write-Host "starting $executable"
if ($Detach) {
    $process = Start-Process -FilePath $executable -WorkingDirectory $bin -PassThru
    Write-Host "process $($process.Id)"
} else {
    & $executable
    exit $LASTEXITCODE
}

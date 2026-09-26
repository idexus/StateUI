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
# Runs the WinUI host's tests: `swift test` in lib\StateUI.WinUI, whose test
# runner is given the Windows App SDK first, as an application is - WinUI's
# classes are found through the runner's manifest.
#
#   .\test-winui.ps1 [-Filter <test>] [-Conformance] [-ScratchPath <dir>]
#
# Alone it runs the host's own tests, in one process. -Conformance runs the
# contract's families, whose verdicts are WinUI's column of the dictionary -
# each test in a process of its own, as WinUI keeps GDI objects of every
# window a test closes and a process holds only so many
# (docs/design/platforms/winui/conformance.md): some fifteen minutes, so on
# request. A filter runs the tests it names, each in a process of its own.
#
# The tests are built, the Windows App SDK laid beside the runner, and the run
# skips the build.
# ---------------------------------------------------------------------------
param(
    [string]$Filter,
    [switch]$Conformance,
    [string]$ScratchPath
)
. (Join-Path $PSScriptRoot 'tools.ps1')

Initialize-StateUIProjection
$scratch = @()
if ($ScratchPath) { $scratch = @('--scratch-path', $ScratchPath) }

Write-Host 'building the WinUI host tests - SwiftPM reads the packages first, printing nothing'
Write-StateUIEditorBuilds
swift build --package-path $StateUIWinUIHost --build-tests @scratch
if ($LASTEXITCODE) { throw 'the WinUI host tests did not build' }
Write-Host 'laying the Windows App SDK beside the test runner'
$bin = (swift build --package-path $StateUIWinUIHost @scratch --show-bin-path).Trim()
Set-StateUISelfContained -Directory $bin -Executables (Join-Path $bin 'StateUIWinUITests-test-runner.exe')

# A variable's name is its parameter's whatever the case, so the arguments have one of their own.
$apart = @('--parallel', '--num-workers', '1')
$narrowing = if ($Filter) { @('--filter', $Filter) + $apart }
    elseif ($Conformance) { @('--filter', 'WinUIConformanceTests') + $apart }
    else { @('--skip', 'WinUIConformanceTests') }
swift test --package-path $StateUIWinUIHost @scratch --skip-build @narrowing
exit $LASTEXITCODE

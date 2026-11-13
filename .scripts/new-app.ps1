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
# Creates a new StateUI application: `stateui new`, run from this checkout's own
# tool (tools/StateUI.CLI), which owns the rule - HelloWorld under another name,
# naming this checkout by the path from it.
#
#   .\new-app.ps1 -Name MyApp [-AppsDir <dir>]      -AppsDir defaults to <repo>\apps
#
# The first run builds the tool, which fetches its packages.
# ---------------------------------------------------------------------------
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$AppsDir
)

$ErrorActionPreference = "Stop"
$rootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $AppsDir) { $AppsDir = Join-Path $rootDir "apps" }

swift run --quiet --package-path (Join-Path $rootDir "tools/StateUI.CLI") stateui new $Name --directory $AppsDir --checkout $rootDir
exit $LASTEXITCODE

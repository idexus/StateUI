# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Holds a module a host's build made - its facade, a backend - to its record, lib/StateUI/exports/api/<Module>.txt,
# or writes the record under STATEUI_UPDATE_EXPORTS=1: through the core's APISurfaceTests, the one reading of a
# public surface. record.sh's twin, for a host whose scripts are PowerShell's.
#
# USAGE:
#   .\record.ps1 -Module <module> -Modules <modules-dir> [-Arguments <argument>...]
#
#   Modules    the folder the module and those it imports were built in
#   Arguments  what the compiler needs to find the module's C modules: -Xcc, -fmodule-map-file=...
param(
    [Parameter(Mandatory)][string]$Module,
    [Parameter(Mandatory)][string]$Modules,
    [string[]]$Arguments = @()
)
# What swift says on its error stream is no failure; its exit code is.
$ErrorActionPreference = 'Continue'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Write-Host "recording:  $Module"
$host_ = $env:STATEUI_HOST
Remove-Item Env:STATEUI_HOST -ErrorAction SilentlyContinue
$env:STATEUI_API_MODULE = $Module
$env:STATEUI_API_MODULES = $Modules
$env:STATEUI_API_ARGUMENTS = $Arguments -join ' '
try {
    swift test --package-path $repository --filter APISurfaceTests/testTheModuleAHostsScriptNamesIsItsRecord
    if ($LASTEXITCODE) { throw "the record of $Module does not hold" }
} finally {
    Remove-Item Env:STATEUI_API_MODULE, Env:STATEUI_API_MODULES, Env:STATEUI_API_ARGUMENTS -ErrorAction SilentlyContinue
    if ($host_) { $env:STATEUI_HOST = $host_ }
}

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
# What every WinUI script shares, dot-sourced: the versions of C++/WinRT and
# the Windows App SDK - here and nowhere else - the packages fetched where
# they are missing, the projection the relay includes, and a directory made
# self-contained: the Windows App SDK beside the executables, its classes
# registered in a manifest beside each one, and resources.pri. No MSBuild.
# Design: docs/design/platforms/winui/runtime.md#self-contained
# ---------------------------------------------------------------------------

# Native tools write to stderr as they work; each step is judged by its exit code.
$ErrorActionPreference = 'Continue'

$StateUIRepository = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$StateUIWinUIHost = Join-Path $StateUIRepository 'lib\StateUI.WinUI'

# The packages, pinned: the WebView2 is the one WinUI's nuspec names.
$StateUIPackages = [ordered]@{
    'microsoft.windows.cppwinrt'                   = '3.0.260818.1'
    'microsoft.windowsappsdk.winui'                = '1.8.260528001'
    'microsoft.windowsappsdk.foundation'           = '1.8.260527000'
    'microsoft.windowsappsdk.interactiveexperiences' = '1.8.260525001'
    'microsoft.web.webview2'                       = '1.0.3179.45'
}

$StateUIPackageRoot = if ($env:NUGET_PACKAGES) { $env:NUGET_PACKAGES } else { Join-Path $env:USERPROFILE '.nuget\packages' }
$StateUIArchitecture = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }

# One package's folder, fetched from nuget.org first where it is missing - its
# SHA-512 checked against the catalog's before a byte of it is unpacked.
function Get-StateUIPackage([string]$Id) {
    $version = $StateUIPackages[$Id]
    $folder = Join-Path $StateUIPackageRoot "$Id\$version"
    if (Test-Path (Join-Path $folder "$Id.nuspec")) { return $folder }

    Write-Host "fetching $Id $version"
    $download = Join-Path $env:TEMP "$Id.$version.nupkg"
    Invoke-WebRequest "https://api.nuget.org/v3-flatcontainer/$Id/$version/$Id.$version.nupkg" -OutFile $download
    $registration = Invoke-RestMethod "https://api.nuget.org/v3/registration5-semver1/$Id/$version.json"
    $catalog = Invoke-RestMethod $registration.catalogEntry
    $hash = [Convert]::ToBase64String(
        [System.Security.Cryptography.SHA512]::Create().ComputeHash([IO.File]::ReadAllBytes($download)))
    if ($hash -ne $catalog.packageHash) { throw "$Id $version does not match nuget.org's catalog" }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Force $folder | Out-Null
    [IO.Compression.ZipFile]::ExtractToDirectory($download, $folder)
    Remove-Item $download
    return $folder
}

# The C++/WinRT projection of the Windows SDK, WinUI and the Windows App SDK,
# into the host's .projection/, generated again when the versions change -
# beside it, WinUI's header for drawing with DirectX into its elements.
function Initialize-StateUIProjection {
    $projection = Join-Path $StateUIWinUIHost '.projection'
    $stamp = Join-Path $projection 'versions.txt'
    $interop = 'microsoft.ui.xaml.media.dxinterop.h'
    $versions = ($StateUIPackages.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" }) -join "`n"
    if ((Test-Path $stamp) -and ((Get-Content $stamp -Raw).Trim() -eq $versions.Trim()) -and
        (Test-Path (Join-Path $projection $interop))) { return }

    $cppwinrt = Join-Path (Get-StateUIPackage 'microsoft.windows.cppwinrt') 'bin\cppwinrt.exe'
    $winui = Get-StateUIPackage 'microsoft.windowsappsdk.winui'
    $foundation = Get-StateUIPackage 'microsoft.windowsappsdk.foundation'
    $experiences = Get-StateUIPackage 'microsoft.windowsappsdk.interactiveexperiences'
    $webview = Get-StateUIPackage 'microsoft.web.webview2'

    Write-Host 'generating the C++/WinRT projection'
    if (Test-Path $projection) { Remove-Item -Recurse -Force $projection }
    & $cppwinrt -input sdk -input "$winui\metadata" -input "$foundation\metadata" `
        -input "$experiences\metadata\10.0.18362.0" -input "$webview\lib\Microsoft.Web.WebView2.Core.winmd" `
        -output $projection
    if ($LASTEXITCODE) { throw 'cppwinrt could not generate the projection' }
    Copy-Item (Join-Path $winui "include\$interop") $projection
    Set-Content -Path $stamp -Value $versions -Encoding ascii
}

# Says so when the editor is building for its index: it shares the processor
# with a build, and can make it minutes longer.
function Write-StateUIEditorBuilds {
    $builds = Get-CimInstance Win32_Process -Filter "Name = 'swift-build.exe' OR Name = 'swiftc.exe' OR Name = 'clang.exe'" |
        Where-Object { $_.CommandLine -match 'index-build' }
    if ($builds) { Write-Host 'the editor is building for its index, which slows this build' }
}

# Makes `Directory` self-contained for each of `Executables`: the Windows App
# SDK's runtime beside them, every class its components declare registered in
# the manifest beside each one, and resources.pri. An executable is never
# rewritten after its build: the next build would link it again.
function Set-StateUISelfContained([string]$Directory, [string[]]$Executables) {
    $components = 'microsoft.windowsappsdk.winui', 'microsoft.windowsappsdk.foundation',
        'microsoft.windowsappsdk.interactiveexperiences' | ForEach-Object { Get-StateUIPackage $_ }

    foreach ($component in $components) {
        $native = Join-Path $component "runtimes-framework\win-$StateUIArchitecture\native"
        robocopy $native $Directory /E /XO /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "the Windows App SDK could not be copied from $native" }
    }
    $global:LASTEXITCODE = 0

    $manifest = New-StateUIManifest $components
    foreach ($executable in $Executables) { [IO.File]::WriteAllText("$executable.manifest", $manifest) }

    # WinUI's controls find their resources in the application's index.
    Copy-Item (Join-Path $Directory 'Microsoft.UI.Xaml.Controls.pri') (Join-Path $Directory 'resources.pri') -Force
}

# The manifest a self-contained application carries: every class each
# component's package.appxfragment declares, in the file that holds it, and
# the application's own settings.
function New-StateUIManifest([string[]]$Components) {
    $text = [System.Text.StringBuilder]::new()
    [void]$text.AppendLine("<?xml version='1.0' encoding='utf-8' standalone='yes'?>")
    [void]$text.AppendLine("<assembly manifestVersion='1.0' xmlns='urn:schemas-microsoft-com:asm.v1' xmlns:asmv3='urn:schemas-microsoft-com:asm.v3' xmlns:winrtv1='urn:schemas-microsoft-com:winrt.v1'>")
    foreach ($component in $Components) {
        [xml]$fragment = Get-Content (Join-Path $component 'runtimes-framework\package.appxfragment') -Raw
        $names = [System.Xml.XmlNamespaceManager]::new($fragment.NameTable)
        $names.AddNamespace('m', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
        foreach ($server in $fragment.SelectNodes('./m:Fragment/m:Extensions/m:Extension/m:InProcessServer', $names)) {
            [void]$text.AppendLine("  <asmv3:file name='$($server.Path)'>")
            foreach ($class in $server.SelectNodes('./m:ActivatableClass', $names)) {
                [void]$text.AppendLine("    <winrtv1:activatableClass name='$($class.ActivatableClassId)' threadingModel='both'/>")
            }
            [void]$text.AppendLine('  </asmv3:file>')
        }
        foreach ($stub in $fragment.SelectNodes('./m:Fragment/m:Extensions/m:Extension/m:ProxyStub', $names)) {
            # A self-contained application has no singleton for these two.
            if ($stub.Path -in 'PushNotificationsLongRunningTask.ProxyStub.dll', 'Microsoft.Windows.Widgets.dll') { continue }
            [void]$text.AppendLine("  <asmv3:file name='$($stub.Path)'>")
            [void]$text.AppendLine("    <asmv3:comClass clsid='{$($stub.ClassId)}'/>")
            foreach ($interface in $stub.SelectNodes('./m:Interface', $names)) {
                [void]$text.AppendLine("    <asmv3:comInterfaceProxyStub name='$($interface.Name)' iid='{$($interface.InterfaceId)}'/>")
            }
            [void]$text.AppendLine('  </asmv3:file>')
        }
    }
    [void]$text.AppendLine(@'
  <asmv3:application>
    <asmv3:windowsSettings>
      <dpiAwareness xmlns='http://schemas.microsoft.com/SMI/2016/WindowsSettings'>PerMonitorV2</dpiAwareness>
    </asmv3:windowsSettings>
  </asmv3:application>
  <compatibility xmlns='urn:schemas-microsoft-com:compatibility.v1'>
    <application>
      <supportedOS Id='{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}'/>
    </application>
  </compatibility>
</assembly>
'@)
    return $text.ToString()
}

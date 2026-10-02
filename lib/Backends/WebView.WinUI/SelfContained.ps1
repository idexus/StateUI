# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0

# What the web view's backend lays beside a WinUI application linking it: the
# WebView2 package's component, whose classes WinUI's manifest names, and its
# loader - through them WinUI's WebView2 drives the system's WebView2 runtime.
# Run by .scripts/WinUI/tools.ps1 (Set-StateUISelfContained) for the directory
# it makes self-contained, for the architecture the application is built for;
# an application without the backend gets nothing.
param([string]$Directory, [string]$Architecture)

if (-not (Test-Path (Join-Path $Directory 'StateUIWebViewWinUI.dll'))) { return }
$webview = Get-StateUIPackage 'microsoft.web.webview2'
Copy-Item (Join-Path $webview "runtimes\win-$Architecture\native_uap\Microsoft.Web.WebView2.Core.dll") $Directory -Force
Copy-Item (Join-Path $webview "runtimes\win-$Architecture\native\WebView2Loader.dll") $Directory -Force

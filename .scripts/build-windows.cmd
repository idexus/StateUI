@echo off
REM Copyright 2026 the StateUI project authors
REM
REM Licensed under the Apache License, Version 2.0 (the "License");
REM you may not use this file except in compliance with the License.
REM You may obtain a copy of the License at
REM
REM     http://www.apache.org/licenses/LICENSE-2.0
REM
REM Unless required by applicable law or agreed to in writing, software
REM distributed under the License is distributed on an "AS IS" BASIS,
REM WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
REM See the License for the specific language governing permissions and
REM limitations under the License.
REM ---------------------------------------------------------------------------
REM Wrapper for running build-windows.ps1 by hand.
REM
REM The default Windows ExecutionPolicy blocks .ps1 files ("running scripts is
REM disabled on this system"). This bypasses it for one call, without changing
REM any system setting. All arguments are forwarded unchanged.
REM
REM USAGE:
REM     build-windows.cmd
REM     build-windows.cmd -Config debug
REM     build-windows.cmd -Config debug -Arch x64
REM
REM Pure ASCII on purpose: .cmd files are read using the system code page.
REM ---------------------------------------------------------------------------

setlocal

REM Clears the "downloaded from the internet" mark that Windows puts on files
REM extracted from a ZIP; some policies refuse to run them even with Bypass.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Unblock-File -Path '%~dp0build-windows.ps1' -ErrorAction SilentlyContinue"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-windows.ps1" %*

endlocal
exit /b %ERRORLEVEL%

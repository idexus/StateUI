# ---------------------------------------------------------------------------
# Waits until the app process exists, then returns.
#
# Used as a preLaunchTask by the second half of a compound debug configuration.
# Compound sessions start simultaneously, so the debugger that attaches would
# otherwise race the one that launches the app.
#
# Polling rather than a fixed sleep: a cold build can take a minute while a warm
# one is nearly instant, so any constant is either too short sometimes or wasted
# time always.
#
# Pure ASCII on purpose - Windows PowerShell 5.1 reads BOM-less .ps1 as ANSI.
# ---------------------------------------------------------------------------
param(
    [string]$ProcessName = "Gallery",
    [int]$TimeoutSeconds = 180,   # generous, because a cold build is included
    [int]$SettleSeconds  = 1      # extra pause after the process appears
)

Write-Host "Waiting for '$ProcessName' to start (timeout: ${TimeoutSeconds}s)..."

$elapsed = 0
while ($elapsed -lt $TimeoutSeconds) {
    if (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) {
        Write-Host "Found '$ProcessName' after ${elapsed}s."
        # A brief settle: the process exists a moment before its runtime is
        # ready to be attached to.
        Start-Sleep -Seconds $SettleSeconds
        exit 0
    }

    Start-Sleep -Seconds 1
    $elapsed++

    # Progress every 10s, so a long wait does not look like a hang.
    if ($elapsed % 10 -eq 0) {
        Write-Host "  still waiting... (${elapsed}s)"
    }
}

Write-Host "Timed out after ${TimeoutSeconds}s - '$ProcessName' never appeared."
Write-Host "The build may have failed; check the other debug session's output."
exit 1

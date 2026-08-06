# cleanup-locks.ps1
# Reasonix SessionStart hook: remove ORPHAN session lease locks.
# An orphan lock is a *.lease.lock / *.jsonl.lock whose session file is NOT
# currently open in any desktop tab (per desktop-tabs.json). Such locks are
# leftovers from abnormal exits (crash / force kill) and make Reasonix think a
# session is "still running in the background", causing false "workspace
# occupied" errors when opening multiple projects.
#
# Safety: only locks whose session is absent from the active tab set are
# removed. Never touches .display.json.lock / .planner-display.json.lock.
# Prints nothing on success (SessionStart stdout is injected into the next
# model turn), only short stderr diagnostics.

$ErrorActionPreference = 'Stop'

$homeDir = Join-Path $env:APPDATA 'reasonix'
$projectsDir = Join-Path $homeDir 'projects'
$tabsFile = Join-Path $homeDir 'desktop-tabs.json'

if (-not (Test-Path -LiteralPath $projectsDir)) { exit 0 }

# 1) Active session paths from desktop-tabs.json (case-insensitive)
$active = @{}
try {
    if (Test-Path -LiteralPath $tabsFile) {
        $tabs = Get-Content -LiteralPath $tabsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($t in $tabs.tabs) {
            if ($t.sessionPath) { $active[[string]$t.sessionPath.ToLowerInvariant()] = $true }
        }
    }
} catch {
    # If tabs cannot be parsed, be conservative: do not delete anything.
    exit 0
}

$deleted = 0
$failed = 0

Get-ChildItem -LiteralPath $projectsDir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like '*.lease.lock' -or $_.Name -like '*.jsonl.lock' } |
    ForEach-Object {
        $lock = $_
        if ($lock.Name -like '*.lease.lock') {
            $session = $lock.FullName.Substring(0, $lock.FullName.Length - '.lease.lock'.Length)
        } else {
            $session = $lock.FullName.Substring(0, $lock.FullName.Length - '.lock'.Length)
        }
        if (-not $active.ContainsKey($session.ToLowerInvariant())) {
            try {
                Remove-Item -LiteralPath $lock.FullName -Force -ErrorAction Stop
                $deleted++
            } catch {
                $failed++
                [Console]::Error.WriteLine('lock-cleanup: cannot remove ' + $lock.FullName + ' : ' + $_.Exception.Message)
            }
        }
    }

if ($deleted -gt 0 -or $failed -gt 0) {
    [Console]::Error.WriteLine('lock-cleanup: removed ' + $deleted + ' orphan lock(s), failed ' + $failed)
}
exit 0

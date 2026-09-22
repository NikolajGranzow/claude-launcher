<#
.SYNOPSIS
    Claude Code project launcher - pick a project from a menu and start Claude Code in it.

.DESCRIPTION
    Your project list lives in a JSON config file (default: %USERPROFILE%\.claude-launcher.json),
    so this script stays free of personal paths and can be shared as-is. Projects are added and
    removed from inside the menu - no editing the script.

.PARAMETER ConfigPath
    Alternative location for the project list. Defaults to %USERPROFILE%\.claude-launcher.json

.NOTES
    Requires PowerShell 5.1+ and the Claude Code CLI ("claude") on PATH.
#>

[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $env:USERPROFILE '.claude-launcher.json')
)

# --- config -----------------------------------------------------------------

function Read-ProjectConfig {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return @() }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
        $data = $raw | ConvertFrom-Json
    } catch {
        Write-Host "Could not read $Path - starting with an empty list." -ForegroundColor Yellow
        return @()
    }

    # ConvertFrom-Json hands back a bare object when the file holds a single entry.
    return @($data | Where-Object { $_ -and $_.Path })
}

function Save-ProjectConfig {
    param([object[]]$Projects, [string]$Path)

    $json = ConvertTo-Json -InputObject @($Projects) -Depth 3
    # Force array syntax so a one-project config still round-trips as a list.
    if (-not $json.TrimStart().StartsWith('[')) { $json = "[$json]" }
    Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
}

function Resolve-ProjectPath {
    param([string]$Raw)

    $p = $Raw.Trim()
    $p = $p.Trim('"').Trim("'").Trim()
    if ([string]::IsNullOrWhiteSpace($p)) { return $null }

    $p = [Environment]::ExpandEnvironmentVariables($p)
    try { return (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path } catch { return $p }
}

# --- menu actions -----------------------------------------------------------

function Add-Project {
    param([object[]]$Projects, [string]$Path)

    Write-Host ""
    Write-Host "Add a project" -ForegroundColor Cyan
    Write-Host "Paste or drag the project folder into this window, then press Enter."
    Write-Host "(Leave empty to cancel.)"
    Write-Host ""

    $folder = Resolve-ProjectPath (Read-Host "Folder")
    if (-not $folder) { return $Projects }

    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        Write-Host "That folder does not exist: $folder" -ForegroundColor Red
        Read-Host "Press Enter to go back" | Out-Null
        return $Projects
    }

    $existing = $Projects | Where-Object { $_.Path -eq $folder }
    if ($existing) {
        Write-Host "Already on the list as '$($existing.Name)'." -ForegroundColor Yellow
        Read-Host "Press Enter to go back" | Out-Null
        return $Projects
    }

    $default = Split-Path -Leaf $folder
    $name = (Read-Host "Name [$default]").Trim()
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $default }

    $updated = @($Projects) + [pscustomobject]@{ Name = $name; Path = $folder }
    Save-ProjectConfig -Projects $updated -Path $Path

    Write-Host "Added '$name'." -ForegroundColor Green
    Start-Sleep -Milliseconds 700
    return $updated
}

function Remove-Project {
    param([object[]]$Projects, [string]$Path)

    if ($Projects.Count -eq 0) { return $Projects }

    Write-Host ""
    $answer = (Read-Host "Remove which number? (empty to cancel)").Trim()
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Projects }

    $index = 0
    if (-not [int]::TryParse($answer, [ref]$index) -or $index -lt 1 -or $index -gt $Projects.Count) {
        Write-Host "No project with that number." -ForegroundColor Red
        Start-Sleep -Milliseconds 900
        return $Projects
    }

    $target = $Projects[$index - 1]
    $confirm = (Read-Host "Remove '$($target.Name)' from the menu? (y/N)").Trim()
    if ($confirm -notmatch '^(y|yes)$') { return $Projects }

    $updated = @($Projects | Where-Object { $_ -ne $target })
    Save-ProjectConfig -Projects $updated -Path $Path

    Write-Host "Removed '$($target.Name)'. The folder itself was not touched." -ForegroundColor Green
    Start-Sleep -Milliseconds 900
    return $updated
}

function Test-ConversationHistory {
    <#
        Claude Code keys every conversation to the directory it was started in and
        stores it as ~\.claude\projects\<path, ':' and '\' swapped for '-'>\*.jsonl.

        $true means there is definitely something for "claude -c" to resume. $false
        means "nothing found" - which also covers "the layout is not what we expect",
        so the caller still gives -c the first go and a wrong guess costs nothing.
    #>
    param([string]$ProjectPath)

    $store = Join-Path $env:USERPROFILE '.claude\projects'
    $folder = Join-Path $store ($ProjectPath -replace '[:\\]', '-')
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) { return $false }

    $sessions = @(Get-ChildItem -LiteralPath $folder -Filter '*.jsonl' -File -ErrorAction SilentlyContinue)
    return $sessions.Count -gt 0
}

function Test-ProjectFolder {
    param([object]$Project)

    if (Test-Path -LiteralPath $Project.Path -PathType Container) { return $true }

    Write-Host ""
    Write-Host "The folder is gone: $($Project.Path)" -ForegroundColor Red
    Write-Host "Use [R] to remove it, or [A] to add it again at its new location." -ForegroundColor Yellow
    Read-Host "Press Enter to go back" | Out-Null
    return $false
}

# --- main loop --------------------------------------------------------------

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "Could not find the 'claude' command on PATH." -ForegroundColor Red
    Write-Host "Install Claude Code first: https://claude.com/claude-code" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to close" | Out-Null
    exit 1
}

# @(...) on every assignment below: PowerShell unrolls a single-element array on return,
# which would otherwise turn a one-project config into a bare object.
$projects = @(Read-ProjectConfig -Path $ConfigPath)
$selected = $null

while ($null -eq $selected) {
    Clear-Host
    Write-Host ""
    Write-Host "==================================="
    Write-Host "   Choose a Claude Code project"
    Write-Host "==================================="
    Write-Host ""

    if ($projects.Count -eq 0) {
        Write-Host "  No projects yet - press [A] to add your first one." -ForegroundColor Yellow
    } else {
        for ($i = 0; $i -lt $projects.Count; $i++) {
            $p = $projects[$i]
            $missing = ''
            if (-not (Test-Path -LiteralPath $p.Path -PathType Container)) { $missing = '  (folder missing)' }
            Write-Host ("  [{0}]  {1}{2}" -f ($i + 1), $p.Name, $missing)
        }
    }

    Write-Host ""
    Write-Host "  [A]  Add a project"
    if ($projects.Count -gt 0) { Write-Host "  [R]  Remove a project" }
    Write-Host "  [Q]  Quit"
    Write-Host ""
    Write-Host "  Config: $ConfigPath" -ForegroundColor DarkGray
    Write-Host ""

    $choice = (Read-Host "Type a number or letter and press Enter").Trim()

    switch -Regex ($choice) {
        '^(?i)a$' { $projects = @(Add-Project    -Projects $projects -Path $ConfigPath); continue }
        '^(?i)r$' { $projects = @(Remove-Project -Projects $projects -Path $ConfigPath); continue }
        '^(?i)q$' { exit 0 }
        '^\d+$' {
            $index = [int]$choice
            if ($index -ge 1 -and $index -le $projects.Count) {
                $candidate = $projects[$index - 1]
                if (Test-ProjectFolder -Project $candidate) { $selected = $candidate }
                continue
            }
            Write-Host "No project with that number." -ForegroundColor Red
            Start-Sleep -Milliseconds 900
            continue
        }
        default {
            Write-Host "Not a valid choice." -ForegroundColor Red
            Start-Sleep -Milliseconds 900
            continue
        }
    }
}

# --- launch -----------------------------------------------------------------
#
# Keep every claude call below at the top level of the script. If one runs inside a
# function whose output is consumed - if (Start-Claude ...), $x = Start-Claude, or a
# pipeline - PowerShell captures the native command's stdout. Claude Code then sees a
# redirected stdout, assumes --print mode, and exits with "Input must be provided
# either through stdin or as a prompt argument" instead of starting an interactive
# session.

# Check before launching, while the exit code still means something we can trust.
$hasHistory = Test-ConversationHistory -ProjectPath $selected.Path

Set-Location -LiteralPath $selected.Path
Write-Host ""
Write-Host "Starting Claude Code in: $($selected.Path)" -ForegroundColor Green
Write-Host ""

if ($hasHistory) {
    # Something is there to resume, so a non-zero exit is the resumed session itself
    # ending - a crash, or just Ctrl+C. Starting a second Claude on top of that would
    # drop the user into an empty prompt they never asked for, so this branch has no
    # fallback: -c gets to fail loudly instead.
    claude -c
} else {
    # Nothing found to resume, so -c should hit "no conversation to continue" and exit
    # non-zero without ever opening a session - which makes falling back safe here.
    # -c still goes first, so an unrecognised store layout just resumes as normal.
    claude -c
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "No previous conversation here - starting a new session..." -ForegroundColor Yellow
        Write-Host ""
        claude
    }
}
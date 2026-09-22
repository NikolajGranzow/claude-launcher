<#
.SYNOPSIS
    Creates a desktop shortcut that opens the Claude Code project launcher.

.DESCRIPTION
    Run this once after cloning or downloading the repo. It puts a "Claude Launcher"
    shortcut on your desktop; right-click it and choose "Pin to taskbar" if you want
    it permanently within reach.
#>

[CmdletBinding()]
param(
    [string]$Name = 'Claude Launcher'
)

$script = Join-Path $PSScriptRoot 'claude-launcher.ps1'
if (-not (Test-Path -LiteralPath $script)) {
    Write-Host "Could not find claude-launcher.ps1 next to this script." -ForegroundColor Red
    exit 1
}

$linkPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "$Name.lnk"

$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($linkPath)
$link.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$link.Arguments = "-NoExit -ExecutionPolicy Bypass -File `"$script`""
$link.WorkingDirectory = $PSScriptRoot
$link.IconLocation = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe,0"
$link.Description = 'Pick a project and start Claude Code in it'
$link.Save()

Write-Host ""
Write-Host "Created: $linkPath" -ForegroundColor Green
Write-Host "Right-click it and choose 'Pin to taskbar' to keep it handy." -ForegroundColor Yellow
Write-Host ""

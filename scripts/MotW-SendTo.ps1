<#
.SYNOPSIS
  Interactive wrapper for MotW.ps1 - designed for "Send To" context menu usage.

.DESCRIPTION
  Provides an interactive prompt for zone reassignment when invoked via "Send To".
  Shows current zone and prompts user to select target zone.
  No registry editing required - uses Windows "Send To" folder.

.PARAMETER FilePath
  Path to the file to process (passed from "Send To" menu)
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$FilePath
)

# Resolve the path to MotW.ps1 (should be in the same directory)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$MotWScript = Join-Path $ScriptDir "MotW.ps1"

if (-not (Test-Path $MotWScript)) {
    Write-Host "ERROR: MotW.ps1 not found at: $MotWScript" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Dot-source MotW.ps1 to get access to helper functions
. $MotWScript -Action status -ArgsRest @() -ErrorAction SilentlyContinue 2>$null | Out-Null

# Get current zone
$currentZone = Get-ZoneId -Path $FilePath

# Display header
$fileName = Split-Path -Leaf $FilePath
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "MotW Zone Reassignment" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""
Write-Host "File: " -NoNewline
Write-Host $fileName -ForegroundColor White
Write-Host ""

if ($null -eq $currentZone) {
    Write-Host "Status: " -NoNewline
    Write-Host "No MotW (already clean)" -ForegroundColor Green
    Write-Host ""
    Write-Host "This file has no Mark-of-the-Web metadata."
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 0
}

# Display current zone with color coding
$zoneName = Get-ZoneName -ZoneId $currentZone
$zoneColor = switch ($currentZone) {
    0 { 'Cyan' }
    1 { 'Green' }
    2 { 'Yellow' }
    3 { 'Red' }
    4 { 'Magenta' }
    default { 'White' }
}

Write-Host "Current Zone: " -NoNewline
Write-Host "Zone $currentZone - $zoneName" -ForegroundColor $zoneColor
Write-Host ""

# Show prompt
Write-Host "Reassign to which zone?" -ForegroundColor White
Write-Host ""

# Only show zones lower than current zone (can only move down or remove)
if ($currentZone -gt 2) {
    Write-Host "  [2] " -NoNewline -ForegroundColor Yellow
    Write-Host "Zone 2 - Trusted Sites " -NoNewline
    Write-Host "(recommended)" -ForegroundColor Gray
}
if ($currentZone -gt 1) {
    Write-Host "  [1] " -NoNewline -ForegroundColor Green
    Write-Host "Zone 1 - Local Intranet"
}
if ($currentZone -gt 0) {
    Write-Host "  [0] " -NoNewline -ForegroundColor Cyan
    Write-Host "Zone 0 - Local Machine"
}
Write-Host "  [R] " -NoNewline -ForegroundColor White
Write-Host "Remove MotW entirely " -NoNewline
Write-Host "(not recommended)" -ForegroundColor Gray
Write-Host "  [C] " -NoNewline -ForegroundColor White
Write-Host "Cancel (do nothing)"
Write-Host ""

# Get user choice
$choice = Read-Host "Your choice"

# Process choice
switch ($choice.ToUpper()) {
    '2' {
        if ($currentZone -le 2) {
            Write-Host "`nFile is already at Zone 2 or lower." -ForegroundColor Yellow
            break
        }
        Write-Host "`nReassigning to Zone 2 (Trusted Sites)..." -ForegroundColor Cyan
        & $MotWScript reassign $FilePath -TargetZone 2
    }
    '1' {
        if ($currentZone -le 1) {
            Write-Host "`nFile is already at Zone 1 or lower." -ForegroundColor Yellow
            break
        }
        Write-Host "`nReassigning to Zone 1 (Local Intranet)..." -ForegroundColor Cyan
        & $MotWScript reassign $FilePath -TargetZone 1
    }
    '0' {
        if ($currentZone -le 0) {
            Write-Host "`nFile is already at Zone 0." -ForegroundColor Yellow
            break
        }
        Write-Host "`nReassigning to Zone 0 (Local Machine)..." -ForegroundColor Cyan
        & $MotWScript reassign $FilePath -TargetZone 0
    }
    'R' {
        Write-Host "`nRemoving MotW entirely..." -ForegroundColor Yellow
        Write-Host "Note: It's recommended to reassign to a zone instead." -ForegroundColor Gray
        & $MotWScript unblock $FilePath
    }
    'C' {
        Write-Host "`nCancelled. No changes made." -ForegroundColor Gray
    }
    default {
        Write-Host "`nInvalid choice. No changes made." -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

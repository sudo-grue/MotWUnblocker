<#
.SYNOPSIS
  Simple wrapper for MotW.ps1 - designed for "Send To" context menu usage.

.DESCRIPTION
  Reassigns files from higher zones (3-4) to Zone 2 (Trusted Sites).
  Automatically processes files without interactive prompts.
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

# Source the main script to get helper functions
. $MotWScript -Action status -ArgsRest @() -ErrorAction SilentlyContinue 2>$null | Out-Null

$currentZone = Get-ZoneId -Path $FilePath
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

# Only reassign Zone 3 (Internet) - never touch Zone 4 (Restricted Sites)
if ($currentZone -eq 4) {
    Write-Host "WARNING: Zone 4 (Restricted Sites) detected." -ForegroundColor Red
    Write-Host "This file has been explicitly restricted by policy." -ForegroundColor Yellow
    Write-Host "It should NOT be reassigned. No action taken." -ForegroundColor Yellow
} elseif ($currentZone -eq 3) {
    Write-Host "Reassigning to Zone 2 (Trusted Sites)..." -ForegroundColor Cyan
    Write-Host ""
    & $MotWScript reassign $FilePath -TargetZone 2 -Confirm:$false
} else {
    Write-Host "File is already at Zone $currentZone or lower - no action needed." -ForegroundColor Green
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

<#
.SYNOPSIS
  Builds release binaries and generates SHA256 checksums.

.DESCRIPTION
  Builds Framework-Dependent version of MotWasher (default) and MotWatcher,
  copies PowerShell scripts, generates release notes and checksums.

  Version 1.1.0
#>

[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [string]$Version = "1.1.0"
)

$ErrorActionPreference = 'Stop'

$ReleaseDir = Join-Path $PSScriptRoot "release"
$ChecksumFile = Join-Path $ReleaseDir "checksums.txt"
$ReleaseNotesFile = Join-Path $ReleaseDir "RELEASE-NOTES.md"

Write-Host "`nBuilding MotW Tools v$Version Release..." -ForegroundColor Cyan

# Run tests before building
Write-Host "`nRunning tests..." -ForegroundColor Cyan

Write-Host "  PowerShell tests (Pester)..." -ForegroundColor Gray
try {
    $pesterResult = Invoke-Pester -Path "tests\MotW.Tests.ps1" -PassThru -Quiet

    if ($pesterResult.FailedCount -gt 0) {
        Write-Host "    PowerShell: $($pesterResult.PassedCount) passed, $($pesterResult.FailedCount) failed" -ForegroundColor Yellow
    }
    else {
        Write-Host "    PowerShell: All $($pesterResult.PassedCount) tests passed" -ForegroundColor Green
    }
}
catch {
    Write-Host "    PowerShell: Test execution failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "  C# tests (xUnit)..." -ForegroundColor Gray
try {
    $dotnetTestOutput = dotnet test MotW.Shared.Tests/MotW.Shared.Tests.csproj --nologo --verbosity quiet 2>&1
    $lastLine = $dotnetTestOutput | Select-Object -Last 1

    if ($lastLine -match 'Passed!\s+-\s+Failed:\s+(\d+),\s+Passed:\s+(\d+)') {
        $failed = [int]$matches[1]
        $passed = [int]$matches[2]

        if ($failed -gt 0) {
            Write-Host "    C#: $passed passed, $failed failed" -ForegroundColor Yellow
        }
        else {
            Write-Host "    C#: All $passed tests passed" -ForegroundColor Green
        }
    }
    else {
        Write-Host "    C#: Tests completed (check output for details)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "    C#: Test execution failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

if (Test-Path $ReleaseDir) {
    Write-Host "`nCleaning existing release directory..." -ForegroundColor Yellow
    try {
        Remove-Item $ReleaseDir -Recurse -Force -ErrorAction Stop
    }
    catch {
        Write-Host "  Warning: Could not remove release directory. It may be in use." -ForegroundColor Yellow
        Write-Host "  Attempting to clean contents instead..." -ForegroundColor Yellow
        Get-ChildItem $ReleaseDir -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir | Out-Null
}

Write-Host "`nBuilding MotWasher..." -ForegroundColor Cyan
Set-Location (Join-Path $PSScriptRoot "MotWasher")

dotnet publish -c $Configuration -nologo

if ($LASTEXITCODE -ne 0) {
    Write-Error "MotWasher build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Set-Location $PSScriptRoot

Write-Host "`nBuilding MotWatcher..." -ForegroundColor Cyan
Set-Location (Join-Path $PSScriptRoot "MotWatcher")

dotnet publish -c $Configuration -nologo

if ($LASTEXITCODE -ne 0) {
    Write-Error "MotWatcher build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Set-Location $PSScriptRoot

Write-Host "`nCopying release assets..." -ForegroundColor Cyan

$MotWasherExe = "MotWasher\bin\$Configuration\publish\MotWasher.exe"
$MotWatcherExe = "MotWatcher\bin\$Configuration\publish\MotWatcher.exe"

Copy-Item $MotWasherExe -Destination $ReleaseDir
Copy-Item $MotWatcherExe -Destination $ReleaseDir
Copy-Item "scripts\MotW.ps1" -Destination $ReleaseDir
Copy-Item "scripts\MotW-SendTo.ps1" -Destination $ReleaseDir

# Generate Install-MotWContext.ps1 with fresh embedded MotW.ps1
Write-Host "  Injecting current MotW.ps1 into Install-MotWContext.ps1..." -ForegroundColor Gray
$motwContent = Get-Content "scripts\MotW.ps1" -Raw
$installerTemplate = Get-Content "scripts\Install-MotWContext.ps1"

# Find the start and end of the embedded script
$startLine = -1
$endLine = -1
for ($i = 0; $i -lt $installerTemplate.Count; $i++) {
    if ($installerTemplate[$i] -match '^\s*\$motwScriptContent = @''$') {
        $startLine = $i
    }
    if ($startLine -ge 0 -and $installerTemplate[$i] -match '^''@$') {
        $endLine = $i
        break
    }
}

if ($startLine -ge 0 -and $endLine -gt $startLine) {
    # Build new installer with injected content
    $newInstaller = @()
    $newInstaller += $installerTemplate[0..($startLine)]
    $newInstaller += $motwContent
    $newInstaller += $installerTemplate[$endLine..($installerTemplate.Count - 1)]

    Set-Content -Path (Join-Path $ReleaseDir "Install-MotWContext.ps1") -Value $newInstaller -Encoding UTF8
    Write-Host "  Install-MotWContext.ps1 generated with v$Version MotW.ps1 embedded" -ForegroundColor Green
}
else {
    Write-Error "Failed to find embedded script markers in Install-MotWContext.ps1"
}

Copy-Item "scripts\Uninstall-MotWContext.ps1" -Destination $ReleaseDir

Write-Host "`nGenerating release notes..." -ForegroundColor Cyan

$releaseNotes = @"
# MotW Tools v$Version

Major philosophical shift from "MotW removal" to "zone reassignment" with improved policy messaging.

## What's New in v1.1.0

**Philosophy Change: Zone Reassignment > Removal**
- Tools now emphasize reassigning files between security zones rather than removing MotW entirely
- Clear messaging: This is a temporary workaround while Group Policy zone configurations are being implemented
- Target audience: Professionals working in environments where zone policies are still being configured
- Intentional friction (progressive washing) reminds users that configuring zone policies is the proper solution

**PowerShell Scripts (v1.1.0)**
- **NEW**: ``reassign`` action (default) - Progressive zone washing (3→2→1→0→remove)
- **NEW**: ``-TargetZone`` parameter for direct zone reassignment
- **NEW**: Zone helper functions (Get-ZoneId, Set-ZoneId, Get-ZoneName)
- **NEW**: RFC 5424 logging levels (Emergency/Alert/Critical/Error/Warning/Notice/Info/Debug)
- **NEW**: Interactive MotW-SendTo.ps1 wrapper for "Send To" menu
- Color-coded status output by zone (Red=Zone 3, Yellow=Zone 2, Green=Zone 1, Cyan=Zone 0)

**Installer Improvements (v1.1.0)**
- **NEW**: Environment detection (Send To, Context Menu, .NET Runtime availability)
- **NEW**: Smart recommendations based on environment capabilities
- Creates "Send To → MotW - Reassign" shortcut with interactive zone selection
- Detects restrictive environments and adapts installation accordingly
- Installs MotW-SendTo.ps1 interactive wrapper

**GUI Application**
- Added keyboard shortcuts (Ctrl+A, Ctrl+U, Ctrl+L, Delete, F5, Ctrl+B)
- Added Select All toggle functionality
- Added Clear All functionality
- Converted to async/await for responsive UI during file operations
- Added thread-safe logging with automatic rotation
- Improved file size display (KB/MB/GB formatting)
- Enhanced error handling with specific exception messages

## Downloads

**GUI Applications**
- **MotWasher.exe** (≈196 KB) - Batch file processor - Requires [.NET 9 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/9.0)
- **MotWatcher.exe** (≈197 KB) - System tray file watcher - Requires [.NET 9 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/9.0)

**PowerShell Scripts**
- **MotW.ps1** - CLI tool for zone reassignment and status checking
- **MotW-SendTo.ps1** - Interactive wrapper for "Send To" menu integration
- **Install-MotWContext.ps1** - One-click installer with environment detection
- **Uninstall-MotWContext.ps1** - Clean uninstaller

**Verification**
- **checksums.txt** - SHA256 hashes for all downloads

## Features

**MotWasher (GUI)**
- Batch file processing with drag-and-drop
- Real-time MotW status checking
- Keyboard shortcuts (Ctrl+A, Ctrl+U, Delete, F5, etc.)
- Comprehensive logging to %LOCALAPPDATA%\MotW\motw.log
- No admin rights required

**MotWatcher (System Tray)**
- Background file monitoring and automatic MotW removal
- Configurable watched directories via Settings UI
- File type filtering per directory
- Zone ID threshold filtering
- Auto-start with Windows option
- Start watching on launch option
- Debouncing for partial downloads
- Low resource usage
- Comprehensive logging to %LOCALAPPDATA%\MotW\motw.log

**MotW.ps1 (PowerShell)**
- Four actions: ``reassign`` (default), ``add``, ``status``, ``unblock``
- Progressive zone washing (3→2→1→0→remove) or direct with ``-TargetZone``
- Zone helper functions (Get-ZoneId, Set-ZoneId, Get-ZoneName)
- ``-WhatIf`` and ``-Confirm`` support for safe testing
- Recursive directory processing with ``-Recurse``
- RFC 5424 logging levels (Emergency through Debug)
- Color-coded zone output (Red=Zone 3, Yellow=Zone 2, Green=Zone 1, Cyan=Zone 0)

**MotW-SendTo.ps1 (Interactive Wrapper)**
- Educational interactive prompt for zone selection
- Only shows valid target zones (can only move down or remove)
- Color-coded current zone display
- Intentional friction - requires conscious choice
- Works via "Send To" menu (no registry editing required)

## Quick Start

**MotWasher (Batch Processing)**: Download ``MotWasher.exe`` and run

**MotWatcher (Background Monitoring)**: Download ``MotWatcher.exe``, run, right-click tray icon → Settings to configure

**PowerShell**:
``````powershell
# Install (with environment detection)
.\Install-MotWContext.ps1

# Progressive zone washing
MotW.ps1 reassign *.pdf

# Direct reassignment to Trusted Sites
MotW.ps1 reassign *.pdf -TargetZone 2

# Check zone status
MotW.ps1 status .
``````

**Send To Menu**:
Right-click file → Send To → MotW - Reassign → Choose target zone interactively

## Security

**Verify Downloads:**
``````powershell
# Windows PowerShell
Get-FileHash MotWasher.exe -Algorithm SHA256
# Compare with checksums.txt
``````

## Documentation

See [README.md](https://github.com/sudo-grue/MotWTools/blob/main/README.md) for full documentation.

## System Requirements
- Windows 10 (21H2+) or Windows 11 x64
- .NET 9 Desktop Runtime - [Download here](https://dotnet.microsoft.com/download/dotnet/9.0)
"@

Set-Content -Path $ReleaseNotesFile -Value $releaseNotes -Encoding UTF8

Write-Host "`nGenerating SHA256 checksums..." -ForegroundColor Cyan

$files = Get-ChildItem -Path $ReleaseDir -File | Where-Object {
    $_.Name -ne "checksums.txt" -and $_.Name -ne "RELEASE-NOTES.md"
}

$checksums = @()
foreach ($file in $files) {
    $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
    $checksums += "$($hash.Hash.ToLower())  $($file.Name)"
    Write-Host "  $($file.Name): $($hash.Hash.ToLower())" -ForegroundColor Gray
}

Set-Content -Path $ChecksumFile -Value ($checksums -join "`n") -Encoding UTF8

Write-Host "`nRelease assets ready in: $ReleaseDir" -ForegroundColor Green
Write-Host "`nFiles included:" -ForegroundColor Cyan
Get-ChildItem -Path $ReleaseDir -File | ForEach-Object {
    $size = if ($_.Length -gt 1MB) {
        "{0:N2} MB" -f ($_.Length / 1MB)
    }
    else {
        "{0:N2} KB" -f ($_.Length / 1KB)
    }
    Write-Host "  $($_.Name) ($size)" -ForegroundColor White
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Review files in: $ReleaseDir"
Write-Host "  2. Commit and push code: git add . && git commit -m 'Release v$Version' && git push"
Write-Host "  3. Create GitHub release and upload all files from release/"
Write-Host "`nReady to create GitHub release!" -ForegroundColor Green

<#
.SYNOPSIS
  Builds release binaries and generates SHA256 checksums.

.DESCRIPTION
  Builds Framework-Dependent version of MotWasher (default) and MotWatcher,
  copies PowerShell scripts, generates release notes and checksums.

  Version 1.0.0
#>

[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [string]$Version = "1.0.1"
)

$ErrorActionPreference = 'Stop'

$ReleaseDir = Join-Path $PSScriptRoot "release"
$ChecksumFile = Join-Path $ReleaseDir "checksums.txt"
$ReleaseNotesFile = Join-Path $ReleaseDir "RELEASE-NOTES.md"

Write-Host "`nBuilding MotW Tools v$Version Release..." -ForegroundColor Cyan

if (Test-Path $ReleaseDir) {
    Write-Host "Cleaning existing release directory..." -ForegroundColor Yellow
    Remove-Item $ReleaseDir -Recurse -Force
}

New-Item -ItemType Directory -Path $ReleaseDir | Out-Null

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
Copy-Item "scripts\Install-MotWContext.ps1" -Destination $ReleaseDir
Copy-Item "scripts\Uninstall-MotWContext.ps1" -Destination $ReleaseDir

Write-Host "`nGenerating release notes..." -ForegroundColor Cyan

$releaseNotes = @"
# MotW Tools v$Version

Improved release of MotW Tools with enhanced PowerShell logging and error handling.

## What's New in v1.0.1

**PowerShell Scripts**
- Added comprehensive logging to all PowerShell scripts
- Added ``-WhatIf`` and ``-Confirm`` support for safe testing
- Optimized path resolution with hashtable-based deduplication
- Enhanced error handling with specific error messages
- Added colored console output for better visibility
- Added success/failure counters for batch operations
- Hybrid installer approach (tries local MotW.ps1, falls back to embedded)
- Proper COM object disposal in installer

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
- **MotW.ps1** - CLI tool for batch operations
- **Install-MotWContext.ps1** - One-click installer
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
- Three actions: ``unblock``, ``add``, ``status``
- ``-WhatIf`` and ``-Confirm`` support for safe testing
- Recursive directory processing with ``-Recurse``
- Comprehensive logging to %LOCALAPPDATA%\MotW\motw.log
- Colored console output
- Success/failure counters

## Quick Start

**MotWasher (Batch Processing)**: Download ``MotWasher.exe`` and run

**MotWatcher (Background Monitoring)**: Download ``MotWatcher.exe``, run, right-click tray icon → Settings to configure

**PowerShell**:
``````powershell
.\Install-MotWContext.ps1
MotW.ps1 *.pdf
``````

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
    } else {
        "{0:N2} KB" -f ($_.Length / 1KB)
    }
    Write-Host "  $($_.Name) ($size)" -ForegroundColor White
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Review files in: $ReleaseDir"
Write-Host "  2. Commit and push code: git add . && git commit -m 'Release v$Version' && git push"
Write-Host "  3. Create GitHub release and upload all files from release/"
Write-Host "`nReady to create GitHub release!" -ForegroundColor Green

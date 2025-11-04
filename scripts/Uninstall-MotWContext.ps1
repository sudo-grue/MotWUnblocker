<#
.SYNOPSIS
  Uninstalls MotW CLI tools and related integrations.

.DESCRIPTION
  Removes MotW context menu shortcuts, optionally removes from user PATH,
  and optionally deletes the installation directory.

  Version 1.1.0

.PARAMETER KeepPath
  Do not remove MotW from user PATH

.PARAMETER RemoveFiles
  Delete the installation directory (%USERPROFILE%\Tools\MotW)

.EXAMPLE
  .\Uninstall-MotWContext.ps1
  Standard uninstallation - removes shortcuts and PATH entry

.EXAMPLE
  .\Uninstall-MotWContext.ps1 -KeepPath
  Remove shortcuts only, keep PATH entry

.EXAMPLE
  .\Uninstall-MotWContext.ps1 -RemoveFiles
  Complete removal including installation directory
#>

[CmdletBinding()]
param(
    [switch]$KeepPath,
    [switch]$RemoveFiles
)

$Script:Version = "1.1.0"
$ErrorActionPreference = 'Stop'

$ToolRoot = Join-Path $env:USERPROFILE 'Tools\MotW'
$SendToDir = Join-Path $env:APPDATA 'Microsoft\Windows\SendTo'
$SendToLnk = Join-Path $SendToDir 'MotW - Reassign.lnk'
$SendToLnkOld = Join-Path $SendToDir 'MotW - Unblock.lnk'
$LogPath = Join-Path $env:LOCALAPPDATA "MotW\uninstall.log"
$LogDir = Split-Path $LogPath -Parent
$LogFolder = Join-Path $env:LOCALAPPDATA "MotW"

function Write-UninstallLog {
    param(
        [Parameter(Mandatory)][string]$Level,
        [Parameter(Mandatory)][string]$Message
    )

    try {
        if (-not (Test-Path $LogDir)) {
            New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
        $logLine = "$timestamp [$Level] $Message"
        Add-Content -Path $LogPath -Value $logLine -ErrorAction SilentlyContinue

        switch ($Level) {
            "INFO" { Write-Host $Message -ForegroundColor Green }
            "WARN" { Write-Warning $Message }
            "ERROR" { Write-Error $Message }
        }
    }
    catch {
        Write-Debug "Logging failed: $_"
    }
}

Write-UninstallLog -Level "INFO" -Message "MotW Uninstaller v$Script:Version started"

# Detection: what is currently installed?
$detected = @{
    Scripts        = Test-Path $ToolRoot
    SendToShortcut = (Test-Path $SendToLnk) -or (Test-Path $SendToLnkOld)
    InPath         = $false
    LogFolder      = Test-Path $LogFolder
}

# Check PATH
$pathUser = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($pathUser) {
    $pathEntries = $pathUser.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
    $detected.InPath = $null -ne ($pathEntries | Where-Object { $_.Trim() -eq $ToolRoot })
}

# Show what was detected
Write-Host "`nDetected Installations:" -ForegroundColor Cyan
if ($detected.Scripts) {
    Write-Host "  [X] Scripts in $ToolRoot" -ForegroundColor Yellow
}
else {
    Write-Host "  [ ] Scripts (not found)" -ForegroundColor Gray
}

if ($detected.InPath) {
    Write-Host "  [X] PATH entry" -ForegroundColor Yellow
}
else {
    Write-Host "  [ ] PATH entry (not found)" -ForegroundColor Gray
}

if ($detected.SendToShortcut) {
    Write-Host "  [X] Send To shortcut" -ForegroundColor Yellow
}
else {
    Write-Host "  [ ] Send To shortcut (not found)" -ForegroundColor Gray
}

if ($detected.LogFolder) {
    Write-Host "  [X] Log folder (%LOCALAPPDATA%\MotW)" -ForegroundColor Yellow
}
else {
    Write-Host "  [ ] Log folder (not found)" -ForegroundColor Gray
}

Write-Host ""

# If nothing detected, exit early
if (-not ($detected.Scripts -or $detected.InPath -or $detected.SendToShortcut -or $detected.LogFolder)) {
    Write-Host "No MotW installations detected. Nothing to uninstall." -ForegroundColor Green
    Write-UninstallLog -Level "INFO" -Message "No installations detected - exiting"
    return
}

# Interactive prompt if no explicit parameters
if (-not $PSBoundParameters.ContainsKey('RemoveFiles') -and -not $PSBoundParameters.ContainsKey('KeepPath')) {
    Write-Host "Uninstallation Options:" -ForegroundColor Cyan
    Write-Host "  [1] Remove integration only (keep scripts and logs)" -ForegroundColor Yellow
    Write-Host "      - Remove Send To shortcut"
    Write-Host "      - Remove PATH entry"
    Write-Host "      - Keep scripts in $ToolRoot"
    Write-Host "      - Keep logs in %LOCALAPPDATA%\MotW"
    Write-Host ""
    Write-Host "  [2] Full uninstall (remove everything)" -ForegroundColor Red
    Write-Host "      - Remove Send To shortcut"
    Write-Host "      - Remove PATH entry"
    Write-Host "      - DELETE scripts from $ToolRoot"
    Write-Host "      - DELETE logs from %LOCALAPPDATA%\MotW"
    Write-Host ""
    Write-Host "  [C] Cancel uninstallation"
    Write-Host ""

    $choice = Read-Host "Your choice [1/2/C]"

    switch ($choice.ToUpper()) {
        '1' {
            Write-UninstallLog -Level "INFO" -Message "User selected: Remove integration only"
            # RemoveFiles stays $false, KeepPath stays $false
        }
        '2' {
            Write-UninstallLog -Level "INFO" -Message "User selected: Full uninstall"
            $RemoveFiles = $true
        }
        'C' {
            Write-Host "`nUninstallation cancelled by user." -ForegroundColor Yellow
            Write-UninstallLog -Level "INFO" -Message "Uninstallation cancelled by user"
            return
        }
        default {
            Write-Host "`nInvalid choice. Uninstallation cancelled." -ForegroundColor Red
            Write-UninstallLog -Level "WARN" -Message "Uninstallation cancelled - invalid choice: $choice"
            return
        }
    }
    Write-Host ""
}

if ($RemoveFiles) {
    if (Test-Path $ToolRoot) {
        try {
            Remove-Item $ToolRoot -Recurse -Force -ErrorAction Stop
            Write-UninstallLog -Level "INFO" -Message "Removed installation directory: $ToolRoot"
        }
        catch {
            Write-UninstallLog -Level "ERROR" -Message "Failed to remove installation directory: $_"
            Write-UninstallLog -Level "WARN" -Message "You may need to manually delete: $ToolRoot"
        }
    }
    else {
        Write-UninstallLog -Level "INFO" -Message "Installation directory not found: $ToolRoot"
    }
}
else {
    Write-UninstallLog -Level "INFO" -Message "Keeping installation directory (use -RemoveFiles to delete)"
}

# Remove new Send To shortcut
if (Test-Path $SendToLnk) {
    try {
        Remove-Item $SendToLnk -Force -ErrorAction Stop
        Write-UninstallLog -Level "INFO" -Message "Removed SendTo shortcut: $SendToLnk"
    }
    catch {
        Write-UninstallLog -Level "WARN" -Message "Failed to remove SendTo shortcut: $_"
    }
}

if (Test-Path $SendToLnkOld) {
    try {
        Remove-Item $SendToLnkOld -Force -ErrorAction Stop
        Write-UninstallLog -Level "INFO" -Message "Removed old SendTo shortcut: $SendToLnkOld"
    }
    catch {
        Write-UninstallLog -Level "WARN" -Message "Failed to remove old SendTo shortcut: $_"
    }
}

if (-not (Test-Path $SendToLnk) -and -not (Test-Path $SendToLnkOld)) {
    Write-UninstallLog -Level "INFO" -Message "SendTo shortcuts not found"
}

# Remove log folder if RemoveFiles is set
if ($RemoveFiles -and (Test-Path $LogFolder)) {
    try {
        Remove-Item $LogFolder -Recurse -Force -ErrorAction Stop
        Write-UninstallLog -Level "INFO" -Message "Removed log folder: $LogFolder"
    }
    catch {
        Write-UninstallLog -Level "WARN" -Message "Failed to remove log folder: $_"
    }
}

if (-not $KeepPath) {
    try {
        $pathUser = [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not $pathUser) { $pathUser = '' }

        $pathEntries = $pathUser.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
        $wasInPath = $pathEntries | Where-Object { $_.Trim() -eq $ToolRoot }

        if ($wasInPath) {
            $newPath = ($pathEntries | Where-Object { $_.Trim() -ne $ToolRoot }) -join ';'
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
            Write-UninstallLog -Level "INFO" -Message "Removed from user PATH: $ToolRoot"
            Write-Host "  NOTE: Restart your terminal for PATH changes to take effect" -ForegroundColor Cyan
        }
        else {
            Write-UninstallLog -Level "INFO" -Message "User PATH did not contain: $ToolRoot"
        }
    }
    catch {
        Write-UninstallLog -Level "ERROR" -Message "Failed to modify PATH: $_"
    }
}
else {
    Write-UninstallLog -Level "INFO" -Message "Keeping PATH entry (use without -KeepPath to remove)"
}

Write-UninstallLog -Level "INFO" -Message "Uninstallation complete"
Write-Host "`nUninstallation Summary:" -ForegroundColor Cyan
Write-Host "  Log:      $LogPath"
if (-not $KeepPath) { Write-Host "  PATH:     Removed" }
if ($RemoveFiles) { Write-Host "  Files:    Deleted" }

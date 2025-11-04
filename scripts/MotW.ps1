<#
.SYNOPSIS
  View/Add/Reassign/Remove Mark-of-the-Web (Zone.Identifier) on files.

.DESCRIPTION
  Manages the NTFS Zone.Identifier alternate data stream that marks files
  as downloaded from the Internet or other security zones. Version 1.1.0

  RECOMMENDED: Use 'reassign' instead of 'unblock' to move files between zones
  rather than removing MotW entirely. This is the preferred approach for
  handling files while Group Policy zone configurations are being implemented.

.USAGE
  MotW.ps1 reassign *.pdf               # Progressive (zone 3→2, 2→1, 1→0, 0→remove)
  MotW.ps1 reassign *.pdf -TargetZone 2 # Direct reassign to Trusted Sites
  MotW.ps1 reassign . -Recurse          # Progressive wash recursively
  MotW.ps1 reassign *.exe -WhatIf       # Preview changes
  MotW.ps1 add *.pdf                    # Add MotW (Zone 3 - Internet)
  MotW.ps1 status .                     # Check MotW status
  MotW.ps1 unblock *.pdf                # Remove MotW entirely
#>

[CmdletBinding(PositionalBinding = $false, SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('reassign', 'unblock', 'add', 'status')]
    [string]$Action = 'reassign',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgsRest,

    [ValidateRange(0, 4)]
    [int]$TargetZone = -1,

    [switch]$Recurse
)

$Script:Version = "1.1.0"
$Script:LogPath = Join-Path $env:LOCALAPPDATA "MotW\motw.log"
$Script:LogDir = Split-Path $Script:LogPath -Parent

# RFC 5424 (Syslog Protocol) standard logging levels
function Write-Log {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('EMERG', 'ALERT', 'CRIT', 'ERROR', 'WARN', 'NOTICE', 'INFO', 'DEBUG')]
        [string]$Level,
        [Parameter(Mandatory)][string]$Message
    )

    try {
        if (-not (Test-Path $Script:LogDir)) {
            New-Item -Path $Script:LogDir -ItemType Directory -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
        $sanitizedMessage = $Message -replace "`r", '\r' -replace "`n", '\n' -replace "`t", '\t'
        $logLine = "$timestamp [$Level] $sanitizedMessage"

        Add-Content -Path $Script:LogPath -Value $logLine -ErrorAction SilentlyContinue
    }
    catch {
        Write-Debug "Logging failed: $_"
    }
}

# RFC 5424 standard logging functions
function Write-LogEmergency { param([string]$Message) Write-Log -Level "EMERG" -Message $Message }
function Write-LogAlert { param([string]$Message) Write-Log -Level "ALERT" -Message $Message }
function Write-LogCritical { param([string]$Message) Write-Log -Level "CRIT" -Message $Message }
function Write-LogError { param([string]$Message) Write-Log -Level "ERROR" -Message $Message }
function Write-LogWarning { param([string]$Message) Write-Log -Level "WARN" -Message $Message }
function Write-LogNotice { param([string]$Message) Write-Log -Level "NOTICE" -Message $Message }
function Write-LogInfo { param([string]$Message) Write-Log -Level "INFO" -Message $Message }
function Write-LogDebug { param([string]$Message) Write-Log -Level "DEBUG" -Message $Message }

# Backwards compatibility alias
function Write-LogWarn { param([string]$Message) Write-LogWarning -Message $Message }

$validActions = @('reassign', 'unblock', 'add', 'status')
[string[]]$Paths = @()

if ($ArgsRest -and $ArgsRest.Count -gt 0) {
    if ($ArgsRest[0] -in $validActions) {
        $Action = $ArgsRest[0]
        if ($ArgsRest.Count -gt 1) { $Paths = $ArgsRest[1..($ArgsRest.Count - 1)] }
    }
    else {
        $Paths = $ArgsRest
    }
}
else {
    Write-Error "No paths provided. Example: MotW.ps1 reassign *.pdf  or  MotW.ps1 status . -Recurse"
    Write-LogError "No paths provided by user"
    return
}

Write-LogInfo "MotW.ps1 v$Script:Version started - Action: $Action, Paths: $($Paths -join ', '), Recurse: $Recurse"

function Resolve-Targets {
    param(
        [string[]]$InputPaths,
        [switch]$Recurse
    )

    $targetSet = @{}

    if (-not $InputPaths -or $InputPaths.Count -eq 0) {
        Write-Error "No paths provided"
        Write-LogError "Resolve-Targets called with no paths"
        return @()
    }

    foreach ($p in $InputPaths) {
        $resolved = @()

        if (Test-Path -LiteralPath $p -ErrorAction SilentlyContinue) {
            $resolved = @((Resolve-Path -LiteralPath $p).Path)
        }
        else {
            try {
                $resolved = @(Get-ChildItem -Path $p -File -ErrorAction Stop | ForEach-Object { $_.FullName })
            }
            catch {
                Write-Warning "Could not resolve path: $p"
                Write-LogWarn "Path resolution failed: $p - $_"
                continue
            }
        }

        foreach ($r in $resolved) {
            if (Test-Path $r -PathType Container) {
                if ($Recurse) {
                    $childItems = Get-ChildItem -LiteralPath $r -Recurse -File -Force -ErrorAction SilentlyContinue
                }
                else {
                    $childItems = Get-ChildItem -LiteralPath $r -File -Force -ErrorAction SilentlyContinue
                }

                foreach ($item in $childItems) {
                    $targetSet[$item.FullName] = $true
                }
            }
            else {
                $targetSet[$r] = $true
            }
        }
    }

    $targets = @($targetSet.Keys | Sort-Object)
    Write-LogInfo "Resolved $($targets.Count) file(s)"
    return $targets
}

function Test-HasMotW {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $null = Get-Item -LiteralPath $Path -Stream Zone.Identifier -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Get-ZoneId {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-HasMotW -Path $Path)) {
        return $null
    }

    try {
        $content = Get-Content -LiteralPath $Path -Stream Zone.Identifier -ErrorAction Stop
        foreach ($line in $content) {
            if ($line -match '^ZoneId=(\d+)') {
                return [int]$matches[1]
            }
        }
    }
    catch {
        Write-LogError "Failed to read ZoneId from $Path : $_"
    }

    return $null
}

function Set-ZoneId {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][int]$ZoneId
    )

    if ($ZoneId -lt 0 -or $ZoneId -gt 4) {
        Write-LogError "Invalid ZoneId: $ZoneId. Must be 0-4."
        return $false
    }

    try {
        $content = "[ZoneTransfer]`nZoneId=$ZoneId`nHostUrl=about:internet"
        Set-Content -LiteralPath $Path -Stream Zone.Identifier -Value $content -Force -ErrorAction Stop
        return $true
    }
    catch {
        Write-LogError "Failed to set ZoneId on $Path : $_"
        return $false
    }
}

function Get-ZoneName {
    param([int]$ZoneId)

    switch ($ZoneId) {
        0 { return "Local Machine" }
        1 { return "Local Intranet" }
        2 { return "Trusted Sites" }
        3 { return "Internet" }
        4 { return "Restricted Sites" }
        default { return "Unknown" }
    }
}

$files = Resolve-Targets -InputPaths $Paths -Recurse:$Recurse
if (-not $files -or $files.Count -eq 0) {
    Write-LogWarn "No files found to process"
    return
}

$successCount = 0
$failCount = 0

switch ($Action) {
    'unblock' {
        foreach ($f in $files) {
            if ($PSCmdlet.ShouldProcess($f, "Remove Mark-of-the-Web")) {
                try {
                    if (Test-Path -LiteralPath $f) {
                        Remove-Item -LiteralPath $f -Stream Zone.Identifier -ErrorAction SilentlyContinue
                        Write-Host "Unblocked: $f" -ForegroundColor Green
                        Write-LogInfo "Unblocked: $f"
                        $successCount++
                    }
                    else {
                        Write-Warning "File not found: $f"
                        Write-LogWarn "File not found: $f"
                        $failCount++
                    }
                }
                catch {
                    Write-Warning "Failed to unblock: $f - $($_.Exception.Message)"
                    Write-LogError "Unblock failed: $f - $($_.Exception.Message)"
                    $failCount++
                }
            }
        }
    }

    'add' {
        foreach ($f in $files) {
            if ($PSCmdlet.ShouldProcess($f, "Add Mark-of-the-Web")) {
                try {
                    if (Test-Path -LiteralPath $f) {
                        Set-Content -LiteralPath $f -Stream Zone.Identifier -Value "[ZoneTransfer]`nZoneId=3`nHostUrl=about:internet" -Force
                        Write-Host "Marked (MotW added): $f" -ForegroundColor Yellow
                        Write-LogInfo "Added MotW: $f"
                        $successCount++
                    }
                    else {
                        Write-Warning "File not found: $f"
                        Write-LogWarn "File not found: $f"
                        $failCount++
                    }
                }
                catch {
                    Write-Warning "Failed to add MotW: $f - $($_.Exception.Message)"
                    Write-LogError "Add MotW failed: $f - $($_.Exception.Message)"
                    $failCount++
                }
            }
        }
    }

    'reassign' {
        foreach ($f in $files) {
            if ($PSCmdlet.ShouldProcess($f, "Reassign zone")) {
                try {
                    if (-not (Test-Path -LiteralPath $f)) {
                        Write-Warning "File not found: $f"
                        Write-LogWarn "File not found: $f"
                        $failCount++
                        continue
                    }

                    $currentZone = Get-ZoneId -Path $f

                    if ($null -eq $currentZone) {
                        Write-Host "[Already Clean] $f" -ForegroundColor Gray
                        Write-LogInfo "File already clean: $f"
                        $successCount++
                        continue
                    }

                    # Security check: Warn about Zone 4 (Restricted Sites)
                    if ($currentZone -eq 4) {
                        Write-Warning "Zone 4 (Restricted Sites) detected: $f"
                        Write-Warning "This file has been explicitly restricted by policy."
                        Write-LogWarn "Zone 4 reassignment attempt: $f"

                        # Only proceed if user explicitly specified -TargetZone (not progressive mode)
                        if ($TargetZone -lt 0) {
                            Write-Host "[Skipped - Zone 4 Protected] $f" -ForegroundColor Yellow
                            Write-LogWarn "Zone 4 reassignment skipped (progressive mode): $f"
                            $successCount++
                            continue
                        }
                    }

                    # Determine target zone
                    if ($TargetZone -ge 0) {
                        # Direct reassignment to specified zone
                        $newZone = $TargetZone
                    }
                    else {
                        # Progressive mode: move down one zone level
                        $newZone = $currentZone - 1
                    }

                    # If new zone would be < 0, remove MotW entirely
                    if ($newZone -lt 0) {
                        Remove-Item -LiteralPath $f -Stream Zone.Identifier -ErrorAction Stop
                        Write-Host "Removed MotW (was Zone $currentZone): $f" -ForegroundColor Green
                        Write-LogInfo "Removed MotW from Zone $currentZone : $f"
                        $successCount++
                    }
                    else {
                        # Reassign to new zone
                        if (Set-ZoneId -Path $f -ZoneId $newZone) {
                            $newZoneName = Get-ZoneName -ZoneId $newZone
                            Write-Host "Reassigned Zone $currentZone -> Zone $newZone ($newZoneName): $f" -ForegroundColor Cyan
                            Write-LogInfo "Reassigned Zone $currentZone -> Zone $newZone : $f"
                            $successCount++
                        }
                        else {
                            Write-Warning "Failed to reassign: $f"
                            Write-LogError "Reassignment failed: $f"
                            $failCount++
                        }
                    }
                }
                catch {
                    Write-Warning "Failed to reassign: $f - $($_.Exception.Message)"
                    Write-LogError "Reassign failed: $f - $($_.Exception.Message)"
                    $failCount++
                }
            }
        }
    }

    'status' {
        foreach ($f in $files) {
            try {
                if (Test-Path -LiteralPath $f) {
                    $zoneId = Get-ZoneId -Path $f
                    if ($null -ne $zoneId) {
                        $zoneName = Get-ZoneName -ZoneId $zoneId
                        $color = switch ($zoneId) {
                            0 { 'Cyan' }
                            1 { 'Green' }
                            2 { 'Yellow' }
                            3 { 'Red' }
                            4 { 'Magenta' }
                            default { 'White' }
                        }
                        Write-Host "[Zone $zoneId - $zoneName] $f" -ForegroundColor $color
                    }
                    else {
                        Write-Host "[Clean] $f" -ForegroundColor Gray
                    }
                    $successCount++
                }
                else {
                    Write-Warning "File not found: $f"
                    Write-LogWarn "File not found: $f"
                    $failCount++
                }
            }
            catch {
                Write-Warning "Failed to read status: $f - $($_.Exception.Message)"
                Write-LogError "Status check failed: $f - $($_.Exception.Message)"
                $failCount++
            }
        }
    }
}

$summary = "Complete - Success: $successCount, Failed: $failCount"
Write-Verbose $summary
Write-LogInfo $summary

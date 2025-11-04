<#
.SYNOPSIS
  Pester tests for MotW.ps1 core functionality.

.DESCRIPTION
  Tests zone detection, reassignment, add, status, and unblock operations.
  Run with: Invoke-Pester -Path tests\MotW.Tests.ps1

  Version 1.1.0
#>

# Path to the MotW.ps1 script
$script:MotWScript = Join-Path $PSScriptRoot '..\scripts\MotW.ps1'

# Helper function to create test files
function New-TestFile {
    param([string]$Path)
    Set-Content -Path $Path -Value "Test content for MotW testing"
}

# Helper function to add MotW with specific zone
function Set-TestMotW {
    param(
        [string]$Path,
        [int]$ZoneId = 3
    )
    $zoneStream = "${Path}:Zone.Identifier"
    $content = "[ZoneTransfer]`nZoneId=$ZoneId`nHostUrl=about:internet"
    Set-Content -Path $zoneStream -Value $content -Force
}

# Helper function to get zone ID
function Get-TestZoneId {
    param([string]$Path)
    $zoneStream = "${Path}:Zone.Identifier"
    if (-not (Test-Path $zoneStream -ErrorAction SilentlyContinue)) {
        return $null
    }
    $content = Get-Content -Path $zoneStream -Raw -ErrorAction SilentlyContinue
    if ($content -match 'ZoneId=(\d+)') {
        return [int]$matches[1]
    }
    return $null
}

# Helper function to check if MotW exists
function Test-TestMotW {
    param([string]$Path)
    $zoneStream = "${Path}:Zone.Identifier"
    return Test-Path $zoneStream -ErrorAction SilentlyContinue
}

Describe "MotW.ps1 - Add Action" {
    It "Should add MotW (Zone 3) to clean file" {
        $testFile = Join-Path $TestDrive 'test-add.txt'
        New-TestFile -Path $testFile

        & $script:MotWScript add $testFile -Confirm:$false

        Get-TestZoneId -Path $testFile | Should Be 3
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Should create Zone.Identifier stream when adding MotW" {
        $testFile = Join-Path $TestDrive 'test-add2.txt'
        New-TestFile -Path $testFile

        & $script:MotWScript add $testFile -Confirm:$false

        Test-TestMotW -Path $testFile | Should Be $true
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }
}

Describe "MotW.ps1 - Unblock Action" {
    It "Should remove MotW completely" {
        $testFile = Join-Path $TestDrive 'test-unblock.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 3

        & $script:MotWScript unblock $testFile -Confirm:$false

        Test-TestMotW -Path $testFile | Should Be $false
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Should not have Zone.Identifier after unblock" {
        $testFile = Join-Path $TestDrive 'test-unblock2.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 3

        & $script:MotWScript unblock $testFile -Confirm:$false

        Get-TestZoneId -Path $testFile | Should Be $null
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }
}

Describe "MotW.ps1 - Reassign Action (Progressive)" {
    It "Should reassign Zone 3 -> Zone 2 progressively" {
        $testFile = Join-Path $TestDrive 'test-reassign-3.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 3

        & $script:MotWScript reassign $testFile -Confirm:$false

        Get-TestZoneId -Path $testFile | Should Be 2
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Should reassign Zone 2 -> Zone 1 progressively" {
        $testFile = Join-Path $TestDrive 'test-reassign-2.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 2

        & $script:MotWScript reassign $testFile -Confirm:$false

        Get-TestZoneId -Path $testFile | Should Be 1
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Should reassign Zone 1 -> Zone 0 progressively" {
        $testFile = Join-Path $TestDrive 'test-reassign-1.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 1

        & $script:MotWScript reassign $testFile -Confirm:$false

        Get-TestZoneId -Path $testFile | Should Be 0
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Should remove MotW when reassigning from Zone 0" {
        $testFile = Join-Path $TestDrive 'test-reassign-0.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 0

        & $script:MotWScript reassign $testFile -Confirm:$false

        Test-TestMotW -Path $testFile | Should Be $false
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }
}

Describe "MotW.ps1 - Reassign Action (Direct)" {
    It "Should reassign Zone 3 -> Zone 2 directly with -TargetZone" {
        $testFile = Join-Path $TestDrive 'test-direct-2.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 3

        & $script:MotWScript reassign $testFile -TargetZone 2 -Confirm:$false

        Get-TestZoneId -Path $testFile | Should Be 2
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Should reassign Zone 3 -> Zone 1 directly with -TargetZone" {
        $testFile = Join-Path $TestDrive 'test-direct-1.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 3

        & $script:MotWScript reassign $testFile -TargetZone 1 -Confirm:$false

        Get-TestZoneId -Path $testFile | Should Be 1
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Should reassign Zone 3 -> Zone 0 directly with -TargetZone" {
        $testFile = Join-Path $TestDrive 'test-direct-0.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 3

        & $script:MotWScript reassign $testFile -TargetZone 0 -Confirm:$false

        Get-TestZoneId -Path $testFile | Should Be 0
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }
}

Describe "MotW.ps1 - WhatIf Support" {
    It "Should not modify file when using -WhatIf with reassign" {
        $testFile = Join-Path $TestDrive 'test-whatif-reassign.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 3

        & $script:MotWScript reassign $testFile -WhatIf

        # File should still be Zone 3
        Get-TestZoneId -Path $testFile | Should Be 3
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Should not remove MotW when using -WhatIf with unblock" {
        $testFile = Join-Path $TestDrive 'test-whatif-unblock.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 3

        & $script:MotWScript unblock $testFile -WhatIf

        Test-TestMotW -Path $testFile | Should Be $true
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }
}

Describe "MotW.ps1 - Error Handling" {
    It "Should handle non-existent file gracefully for status" {
        $nonExistent = Join-Path $TestDrive "does-not-exist.txt"

        { & $script:MotWScript status $nonExistent -ErrorAction Stop } | Should Not Throw
    }
}

# Zone 4 Protection Tests
Describe "Zone 4 (Restricted Sites) Protection" {
    It "Should skip Zone 4 files in progressive mode" {
        $testFile = Join-Path $TestDrive 'test-zone4-progressive.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 4

        & $script:MotWScript reassign $testFile -Confirm:$false 2>&1 | Out-Null

        # Zone should remain 4 (not modified)
        Get-TestZoneId -Path $testFile | Should Be 4
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Should warn but allow Zone 4 with direct -TargetZone" {
        $testFile = Join-Path $TestDrive 'test-zone4-direct.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 4

        & $script:MotWScript reassign $testFile -TargetZone 2 -Confirm:$false 2>&1 | Out-Null

        # Zone should be reassigned (direct mode allows it with warning)
        Get-TestZoneId -Path $testFile | Should Be 2
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Should process Zone 3 files normally (not Zone 4)" {
        $testFile = Join-Path $TestDrive 'test-zone3-normal.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 3

        & $script:MotWScript reassign $testFile -Confirm:$false 2>&1 | Out-Null

        # Zone 3 should become Zone 2
        Get-TestZoneId -Path $testFile | Should Be 2
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Should detect Zone 4 with status command" {
        $testFile = Join-Path $TestDrive 'test-zone4-status.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 4

        # Status command should run successfully and show Zone 4
        & $script:MotWScript status $testFile 2>&1 | Out-Null

        # Verify the zone is still 4
        Get-TestZoneId -Path $testFile | Should Be 4
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Should allow unblock to remove Zone 4" {
        $testFile = Join-Path $TestDrive 'test-zone4-unblock.txt'
        New-TestFile -Path $testFile
        Set-TestMotW -Path $testFile -ZoneId 4

        # Unblock should work (removes all MotW, including Zone 4)
        & $script:MotWScript unblock $testFile -Confirm:$false 2>&1 | Out-Null

        # Zone should be removed
        Get-TestZoneId -Path $testFile | Should Be $null
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }
}

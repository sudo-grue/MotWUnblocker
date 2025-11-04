# MotW Tools Testing Framework

Pester-based testing framework for MotW Tools installation and environment detection.

## Prerequisites

```powershell
# Install Pester (if not already installed)
Install-Module -Name Pester -Force -SkipPublisherCheck
```

## Running Tests

```powershell
# Run all tests
Invoke-Pester -Path tests\

# Run specific test file
Invoke-Pester -Path tests\Install-MotWContext.Tests.ps1

# Run with detailed output
Invoke-Pester -Path tests\ -Output Detailed

# Generate code coverage report
Invoke-Pester -Path tests\ -CodeCoverage scripts\*.ps1
```

## Test Structure

### Install-MotWContext.Tests.ps1
Tests for the installation script including:
- **Environment Detection**: Send To availability, .NET runtime detection, registry access
- **Installation Logic**: Component selection, PATH management, Send To integration
- **Logging**: Log creation, operation logging, error handling
- **Error Handling**: Directory creation failures, PATH failures, shortcut failures

### Uninstall-MotWContext.Tests.ps1
Tests for the uninstallation script including:
- **Installation Detection**: Script detection, PATH detection, shortcut detection
- **Removal Logic**: Partial removal, full removal, component preservation
- **PATH Management**: PATH removal, missing entry handling, preservation
- **Error Handling**: File removal failures, PATH failures, shortcut removal failures

## Test Categories

### Unit Tests
Tests for individual functions in isolation:
- `Test-SendToAvailable`
- `Test-ContextMenuAvailable`
- `Test-DotNetRuntime`
- `Show-EnvironmentDetection`

### Integration Tests
Tests for end-to-end scenarios:
- Full installation flow
- Partial installation flow
- Full uninstallation flow
- Partial uninstallation flow
- Upgrade scenarios (v1.0.0 → v1.1.0)

### Environment Tests
Tests that verify behavior in different environments:
- Restrictive environment (no Send To, no registry)
- Standard environment (all capabilities)
- Partial environment (missing .NET)

## Development Workflow

1. **Write Tests First** (TDD approach):
   ```powershell
   # Create test for new feature
   Describe "New Feature" {
       It "Should do something" {
           # Test implementation
       }
   }
   ```

2. **Run Tests**:
   ```powershell
   Invoke-Pester -Path tests\Install-MotWContext.Tests.ps1 -Output Detailed
   ```

3. **Implement Feature**:
   - Add code to satisfy tests
   - Re-run tests until passing

4. **Verify Coverage**:
   ```powershell
   Invoke-Pester -Path tests\ -CodeCoverage scripts\*.ps1
   ```

## Test Environment Setup

For comprehensive testing, you may need to set up test environments:

### Restrictive Environment Simulation
```powershell
# Simulate restricted Send To folder (requires admin)
icacls "%APPDATA%\Microsoft\Windows\SendTo" /deny "$env:USERNAME:(W)"

# Restore access
icacls "%APPDATA%\Microsoft\Windows\SendTo" /grant "$env:USERNAME:(F)"
```

### .NET Runtime Testing
```powershell
# Mock .NET runtime absence
Mock Get-Command -CommandName dotnet -MockWith { throw "Command not found" }
```

## CI/CD Integration

### GitHub Actions Example
```yaml
name: PowerShell Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Pester Tests
        shell: pwsh
        run: |
          Install-Module -Name Pester -Force -SkipPublisherCheck
          Invoke-Pester -Path tests\ -Output Detailed -CI
```

## Known Testing Limitations

1. **Registry Access**: Tests requiring registry writes may need admin rights
2. **PATH Modification**: Tests that modify PATH should use isolated test environments
3. **File System**: Tests use `$TestDrive` (Pester temp directory) for isolation
4. **Interactive Prompts**: Tests for `Read-Host` require mocking

## Future Test Additions

- [ ] MotW.ps1 reassignment logic tests
- [ ] MotW-SendTo.ps1 interactive prompt tests
- [ ] Logger.cs RFC 5424 level filtering tests
- [ ] MotWService.cs zone reassignment tests
- [ ] FileWatcherService.cs auto-reassignment tests

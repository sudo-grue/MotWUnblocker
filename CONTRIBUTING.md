# Contributing to MotW Tools

## Development Philosophy

MotW Tools is designed with the following principles:

### Security by Design
- **Never remove security metadata without user consent** - Default to zone reassignment rather than complete removal
- **Never touch Zone 4 (Restricted Sites)** - Zone 4 is explicitly set to block dangerous files; all tools skip Zone 4 automatically
- **Create intentional friction** - Progressive washing (3→2→1→0→remove) reminds users that configuring zone policies is the proper solution
- **Maintain transparency** - All operations are logged; users should understand what's happening

### User Experience
- **Educational, not prescriptive** - Tools should remind users of the proper solution while providing the workaround
- **Minimize ceremony** - No admin rights required, per-user installation, works in restrictive environments
- **Fail safely** - Operations should be reversible; preview modes (`-WhatIf`) should be available

### Code Quality
- **Comprehensive testing** - Both PowerShell and C# code have unit test coverage
- **Clear error handling** - Errors should be actionable and logged appropriately
- **Consistent logging** - RFC 5424 standard logging levels across all components
- **Static code analysis** - Roslynator analyzers with .NET code quality rules enabled

---

## Building From Source

### Prerequisites
- .NET 9.0 SDK (Windows Desktop runtime)
- PowerShell 5.1 or higher
- Pester 3.x (for PowerShell tests)
- Windows 10 (21H2+) or Windows 11 x64

### Build MotWasher (GUI)
```powershell
cd .\MotWasher\

# Default: Framework-Dependent build (MotWasher.exe)
dotnet publish -c Release

# Optional: Self-Contained build (MotWasher-sc.exe)
dotnet publish -c Release -p:PublishFlavor=SelfContained

# Build both
dotnet msbuild -t:PublishBoth -p:Configuration=Release
```

### Build MotWatcher (System Tray)
```powershell
cd .\MotWatcher\

# Default: Framework-Dependent build (MotWatcher.exe)
dotnet publish -c Release

# Optional: Self-Contained build (MotWatcher-sc.exe)
dotnet publish -c Release -p:PublishFlavor=SelfContained
```

### Build All (Release Script)
```powershell
# From repository root
.\Build-Release.ps1 -Version "1.1.0"
# Outputs to: .\release\
```

The release build script automatically:
- Runs all unit tests (PowerShell + C#)
- Builds both GUI applications
- Creates framework-dependent and self-contained builds
- Injects the latest MotW.ps1 into the installer
- Generates release artifacts

---

## Testing

### Running Tests

**PowerShell Tests (Pester):**
```powershell
# Run all PowerShell tests
Invoke-Pester -Path tests\MotW.Tests.ps1

# Run with detailed output
Invoke-Pester -Path tests\MotW.Tests.ps1 -Output Detailed
```

**C# Tests (xUnit):**
```powershell
# Run all C# unit tests
dotnet test MotW.Shared.Tests/MotW.Shared.Tests.csproj

# Run with verbose output
dotnet test MotW.Shared.Tests/MotW.Shared.Tests.csproj --verbosity normal
```

### Test Coverage

**PowerShell Tests (19 tests):**
- Adding MotW metadata (Zone 3)
- Removing MotW metadata (unblock)
- Progressive reassignment (3→2→1→0→remove)
- Direct zone reassignment with `-TargetZone`
- `-WhatIf` support
- Error handling (non-existent files)
- Zone 4 protection (progressive mode skips, direct mode warns, status detection, unblock capability)

**C# Tests (25 tests):**
- `HasMotW()` - Zone.Identifier detection
- `GetZoneId()` - Zone ID parsing
- `Block()` - Adding MotW metadata with zone validation
- `Unblock()` - Removing MotW metadata
- `Reassign()` - Direct zone reassignment
- `ReassignProgressive()` - Progressive zone washing including full sequence (3→2→1→0→remove)
- Error handling (empty paths, non-existent files, invalid zone IDs)
- Zone 4 protection (progressive mode refusal, direct mode allowance, detection, no modification)

**Total:** 44 automated tests

All tests are automatically run as part of the release build process.

---

## Static Code Analysis

The project uses comprehensive static code analysis to maintain code quality and catch issues early.

### Configured Analyzers

**Roslynator** (500+ analyzers)
- Code quality and style enforcement
- Performance optimizations
- Best practice recommendations
- Installed via `Directory.Build.props` in the repository root

**.NET Code Analysis** (built-in)
- `AnalysisLevel: latest` - Use the latest analyzer rules
- `AnalysisMode: AllEnabledByDefault` - Enable all available rules
- `EnableNETAnalyzers: true` - Enable .NET code quality analyzers
- `EnforceCodeStyleInBuild: true` - Enforce code style during build

### Running Analysis

Analysis runs automatically during build:
```powershell
dotnet build
```

All analyzer warnings have been resolved. The following rule categories are suppressed as appropriate for this project:
- **CA1716**: Namespace conflicts with VB.NET reserved keywords (VB.NET not used)
- **CA1515**: Make types internal (WPF requires public types)
- **CA1303**: Localization warnings (English-only Windows tool)
- **CA2227**: Collection setters (required for JSON deserialization)
- **CA1305**: IFormatProvider (display-only formatting)

### Key Improvements Made

**Performance:**
- Use `TryGetValue()` instead of `ContainsKey()` + indexer for Dictionary lookups
- Use `AsSpan()` instead of `Substring()` for substring parsing
- Static readonly arrays instead of repeated allocations
- `ToUpperInvariant()` instead of `ToLowerInvariant()` for normalization

**Correctness:**
- Proper Dispose pattern implementation (IDisposable)
- `ArgumentNullException.ThrowIfNull()` for parameter validation
- StringComparison specified for all string operations
- Culture-invariant string operations where appropriate

---

## Integration Testing

### Manual Test Scenarios

**Scenario 1: Progressive Washing**
1. Download a file from the internet (will have Zone 3)
2. Run `MotW.ps1 status file.pdf` - verify Zone 3 shown
3. Run `MotW.ps1 reassign file.pdf` - verify moves to Zone 2
4. Run `MotW.ps1 reassign file.pdf` again - verify moves to Zone 1
5. Continue until Zone.Identifier is removed

**Scenario 2: GUI Workflow**
1. Open MotWasher
2. Drag and drop files with various zones
3. Click "Wash Files"
4. Verify all files moved down one zone level
5. Drop files again and repeat to test multi-stage washing

**Scenario 3: Send To Integration**
1. Install with `Install-MotWContext.ps1`
2. Right-click a file → Send to → MotW - Reassign
3. Verify current zone is displayed
4. Verify automatic reassignment to Zone 2 (for files in Zone 3 only, Zone 4 should be refused)

**Scenario 4: MotWatcher Automation**
1. Configure MotWatcher with a test directory
2. Set minimum zone 3, target zone 2
3. Start watching
4. Drop files with Zone 3 into watched directory
5. Verify automatic reassignment to Zone 2
6. Verify balloon notification

### Testing Edge Cases

**NTFS Alternate Data Streams:**
- Test on files with existing Zone.Identifier
- Test on files with no Zone.Identifier
- Test on files with corrupted Zone.Identifier (invalid format)
- Test on files with zone IDs outside 0-4 range

**File System Operations:**
- Test with read-only files (should fail gracefully)
- Test with files locked by other processes
- Test with UNC paths
- Test with very long file paths (>260 characters)

**Permissions:**
- Test with files in user-writable directories
- Test with files in restricted directories (should fail gracefully)
- Test with files the user doesn't own

---

## Project Structure

```
MotW.Shared/              # Shared library for common code
├── Services/             # MotW read/write logic
│   └── MotWService.cs    # Core service class
└── Utils/                # Logging helpers
    └── Logger.cs         # RFC 5424 logging

MotW.Shared.Tests/        # C# unit tests (xUnit)
└── MotWServiceTests.cs   # 25 tests for MotWService

MotWasher/                # GUI application
├── Models/               # Data models and view models
│   └── FileEntry.cs      # File list entry model
└── MainWindow.xaml       # WPF UI definition

MotWatcher/               # System tray service
├── Models/               # Configuration models
│   ├── WatcherConfig.cs  # Configuration model
│   └── WatchTarget.cs    # Watch target model
├── Services/             # FileWatcher and config services
│   ├── FileWatcherService.cs  # File monitoring
│   └── ConfigService.cs       # Configuration management
└── App.xaml              # System tray application

scripts/                  # PowerShell tools
├── MotW.ps1              # Core CLI tool (embedded in installer)
├── MotW-SendTo.ps1       # Simple wrapper that auto-reassigns to Zone 2
├── Install-MotWContext.ps1    # Installer with environment detection
├── Uninstall-MotWContext.ps1  # Clean uninstaller
└── Build-Release.ps1     # Release build script

tests/                    # PowerShell tests (Pester)
└── MotW.Tests.ps1        # 19 tests for MotW.ps1
```

---

## Technical Specifications

### .NET Applications
- **Framework:** .NET 9.0 (net9.0-windows)
- **UI:** WPF (Windows Presentation Foundation)
- **Deployment:** Framework-Dependent (default), Self-Contained (optional)
- **Target:** Windows x64
- **Binary Sizes:**
  - Framework-Dependent: ≈203 KB (MotWasher), ≈240 KB (MotWatcher)
  - Self-Contained: ≈60 MB (includes .NET runtime)

### PowerShell Scripts
- **PowerShell Version:** 5.1 or higher
- **Execution Policy:** Bypass recommended (used in all script invocations)
- **Scope:** User-level only (no admin rights required)
- **Logging:** RFC 5424 standard levels to `%LOCALAPPDATA%\MotW\motw.log`

### NTFS Metadata
- **Stream Name:** `:Zone.Identifier`
- **Format:** INI-style with `[ZoneTransfer]` section
- **Zone IDs:**
  - 0 = Local Machine
  - 1 = Local Intranet
  - 2 = Trusted Sites
  - 3 = Internet
  - 4 = Restricted Sites

---

## Code Style Guidelines

### C# Code
- Use XML documentation comments for public APIs
- Follow Microsoft's C# coding conventions
- Keep methods focused on single responsibility
- Use `out` parameters for error messages (maintains backward compatibility)
- Log all operations (Info for success, Error for failures)

**Example:**
```csharp
/// <summary>
/// Progressively reassigns a file down one zone level (3→2→1→0→remove).
/// This creates intentional friction, reminding users that the proper solution is configuring zone policies.
/// </summary>
public static bool ReassignProgressive(string path, out string? error)
{
    // Implementation...
}
```

### PowerShell Code
- Use approved verbs (`Get-`, `Set-`, `New-`, etc.)
- Support common parameters (`-WhatIf`, `-Confirm`, `-Verbose`)
- Use `ValidateSet` for enumerated parameters
- Write-Host for user output, Write-Log for file logging
- Use proper error handling with `try/catch` and meaningful messages

**Example:**
```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [ValidateSet('reassign', 'add', 'status', 'unblock')]
    [string]$Action
)
```

### Comments
- **Focus on "why" not "what"** - The code should be self-documenting
- Remove educational comments that describe obvious operations
- Keep XML documentation for public APIs
- Use inline comments only for complex or non-obvious logic

---

## Release Process

### Version Numbering
- Follow semantic versioning: `MAJOR.MINOR.PATCH`
- Update version in:
  - `scripts/MotW.ps1` (`.VERSION` section and header comment)
  - `scripts/Install-MotWContext.ps1` (installer version)
  - Build-Release.ps1 invocation example in documentation

### Creating a Release

1. **Update version numbers** across all files
2. **Run all tests** to ensure they pass:
   ```powershell
   Invoke-Pester -Path tests\MotW.Tests.ps1
   dotnet test MotW.Shared.Tests/MotW.Shared.Tests.csproj
   ```
3. **Build release artifacts**:
   ```powershell
   .\Build-Release.ps1 -Version "X.Y.Z"
   ```
4. **Test the installer** with embedded script:
   - Verify version number in installed script
   - Verify all actions are available
   - Test Send To integration
5. **Update CHANGELOG.md** (if exists) or create release notes
6. **Create git tag**:
   ```powershell
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin vX.Y.Z
   ```
7. **Upload release artifacts** from `.\release\` directory

---

## Security Considerations

### Threat Model
- **In scope:** Correcting zone assignments while Group Policy configurations are being implemented (Zone 3 only)
- **Out of scope:** Bypassing legitimate security controls, processing untrusted files, modifying Zone 4 files

### Security Features
- **Zone 4 protection** - Never modifies Zone 4 (Restricted Sites) files under any circumstances
- **Zone reassignment over removal** - Maintains some security metadata
- **Progressive washing** - Creates friction to remind users of proper solution
- **Comprehensive logging** - All operations are logged for audit trail
- **No elevation required** - Per-user scope reduces attack surface
- **No registry modification** - Uses file system only (Send To folder, PATH)

### What We Don't Do
- **No silent operation** - Tools require user interaction (except MotWatcher by design)
- **No bypassing** - We don't disable SmartScreen or other security features
- **No obfuscation** - All code is open and readable
- **No network access** - All operations are local file system only

---

## Contributing Guidelines

### Pull Requests
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for new functionality
4. Ensure all tests pass
5. Update documentation
6. Commit changes with clear messages
7. Push to your fork
8. Open a Pull Request

### Issue Reports
When reporting issues, please include:
- MotW Tools version
- Windows version
- .NET version (for GUI issues)
- PowerShell version (for script issues)
- Steps to reproduce
- Expected vs actual behavior
- Relevant log files from `%LOCALAPPDATA%\MotW\`

---

## License

See [LICENSE](LICENSE) file for details.

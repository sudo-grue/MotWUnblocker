# MotW Tools

A suite of Windows utilities for viewing, managing, and **reassigning** security zones for **Mark-of-the-Web (MotW)** metadata on files.

## Executive Summary

Microsoft's recent security updates (notably Windows 11 25H2 / KB5070960) expanded enforcement of the Mark-of-the-Web feature, preventing the preview of downloaded files and adding additional safety prompts.
While this change improves protection against credential leaks and malicious file execution, it also creates real productivity friction for **professionals working in environments with improperly configured zone policies**.

### Target Audience

**MotW Tools** is designed for professionals who:
- Receive files from trusted sources that are incorrectly marked as Internet zone (Zone 3)
- Work in environments where IT departments haven't properly configured Group Policy trust zones
- Need to correct zone assignments on legitimate business files to restore productivity
- Understand that the **proper solution is fixing IT policies**, but need a workaround until that happens

### Important: This is a Workaround, Not a Solution

The **correct fix** is for your IT department to:
1. Configure trusted download sources via Group Policy
2. Set up proper domain trust relationships
3. Whitelist known-safe internal file servers in security zones

**MotW Tools provides a temporary workaround** while you work with your IT department to implement the proper solution.

### Tool Suite

| Component      | Type                  | Description                                                                                              |
| -------------- | --------------------- | -------------------------------------------------------------------------------------------------------- |
| **MotWasher**  | GUI Application (WPF) | Progressive zone reassignment (Zone 3→2→1→0) with visual feedback and educational reminders.             |
| **MotWatcher** | System Tray Service   | Background file watcher that automatically reassigns files from monitored directories to safer zones.    |
| **MotW.ps1**   | PowerShell Script     | Command-line tool for zone reassignment, status checking, and "Send To" integration. Supports progressive and direct zone reassignment. |

All tools operate per-user and require no administrative rights.

---

## Table of Contents
- [MotW Tools](#motw-tools)
  - [Executive Summary](#executive-summary)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [GUI Application: MotWasher](#gui-application-motwasher)
    - [Installation](#installation)
    - [System Requirements](#system-requirements)
    - [Usage](#usage)
  - [System Tray Service: MotWatcher](#system-tray-service-motwatcher)
  - [PowerShell CLI Tools](#powershell-cli-tools)
    - [Scripts Included](#scripts-included)
    - ["Send to..." Usage](#send-to-usage)
    - [CLI Usage](#cli-usage)
    - [Quick Installation](#quick-installation)
    - [Manual Installation (Advanced)](#manual-installation-advanced)
    - [Scheduled or Automated Usage](#scheduled-or-automated-usage)
  - [Developer Information](#developer-information)
    - [Building From Source](#building-from-source)
    - [Project Structure](#project-structure)
    - [Technical Specifications](#technical-specifications)
  - [Security Considerations](#security-considerations)
  - [Support and Contact](#support-and-contact)

---

## Overview

When Windows detects a file downloaded from the Internet, it appends a small hidden stream named `Zone.Identifier` that assigns the file to a security zone:

### Windows Security Zones
| Zone ID | Name               | Typical Use                                                   | Impact                                    |
| ------- | ------------------ | ------------------------------------------------------------- | ----------------------------------------- |
| **0**   | Local Machine      | Files on your local computer                                  | Full trust, no restrictions               |
| **1**   | Local Intranet     | Files from your corporate network                             | Minimal restrictions                      |
| **2**   | Trusted Sites      | Explicitly trusted domains (configured by IT or user)         | Reduced restrictions                      |
| **3**   | Internet           | Files downloaded from the Internet (default for downloads)    | Heavy restrictions, preview blocked       |
| **4**   | Restricted Sites   | Known malicious or explicitly blocked sites                   | Maximum restrictions                      |

Files marked as **Zone 3 (Internet)**:
- Have file previews disabled in Explorer and Outlook
- Trigger additional warning prompts when opened
- Have scripts and macros blocked by default

**MotW Tools helps you reassign files from Zone 3 (Internet) to more appropriate zones** (like Zone 2 - Trusted Sites) when you know the source is legitimate but your IT policies haven't been configured correctly.

All tools modify only this metadata; the original file contents and hashes remain unchanged.

---

## GUI Application: MotWasher

### Installation

After building or publishing the project, you'll find the compiled executables in your local build output directories:

- [MotWasher.exe (Framework-Dependent; ≈196 KB)](MotWasher/bin/Release/publish/MotWasher.exe) - **Default**
- [MotWasher-sc.exe (Self-Contained; ≈60 MB)](MotWasher/bin/Release/SelfContained/MotWasher-sc.exe) - Optional

| Build Type              | Output Directory             | Description                                                                  |
| ----------------------- | ---------------------------- | ---------------------------------------------------------------------------- |
| **Framework-Dependent** | `bin\Release\publish\`       | Smaller binary that requires the installed `.NET 9 WindowsDesktop` runtime. |
| **Self-Contained**      | `bin\Release\SelfContained\` | Includes the .NET runtime — runs on any Windows 10/11 x64 system.           |

### System Requirements

| Requirement | Self-Contained                       | Framework-Dependent                  |
| ----------- | ------------------------------------ | ------------------------------------ |
| OS          | Windows 10 (21H2+) or Windows 11 x64 | Windows 10 (21H2+) or Windows 11 x64 |
| Runtime     | Bundled                              | `Microsoft.WindowsDesktop.App 9.x`   |

### Usage

**Progressive Washing Philosophy:**
MotWasher uses a **one-zone-per-operation** approach to create intentional friction, reminding you that fixing IT policies is the proper solution.

1. **Drop Files** – Drag and drop files into the window
2. **Review Zones** – See color-coded current and next zones:
   - 🔴 **Red** = Zone 3 (Internet) → Next: Zone 2 (Trusted)
   - 🟡 **Yellow** = Zone 2 (Trusted) → Next: Zone 1 (Intranet)
   - 🟢 **Green** = Zone 1 (Intranet) → Next: Zone 0 (Local)
   - 🔵 **Blue** = Zone 0 (Local) → Next: Remove MotW
3. **Wash Files** – Click "Wash Files" to move all files down one zone level
4. **Repeat** – Drop files again for additional washing if needed

Each operation moves files ONE zone level (3→2→1→0→remove). This deliberate friction reminds you to ask IT to fix the root cause.

**Keyboard Shortcuts**
| Shortcut | Action |
| -------- | ------ |
| `Ctrl+O` | Add files to the list |
| `Ctrl+L` | Clear all files from the list |
| `F5` | Refresh MotW status for all files |
| `Ctrl+W` | Wash files (progressive reassignment) |

**Features**
- Progressive zone reassignment (one level per operation)
- Color-coded visual feedback for each zone
- Educational banner explaining this is a workaround
- Drag-and-drop support
- Automatic list clearing after washing (encourages re-drop for next level)
- Keyboard shortcuts for efficient workflow
- Detailed local logging
- No elevated permissions required

**Logs:**
`%LOCALAPPDATA%\MotW\motw.log`
Accessible via the **Open Log Folder** button.

---

## System Tray Service: MotWatcher

MotWatcher is a background application that monitors directories and automatically **reassigns zone IDs** for files as they are added. Instead of removing MotW entirely, it reassigns files to safer zones while maintaining security metadata.

### Installation

- [MotWatcher.exe (Framework-Dependent; ≈197 KB)](MotWatcher/bin/Release/publish/MotWatcher.exe) - **Default**
- [MotWatcher-sc.exe (Self-Contained; ≈60 MB)](MotWatcher/bin/Release/SelfContained/MotWatcher-sc.exe) - Optional

### Usage

1. Run `MotWatcher.exe` - a system tray icon will appear
2. Right-click the tray icon and select **Settings** to configure watched directories
3. Configure minimum zone threshold and target zone for each directory
4. Click **Start Watching** from the tray menu
5. Files added to monitored directories will be automatically reassigned to your specified zone

**Zone Reassignment Example:**
- Set **Minimum Zone: 3 (Internet)** and **Target Zone: 2 (Trusted Sites)**
- Files from the Internet (Zone 3) will be reassigned to Trusted Sites (Zone 2)
- Files already in Zone 2 or lower won't be touched

**Smart Defaults:**
- Minimum Zone 3+ → Target Zone 2 (Internet → Trusted)
- Minimum Zone 2+ → Target Zone 1 (Trusted → Intranet)
- Minimum Zone 1+ → Target Zone 0 (Intranet → Local)

**Features:**
- Background monitoring with FileSystemWatcher
- **Zone reassignment** instead of removal (maintains security metadata)
- **Settings UI** for easy configuration (no JSON editing required)
- Statistics tracking with dashboard (files processed, zones, file types, daily activity)
- Configurable watched directories with add/remove/edit
- File type filtering per directory (e.g., *.pdf, *.docx)
- Exclude patterns for partial downloads (*.part, *.tmp, *.7z.*)
- Minimum zone threshold per directory (only process files above threshold)
- Target zone selection per directory
- Auto-start with Windows option
- Start watching automatically on launch option
- Debouncing to handle partial downloads
- Balloon notifications when files are processed
- Low resource usage

**Configuration:**
Right-click the tray icon and select **Settings** to configure:
- **General Settings:**
  - Auto-start with Windows
  - Start watching automatically on launch
  - Notification preferences
  - Debounce delay (0.5-10 seconds)
- **Watched Directories:**
  - Add/remove directories to monitor
  - Enable/disable individual directories
  - Toggle recursive monitoring per directory
  - Set minimum zone ID threshold per directory
  - Set target zone ID per directory (smart defaults provided)
  - Add exclude patterns (glob-style: *.part, *.tmp)
- **File Type Filters:**
  - Add specific file extensions (e.g., *.pdf, *.docx)
  - Remove filters as needed
  - Wildcard (*) to process all file types

Advanced users can also manually edit `%LOCALAPPDATA%\MotW\watcher-config.json`

**Logs:**
`%LOCALAPPDATA%\MotW\motw.log`
Accessible via tray icon → **Open Log Folder**

---

## PowerShell CLI Tools

The `scripts/` directory contains automation-friendly tools that can be installed per-user without admin rights.

### Scripts Included
| Script                        | Purpose                                                                         |
| ----------------------------- | ------------------------------------------------------------------------------- |
| **MotW.ps1**                  | Core logic for zone reassignment, adding, removing, and status checking of MotW. |
| **Install-MotWContext.ps1**   | Installs the CLI tool and "Send To → MotW – Reassign" shortcut.                |
| **Uninstall-MotWContext.ps1** | Cleanly removes all installed components.                                       |

**Features (v1.1.0)**
- **Zone reassignment** (progressive or direct)
- RFC 5424 standard logging levels (Emergency through Debug)
- Comprehensive logging to `%LOCALAPPDATA%\MotW\motw.log`
- `-WhatIf` and `-Confirm` support for safe testing
- Color-coded console output for zone visibility
- Optimized performance with hashtable-based deduplication
- Detailed error handling and reporting
- Success/failure counters

---

### "Send to..." Usage

After installation, right-click any file and select **"Show more options → Send to → MotW - Reassign"**.

**Interactive Prompt Experience:**
```
============================================================
MotW Zone Reassignment
============================================================

File: document.pdf

Current Zone: Zone 3 - Internet

Reassign to which zone?

  [2] Zone 2 - Trusted Sites (recommended)
  [1] Zone 1 - Local Intranet
  [0] Zone 0 - Local Machine
  [R] Remove MotW entirely (not recommended)
  [C] Cancel (do nothing)

Your choice:
```

**Features:**
- **Interactive prompt** - Choose target zone for each file
- **Educational** - See current zone and available options
- **Color-coded** - Visual feedback (Red=Zone 3, Yellow=Zone 2, Green=Zone 1, Cyan=Zone 0)
- **Intentional friction** - Requires conscious choice
- **No registry editing** - Uses Windows "Send To" folder (works in restrictive environments)

**Single-file workflow:**
1. Right-click file → Send to → MotW - Reassign
2. Review current zone in PowerShell window
3. Choose target zone [2/1/0/R/C]
4. File is reassigned immediately

### CLI Usage

```powershell
# Progressive reassignment (recommended - moves down one zone)
MotW.ps1 *.pdf                        # Zone 3→2, 2→1, 1→0, 0→remove
MotW.ps1 reassign *.docx              # Explicit progressive mode

# Direct reassignment to specific zone
MotW.ps1 reassign *.pdf -TargetZone 2 # Direct to Trusted Sites
MotW.ps1 reassign *.docx -TargetZone 1 # Direct to Local Intranet

# Recursive processing
MotW.ps1 reassign . -Recurse          # Progressive wash entire directory tree

# Preview mode
MotW.ps1 reassign *.pdf -WhatIf       # Preview changes without making them

# Status checking with zone details
MotW.ps1 status .                     # Shows zone ID and name with color coding

# Add MotW metadata
MotW.ps1 add *.exe                    # Marks as Zone 3 (Internet)

# Remove MotW entirely
MotW.ps1 unblock *.pdf                # Removes MotW completely
```

**Actions**
| Action     | Description                                                                      |
| ---------- | -------------------------------------------------------------------------------- |
| `reassign` | **Recommended.** Progressive (zone-1) or direct (-TargetZone N) reassignment. |
| `add`      | Adds MotW metadata (`ZoneId=3` - Internet zone).                                 |
| `status`   | Displays zone ID, name, and color-coded status for each file.                    |
| `unblock`  | Removes MotW metadata entirely.                  |

**Common Parameters**
| Parameter      | Description                                           |
| -------------- | ----------------------------------------------------- |
| `-TargetZone`  | Direct reassignment to specific zone (0-4).           |
| `-Recurse`     | Process directories recursively.                      |
| `-WhatIf`      | Show what would happen without making changes.        |
| `-Confirm`     | Prompt for confirmation before each file operation.   |
| `-Verbose`     | Display detailed operation information.               |

**Examples**
```powershell
# Progressive reassignment (one zone down)
MotW.ps1 reassign *.pdf               # Zone 3→2, repeat for 2→1, 1→0, 0→remove

# Direct reassignment to Trusted Sites
MotW.ps1 reassign *.docx -TargetZone 2

# Check status with zone details
MotW.ps1 status . -Recurse            # Color-coded: Red=3, Yellow=2, Green=1, Cyan=0

# Add MotW for testing
MotW.ps1 add *.exe

# Preview reassignment
MotW.ps1 reassign *.pdf -TargetZone 2 -WhatIf

# Confirmation prompts
MotW.ps1 reassign *.pdf -Confirm
```

**Logs:**
All PowerShell operations are logged to:
- `%LOCALAPPDATA%\MotW\motw.log` (MotW.ps1 operations)
- `%LOCALAPPDATA%\MotW\install.log` (Installation)
- `%LOCALAPPDATA%\MotW\uninstall.log` (Uninstallation)

---

### Quick Installation

**Installation Philosophy**: The installer **detects your environment first**, then offers options based on what's available.

```powershell
# Run from the scripts directory
.\Install-MotWContext.ps1
```

**Interactive Installation Experience:**
```
Environment Detection:
  Send To Menu:        Available
  Context Menu:        Restricted
  .NET Runtime:        .NET 9+ Found

Installation Options:
  [1] Full Installation (recommended)
      - PowerShell scripts to %USERPROFILE%\Tools\MotW
      - Add to PATH for global access
      - 'Send To' menu integration with interactive prompt

  [2] Scripts + PATH (no Send To integration)
  [3] Scripts Only (minimal - no PATH or Send To)
  [C] Cancel installation

Your choice [1/2/3/C]:
```

**What Gets Installed:**
- `%USERPROFILE%\Tools\MotW\MotW.ps1` - Core CLI tool
- `%USERPROFILE%\Tools\MotW\MotW-SendTo.ps1` - Interactive wrapper for "Send To"
- Adds `%USERPROFILE%\Tools\MotW` to the user PATH (optional)
- Creates **"Send To → MotW - Reassign"** shortcut with interactive prompt (if available)
- **No registry edits required** - uses Windows "Send To" folder

**Non-Interactive Installation:**
```powershell
# Full installation (non-interactive)
.\Install-MotWContext.ps1 -NonInteractive

# Custom installation without prompts
.\Install-MotWContext.ps1 -NoSendTo
.\Install-MotWContext.ps1 -NoPath
.\Install-MotWContext.ps1 -NoSendTo -NoPath  # Minimal
```

**Uninstallation:**
The uninstaller **detects what's installed**, then offers removal options:

```powershell
# Interactive uninstall (detects and prompts)
.\Uninstall-MotWContext.ps1

# Non-interactive full removal
.\Uninstall-MotWContext.ps1 -RemoveFiles

# Remove integration only (keep scripts and logs)
.\Uninstall-MotWContext.ps1 -KeepPath:$false
```

**Uninstallation Experience:**
```
Detected Installations:
  [X] Scripts in C:\Users\...\Tools\MotW
  [X] PATH entry
  [X] Send To shortcut
  [X] Log folder (%LOCALAPPDATA%\MotW)

Uninstallation Options:
  [1] Remove integration only (keep scripts and logs)
      - Remove Send To shortcut
      - Remove PATH entry
      - Keep scripts in C:\Users\...\Tools\MotW
      - Keep logs in %LOCALAPPDATA%\MotW

  [2] Full uninstall (remove everything)
      - Remove Send To shortcut
      - Remove PATH entry
      - DELETE scripts from C:\Users\...\Tools\MotW
      - DELETE logs from %LOCALAPPDATA%\MotW

  [C] Cancel uninstallation

Your choice [1/2/C]:
```

---

### Manual Installation (Advanced)

If you prefer not to run the installer:

1. Create a folder:
   `C:\Users\<User>\Tools\MotW`
2. Copy `MotW.ps1` into that folder.
3. Add the folder to your **User PATH**:
   _Settings → System → About → Advanced System Settings → Environment Variables → User variables → Path._
4. Optional: add a `.cmd` to `shell:sendto` containing
   ```bat
   @echo off
   powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\Tools\MotW\MotW.ps1" unblock "%~1"
   ```

---

### Scheduled or Automated Usage

For routine compliance or maintenance, the CLI can be run as a **Scheduled Task** without user interaction:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File "C:\Users\<User>\Tools\MotW\MotW.ps1" unblock "C:\TrustedFiles\*.pdf"
```

Common scenarios:
- Clear MotW from a trusted download folder each night.
- Audit MotW status weekly across a shared directory (`status . -Recurse`).
- Reapply MotW to outbound transfer folders before uploads.

Tasks should run as the logged-in user (not SYSTEM) to ensure the same access context.

---

## Developer Information

### Building From Source

**Build MotWasher (GUI):**
```powershell
cd .\MotWasher\

# Default: Framework-Dependent build (MotWasher.exe)
dotnet publish -c Release

# Optional: Self-Contained build (MotWasher-sc.exe)
dotnet publish -c Release -p:PublishFlavor=SelfContained

# Build both
dotnet msbuild -t:PublishBoth -p:Configuration=Release
```

**Build MotWatcher (System Tray):**
```powershell
cd .\MotWatcher\

# Default: Framework-Dependent build (MotWatcher.exe)
dotnet publish -c Release

# Optional: Self-Contained build (MotWatcher-sc.exe)
dotnet publish -c Release -p:PublishFlavor=SelfContained
```

**Build All (Release Script):**
```powershell
# From repository root
.\Build-Release.ps1 -Version "1.0.2"
# Outputs to: .\release\
```

---

### Project Structure
```
MotW.Shared/          # Shared library for common code
├── Services/         # MotW read/write logic
└── Utils/            # Logging helpers

MotWasher/            # GUI application
├── Models/           # Data models and view models
└── MainWindow.xaml   # WPF UI definition

MotWatcher/           # System tray service
├── Models/           # Configuration models
├── Services/         # FileWatcher and config services
└── App.xaml          # System tray application

scripts/              # PowerShell tools
├── MotW.ps1
├── Install-MotWContext.ps1
└── Uninstall-MotWContext.ps1
```

---

### Technical Specifications
- **Framework:** .NET 9.0
- **UI:** WPF (Windows Presentation Foundation)
- **Deployment:** Framework-Dependent (default), Self-Contained (optional)
- **Target:** Windows x64
- **Binary Sizes:**
  - Framework-Dependent: ≈196 KB (MotWasher), ≈197 KB (MotWatcher)
  - Self-Contained: ≈60 MB (includes .NET runtime)
- **PowerShell Version:** 5.1 or higher
- **Permissions:** Per-user only (no admin rights required)
- **Shared Code:** MotW.Shared library used by both GUI applications

---

## Security Considerations

These tools modify only **NTFS alternate data streams** (`Zone.Identifier`).
They never alter file content or integrity.

### Intended Use
- **Correcting improperly configured zone policies** from underwhelming IT administration
- Reassigning files from trusted internal sources marked incorrectly as Internet zone
- Temporary workaround while IT implements proper Group Policy configurations

### Not Intended For
- Bypassing legitimate security controls
- Processing files from untrusted or unknown sources
- Circumventing corporate security policies that are properly configured

### The Proper Solution
Ask your IT department to:
1. Configure trusted sites in Group Policy (`Computer Configuration → Windows Settings → Security Settings → Local Policies → Security Options`)
2. Add internal file servers to the Trusted Sites or Local Intranet zone
3. Configure trusted download locations using Zone Elevation policies
4. Set up UNC path exclusions for internal file shares

**MotW Tools should be used as a temporary productivity aid** while working with IT to implement the correct long-term solution.

---

## Support and Contact

For questions, feature requests, or deployment guidance, open an issue on the project’s **GitHub Issues** page.

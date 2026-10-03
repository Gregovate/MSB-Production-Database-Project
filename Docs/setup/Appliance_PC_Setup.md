# Appliance PC Setup

> **Status:** Work in progress. This document is being built from the actual setup of the MSB Show PC. Only steps that have been verified on the machine should be promoted into the confirmed procedure.

## Purpose

This procedure documents how to build or rebuild a Windows 11 Pro PC that operates as a shared MSB appliance-style workstation, such as the Show PC.

The intended operating model is:

- one shared local Windows account;
- local administrator access;
- no Microsoft account dependency for Windows sign-in;
- automatic Windows logon after boot;
- automatic application startup after logon;
- no per-user permission model;
- normal Windows Update and security maintenance without using Microsoft cloud identity for the operator account.

## Security and Credential Rule

Do **not** place the Windows account password, recovery keys, API keys, or other credentials in this repository.

The Show PC is intentionally configured for unattended/shared operation. Physical access to the PC should therefore be treated as access to the logged-in appliance account.

---

## 1. Install Windows 11 Pro

Install or reset the PC with **Windows 11 Pro 64-bit**.

### Current OOBE behavior observed

During the current Windows 11 Pro cloud reinstall, Windows required progression through the network portion of OOBE.

The older `BypassNRO` registry method did **not** expose the expected offline/limited-setup option on this build and is not part of this confirmed procedure.

### Create the local appliance account

At the Microsoft account sign-in screen:

1. Open Command Prompt with:

   ```text
   Shift + F10
   ```

   On hardware where the function keys require it, use:

   ```text
   Fn + Shift + F10
   ```

2. Run:

   ```cmd
   start ms-cxh:localonly
   ```

3. The local-user creation dialog should open.

4. Create the local appliance account:

   ```text
   Light-O-Rama
   ```

5. Use a local password, but **do not record the password in this repository**.

6. Complete Windows setup using the local account. Do not convert the Windows sign-in to a Microsoft account.

> **Verified:** `start ms-cxh:localonly` successfully opened the local-account setup during the 2026 Show PC build.

---

## 2. Configure Automatic Logon

The Show PC must log in automatically after Windows boots so the show can recover without an operator entering credentials.

Use **Microsoft Sysinternals Autologon**.

### Choose the correct executable

The Sysinternals Autologon package contains multiple executables:

| File | Architecture | Use |
|---|---|---|
| `Autologon.exe` | 32-bit x86 | Older 32-bit Windows systems |
| `Autologon64.exe` | 64-bit x64 | **Use for the MSB Intel/AMD Windows 11 Show PC** |
| `Autologon64a.exe` | ARM64 | ARM-based Windows PCs |

For the MSB Show PC, run:

```text
Autologon64.exe
```

### Enable automatic logon

1. Run `Autologon64.exe` as Administrator.
2. Verify the username is:

   ```text
   Light-O-Rama
   ```

3. Verify the domain/computer field identifies the local PC.
4. Enter the local account password.
5. Click **Enable**.
6. Restart the PC.
7. Verify Windows boots directly to the `Light-O-Rama` desktop without prompting for credentials.

> **Verified on MSB-SHOW_PC2:** Sysinternals Autologon is working and the PC logs directly into the `Light-O-Rama` desktop after restart.

Sysinternals stores the automatic-logon password as an LSA secret rather than as a normal visible password value. An administrator with access to the computer can still recover it, so this mechanism should not be treated as protection against someone who already has administrative or physical access.

### Temporarily bypass automatic logon

Hold **Shift** during startup/logon to bypass Autologon for that boot.

---

## 3. Confirmed Appliance Account Model

The target Windows account model is:

```text
Computer name:   MSB-SHOW_PC2
Local account:   Light-O-Rama
Account type:    Local Administrator
Microsoft login: None
Automatic login: Enabled
```

For Sysinternals Autologon on this local account, use the computer name as the Domain value:

```text
Username: Light-O-Rama
Domain:   MSB-SHOW_PC2
Password: <local account password>
```

Do not store the password in this repository.

---

## 4. Configure the Web Browser

The Show PC uses **Google Chrome** as the normal web browser.

### Install and pin Chrome

1. Unpin Microsoft Edge from the Windows taskbar.
2. Download and install Google Chrome.
3. Pin Google Chrome to the taskbar if desired.

### Set Chrome as the default browser

Open:

```text
Settings -> Apps -> Default apps -> Google Chrome
```

Select **Set default**.

For normal web browsing, verify these associations are assigned to Google Chrome:

```text
HTTP
HTTPS
.htm
.html
```

Do not blindly reassign every Edge-associated file type or protocol. Some entries are file viewers rather than browser defaults, and the Windows `microsoft-edge:` protocol explicitly launches Microsoft Edge.

Optional file types such as PDF, SVG, or XML may be assigned based on the operational preference for the Show PC; they are not required to make Chrome the default web browser.

### Chrome administrator profile

An administrator Chrome profile was added after Chrome installation so an MSB administrator can use browser-based management and setup tools when needed. This is separate from the Windows `Light-O-Rama` local appliance account and does not change the Windows sign-in model.

---

## 5. Install Google Drive for Desktop

1. Download and install **Google Drive for desktop**.
2. Sign in using the dedicated Show PC Google Workspace account:

   ```text
   showpc@sheboyganlights.org
   ```

3. Do not store the Google account password or recovery information in this repository.
4. Drive mapping and synchronization behavior will be documented after they are verified on the new PC.

---

## 6. Application Installation Source Rule

For this appliance PC, install Windows applications from the **official vendor website**, not from the Microsoft Store, unless this procedure explicitly documents an exception.

Reasons:

- the Show PC uses a local Windows account and should not depend on a Microsoft Store account;
- vendor installers are easier to reproduce during a rebuild;
- installers can be archived when a production-approved version must be preserved;
- vendor download pages make the source and version easier to document;
- Light-O-Rama is not distributed through the Microsoft Store.

Do not use third-party download sites.

---

## 7. Standard Setup Applications

These applications are part of the normal Show PC setup.

| Application | Official source | Setup note |
|---|---|---|
| Light-O-Rama ShowTime Sequencing Suite | [Light-O-Rama Software Downloads](https://store.lightorama.com/pages/download-software) | Install the production-approved ShowTime version. Do not change major versions merely because a newer release is available. Verify the required license/version against the production Show PC before final cutover. |
| GIMP | [GIMP Downloads](https://www.gimp.org/downloads/) | Use the official Windows installer from GIMP.org rather than the Microsoft Store package. |
| draw.io Desktop | [draw.io Offline/Desktop](https://www.drawio.com/docs/manual/editor/offline/) | Install the standalone Windows desktop application so diagrams remain usable without Internet access. |
| CableIQ Reporter | [Fluke Networks Downloads](https://www.flukenetworks.com/support/downloads) | On the Fluke download page, locate **CableIQ Reporter Software V2.0** and the **64Bit USB Drivers for DTX, OptiFiber and CableIQ** if the tester requires them. Windows 11 operation must be verified on this PC because Fluke's current CableIQ Reporter description does not explicitly list Windows 11. |
| ExpertGPS | [ExpertGPS Download](https://www.expertgps.com/download.asp) | Install the Windows version from the official ExpertGPS site. Preserve existing license information outside the repository. |

### Standard application verification

After installation, verify each application launches under the automatic-logon `Light-O-Rama` account.

For Light-O-Rama, also record the installed version and license level after they are confirmed on the production setup.

---

## 8. Advanced Applications

These applications are installed when the Show PC will also be used for MSB engineering, repository maintenance, diagnostics, or controlled scripting.

### Visual Studio Code

Official source:

[Visual Studio Code](https://code.visualstudio.com/)

Install the **Windows x64 User Installer**.

During installation:

- leave the normal installer options enabled;
- keep **Add to PATH** enabled;
- enabling **Open with Code** Explorer integration is useful but optional.

#### Git for repository work

VS Code requires Git when this PC will clone or maintain the MSB repository.

Official source:

[Git for Windows](https://git-scm.com/install/windows)

Install the **x64** build.

Use these installer selections for the MSB appliance PC:

| Git for Windows installer screen | Selection |
|---|---|
| Choosing the default editor used by Git | **Use Visual Studio Code as Git's default editor** |
| Adjusting the name of the initial branch in new repositories | **Override the default branch name for new repositories: `main`** |
| Adjusting the PATH environment | **Git from the command line and also from 3rd-party software** |
| Choosing the SSH executable | **Use bundled OpenSSH** |
| Choosing HTTPS transport backend | **Use the native Windows Secure Channel library** |
| Configuring the line ending conversions | **Checkout as-is, commit Unix-style line endings** |
| Configuring the terminal emulator to use with Git Bash | **Use MinTTY** |
| Choose the default behavior of `git pull` | **Only ever fast-forward** |
| Choose a credential helper | **Git Credential Manager** |
| Configuring extra options — file system caching | **Enable file system caching** |
| Configuring extra options — symbolic links | **Do not enable symbolic links** |

### Why these Git choices are used

- `main` matches the MSB repository's normal primary branch naming. This setting affects newly initialized repositories; clones keep the branch names supplied by the remote repository.
- **Git from the command line and also from 3rd-party software** makes Git available to VS Code, PowerShell, Command Prompt, and other approved tools.
- **Bundled OpenSSH** keeps Git's SSH implementation self-contained and avoids depending on a separately configured Windows OpenSSH installation.
- **Windows Secure Channel** uses the Windows certificate store and Windows-native TLS integration.
- **MinTTY** is retained as the normal Git Bash terminal; normal MSB work can still use PowerShell or the VS Code integrated terminal.
- **Only ever fast-forward** prevents `git pull` from silently creating a merge commit when local and remote history have diverged. A divergence must be handled deliberately.
- **Git Credential Manager** provides the supported credential helper for GitHub authentication.
- **File system caching** remains enabled for normal performance.
- **Symbolic links** remain disabled because the current MSB Windows workflow does not require them and enabling them introduces additional Windows privilege/developer-mode behavior.

### Line ending policy

The line-ending selection above corresponds to:

```text
core.autocrlf=input
```

The MSB repository contains both Windows PowerShell files (`.ps1`) and Unix shell files (`.sh`). The repository currently does not define a root `.gitattributes` or `.editorconfig` policy, so the appliance PC should avoid rewriting files to CRLF during checkout. This option preserves files as stored in the repository while normalizing any CRLF line endings to LF when committed.

After installation, verify:

```cmd
git config --global core.autocrlf
```

Expected result:

```text
input
```

### Python

Official source:

[Python 3.13.16](https://www.python.org/downloads/release/python-31316/)

Install **Python 3.13.16 Windows 64-bit** for the current MSB repository environment.

Do not install Python 3.14 on this appliance yet. Current repository requirements include `psycopg2-binary==2.9.10`, and the current package compatibility is already established for CPython 3.13 Windows x64.

During Python installation:

1. Select the **Windows installer (64-bit)**.
2. Enable **Add python.exe to PATH**.
3. Complete the standard installation.
4. If offered, enable **Disable path length limit** after installation.

After VS Code, Git, and Python are installed, verify from Command Prompt:

```cmd
python --version
git --version
code --version
```

Record the actual installed versions after verification.

---

## 9. Remaining Setup Steps

The following items still need to be performed and verified on the new Show PC before they become part of the confirmed procedure:

- set and verify the final computer name;
- complete Windows Update and driver installation;
- configure the normal MSB LAN interface;
- configure the dedicated E1.31 interface(s);
- verify E1.31 interfaces have no unintended default gateway;
- install and verify the dedicated broadcast audio device;
- configure both show monitors;
- configure power, sleep, hibernation, and restart behavior for appliance operation;
- verify recovery after loss of AC power;
- install and configure Light-O-Rama software;
- configure automatic startup of the required show applications;
- configure Google Drive and required drive mapping;
- verify USB/serial controller interfaces and COM-port assignments;
- perform a complete reboot-to-ready test;
- perform an actual show-load test;
- document backup and recovery requirements.

Add each item to the confirmed procedure only after it has been tested on the actual appliance PC.

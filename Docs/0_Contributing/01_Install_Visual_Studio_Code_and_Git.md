# 01 — Install Visual Studio Code and Git

[← Back to Contributor Training](README.md) | [Next: Create a GitHub Account and Get Access →](02_Create_GitHub_Account_and_Get_Access.md)

---

## Before You Begin

This is the first setup step.

You will install two programs:

1. **Visual Studio Code**
2. **Git**

Both programs are free and are required before you can contribute to the MSB Documentation Project.

---

## Required Software

### Visual Studio Code

Visual Studio Code (VS Code) is the editor used to read and edit the MSB documentation.

Official download:

https://code.visualstudio.com/

---

### Git

Git keeps track of document changes and allows Visual Studio Code to communicate with GitHub.

Official download:

https://git-scm.com/downloads

---

Continue with the installation instructions below.

---

# Part 1 — Install Visual Studio Code

## What Is Visual Studio Code?

Visual Studio Code is usually called **VS Code**.

VS Code is the program you will use to:

* Browse the MSB documentation folders.
* Open documents.
* Edit documents.
* Preview documents.
* Save changes.
* Review the changes you made.
* Submit changes for review.

VS Code can also be used for computer programming, but programming is **not** what you are learning here.

For MSB documentation work, think of VS Code as your document editor.

---

# Download VS Code

Open your web browser.

Go to:

**https://code.visualstudio.com/**

Look for the download for Windows.

For a normal Windows computer, choose the **User Installer** for Windows.

The User Installer is the normal choice for an individual Windows user.

> Do not download Visual Studio.
>
> **Visual Studio** and **Visual Studio Code** are different programs.
>
> The program used for this training is **Visual Studio Code**.

---

# Run the VS Code Installer

After the download completes:

1. Open your **Downloads** folder.

2. Find the downloaded VS Code installer.

The filename will look similar to:

`VSCodeUserSetup-x64-1.xx.x.exe`

The numbers in the filename will change as new versions are released.

That is normal.

3. Double-click the installer.

4. If Windows displays a security question, verify that you downloaded the installer from the official Visual Studio Code website.

5. Continue with the installation.

---

# VS Code Installation Choices

The installer may display several screens.

Unless this guide specifically tells you otherwise, leave the normal/default choices selected.

When you reach the screen named **Select Additional Tasks**, you may see choices similar to:

* Create a desktop icon.
* Add "Open with Code" to Windows Explorer.
* Register Code as an editor.
* Add to PATH.

It is fine to leave the normal installer selections in place.

Adding VS Code to PATH is useful and should remain enabled if it is already selected.

Continue until the installation is complete.

---

# Start VS Code

When installation finishes, start Visual Studio Code.

You can also find it later by:

1. Opening the Windows **Start** menu.

2. Typing:

   `Visual Studio Code`

3. Clicking **Visual Studio Code**.

---

# Verify VS Code Is Installed

VS Code should open in a large window.

You should see a menu near the top containing items such as:

* File
* Edit
* Selection
* View
* Go
* Run
* Terminal
* Help

Do not worry about understanding all of these.

For MSB documentation, you will only use a small portion of VS Code.

### Expected Result

Visual Studio Code opens successfully.

If it does, this part is complete.

You may close VS Code before installing Git.

---

# Part 2 — Install Git

## What Is Git?

Git is the program that keeps track of changes to MSB documentation files.

Most of the time you will **not see Git running as a separate program**.

VS Code will use Git in the background.

If you have used:

* Track Changes in Microsoft Word,
* Version History in Google Docs, or
* Revision history in a spreadsheet,

you already understand the basic reason we use Git.

Git provides a much more complete history for a collection of files and folders.

---

# Why Git Is Required

Git allows the MSB documentation system to know:

* Which files changed.
* Which lines changed.
* What the previous version contained.
* Who submitted a change.
* When a change was made.

It also allows us to review a proposed change before adding it to the official documentation.

You do not need to learn Git commands to perform the normal documentation workflow in this guide.

---

# Download Git

Open your web browser.

Go to:

**https://git-scm.com/install/windows**

Look for the normal Windows installer.

Most current Windows computers use the:

**x64 Setup**

If your computer is a normal Intel or AMD Windows desktop or laptop, x64 is normally the correct choice.

If you know that your computer uses Windows on ARM, use the ARM64 version instead.

If you do not know and this is a normal Windows PC, use x64.

---

# Run the Git Installer

After the download finishes:

1. Open your **Downloads** folder.

2. Find the Git installer.

The filename will look similar to:

`Git-2.xx.x-64-bit.exe`

The numbers will change as newer versions of Git are released.

3. Double-click the installer.

4. Windows may ask whether you want to allow the installer to make changes.

5. Continue with the installation.

---

# Important — The Git Installer Has Many Questions

The Git installer contains more setup screens than most programs.

Some of the choices will use unfamiliar terminology.

This is normal.

You are **not expected to understand every option**.

For this documentation workflow:

> Leave the installer choices at their default settings unless this MSB guide specifically tells you to change something.

Click **Next** through the normal installation choices.

Do not experiment with settings simply because they are available.

When you reach the installation step, click **Install**.

Wait for installation to finish.

Then click **Finish**.

---

# You May See "Git Bash"

Installing Git may also install something called:

**Git Bash**

You do not need to learn Git Bash for the normal MSB documentation workflow.

If Git Bash opens after installation, you may close it.

Git itself will still be installed and available to VS Code.

---

# Part 3 — Restart VS Code

If VS Code was running while Git was installed:

1. Close VS Code completely.

2. Open VS Code again.

This allows VS Code to recognize the newly installed Git program.

---

# Part 4 — Verify Git Is Available in VS Code

Open VS Code.

Look at the narrow vertical area along the left side of the VS Code window.

You should see several icons.

One of them is the **Source Control** icon.

It normally looks similar to a branching line with circles.

Click the **Source Control** icon.

At this point you may see a message because you have not opened an MSB folder yet.

That is normal.

You should **not** be told that Git is missing or that Git must be installed.

### Expected Result

VS Code opens normally and Git is available to VS Code.

---

# What You Have Now

Your computer now has the two programs required for MSB documentation work.

## Visual Studio Code

This is the program you will work in.

Think:

**Document editor**

## Git

This keeps track of changes and helps synchronize your documentation.

Think:

**Change history and document synchronization**

---

# You Are Not Finished With Setup Yet

Installing these programs does **not** give you access to MSB documentation.

The next step is to set up your GitHub account and receive permission to access the MSB documentation.

Continue with:

**02_Create_GitHub_Account_and_Get_Access.md**

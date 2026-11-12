# 03 — Get the MSB Documentation on Your Computer

[← Previous: Create a GitHub Account and Get Access](02_GitHub_Account.md) | [Back to Contributor Training](README.md) | [Next: Open and Find MSB Documents →](04_Open_and_Find_MSB_Documents.md)

---

Before starting this section, you should already have:

* Visual Studio Code installed.
* Git installed.
* A GitHub account.
* Permission to access the MSB documentation project.

If any of those steps are not complete, return to:

* [01 — Install Visual Studio Code and Git](01_Install_Visual_Studio_Code_and_Git.md)
* [02 — Create a GitHub Account and Get Access](02_GitHub_Account.md)

---

## What You Are Going to Do

The official MSB documentation is stored online in GitHub.

To work on the documentation, you will place a working copy of the project on your computer.

GitHub and VS Code call this process **cloning a repository**.

Those words may sound technical, but the idea is simple.

You are making a working copy of the MSB project on your computer.

After that:

* You will open the local copy in VS Code.
* You will edit documents on your computer.
* Git will keep track of your changes.
* You will later submit those changes back to GitHub for review.

---

# What Is a Repository?

GitHub uses the word **repository** for a project that contains files and folders.

For this training, you can think of a repository as a shared project folder.

It contains:

* MSB documentation.
* Folders that organize the documentation.
* A history of changes.
* Information GitHub uses to keep everyone working from the same project.

You do not need to understand the technical details of a repository to edit MSB documentation.

---

# What Does Clone Mean?

GitHub uses the word **clone** when it creates a working copy of the project on your computer.

Think of it as:

**Copy the MSB project to my computer and keep it connected to the GitHub version.**

This is different from manually downloading a folder.

A cloned copy remains connected to GitHub so VS Code and Git can later:

* Get newer changes.
* Show your changes.
* Send your changes for review.

---

# Part 1 — Open the MSB Project in GitHub

Open your web browser.

Go to the MSB GitHub project link provided by the MSB administrator.

Sign in to GitHub if necessary.

You should see the MSB project page.

The page will contain a list of folders and files.

---

# Part 2 — Copy the Project Address

Near the top of the GitHub project page, look for the green button labeled:

**Code**

Click **Code**.

A small window will open.

Make sure the **HTTPS** option is selected.

You should see an address that begins with:

`https://github.com/`

Click the copy button next to that address.

This copies the project address to your Windows clipboard.

You do not need to type the address manually.

---

# Part 3 — Open Visual Studio Code

Open Visual Studio Code.

You can find it from the Windows Start menu by searching for:

`Visual Studio Code`

---

# Part 4 — Choose Clone Repository

When VS Code opens, you may see a Welcome screen.

Look for:

**Clone Git Repository**

or:

**Clone Repository**

Click it.

If you do not see that choice:

1. Click **View** on the top menu.
2. Click **Command Palette**.
3. Type:

   `Git: Clone`

4. Select:

   **Git: Clone**

---

# Part 5 — Paste the GitHub Address

VS Code will ask for the repository address.

Paste the address you copied from GitHub.

You can paste using:

`Ctrl+V`

Press **Enter**.

---

# Part 6 — Choose Where the MSB Folder Will Be Stored

VS Code will now ask where you want to store the project on your computer.

Choose a location you can easily find later.

A simple location could be inside your Windows Documents folder.

For example:

`Documents\MSB`

You may choose another location if instructed by the MSB administrator.

## Important

Do not place the project inside:

* OneDrive, unless specifically instructed.
* Google Drive, unless specifically instructed.
* Dropbox.
* Another automatically synchronized folder.

Git already manages the documentation changes.

Using another file synchronization system on the same working folder can cause unnecessary problems.

---

# Part 7 — Select the Parent Folder

When VS Code asks where to clone the repository, select the folder that should contain the MSB project.

For example, if you select:

`Documents`

VS Code may create a folder inside Documents using the name of the GitHub project.

You do not normally need to create the final project folder yourself.

Click:

**Select as Repository Destination**

or the equivalent button shown by VS Code.

---

# Part 8 — Wait for the Project Files to Appear

VS Code will copy the project files from GitHub to your computer.

When it finishes, VS Code may ask:

**Would you like to open the cloned repository?**

Choose:

**Open**

---

# Part 9 — Workspace Trust

The first time you open the project, VS Code may display a message asking whether you trust the authors of the files in the folder.

This is a normal VS Code security feature.

If the folder is the official MSB project that you just cloned from the approved MSB GitHub location, choose the option indicating that you trust the authors.

Do not choose this option for unrelated folders or projects from unknown sources.

---

# Part 10 — Look at the Explorer

Look at the left side of the VS Code window.

You should see the **Explorer** area.

The Explorer works much like Windows File Explorer.

You will see folders and files arranged underneath the project name.

You can:

* Click the small arrow next to a folder to open it.
* Click the arrow again to close it.
* Click a file to open it.

---

# Verify the MSB Documentation Is Present

In the Explorer, look for the folder:

`Docs`

Click the arrow next to:

`Docs`

You should see additional folders underneath it.

One of them should be:

`00_Contributing`

The folder you are currently reading should be located there.

You should also see:

`01_LOR_System`

---

# Find the LOR Preview Authoring Folder

Expand the folders in this order:

`Docs`

then:

`01_LOR_System`

then:

`01_Preview_Authoring`

The full folder path is:

`Docs/01_LOR_System/01_Preview_Authoring`

This is where the LOR Preview Authoring documentation is stored.

Do not make changes yet.

The next section explains how to open and navigate the MSB documentation safely.

---

# What You Have Accomplished

You now have:

* Visual Studio Code installed.
* Git installed.
* A GitHub account.
* Access to the MSB GitHub project.
* A working copy of the MSB project on your computer.
* The project open in VS Code.

This initial setup normally only needs to be done once on a computer.

---

# Important — Do Not Clone the Project Again Each Time

You do not need to repeat this process every time you work on documentation.

After the project has been cloned, the working copy remains on your computer.

In the future, you will open the existing MSB project folder and update it before beginning new work.

That process is covered later in this training.

---

# If VS Code Asks You to Sign In to GitHub

During setup, VS Code may ask you to sign in to GitHub.

If it does:

1. Choose the option to sign in to GitHub.
2. Your web browser may open.
3. GitHub may ask you to authorize Visual Studio Code.
4. Verify that the request is for Visual Studio Code.
5. Approve the authorization.
6. Return to VS Code when prompted.

You should not need to give another person your GitHub password.

---

# If You Cannot Clone the Project

If VS Code reports that you do not have permission to access the project:

1. Verify that you are signed into the correct GitHub account.
2. Verify that you accepted the MSB GitHub invitation.
3. Open the MSB project in your web browser and confirm that you can see its files.

If you cannot see the project on GitHub, contact the MSB administrator.

Do not create a new repository or upload your own copy of the MSB documents.

---

# Stop Here Before Editing

At this point, the goal is only to confirm that the project is correctly installed and accessible.

Do not begin making document changes until you understand how the project folders and documents are organized.

---

# Next Step

Continue with:

[04 — Open and Find MSB Documents](04_Open_and_Find_MSB_Documents.md)

---

[← Previous: Create a GitHub Account and Get Access](02_GitHub_Account.md) | [Back to Contributor Training](README.md) | [Next: Open and Find MSB Documents →](04_Open_and_Find_MSB_Documents.md)

We are starting or continuing a sub-project within the existing **MSB Production Database Project**.

Repository:

`Gregovate/MSB-Production-Database-Project`

Local repository root:

`C:\lor\ImportExport\VSCode`

Git and GitHub CLI (`gh`) are installed and authenticated.

## Sub-project

**Name:** `[SUB-PROJECT NAME]`

**Objective:**
`[What this sub-project needs to accomplish.]`

**Current situation / reason for work:**
`[Known issue, requirement, requested improvement, or current status.]`

**Specific constraints or instructions:**
`[Anything unique to this sub-project.]`

---

## Repository and Git baseline

At the beginning of a new chat, do not assume the local repository is still in the state described by an earlier chat.

Verify the current state as needed:

```powershell
git rev-parse --show-toplevel
git remote -v
git status
git branch --show-current
git status -sb
git fetch origin
gh auth status
gh repo view Gregovate/MSB-Production-Database-Project
```

Establish:

* the correct repository;
* current branch;
* working-tree state;
* relationship to the remote branch;
* whether `main` has changed since prior work;
* whether there is an existing branch or PR for this sub-project.

Do not discard, overwrite, reset, merge, or otherwise alter unexpected work merely to obtain a clean repository. Investigate unexpected state first.

---

## Use the repository as the engineering source of truth

Use the **current repository** to establish how the MSB system actually works.

Read the documentation and implementation relevant to the work rather than relying solely on prior-chat memory.

Relevant areas may include:

* repository `README.md`;
* `Docs/`;
* `System_Documentation/`;
* `Database/`;
* `LOR/`;
* `LOR2DB/`;
* `Utilities/`;
* application-specific directories;
* SQL schema, functions, views, triggers, migrations, and queries;
* tests;
* launchers and deployment scripts;
* operator procedures;
* archived material when historical context is specifically needed.

Follow the repository's existing documentation and engineering standards.

If repository documentation and implementation disagree, identify the discrepancy rather than silently choosing one.

---

## Understand the affected system

Before making a material recommendation or change, understand enough of the surrounding system to avoid breaking an established contract.

As applicable, identify:

* relevant source files and applications;
* data sources and destinations;
* PostgreSQL schemas, tables, views, functions, and triggers;
* SQLite dependencies;
* LOR inputs and outputs;
* filesystem or Google Drive dependencies;
* web/application interfaces;
* IDs and relationships;
* upstream systems;
* downstream consumers;
* operator workflows;
* reports and procedures;
* hard-coded assumptions;
* testing and validation requirements.

The depth of this investigation should match the scope of the sub-project. Do not turn a simple isolated change into an unnecessary system-wide audit.

---

## Preserve established contracts unless the project explicitly changes them

Treat existing production identities and interfaces as contracts until evidence shows they should change.

Pay particular attention when work touches:

* Display identity and `display_id`;
* Stage, Scene, Preview, and Display relationships;
* LOR Prop and Preview identity;
* controller/network/UID/channel relationships;
* containers and operational relationships;
* PostgreSQL production authority;
* immutable `lor_snap` snapshots;
* the V7 parser;
* LOR2DB ingest and reconciliation;
* Directus;
* field/operator workflows;
* filesystem and path-resolution contracts.

A sub-project may intentionally change one of these, but that should be an explicit design decision rather than an accidental side effect.

---

## Distinguish evidence from decisions

When analyzing the system, clearly distinguish where useful between:

**Observed current behavior**
Verified from current code, database objects, files, configuration, or runtime behavior.

**Documented intended behavior**
Defined by authoritative MSB documentation.

**Historical behavior**
Found in archived or superseded material.

**Inference / open question**
Not yet directly proven.

**Proposed behavior**
A possible future design or change.

**Approved direction**
A decision already made for this sub-project.

Do not turn an inference into a requirement without identifying it.

---

## Git and branch discipline

Do not perform normal sub-project development directly on `main`.

Before implementation work:

1. understand the current Git state;
2. make sure the intended base is current;
3. determine whether an existing sub-project branch should be continued;
4. otherwise create an appropriately named dedicated branch;
5. keep unrelated work out of the branch;
6. make logical commits with meaningful commit messages;
7. push the branch to GitHub;
8. use a pull request when the work is ready to integrate.

Do not create a new branch automatically if the work already has an established branch.

---

## Scope control

Stay within the requested sub-project.

Do not perform unrelated cleanup simply because you encounter old code, unconventional organization, stale comments, or other potential improvements.

If an adjacent issue materially affects the current work:

* identify it;
* explain the dependency;
* determine whether it belongs in this sub-project or should become separate work.

Preserve working production behavior unless changing it is part of the approved objective.

---

## Documentation

Documentation is part of the MSB engineering system.

For changes that affect architecture, operations, data contracts, or procedures, determine which documentation must also be updated.

Do not leave repository documentation describing a system that no longer exists.

Historical or superseded material should be retained or archived according to existing repository standards rather than casually deleted.

---

## Working approach

The **sub-project objective determines the phase of work**.

A project may begin with:

* reconnaissance;
* architecture recovery;
* troubleshooting;
* requirements gathering;
* design;
* implementation;
* schema work;
* testing;
* documentation;
* deployment;
* validation;
* maintenance;

or a combination of these.

Do not impose a discovery-only phase when the current state is already known and implementation has been authorized.

Likewise, do not jump directly into implementation when the existing system or impact is not sufficiently understood.

Use the current repository state, prior approved decisions, and the sub-project instructions to determine the correct next action.

---

## At the start of a new chat

First re-establish enough context to safely continue the work:

1. identify the sub-project and objective;
2. verify or inspect the current Git/branch state when relevant;
3. locate any existing work, commits, PRs, documentation, or implementation for the sub-project;
4. read the repository material necessary for the current task;
5. determine where the previous work stopped;
6. continue from the established state rather than restarting the design from scratch.

Then proceed with the requested work.

# Install a reviewed Setup change

| Document control | Value |
|---|---|
| Status | CURRENT operator instructions; use only with a reviewed release runner |
| Owner | MSB Production Database project |
| Reviewed | 2026-10-04 |

## Before you start

1. Tell the active chats which change is being installed. Only one chat directs the installation. Other chats may prepare fixes, but must not change the running system.
2. The directing chat must read the current server instructions and issue record. A new chat must read them again.
3. Confirm the change is merged into main and has passed testing and your screen review. The release check must confirm the visible Updated date matches the latest UI change. A stale date means STOP.
4. Run the check command supplied by that chat. Send back only PASS or STOP and the report folder.
5. Do not start maintenance if any check says STOP.

## Install the change

The directing chat gives you one reviewed command. It checks the release again, starts maintenance, confirms normal database writers are blocked, saves and checks a backup, installs the approved change, checks the result, and returns the system to service.

Keep the terminal open. The full report stays on the server. You do not need to copy the whole report into chat.

Maintenance keeps the wiring lookup available. Other affected screens show the “Making Improvements” page. This is expected during a database change.

## Read the result

- **PASS:** the server checks passed. Refresh the normal Setup screen and complete the short screen check supplied by the directing chat. Confirm both the Client version and the Updated date. An older window can keep showing the previous screen.
- **STOP:** do not run the command again. Send the STOP line and report folder to the directing chat.
- **No result, lost connection, or closed terminal:** do not assume the change failed or succeeded. Give the new chat the issue and report folder. It must check the saved stage and the running system before doing anything.

Do not click Return to Service after STOP unless the directing chat has checked that it is safe. Do not restore an old backup on your own; it could erase work completed since that backup.

## Finish the work

The change is not finished until the directing chat records:

- the version now running and the exact source used;
- the backup and report locations;
- your screen-check result;
- the updated server instructions and deployment history;
- the issue result and any real work still left.

The directing chat must merge the documentation closeout before handing work to a new chat. A chat summary alone is not the record.

## If an urgent fix is needed tomorrow

Tell the directing chat what is wrong and which screen is affected. Use this same process. A screen-only change uses the documented application update procedure. A change to database rules or saved data uses maintenance. The chat must identify which applies; it must not skip maintenance to save time.

The tested release runner is specific to migration 069. Future changes use the same server-maintenance procedure with their own reviewed migration and checks. Do not reuse an old command by changing only a version number.

## Engineering links

- [Setup acceptance and deployment](../Acceptance/README.md)
- [Server-owned deployment procedure](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Production_Database_Change_Deployment_Runbook.md)
- [Migration 069 record](../Acceptance/Setup_205_Migration_069_Deployment_Record.md)

This will list scanning options and result

# Display Scanning

## Open Display Record

## Open Current Test Record

If a scanned display does not have a matching display_test_session record, the system must evaluate the status of the display's assigned container test session.

If the container test session is Not Started:
- the display is not yet testable
- no child display_test_session records should exist yet

If the container test session is In Progress:
- child display_test_session records should already exist for all displays in that container
- if the scanned display is missing, this is a mismatch condition requiring review

Corrective actions:
- update the display container assignment (manager only), then add the display into the current container test session
- or move the display to the correct container

## Open Container

## Open Work Orders
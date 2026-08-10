# T_After_Refresh_Test_Session

## Purpose

Invokes the test session refresh procedure after a refresh request has been submitted.

## Trigger

`ops.trg_after_refresh_test_session`

## Event

`AFTER UPDATE ON ops.test_session`

## Condition

`refresh_requested` changes from `FALSE` to `TRUE`.

## Workflow

```text
Directus
    ↓
refresh_requested = TRUE
    ↓
trg_after_refresh_test_session
    ↓
tf_after_refresh_test_session()
    ↓
ops.p_refresh_test_session()
```

## Business Responsibility

The trigger contains no business logic. Its only responsibility is to invoke the production refresh procedure.

## Related Documentation

- [`P_Refresh_Test_Session.md`](../01_Functions_and_Procedures/P_Refresh_Test_Session.md)

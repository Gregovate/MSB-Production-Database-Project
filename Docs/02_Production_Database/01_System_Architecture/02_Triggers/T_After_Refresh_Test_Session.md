Purpose

Invokes the test session refresh procedure after a refresh request has been submitted.

Trigger

ops.trg_after_refresh_test_session

Event

AFTER UPDATE
ON ops.test_session

Condition

refresh_requested changed
FALSE → TRUE

Workflow

Directus

↓

refresh_requested = TRUE

↓

trg_after_refresh_test_session

↓

tf_after_refresh_test_session()

↓

ops.p_refresh_test_session()

Business Responsibility

The trigger contains no business logic.

Its only responsibility is to invoke the production refresh procedure.
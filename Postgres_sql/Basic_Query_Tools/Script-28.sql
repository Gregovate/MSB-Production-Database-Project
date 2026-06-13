CREATE TRIGGER trg_display_test_session_set_actor_update
BEFORE UPDATE ON ops.display_test_session
FOR EACH ROW
EXECUTE FUNCTION ref.set_actor_on_update();
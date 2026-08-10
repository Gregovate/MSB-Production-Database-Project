CREATE TRIGGER trg_audit_collection_policy_set_actor_insert
BEFORE INSERT ON ref.audit_collection_policy
FOR EACH ROW
EXECUTE FUNCTION ref.set_actor_on_insert();
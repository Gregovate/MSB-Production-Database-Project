CREATE OR REPLACE FUNCTION ref.set_audit_fields()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    NEW.updated_by := current_user;
    RETURN NEW;
END;
$$;
/**
 * Directus hook: policy-driven actor stamping with temporary debug logging.
 *
 * Purpose:
 * - Stamp human-readable actor fields from ref.person for Directus writes
 * - Use ref.audit_collection_policy to control which collections participate
 * - Leave timestamps to PostgreSQL
 * - Allow PostgreSQL fallback for DBeaver / pgAdmin / scripts
 *
 * Temporary debug goals:
 * - Prove what Directus thinks the collection name is
 * - Prove actor lookup is working
 * - Prove policy lookup is or is not matching
 * - Prove whether the outgoing payload actually contains Greg before insert/update
 *
 * IMPORTANT:
 * - Remove these debug logs after the container_endpoint test is solved.
 */
export default ({ filter }, { logger }) => {
    /**
     * Resolve the logged-in Directus user to ref.person.
     */
    async function getActor(context) {
        const userId = context?.accountability?.user;
        if (!userId) return null;

        const person = await context.database("ref.person")
            .select("person_id", "preferred_name")
            .where("directus_user_id", userId)
            .first();

        if (!person) return null;

        return {
            directus_user_id: String(userId),
            person_id: person.person_id,
            preferred_name: person.preferred_name,
        };
    }

    /**
     * Look up audit policy by collection name.
     *
     * For now, Directus gives us collection names like:
     * - test_session
     * - display_test_session
     * - container_endpoint
     *
     * The schema is stored in the table for documentation and future hardening,
     * but collection_name is the key match used here.
     */
    async function getAuditPolicy(collection, context) {
        if (!collection) return null;

        const policy = await context.database("ref.audit_collection_policy")
            .select(
                "audit_collection_policy_id",
                "schema_name",
                "collection_name",
                "insert_actor_enabled",
                "update_actor_enabled",
                "checked_actor_enabled",
                "active_flag"
            )
            .where({
                collection_name: collection,
                active_flag: true,
            })
            .first();

        return policy ?? null;
    }

    /**
     * Stamp create actor fields.
     */
    function stampCreateFields(payload, actor) {
        payload.created_by = actor.preferred_name;
        payload.created_by_person_id = actor.person_id;
        payload.updated_by = actor.preferred_name;
        payload.updated_by_person_id = actor.person_id;
    }

    /**
     * Stamp update actor fields.
     */
    function stampUpdateFields(payload, actor) {
        payload.updated_by = actor.preferred_name;
        payload.updated_by_person_id = actor.person_id;
    }

    /**
     * Stamp checked actor fields.
     */
    function stampCheckedFields(payload, actor) {
        payload.checked_by = actor.preferred_name;
        payload.checked_by_person_id = actor.person_id;
    }

    /**
     * Main write filter.
     */
    async function stampActor(payload, meta, context) {
        try {
            const collection = meta?.collection;
            const event = meta?.event;

            logger.info(
                `stamp-actor-fields: event=${event} collection=${collection}`
            );

            const actor = await getActor(context);

            logger.info(
                `stamp-actor-fields: actor=${JSON.stringify(actor)}`
            );

            if (!actor) {
                logger.warn(
                    `stamp-actor-fields: no ref.person mapping found for Directus user on collection=${collection}`
                );
                return payload;
            }

            const policy = await getAuditPolicy(collection, context);

            logger.info(
                `stamp-actor-fields: policy=${JSON.stringify(policy)}`
            );

            if (!policy) {
                logger.warn(
                    `stamp-actor-fields: no active audit policy found for collection=${collection}`
                );
                return payload;
            }

            if (event === "items.create" && policy.insert_actor_enabled === true) {
                stampCreateFields(payload, actor);
            }

            if (event === "items.update" && policy.update_actor_enabled === true) {
                stampUpdateFields(payload, actor);
            }

            if (
                event === "items.update" &&
                policy.checked_actor_enabled === true &&
                Object.prototype.hasOwnProperty.call(payload, "test_status") &&
                payload.test_status !== null &&
                payload.test_status !== ""
            ) {
                stampCheckedFields(payload, actor);
            }

            logger.info(
                `stamp-actor-fields: final payload=${JSON.stringify(payload)}`
            );

            return payload;
        } catch (error) {
            logger.error(
                `stamp-actor-fields hook failed: ${error?.message ?? error}`
            );

            // Never block the write; let DB fallback proceed.
            return payload;
        }
    }

    filter("items.create", stampActor);
    filter("items.update", stampActor);
};
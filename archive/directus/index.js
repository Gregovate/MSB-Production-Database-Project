/**
 * Directus hook: actor stamping debug proof
 *
 * Purpose:
 * - Prove beyond doubt whether the filter callback is executing
 * - Prove what Directus reports as event + collection
 * - Prove actor lookup and policy lookup paths
 *
 * IMPORTANT:
 * - This is temporary debug code.
 * - console.error() is used intentionally because it is harder to miss in logs.
 */
export default ({ filter }) => {
    console.error("stamp-actor-fields: extension module loaded");

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

    async function stampActor(payload, meta, context) {
        console.error(
            `stamp-actor-fields: ENTER stampActor event=${meta?.event} collection=${meta?.collection}`
        );

        try {
            const collection = meta?.collection;
            const event = meta?.event;

            const actor = await getActor(context);
            console.error(
                `stamp-actor-fields: actor=${JSON.stringify(actor)}`
            );

            const policy = await getAuditPolicy(collection, context);
            console.error(
                `stamp-actor-fields: policy=${JSON.stringify(policy)}`
            );

            if (!actor || !policy) {
                console.error("stamp-actor-fields: actor or policy missing; returning payload unchanged");
                return payload;
            }

            if (event === "items.create" && policy.insert_actor_enabled === true) {
                payload.created_by = actor.preferred_name;
                payload.created_by_person_id = actor.person_id;
                payload.updated_by = actor.preferred_name;
                payload.updated_by_person_id = actor.person_id;
            }

            if (event === "items.update" && policy.update_actor_enabled === true) {
                payload.updated_by = actor.preferred_name;
                payload.updated_by_person_id = actor.person_id;
            }

            if (
                event === "items.update" &&
                policy.checked_actor_enabled === true &&
                Object.prototype.hasOwnProperty.call(payload, "test_status") &&
                payload.test_status !== null &&
                payload.test_status !== ""
            ) {
                payload.checked_by = actor.preferred_name;
                payload.checked_by_person_id = actor.person_id;
            }

            console.error(
                `stamp-actor-fields: final payload=${JSON.stringify(payload)}`
            );

            return payload;
        } catch (error) {
            console.error(
                `stamp-actor-fields: ERROR ${error?.stack ?? error?.message ?? error}`
            );
            return payload;
        }
    }

    filter("items.create", stampActor);
    filter("items.update", stampActor);

    console.error("stamp-actor-fields: filters registered");
};
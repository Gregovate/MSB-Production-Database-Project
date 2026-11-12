"""Direct physical Container requirements; reuse existing task support authority."""
from psycopg2.extras import RealDictCursor
from setup_next_repository import SetupNextRepository, SetupNextRepositoryError


def required_containers(repository: SetupNextRepository, task_id: int) -> list[dict]:
    with repository.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT 1 FROM ref.setup_task WHERE setup_task_id = %s", (task_id,))
        if cur.fetchone() is None:
            raise SetupNextRepositoryError("Setup task was not found")
        cur.execute("""
            SELECT c.container_id, c.description AS container_description,
                   c.location_code AS home_location_code,
                   tc.relationship_type,
                   (tc.relationship_type = 'REQUIRED_CONTAINER') IS TRUE AS assigned
            FROM ref.container c
            LEFT JOIN ref.setup_task_container_support tc
              ON tc.container_id = c.container_id AND tc.setup_task_id = %s
            ORDER BY lower(coalesce(c.description, '')), c.container_id
        """, (task_id,))
        return [dict(row) for row in cur.fetchall()]


def set_required_container(repository: SetupNextRepository, *, email: str,
                           task_id: int, container_id: int, assigned: bool) -> list[dict]:
    with repository.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT * FROM ref.set_setup_task_required_container(%s,%s,%s,%s,%s)",
                    (email, task_id, container_id, assigned, None))
        if cur.fetchone() is None:
            raise SetupNextRepositoryError("Required Container command returned no result")
        conn.commit()
    return required_containers(repository, task_id)

#!/usr/bin/env python3
import sqlite3, csv, sys, datetime
from pathlib import Path

# Shared-drive defaults (change only if your paths differ)
DEF_DB  = r"G:\Shared drives\MSB Database\database\merger\preview_history.db"
DEF_OUT = r"G:\Shared drives\MSB Database\database\merger\reports"

# CSVs to generate (add more queries as needed)
QUERIES = {
    "runs_summary":      "SELECT * FROM v_runs_summary;",
    "contributors_last": "SELECT * FROM v_run_contributors;",
    "staged_last":       "SELECT * FROM v_staged_in_run;",
}

HTML = """<!doctype html><meta charset="utf-8"><title>Preview History</title>
<h1>Preview History – {ts}</h1>
<ul>
  <li><a href="runs_summary.csv">runs_summary.csv</a></li>
  <li><a href="contributors_last.csv">contributors_last.csv</a></li>
  <li><a href="staged_last.csv">staged_last.csv</a></li>
</ul>
<p>DB: {db}</p>"""

def export_csv(cur, sql, path: Path) -> None:
    """Run a SELECT and write results to CSV."""
    cur.execute(sql)
    cols = [d[0] for d in cur.description]
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(cols)
        w.writerows(cur.fetchall())

def main(db: str = DEF_DB, out_root: str = DEF_OUT) -> None:
    out_dir = Path(out_root) / datetime.datetime.now().strftime("%Y%m%d-%H%M")
    out_dir.mkdir(parents=True, exist_ok=True)

    con = sqlite3.connect(db)
    cur = con.cursor()

    # Ensure the views we rely on exist (safe to run repeatedly)
    cur.executescript("""
      CREATE VIEW IF NOT EXISTS v_runs_summary AS
      SELECT r.run_id, r.started, r.policy,
        (SELECT COUNT(*) FROM file_observations fo WHERE fo.run_id=r.run_id) AS observed,
        (SELECT COUNT(*) FROM staging_decisions sd WHERE sd.run_id=r.run_id AND sd.action='staged')   AS staged,
        (SELECT COUNT(*) FROM staging_decisions sd WHERE sd.run_id=r.run_id AND sd.action='skipped')  AS skipped,
        (SELECT COUNT(*) FROM staging_decisions sd WHERE sd.run_id=r.run_id AND sd.action='archived') AS archived
      FROM runs r
      ORDER BY r.started DESC;

      CREATE VIEW IF NOT EXISTS v_run_contributors AS
      SELECT fo.run_id, fo.user, COUNT(*) AS files, SUM(fo.file_size) AS bytes
      FROM file_observations fo
      GROUP BY fo.run_id, fo.user
      ORDER BY fo.run_id DESC, files DESC;

      CREATE VIEW IF NOT EXISTS v_staged_in_run AS
      SELECT sd.run_id, sd.preview_key, sd.staged_as, sd.decision_reason, sd.conflict
      FROM staging_decisions sd
      WHERE sd.action='staged'
      ORDER BY sd.run_id DESC;
    """)
    con.commit()

    for name, sql in QUERIES.items():
        export_csv(cur, sql, out_dir / f"{name}.csv")

    (out_dir / "index.html").write_text(
        HTML.format(ts=datetime.datetime.now().strftime("%Y-%m-%d %H:%M"), db=db),
        encoding="utf-8"
    )

    print(f"Report written to: {out_dir}")

if __name__ == "__main__":
    db  = sys.argv[1] if len(sys.argv) > 1 else DEF_DB
    out = sys.argv[2] if len(sys.argv) > 2 else DEF_OUT
    main(db, out)

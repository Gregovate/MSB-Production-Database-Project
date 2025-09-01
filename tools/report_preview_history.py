#!/usr/bin/env python3
import sqlite3, csv, os, sys, datetime, json
from pathlib import Path


DEF_OUT = Path(r"G:\\Shared drives\\MSB Database\\database\\merger\\reports")


QUERIES = {
'batches': "SELECT * FROM v_batches;",
'daily_7d': "SELECT DATE(ts_utc) AS day, COUNT(*) AS changes FROM changes WHERE ts_utc >= datetime('now','-7 days') GROUP BY day ORDER BY day DESC;",
'top_churn': "SELECT * FROM v_prop_churn ORDER BY change_events DESC LIMIT 200;",
}


HTML_BLOCK = """
<!doctype html><meta charset="utf-8"><title>Preview History Report</title>
<h1>Preview History – {stamp}</h1>
<ul>
<li><a href="batches.csv">batches.csv</a></li>
<li><a href="daily_7d.csv">daily_7d.csv</a></li>
<li><a href="top_churn.csv">top_churn.csv</a></li>
</ul>
<p>Source: {db}</p>
"""


def export_csv(cur, sql, path):
cur.execute(sql)
cols = [d[0] for d in cur.description]
with open(path, 'w', newline='', encoding='utf-8') as f:
w = csv.writer(f)
w.writerow(cols)
for row in cur.fetchall():
w.writerow(row)




def main(db_path, out_dir=None):
out = Path(out_dir or DEF_OUT) / datetime.datetime.utcnow().strftime('%Y%m%d-%H%M')
out.mkdir(parents=True, exist_ok=True)
con = sqlite3.connect(db_path)
cur = con.cursor()
# Ensure views exist (no‑ops if created by the tool already)
cur.executescript('''
CREATE VIEW IF NOT EXISTS v_batches AS
SELECT b.batch_id, b.started_utc, b.finished_utc, b.run_mode, b.user_name,
(SELECT COUNT(*) FROM changes c WHERE c.batch_id=b.batch_id) AS rowcount
FROM batches b ORDER BY b.started_utc DESC;


CREATE VIEW IF NOT EXISTS v_prop_churn AS
SELECT preview_id, key, COUNT(*) AS change_events,
SUM(CASE WHEN field='Name' AND old_value<>new_value THEN 1 ELSE 0 END) AS renames,
SUM(CASE WHEN field IN ('Network','Controller','StartChannel') AND old_value<>new_value THEN 1 ELSE 0 END) AS rewires
FROM changes GROUP BY preview_id, key ORDER BY change_events DESC;
''')
con.commit()


for name, sql in QUERIES.items():
export_csv(cur, sql, out / f"{name}.csv")


(out / 'index.html').write_text(HTML_BLOCK.format(
stamp=datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC'), db=db_path
), encoding='utf-8')


print(f"Report written to: {out}")


if __name__ == '__main__':
db = sys.argv[1] if len(sys.argv) > 1 else r"G:\\Shared drives\\MSB Database\\database\\merger\\preview_history.db"
out = sys.argv[2] if len(sys.argv) > 2 else None
main(db, out)
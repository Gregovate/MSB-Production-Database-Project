"""Read-only QC history report using Setup's existing browser print/PDF pattern.

Uses only the authorized QC snapshot; no table grants, writes or new services.
"""
from datetime import datetime
from html import escape
from zoneinfo import ZoneInfo


def text(value):
    """Escape every database-supplied value, including notes and person names."""
    return escape(str(value if value is not None else ''), quote=True)


def local_time(value):
    if not value:
        return 'Not recorded'
    try:
        stamp = datetime.fromisoformat(str(value).replace('Z', '+00:00'))
        if stamp.tzinfo is None:
            return 'Time zone not recorded'
        return stamp.astimezone(ZoneInfo('America/Chicago')).strftime('%m/%d/%Y %I:%M %p %Z')
    except ValueError:
        return 'Time unavailable'


def render_qc_report(snapshot, year, scope='all'):
    """Deterministic area/finding/event order; completed history is the default."""
    signoffs = {str(s['setup_session_task_id']): s for s in snapshot.get('signoffs', [])}
    auditors = snapshot.get('auditors', [])
    findings = sorted(snapshot.get('findings', []), key=lambda f: (
        str(f.get('stage_key') or ''), str(f.get('scene_name') or ''),
        int(f['setup_session_task_id']), int(f['qc_finding_id'])))
    if scope == 'outstanding':
        findings = [f for f in findings if f['status'] != 'VERIFIED'
                    and str(f['setup_session_task_id']) not in signoffs]
    labels = {'OPEN':'Needs repair', 'CLAIMED':'Repair claimed',
              'AWAITING_RETEST':'Repaired — awaiting area sign-off', 'VERIFIED':'Verified'}
    cards = []
    for finding in findings:
        task = str(finding['setup_session_task_id'])
        people = [a for a in auditors if str(a['setup_session_task_id']) == task]
        final = signoffs.get(task)
        events = sorted(finding.get('events', []), key=lambda e: (str(e.get('at') or ''), int(e.get('id') or 0)))
        description = next((e.get('note') for e in events if e.get('type') == 'REPORTED'), None) or finding.get('title')
        history = ''.join('<tr><td>'+text(local_time(e.get('at')))+'</td><td>'+text(e.get('person'))+
                          '</td><td>'+text(e.get('type'))+'</td><td class="note">'+text(e.get('note'))+'</td></tr>' for e in events)
        audit = ', '.join(str(a.get('auditor') or 'Auditor #'+str(a['person_id']))+
                          ' (claimed '+local_time(a.get('claimed_at'))+')' for a in people) or 'None assigned'
        final_html = '<p><b>Final area sign-off:</b> Pending</p>'
        if final:
            signer = next((a.get('auditor') for a in people if a['person_id'] == final['auditor_person_id']), None)
            final_html = '<p><b>Ready for Production:</b> '+text(signer or 'Auditor #'+str(final['auditor_person_id']))+' · '+text(local_time(final.get('signed_at')))+'</p><p class="note">'+text(final.get('test_evidence'))+'</p>'
        cards.append(f'''<article><h2>{text(finding.get('stage_name') or finding.get('stage_key'))} · {text(finding.get('scene_name') or 'Stage-level')} · QC #{text(task)}</h2>
<h3>Issue #{text(finding['qc_finding_id'])} — {text(labels.get(finding['status'], finding['status']))}</h3>
<p class="note">{text(description)}</p>
<p><b>Reported by:</b> {text(finding.get('reporter'))} · {text(local_time(finding.get('created_at')))}<br>
<b>Repair claimed by:</b> {text(finding.get('repair_owner') or 'Unclaimed')}<br><b>QC auditors:</b> {text(audit)}</p>
{final_html}<table><thead><tr><th>When</th><th>Who</th><th>Action</th><th>Notes / evidence</th></tr></thead><tbody>{history}</tbody></table></article>''')
    title = 'All findings and history' if scope == 'all' else 'Outstanding findings'
    generated = datetime.now(ZoneInfo('America/Chicago')).strftime('%m/%d/%Y %I:%M %p %Z')
    return f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Setup QC report — {text(year)}</title>
<style>body{{font:18px/1.45 Arial,sans-serif;color:#172033;background:white;margin:24px}}h1{{font-size:26px}}h2{{font-size:21px}}h3{{font-size:19px}}a,button{{font:inherit;margin-right:16px}}button{{padding:12px;background:#075985;color:white;border:0;border-radius:5px}}article{{border-top:2px solid #64748b;padding:12px 0}}table{{border-collapse:collapse;width:100%;font-size:15px}}td,th{{border:1px solid #94a3b8;padding:8px;text-align:left;vertical-align:top}}.note{{white-space:pre-wrap;overflow-wrap:anywhere}}thead{{display:table-header-group}}tr{{break-inside:avoid}}h2,h3{{break-after:avoid}}@page{{size:landscape;margin:12mm}}@media print{{.tools{{display:none}}body{{margin:0;font-size:12pt}}table{{font-size:10pt}}}}</style></head><body>
<div class="tools"><button onclick="window.print()">Print / Save PDF</button><a href="?season_year={year}&amp;scope=all">All findings and history</a><a href="?season_year={year}&amp;scope=outstanding">Outstanding only</a><p>Choose Save as PDF in the print dialog to keep a copy.</p></div>
<h1>Setup QC report — {text(year)}</h1><p>{title} · {len(findings)} finding(s)<br>Generated {generated} · America/Chicago</p>
{''.join(cards) or '<p>No findings in this report scope.</p>'}
</body></html>'''

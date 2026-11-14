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
    if scope in {'punch', 'punch_pending', 'outstanding'}:
        return render_qc_punch_list(snapshot, year, include_pending=scope == 'punch_pending')
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
    current_task = None
    for finding in findings:
        task = str(finding['setup_session_task_id'])
        people = [a for a in auditors if str(a['setup_session_task_id']) == task]
        final = signoffs.get(task)
        events = sorted(finding.get('events', []), key=lambda e: (str(e.get('at') or ''), int(e.get('id') or 0)))
        description = finding.get('current_description') or next((e.get('note') for e in events if e.get('type') == 'REPORTED'), None) or finding.get('title')
        history = ''.join('<tr><td>'+text(local_time(e.get('at')))+'</td><td>'+text(e.get('person'))+
                          '</td><td>'+text(e.get('type'))+'</td><td class="note">'+text(e.get('note'))+'</td></tr>' for e in events)
        history += ''.join('<tr><td>'+text(local_time(c.get('corrected_at')))+'</td><td>'+text(c.get('person'))+
                           '</td><td>Issue corrected</td><td class="note">QC #'+text(c.get('old_task_id'))+' → QC #'+text(c.get('new_task_id'))+
                           '<br>Before: '+text(c.get('old_description'))+'<br>After: '+text(c.get('new_description'))+'</td></tr>' for c in finding.get('corrections', []))
        audit = ', '.join(str(a.get('auditor') or 'Auditor #'+str(a['person_id']))+
                          ' (claimed '+local_time(a.get('claimed_at'))+')' for a in people) or 'None assigned'
        final_html = '<p><b>Final area sign-off:</b> Pending</p>'
        if final:
            signer = next((a.get('auditor') for a in people if a['person_id'] == final['auditor_person_id']), None)
            final_html = '<p><b>Ready for Production:</b> '+text(signer or 'Auditor #'+str(final['auditor_person_id']))+' · '+text(local_time(final.get('signed_at')))+'</p><p class="note">'+text(final.get('test_evidence'))+'</p>'
        # Area accountability belongs to the task, not to each individual finding.
        if task != current_task:
            if current_task is not None:
                cards.append('</section>')
            cards.append(f'''<section class="qc-area"><h2>{text(finding.get('stage_name') or finding.get('stage_key'))} · {text(finding.get('scene_name') or 'Stage-level')} · QC #{text(task)}</h2>
<p><b>QC auditors:</b> {text(audit)}</p>{final_html}''')
            for prior in snapshot.get('signoff_history', []):
                if str(prior['setup_session_task_id']) == task:
                    evidence = prior['evidence']
                    cards.append('<p><b>Previous sign-off:</b> '+text(local_time(evidence.get('signed_at')))+
                                 ' · Auditor #'+text(evidence.get('auditor_person_id'))+' · '+
                                 text(evidence.get('test_evidence'))+'<br>Reopened: '+
                                 text(local_time(prior.get('invalidated_at')))+' · '+text(prior.get('reason'))+'</p>')
            current_task = task
        cards.append(f'''<article><h3>Issue #{text(finding['qc_finding_id'])} — {text(labels.get(finding['status'], finding['status']))}</h3>
<p class="note">{text(description)}</p>
<p><b>Reported by:</b> {text(finding.get('reporter'))} · {text(local_time(finding.get('created_at')))}<br>
<b>Repair claimed by:</b> {text(finding.get('repair_owner') or 'Unclaimed')}</p>
<table><thead><tr><th>When</th><th>Who</th><th>Action</th><th>Notes / evidence</th></tr></thead><tbody>{history}</tbody></table></article>''')
    if current_task is not None:
        cards.append('</section>')
    title = 'All findings and history' if scope == 'all' else 'Outstanding findings'
    generated = datetime.now(ZoneInfo('America/Chicago')).strftime('%m/%d/%Y %I:%M %p %Z')
    return f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Setup QC report — {text(year)}</title>
<style>body{{font:18px/1.45 Arial,sans-serif;color:#172033;background:white;margin:24px}}h1{{font-size:26px}}h2{{font-size:21px}}h3{{font-size:19px}}a,button{{font:inherit;margin-right:16px}}button{{padding:12px;background:#075985;color:white;border:0;border-radius:5px}} .qc-area{{border-top:2px solid #64748b;padding:12px 0}}article{{border-top:1px solid #cbd5e1;padding:8px 0}}table{{border-collapse:collapse;width:100%;font-size:15px}}td,th{{border:1px solid #94a3b8;padding:8px;text-align:left;vertical-align:top}}.note{{white-space:pre-wrap;overflow-wrap:anywhere}}thead{{display:table-header-group}}tr{{break-inside:avoid}}h2,h3{{break-after:avoid}}@page{{size:landscape;margin:12mm}}@media print{{.tools{{display:none}}body{{margin:0;font-size:12pt}}table{{font-size:10pt}}}}</style></head><body>
<div class="tools"><button onclick="window.print()">Print / Save PDF</button><a href="?season_year={year}&amp;scope=all">Full history</a><a href="?season_year={year}&amp;scope=punch">Punch list — needs repair</a><p>Choose Save as PDF in the print dialog to keep a copy.</p></div>
<h1>Setup QC report — {text(year)}</h1><p>{title} · {len(findings)} finding(s)<br>Generated {generated} · America/Chicago</p>
{''.join(cards) or '<p>No findings in this report scope.</p>'}
</body></html>'''


def render_qc_punch_list(snapshot, year, include_pending=False):
    """Compact actionable work; complete evidence remains in the history report."""
    statuses = {'OPEN', 'CLAIMED'}
    if include_pending:
        statuses.add('AWAITING_RETEST')
    findings = sorted((f for f in snapshot.get('findings', []) if f['status'] in statuses),
                      key=lambda f: (str(f.get('stage_key') or ''), str(f.get('scene_name') or ''),
                                     int(f['setup_session_task_id']), int(f['qc_finding_id'])))
    labels = {'OPEN': 'Unclaimed', 'CLAIMED': 'Claimed',
              'AWAITING_RETEST': 'Awaiting final check'}
    sections = []
    current = None
    for f in findings:
        area = (f.get('stage_key'), f.get('stage_name'), f.get('scene_name'))
        if area != current:
            if current is not None:
                sections.append('</tbody></table></section>')
            sections.append('<section><h2>'+text(f.get('stage_name') or f.get('stage_key'))+' · '+
                            text(f.get('scene_name') or 'Stage-level')+
                            '</h2><table><thead><tr><th>Issue</th><th>Problem</th><th>Assigned to</th><th>Status</th></tr></thead><tbody>')
            current = area
        description = f.get('current_description') or next((e.get('note') for e in f.get('events', []) if e.get('type') == 'REPORTED'), None) or f.get('title')
        sections.append('<tr><td>#'+text(f['qc_finding_id'])+'</td><td>'+text(description)+
                        '</td><td>'+text(f.get('repair_owner') or 'Unclaimed')+'</td><td>'+
                        labels[f['status']]+'</td></tr>')
    if current is not None:
        sections.append('</tbody></table></section>')
    generated = datetime.now(ZoneInfo('America/Chicago')).strftime('%m/%d/%Y %I:%M %p %Z')
    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8"><title>QC punch list — {text(year)}</title>
<style>body{{font:18px/1.3 Arial;color:#172033;margin:20px}}h1{{font-size:24px}}h2{{font-size:18px;margin:14px 0 5px}}table{{width:100%;border-collapse:collapse}}td,th{{border:1px solid #94a3b8;padding:6px;text-align:left;vertical-align:top}}td:nth-child(2){{width:65%;white-space:pre-wrap;overflow-wrap:anywhere}}tr{{break-inside:avoid}}h2{{break-after:avoid}}thead{{display:table-header-group}}.tools a,.tools button{{margin-right:12px;font:inherit}}@page{{size:landscape;margin:12mm}}@media print{{.tools{{display:none}}body{{font-size:11pt;margin:0}}}}</style></head><body>
<div class="tools"><button onclick="window.print()">Print / Save PDF</button><a href="?season_year={year}&amp;scope=punch">Needs repair</a><a href="?season_year={year}&amp;scope=punch_pending">Include awaiting final check</a><a href="?season_year={year}&amp;scope=all">Full history</a></div>
<h1>QC punch list — {text(year)}</h1><p>{len(findings)} findings · {generated}</p>
{''.join(sections) or '<p>No findings in this selection.</p>'}</body></html>"""

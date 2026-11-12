"""Read-only breaker reports derived from the existing activity ledger."""
from datetime import datetime, timezone
from io import BytesIO
from zoneinfo import ZoneInfo
import re


def _time(value):
    return datetime.fromisoformat(value.replace('Z', '+00:00'))


def report_rows(snapshot, year, phase):
    """Include unchanged targets: an ON/ON breaker recorded OFF is an exception."""
    corrected = {str(e['corrects_event_id']) for e in snapshot['events'] if e.get('corrects_event_id') is not None}
    latest = {}
    for event in snapshot['events']:
        if str(event['event_id']) in corrected or event['event_kind'] not in {'REPORTED','FIELD_VERIFIED','COMPLETED','UTILITY_CONFIRMED'}:
            continue
        bid = event.get('definition_snapshot', {}).get('site_power_breaker_id')
        if bid is None:
            continue
        key = (_time(event['observed_at']), int(event['event_id']))
        if bid not in latest or key > latest[bid][0]:
            latest[bid] = key, event
    panels = {p['site_panel_id']: p for p in snapshot['panels'] if p['active']}
    rows = []
    for breaker in snapshot['breakers']:
        if not breaker['active'] or breaker['site_panel_id'] not in panels:
            continue
        bid = breaker['site_power_breaker_id']
        event = latest.get(bid, (None, None))[1]
        required = breaker['restoration_desired_state' if phase == 'RESTORATION' else 'show_desired_state']
        actual = event['condition'] if event else 'Not recorded'
        if required not in {'ON','OFF'}:
            status = 'Required state not configured'
        elif actual not in {'ON','OFF'}:
            status = 'No recorded state'
        elif actual != required:
            status = 'Wrong state'
        elif event['season_year'] != year:
            status = 'Not recorded for this season'
        elif event['definition_snapshot'].get('phase') != phase:
            status = 'Not recorded for this season mode'
        else:
            status = 'Completed'
        notes = [breaker.get('source_evidence')] + [c.get('description') for c in snapshot['circuits'] if c['active'] and c.get('site_power_breaker_id') == bid]
        rows.append(dict(panel=panels[breaker['site_panel_id']]['panel_name'], breaker=breaker['breaker_name'],
                         description='; '.join(dict.fromkeys(n for n in notes if n)), required=required, recorded=actual,
                         status=status, person=event.get('operator_name', 'Name unavailable') if event else '',
                         observed_at=event['observed_at'] if event else '', site_power_breaker_id=bid))
    def natural(value):
        return [(1,int(p)) if p.isdigit() else (0,p.casefold()) for p in re.split(r'(\d+)', value)]
    return sorted(rows, key=lambda r: (natural(r['panel']), natural(r['breaker'])))


def build_pdf(snapshot, year, phase, view):
    """A paginated PDF using standard PDF fonts; no Production runtime install.

    All text is escaped as PDF string data. Object offsets are calculated from
    encoded bytes, and oversized rows continue on subsequent pages.
    """
    import textwrap
    rows = report_rows(snapshot, year, phase)
    completed = sum(r['status'] == 'Completed' for r in rows)
    selected = [r for r in rows if view == 'all' or (r['status'] == 'Completed') == (view == 'completed')]
    title = {'all':'All breakers', 'exceptions':'Exceptions / missing work', 'completed':'Completed breakers'}[view]
    local = ZoneInfo('America/Chicago')
    generated = datetime.now(timezone.utc).astimezone(local).strftime('%Y-%m-%d %H:%M %Z')
    pages, content = [], []
    widths = [105,180,45,55,155,192]
    headers = ['Panel / breaker','Description','Required','Recorded','Status','Person / last recorded time']
    def literal(value):
        # Standard WinAnsi fonts cover the names used by the operator directory.
        return str(value).encode('cp1252', errors='replace').replace(b'\\', b'\\\\').replace(b'(', b'\\(').replace(b')', b'\\)').replace(b'\r',b' ').replace(b'\n',b' ')
    def text(x, y, value, size=8.5, font='F1'):
        content.append(f'BT /{font} {size} Tf 1 0 0 1 {x} {y} Tm ('.encode()+literal(value)+b') Tj ET')
    def start_page():
        nonlocal content
        content = []
        text(30,580,f'Breaker report - Season {year} {"ON" if phase == "SETUP" else "OFF"}',17,'F2')
        text(30,558,title,12,'F2')
        text(30,541,f'{completed} completed / {len(rows)} active breakers; {len(rows)-completed} exceptions. Revision {snapshot["revision"]}.',9,'F2')
        text(30,526,f'Generated {generated}. Recorded observations, not proof of isolation. All active breakers evaluated.',8,'F2')
        x=30
        for width, heading in zip(widths,headers):
            content.append(f'0.88 0.92 0.96 rg {x} 498 {width} 20 re f 0 0 0 rg'.encode())
            text(x+4,505,heading,8,'F2'); x+=width
        return 498
    def finish_page():
        text(30,16,'Times: America/Chicago. Missing or outdated observations are not confirmed work.',8,'F2')
        text(700,16,f'Page {len(pages)+1}',8,'F2')
        pages.append(b'\n'.join(content))
    y=start_page()
    if not selected:
        text(30,y-20,'No breakers in this report.',10,'F2')
    for row in selected:
        at=_time(row['observed_at']).astimezone(local).strftime('%Y-%m-%d %H:%M %Z') if row['observed_at'] else ''
        values=[f'{row["panel"]} / {row["breaker"]}',row['description'],row['required'],row['recorded'],row['status'],f'{row["person"]} {at}'.strip()]
        wrapped=[textwrap.wrap(str(value or '-'),max(1,int((width-8)/5.1))) or ['-'] for value,width in zip(values,widths)]
        remaining=max(map(len,wrapped)); offset=0
        while remaining:
            available=int((y-38-8)/11)
            if available<1:
                finish_page();y=start_page();available=int((y-38-8)/11)
            lines=min(remaining,available);height=lines*11+8;x=30
            for width,cell in zip(widths,wrapped):
                content.append(f'0.65 G 0.4 w {x} {y-height} {width} {height} re S 0 G'.encode())
                for index,line in enumerate(cell[offset:offset+lines]): text(x+4,y-12-index*11,line)
                x+=width
            y-=height;offset+=lines;remaining-=lines
    finish_page()
    # Object 1: catalog, 2: page tree, 3/4: standard fonts; then page/stream pairs.
    objects=[b'<< /Type /Catalog /Pages 2 0 R >>',
             ('<< /Type /Pages /Count '+str(len(pages))+' /Kids ['+' '.join(f'{5+i*2} 0 R' for i in range(len(pages)))+'] >>').encode(),
             b'<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>',
             b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>']
    for i, stream in enumerate(pages):
        objects.append(f'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 792 612] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents {6+i*2} 0 R >>'.encode())
        objects.append(f'<< /Length {len(stream)} >>\nstream\n'.encode()+stream+b'\nendstream')
    output=BytesIO();output.write(b'%PDF-1.4\n%\xe2\xe3\xcf\xd3\n');offsets=[0]
    for number,obj in enumerate(objects,1):
        offsets.append(output.tell());output.write(f'{number} 0 obj\n'.encode()+obj+b'\nendobj\n')
    xref=output.tell();output.write(f'xref\n0 {len(objects)+1}\n0000000000 65535 f \n'.encode())
    for offset in offsets[1:]: output.write(f'{offset:010d} 00000 n \n'.encode())
    output.write(f'trailer\n<< /Size {len(objects)+1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n'.encode())
    return output.getvalue()

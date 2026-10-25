"""Validate CableIQ exports into a review manifest. Never connects to a database."""
import argparse
import csv
from datetime import datetime
from decimal import Decimal, InvalidOperation
import hashlib
import io
import json
from pathlib import Path


EXPECTED = ['CableID', 'Date', 'Time', 'Result', 'OperatorField1',
            'OperatorField2', 'OperatorField2', 'S/N', 'Version', 'Length Unit',
            'Length Overall', 'Length 12', 'Length 36', 'Length 45', 'Length 78',
            'Length Coax', 'Wiremap Expected', 'Wiremap Wiring', 'Wiremap Measured']
EXPECTED += [name + str(i) for i in range(1, 9) for name in ('Test', 'Result', 'Reason')]
EXPECTED += ['']


def validate_export(raw):
    """Retain positional fields, duplicate provenance, and local times without guessing."""
    rows = list(csv.reader(io.StringIO(raw.decode('utf-8-sig'))))
    if not rows or rows[0] != EXPECTED:
        raise ValueError('Unsupported CableIQ header layout; review columns before import')
    records, by_hash = [], {}
    for row_number, row in enumerate(rows[1:], 2):
        if not row:
            continue
        digest = hashlib.sha256(json.dumps(row, ensure_ascii=False,
            separators=(',', ':')).encode()).hexdigest()
        if digest in by_hash:
            by_hash[digest]['source_rows'].append(row_number)
            continue
        record = dict(source_rows=[row_number], record_hash=digest, raw_fields=row,
                      errors=[], warnings=[], match_status='UNMATCHED', cable_id=None)
        records.append(record)
        by_hash[digest] = record
        if len(row) != len(EXPECTED):
            record['errors'].append('Column count does not match header')
            continue
        record.update(source_cable_label=row[0], tester_serial=row[7],
            tester_version=row[8], length_unit=row[9], overall_result=row[3],
            operator_fields=row[4:7], wiremap=dict(zip(
                ('expected', 'wiring', 'measured'), row[16:19])))
        if not row[0].strip():
            record['errors'].append('Missing CableID label')
        try:
            record['tested_local'] = datetime.strptime(row[1] + ' ' + row[2],
                '%m/%d/%Y %I:%M:%S %p').isoformat()
        except ValueError:
            record['errors'].append('Invalid test date/time')
        record['warnings'].append('Test timezone requires confirmation')
        if row[9] not in ('ft', 'm'):
            record['errors'].append('Unsupported length unit')
        lengths = {}
        for index, name in enumerate(('overall', '12', '36', '45', '78', 'coax'), 10):
            value = row[index]
            if not value.strip():
                lengths[name] = None
                continue
            try:
                number = Decimal(value)
                if not number.is_finite() or number < 0:
                    raise ValueError()
                lengths[name] = str(number)
            except (InvalidOperation, ValueError):
                record['errors'].append('Invalid length: ' + name)
        record['lengths'] = lengths
        applications = []
        for index in range(19, 43, 3):
            test, result, reason = row[index:index + 3]
            if not any((test, result, reason)):
                continue
            applications.append(dict(application=test, result=result, reason=reason))
            if not test:
                record['errors'].append('Application result without application name')
            if result not in ('Qualified', 'Disqualified'):
                record['errors'].append('Unsupported application result: ' + result)
        record['applications'] = applications
        if row[3] not in ('Qualified', 'Disqualified'):
            record['errors'].append('Unsupported overall result: ' + row[3])
        if row[43].strip():
            record['warnings'].append('Unnamed trailing field contains data')
    return dict(source_sha256=hashlib.sha256(raw).hexdigest(), headers=rows[0],
        source_record_count=sum(len(r['source_rows']) for r in records),
        distinct_record_count=len(records),
        invalid_record_count=sum(bool(r['errors']) for r in records),
        records=records, ready_for_database_import=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = validate_export(args.source.read_bytes())
    args.output.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(f"{result['distinct_record_count']} distinct records; "
          f"{result['invalid_record_count']} invalid; cable matches require review")
    return 1 if result['invalid_record_count'] else 0


if __name__ == '__main__':
    raise SystemExit(main())

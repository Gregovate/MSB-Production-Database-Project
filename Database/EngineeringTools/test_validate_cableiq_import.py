import csv
import io
import pytest
from validate_cableiq_import import EXPECTED, validate_export


def export(*rows):
    stream = io.StringIO()
    writer = csv.writer(stream)
    writer.writerow(EXPECTED)
    writer.writerows(rows)
    return stream.getvalue().encode()


def record():
    row = [''] * 44
    row[:10] = ['GG-10', '10/31/2021', '1:25:25 PM', 'Disqualified',
                'MSB', 'Network Testing', 'Other operator field', '123', 'V1', 'ft']
    row[10] = '399'
    row[19:25] = ['1000BASE-T', 'Disqualified', 'Excessive Length',
                  '10BASE-T', 'Qualified', '']
    return row


def test_duplicate_rows_preserve_provenance_and_application_outcomes():
    result = validate_export(export(record(), record()))
    assert result['source_record_count'] == 2
    assert result['distinct_record_count'] == 1
    item = result['records'][0]
    assert item['source_rows'] == [2, 3]
    assert item['source_cable_label'] == 'GG-10'
    assert item['operator_fields'][1:] == ['Network Testing', 'Other operator field']
    assert item['applications'][1]['result'] == 'Qualified'
    assert item['overall_result'] == 'Disqualified'
    assert item['match_status'] == 'UNMATCHED'
    assert result['ready_for_database_import'] is False


def test_retest_is_distinct_and_invalid_measurements_are_flagged():
    first, second = record(), record()
    second[2] = '1:26:25 PM'
    second[10] = 'NaN'
    result = validate_export(export(first, second))
    assert result['distinct_record_count'] == 2
    assert result['invalid_record_count'] == 1
    assert 'Invalid length: overall' in result['records'][1]['errors']


def test_changed_headers_are_rejected_and_short_rows_flagged():
    with pytest.raises(ValueError):
        validate_export(b'CableID,Date\nfoo,bar\n')
    result = validate_export(export(['short']))
    assert result['invalid_record_count'] == 1

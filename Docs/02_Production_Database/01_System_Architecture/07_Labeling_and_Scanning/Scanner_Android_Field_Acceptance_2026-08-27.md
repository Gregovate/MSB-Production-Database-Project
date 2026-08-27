# Scanner Android Field Acceptance — 2026-08-27

| Document control | Value |
|---|---|
| Status | ACCEPTANCE / FIELD TEST RECORD |
| Date | 2026-08-27 |
| Subsystem | Labeling and Scanning |
| Hardware | Zebra DS3678-HD + HOTWAV R9 Ultra Android tablet |

## Purpose

Record the actual Android/Bluetooth and warehouse-range findings from the 2026-08-27 scanner test so future work does not have to reconstruct them from chat history.

## Android Pairing Result

The Zebra scanner was successfully paired to the HOTWAV R9 Ultra Android tablet and operated as Bluetooth HID keyboard input in the browser.

However, pairing was **not accomplished using Android Bluetooth settings alone**.

An Android application from the Google Play Store was required to complete the scanner/tablet pairing process.

After pairing was established, ordinary MSB browser scanning used standard Bluetooth HID keyboard behavior. No custom MSB Android scanning application or database driver was required for normal barcode/QR input.

The exact Play Store application name was not preserved in the controlled repository evidence available during this reconciliation and must not be guessed. When the exact application identity is recovered, add it here as a controlled setup dependency.

## Code 128 Range Result

A large Code 128 test barcode approximately six inches wide was tested with the DS3678-HD.

Observed practical range was approximately four feet.

This was insufficient for the intended warehouse/forklift operating distance.

Result:

```text
DS3678-HD Bluetooth HID / browser input       PASS
Large Code 128 decode at about four feet      PASS
Warehouse/forklift working-distance use       FAIL
```

The DS3678-HD is therefore not accepted as the workshop forklift scanner. The ordered DS3678-ER is the next extended-range acceptance candidate.

## QR Full-URL HID Delay Finding

Existing Display and Container labels already encode full scan URLs.

Examples:

```text
https://db.sheboyganlights.org/scan/DISP/323
https://db.sheboyganlights.org/scan/CONT/216
```

The Zebra decoded the QR values correctly, but Bluetooth HID transmitted the full URL to Android as keyboard characters over several seconds.

This is functionally correct but too slow for repetitive warehouse scanning.

The finding is an input-performance issue, not a failed decode and not an asset-identity problem.

Already-printed Display and Container labels remain supported and are not to be reprinted merely to shorten the encoded payload.

Compact canonical forms such as:

```text
DISP:323
CONT:216
```

remain relevant for future payload/profile work and/or accepted scanner-side formatting, but no production QR payload was changed by this field test.

## Storage Location Status

Storage Location labels have not been printed.

A future compact Location payload may therefore use the canonical form:

```text
LOC:<location_code>
```

subject to the intended `/scan/LOC/:key` workflow being implemented and accepted before production Location labels are printed.

## What This Test Did Not Change

The 2026-08-27 scanner work did not:

- change PostgreSQL schema;
- change Scan resolver behavior;
- change production QR payloads;
- reprint existing Display or Container labels;
- print Storage Location labels;
- implement the missing Location server route;
- change the LabelPrintService.

## Related Documents

- [Scanner Hardware and Tablet Integration](Scanner_Hardware_and_Tablet_Integration.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Labeling and Scanning](README.md)

"""#81 accepted preview publication, independent of database reconciliation.

No master, parser output or database writes. The authenticated runner owns this
local evidence store. Bootstrap must match completed-source bytes exactly.
Only explicitly proven metadata exceptions can use the no-ingest path.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import uuid
import sqlite3
import subprocess
import sys
import tempfile
import zipfile
from collections import Counter
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path
import xml.etree.ElementTree as ET

POLICY = 'MSB_PREVIEW_CATALOG_V1'


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode()


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def source_digest(files):
    # Match parse_props_v7_scene_parser.source_manifest_sha256 EXACTLY.
    # The software-version checker's manifest_source_signature is a different
    # contract (identity fields/key sorting) and cannot validate ingest evidence.
    entries = [dict(filename=f['filename'], sha256=f['sha256'])
               for f in sorted(files, key=lambda f: f['filename'].casefold())]
    payload = json.dumps(entries, ensure_ascii=False, separators=(',', ':'))
    return hashlib.sha256(payload.encode('utf-8')).hexdigest()


def contract_node(node, depth=0):
    ignored = {'Revision', 'Brightness', 'LastSelectedSceneId'} if depth == 0 else set()
    if depth == 1 and node.tag == 'PropClass':
        ignored = {'MasterDimmable'}
        # Without a Display Comment the parser may use Name as fallback identity.
        if (node.get('Comment') or '').strip():
            ignored.add('Name')
    return [node.tag, sorted((k, v) for k, v in node.attrib.items() if k not in ignored),
            (node.text or '').strip(), [contract_node(c, depth + 1) for c in node],
            (node.tail or '').strip()]


COMPARISON_POLICY = 'MSB_SEQUENCING_CONTRACT_V5'
# Filled from a reviewed, exact published export; never from current master bytes.
LEGACY_SEQUENCING_ANCHORS = {'76501d972e5e739b8ab8f9c2c6736b633912b14fb17b4b80c7376a4cbbd86c53': 'e43ce72274b9ce5d93dc4788278b754d114a6f23542ea346e206f8a3ed7ea49d', '02e0e910e1987c37363b570d9b546bb740c6b27502c7fd512c2081fee4bf3c26': 'c6a893c190c9a3898e9134dbff559890ed43d750a8330df91b5a79d51d194fd9', '6874537a9b97b8b239005af3ad209bbe4de055b8defd457ab63fbf13ceaa66c5': 'abc8f01134c7ff5ae6b12babd19fc01e7d6dc8caf9c8a74d6f5859c8b3842a83', '5e632dd68b6928f9acb0572d531813856c0652b5391da754331254ba253e4c60': '6f544a109fbe490db423b94549fdcbbbdc289cdfabeaa7b9508a334b8bcd9c0d'}


def preview_stage(name):
    # Same StageID patterns as parser V7.0.11. A label rename must not reassign
    # a physical preview to another stage. Actual parity is covered by tests.
    for pattern in (r'^\s*(\d{1,2})([a-z]?)\s*[-_]\s*',
                    r'\bstage\s*0*(\d{1,2})([a-z]?)\b',
                    r'\bshow\s+animation\b.*?\b0*(\d{1,2})\b'):
        match = re.search(pattern, name or '', re.I)
        if match:
            return f"{int(match.group(1)):02d}" + (match.group(2).lower() if len(match.groups()) > 1 else '')
    return None


def sequencing_contract_node_v4(node, depth=0):
    # Narrow sequencing-only branches. Unexpected descendants remain protected:
    # in particular never hide parser-visible PropClass/Scene under a group.
    ignored_trees = {'PropGroup': {'PropGroup', 'member', 'MotionRowDefaults', 'MotionRowDefault'},
                     'PropViews': {'PropViews', 'PropView', 'ViewMember'},
                     'MotionRowDefaults': {'MotionRowDefaults', 'MotionRowDefault'}}
    ignored = {'Revision', 'Brightness', 'LastSelectedSceneId', 'Name'} if depth == 0 else set()
    if node.tag in {'PreviewClass', 'Scene'}: ignored.add('BackgroundFile')
    if depth == 2 and node.tag == 'shape': ignored.update({'OffsetX', 'OffsetY', 'ScaleX', 'ScaleY'})
    if depth == 3 and node.tag == 'point': ignored.update({'x', 'y'})
    if depth == 1 and node.tag == 'PropClass':
        ignored = {'MasterDimmable'}
        if (node.get('Comment') or '').strip(): ignored.add('Name')
    children = []
    for child in node:
        allowed = ignored_trees.get(child.tag)
        is_sequencing = ((depth == 0 and child.tag in {'PropGroup', 'PropViews'})
                         or (depth == 1 and node.tag == 'PropClass' and child.tag == 'MotionRowDefaults'))
        if is_sequencing and allowed and all(n.tag in allowed for n in child.iter()):
            continue
        children.append(sequencing_contract_node_v4(child, depth + 1))
    attrs = sorted((k,v) for k,v in node.attrib.items() if k not in ignored)
    if depth == 0: attrs.append(('__parser_stage_id__', preview_stage(node.get('Name'))))
    return [node.tag, attrs, (node.text or '').strip(), children, (node.tail or '').strip()]


def sequencing_contract_node(node, depth=0):
    """V5 keeps wiring/identity; Traditional line drawings are programming aids.

    Parm1/Parm2 here control the drawn line representation. Parsed approximate
    Lights is not authority for MSB physical counts. No RGB/pixel parameters are
    exempted. Preserve unexpected descendants rather than suppressing them.
    """
    value = sequencing_contract_node_v4(node, depth)
    def project(item):
        tag, attrs, text, children, tail = item
        attrs = dict(attrs)
        children = [project(child) for child in children]
        if tag == 'Scene':
            for key in ('HScroll', 'VScroll', 'Zoom'):
                attrs.pop(key, None)
        if (tag == 'PropClass' and attrs.get('DeviceType') == 'LOR'
                and attrs.get('StringType') == 'Traditional'
                and attrs.get('TraditionalType') == 'Multicolor_string_1_ch'):
            shapes = [child for child in children if child[0] == 'shape']
            if shapes and all(dict(shape[1]).get('ShapeName') == 'Lines-Connected'
                              and all(child[0] == 'point' and not child[3] for child in shape[3]) for shape in shapes):
                attrs.pop('Parm1', None); attrs.pop('Parm2', None)
                children = [child for child in children if child[0] != 'shape']
        if tag == 'PreviewClass':
            # Declaration order of physical props is not Scene membership/order.
            props = iter(sorted((child for child in children if child[0] == 'PropClass'), key=lambda child:dict(child[1]).get('id', '')))
            children = [next(props) if child[0] == 'PropClass' else child for child in children]
        return [tag, sorted(attrs.items()), text, children, tail]
    return project(value)


# Stage 24 original V4 fingerprint was computed on Linux only after its raw
# SHA256 matched the immutable baseline. Equality under V4 proves equality under
# the narrower V5 contract; this is not a current-source self-approval.
VERIFIED_V4_BRIDGES = {'eeff994d6454abf8d1fdce9a1329ad45fb6245bdad6e18baf608ac16c0291f0e': '9d2ae2bfa41c901661d65b598e268e671d1f532b357dfa1c1b4059d91dfad572'}


# A legacy record retains its complete V1 contract hash. Reconstruct only the
# documented old background links; trust the result ONLY if that full hash
# matches. This cannot authorize a prop, scene, wiring or unknown-field edit.
LEGACY_BACKGROUND_LINKS = {
    '5e632dd68b6928f9acb0572d531813856c0652b5391da754331254ba253e4c60': {
        'Who House': r'G:\Shared drives\Display Folders\07-Whoville-WV\PreviewBackground\Show Background Stage 07 WhoHouse Mt Crumpet.png',
    },
    'eeff994d6454abf8d1fdce9a1329ad45fb6245bdad6e18baf608ac16c0291f0e': {
        'BurceTheSpruce': r'G:\Shared drives\Display Folders\24-Traditional Christmas-TC\Bruce the Spruce\Bruce The Spruce-background.jpg',
        '24-FryingSanta': r'G:\Shared drives\Display Folders\24-Traditional Christmas-TC\FryingSanta\PreviewBackground\FryingSantaStage.jpg',
        '24-SnowFamily and 10YrStocking': r'G:\Shared drives\Display Folders\24-Traditional Christmas-TC\Snow Family\PreviewBackground\Snowman Family.jpg',
    },
}


def recover_legacy_background_contract(baseline, root, links=None):
    from copy import deepcopy
    from itertools import product
    links = LEGACY_BACKGROUND_LINKS.get(baseline['sha256']) if links is None else links
    if not links:
        return None
    scenes = {node.get('Name'): node for node in root.iter('Scene')}
    if any(name not in scenes for name in links):
        return None
    # LOR exports use either single or doubled backslashes in BackgroundFile.
    for doubled in product((False, True), repeat=len(links)):
        candidate = deepcopy(root)
        nodes = {node.get('Name'): node for node in candidate.iter('Scene')}
        for (name, path), double in zip(links.items(), doubled):
            nodes[name].set('BackgroundFile', path.replace(chr(92), chr(92)*2) if double else path)
        if digest(contract_node(candidate)) == baseline['contract_sha256']:
            return dict(sequencing_contract_sha256=digest(sequencing_contract_node(candidate)),
                        proof='EXACT_LEGACY_CONTRACT_MATCH', legacy_contract_tree=contract_node(candidate))
    return None


def same_database_contract(baseline, current):
    if baseline['contract_sha256'] == current['contract_sha256']: return True
    anchor = (baseline.get('sequencing_contract_sha256') if baseline.get('comparison_policy') == COMPARISON_POLICY else None) or LEGACY_SEQUENCING_ANCHORS.get(baseline['sha256'])
    return bool(anchor and anchor == current['sequencing_contract_sha256'])


def capture_backgrounds(root):
    """Check every reference; retain scene ownership even for a shared bad path."""
    result, problems = {}, []
    parents = {child: parent for parent in root.iter() for child in parent}
    for node in root.iter():
        raw = node.get('BackgroundFile', '').strip()
        if not raw:
            continue
        owner = node
        while owner is not root and owner.tag != 'Scene':
            owner = parents[owner]
        scene = owner.get('Name', '(unnamed)') if owner.tag == 'Scene' else '(preview background)'
        # Validate one reference at a time so one failure cannot hide later ones.
        probe = ET.Element('PreviewClass', EmbedBackgrounds=root.get('EmbedBackgrounds', 'False'), BackgroundFile=raw)
        try:
            for asset in _capture_backgrounds(probe):
                result[asset['path'].casefold()] = asset
        except ValueError as error:
            problems.append('Scene: ' + scene + '\nImage: ' + raw + '\nReason: ' + str(error))
    if str(root.get('EmbedBackgrounds', 'False')).lower() != 'false' and not problems:
        problems.append('Scene: (preview)\nImage: (embedded)\nReason: Embedded preview backgrounds are not permitted; use external file links')
    if problems:
        raise ValueError('\n\n'.join(str(number) + '. ' + problem for number, problem in enumerate(problems, 1)))
    return sorted(result.values(), key=lambda asset: asset['path'].casefold())


def _capture_backgrounds(root):
    from pathlib import PureWindowsPath
    if str(root.get('EmbedBackgrounds', 'False')).lower() != 'false':
        raise ValueError('Embedded preview backgrounds are not permitted; use external file links')
    result = {}
    for node in root.iter():
        raw = node.get('BackgroundFile', '').strip()
        if not raw: continue
        path = PureWindowsPath(raw)
        if (path.drive.upper() != 'G:' or not path.is_absolute() or '..' in path.parts
                or len(path.parts) < 4 or tuple(p.casefold() for p in path.parts[1:3]) != ('shared drives','display folders')
                or ':' in str(path)[2:] or path.suffix.lower() not in {'.png','.jpg','.jpeg','.bmp','.gif'}):
            raise ValueError('Background must be an external image under G:\\Shared drives\\Display Folders: ' + raw)
        canonical_path = str(path)
        if canonical_path.casefold() in result: continue
        digestor = hashlib.sha256(); size = 0
        try:
            with Path(canonical_path).open('rb') as stream:
                for block in iter(lambda:stream.read(1024*1024), b''):
                    size += len(block)
                    if size > 64*1024*1024: raise ValueError('Background image exceeds 64MB: ' + canonical_path)
                    digestor.update(block)
        except OSError as error:
            code = getattr(error, 'winerror', None)
            reason = ('File or folder not found' if isinstance(error, FileNotFoundError) else
                      'Access denied' if isinstance(error, PermissionError) else 'File read failed')
            diagnostic = error.strerror or type(error).__name__
            raise ValueError(reason + '; ' + diagnostic + '; Windows error=' + str(code) + '; errno=' + str(error.errno)) from error
        if not size: raise ValueError('Background image is empty: ' + canonical_path)
        result[canonical_path.casefold()] = dict(path=canonical_path,sha256=digestor.hexdigest(),bytes=size)
    return sorted(result.values(),key=lambda a:a['path'].casefold())


def background_changes(previous, current):
    if previous is None:
        return [dict(action='VERIFY_LINKED_BACKGROUND',path=a['path']) for a in current]
    old={a['path'].casefold():a for a in previous};new={a['path'].casefold():a for a in current}
    result=[]
    for key in sorted(old.keys() | new.keys()):
        a,b=old.get(key),new.get(key)
        if a==b:continue
        result.append(dict(action='BACKGROUND_REMOVED' if b is None else 'BACKGROUND_ADDED' if a is None else 'BACKGROUND_IMAGE_UPDATED',path=(b or a)['path']))
    return result


def capture(folder, *, include_backgrounds=True):
    files = []
    background_errors = []
    paths = sorted(folder.glob('*.lorprev'), key=lambda p: p.name.casefold())
    if not paths:
        raise ValueError('Master preview set is empty')
    names, ids = set(), set()
    for path in paths:
        if path.is_symlink() or not path.is_file():
            raise ValueError('Master source must contain regular preview files')
        raw = path.read_bytes()
        if len(raw) > 16 * 1024 * 1024 or re.search(br'<!\s*(DOCTYPE|ENTITY)', raw, re.I):
            raise ValueError('Unsupported preview size or XML declarations')
        root = ET.fromstring(raw)
        identity = root.get('id', '')
        if root.tag != 'PreviewClass' or not identity or not root.get('Name') or not re.fullmatch(r'[0-9]+', root.get('Revision', '')):
            raise ValueError('Invalid preview identity/name/Revision')
        if identity in ids or path.name.casefold() in names:
            raise ValueError('Duplicate preview identity or filename')
        ids.add(identity); names.add(path.name.casefold())
        props = list(root.iter('PropClass'))
        prop_ids = [p.get('id') for p in props]
        if any(not p for p in prop_ids) or len(set(prop_ids)) != len(prop_ids):
            raise ValueError('Missing or duplicate prop identity')
        for prop in props:
            if not (prop.get('Name') or '').strip():
                raise ValueError('Channel Name must not be blank')
            if prop.get('MasterDimmable') not in (None, 'True', 'False'):
                raise ValueError('Unsupported master-dimming flag')
        metadata = {p.get('id'): {k: p.get(k) for k in ('Name', 'MasterDimmable')} for p in root if p.tag == 'PropClass'}
        try:
            assets = capture_backgrounds(root) if include_backgrounds else None
        except ValueError as error:
            background_errors.append('Preview file: ' + path.name + '\nPreview: ' + root.get('Name', '') + '\n' + str(error))
            assets = []
        files.append(dict(filename=path.name, preview_id=identity, name=root.get('Name'), revision=root.get('Revision'),
                          sha256=hashlib.sha256(raw).hexdigest(), contract_sha256=digest(contract_node(root)),
                          metadata=metadata, sequencing_contract_sha256=digest(sequencing_contract_node(root)), comparison_policy=COMPARISON_POLICY, previous_policy_contract_sha256=digest(sequencing_contract_node_v4(root)), background_assets=assets))
    if background_errors:
        raise ValueError('Background files could not be read on PRINT-SERVER under Print Service. Publication blocked. Check the errors below before changing any preview links.\n\n' + '\n\n'.join(background_errors))
    return files


# Recover only from the exact reconciled SQLite bytes. Presentation fields
# below are already excluded by the catalog policy; every other stored field
# remains part of the recovery proof, including controller/network/channel IDs.
RECOVERY_TABLES = {
    'previews': {'Name', 'Revision', 'Brightness', 'BackgroundFile', 'SourceFilename'},
    'scenes': {'BackgroundFile', 'HScroll', 'VScroll', 'Zoom'},
    'props': {'MasterDimmable'}, 'subProps': {'MasterDimmable'}, 'dmxChannels': set(),
    'scene_lor_props': set(),
}


def prove_database_rows(baseline_path, candidate_path):
    def rows(path):
        with closing(sqlite3.connect(Path(path).resolve().as_uri() + '?mode=ro', uri=True)) as db:
            result = {}
            for table, excluded in RECOVERY_TABLES.items():
                schema = list(db.execute('PRAGMA table_info("' + table + '")'))
                if not schema:
                    raise ValueError('Recovery table missing: ' + table)
                columns = [r[1] for r in schema if r[1] not in excluded and not
                           (r[1].startswith('Int') and r[2].upper() == 'INTEGER' and r[5])]
                # Channel Name is presentation only when a Display Comment supplies
                # identity. Retain Name when the parser uses it as fallback.
                expressions = []
                for c in columns:
                    if table in {'props', 'subProps'} and c == 'Name' and 'LORComment' in columns:
                        expressions.append("CASE WHEN trim(coalesce(LORComment,'')) <> '' THEN NULL ELSE Name END")
                    else:
                        expressions.append('"' + c.replace('"', '""') + '"')
                quoted = ','.join(expressions)
                result[table] = (columns, Counter(db.execute('SELECT ' + quoted + ' FROM "' + table + '"')))
            return result
    old, new = rows(baseline_path), rows(candidate_path)
    changed = [t for t in RECOVERY_TABLES if old[t] != new[t]]
    if changed:
        raise ValueError('Catalog baseline recovery found database differences in: ' + ', '.join(changed) +
                         '. Retained evidence is unchanged; database review is required.')
    return sorted(RECOVERY_TABLES)


class Catalog:
    def __init__(self, root, folder, version, *, recovery_db=None, parser_path=None, parser_run=None, parser_activity=None):
        self.root, self.folder, self.version = Path(root), Path(folder), version
        self.recovery_db = Path(recovery_db) if recovery_db else None
        self.parser_path = Path(parser_path) if parser_path else None
        self.parser_run = parser_run or {}
        self.parser_activity = parser_activity or {}
        if not self.root.is_absolute() or not self.folder.is_absolute() or self.folder.name != 'Database Previews V' + version:
            raise ValueError('Catalog requires absolute local evidence and exact approved version folder')

    def read(self, path):
        record = json.loads(path.read_text(encoding='utf-8'))
        stored = record.pop('record_sha256', None)
        if stored != digest(record):
            raise ValueError('Catalog evidence integrity failure')
        return record

    def write(self, path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name('.' + uuid.uuid4().hex + '.writing')
        try:
            with temporary.open('xb') as output:
                output.write(canonical(dict(value, record_sha256=digest(value))))
                output.flush(); os.fsync(output.fileno())
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)

    def context(self, accepted):
        if (accepted.get('schema_version') != 1 or accepted.get('status') != 'COMPLETED'
                or accepted.get('validation') != 'PASSED' or accepted.get('lor_version') != self.version
                or accepted.get('source_folder') != str(self.folder)
                or not re.fullmatch('[a-f0-9]{64}', accepted.get('evidence_id', ''))):
            raise ValueError('Catalog requires current completed database source and exact approved runner folder')
        return self.root / accepted['evidence_id']

    def scan(self):
        first, second = capture(self.folder), capture(self.folder)
        if first != second:
            raise ValueError('Master files changed during capture; export completely and retry')
        return first

    def parser_validation(self, files):
        """Distribution authority is passed parser output, never ingest approval.

        State comes from the authenticated runner, not request-supplied fields.
        Recheck the SQLite and current export bytes on both review and publish.
        """
        run, activity = self.parser_run, self.parser_activity
        if not run or not activity:
            return None
        if (run.get('status') != 'COMPLETE' or run.get('validation_status') != 'PASSED'
                or activity.get('status') != 'PASSED' or activity.get('target') != 'current'
                or not activity.get('activity_id')
                or run.get('parser_activity_id') != activity['activity_id']
                or run.get('source_lor_version') != self.version
                or activity.get('source_lor_version') != self.version
                or str(activity.get('source_preview_folder')) != str(self.folder)
                or run.get('source_manifest_sha256') != source_digest(files)):
            return None
        sqlite_hash = run.get('sqlite_sha256', '')
        if (not re.fullmatch('[a-f0-9]{64}', sqlite_hash)
                or not self.recovery_db or not self.parser_path
                or Path(str(run.get('sqlite_path', ''))).resolve() != self.recovery_db.resolve()
                or (activity.get('result') or {}).get('sqlite_sha256') != sqlite_hash):
            return None
        if hashlib.sha256(self.recovery_db.read_bytes()).hexdigest() != sqlite_hash:
            raise ValueError('Parser SQLite changed after validation; run parser again. Ingest is not required.')
        parser_hash = hashlib.sha256(self.parser_path.read_bytes()).hexdigest()
        with closing(sqlite3.connect(self.recovery_db.resolve().as_uri() + '?mode=ro', uri=True)) as db:
            rows = db.execute('SELECT ParserSHA256,SourceManifestSHA256,SourceLORVersion,ValidationStatus,Status,RunMode,SourcePreviewFolder FROM parser_run').fetchall()
        expected = (parser_hash, source_digest(files), self.version, 'PASSED', 'COMPLETE', 'PRODUCTION', str(self.folder))
        if rows != [expected]:
            raise ValueError('Parser provenance does not match current exports; run parser again. Ingest is not required.')
        return dict(authority='PASSED_PARSER_V1', activity_id=activity['activity_id'],
                    source_manifest_sha256=source_digest(files), sqlite_sha256=sqlite_hash,
                    parser_sha256=parser_hash, lor_version=self.version)

    def baseline(self, accepted, actor):
        directory = self.context(accepted)
        path = directory / 'baseline.json'
        if path.exists():
            baseline = self.read(path)
            if baseline['accepted'] != accepted or baseline['policy'] != POLICY:
                raise ValueError('Catalog baseline/source mismatch')
            return baseline
        files = self.scan()
        recovery = None
        parser_validation = self.parser_validation(files)
        if not parser_validation and source_digest(files) != accepted['source_manifest_sha256']:
            snapshot = self.root / 'database-snapshots' / (accepted['source_sqlite_sha256'] + '.json')
            if snapshot.exists():
                retained = self.read(snapshot)
                if (retained['source_manifest_sha256'] != accepted['source_manifest_sha256']
                        or retained['sqlite_sha256'] != accepted['source_sqlite_sha256']):
                    raise ValueError('Retained database snapshot binding mismatch')
                files = retained['files']
            elif self.recovery_db and self.parser_path:
                files, recovery = self.recover_database_baseline(accepted, files)
            else:
                raise ValueError('Initial catalog registration requires unchanged accepted master bytes. Do not regenerate evidence from unaccepted files.')
        actual = sorted((f['filename'], f['preview_id'], f['name'], f['revision']) for f in files)
        expected = sorted((f['filename'], f['preview_id'], f['name'], f['revision']) for f in accepted['previews'])
        if not recovery and not parser_validation and actual != expected:
            raise ValueError('Initial master inventory does not match frozen completed source')
        value = dict(policy=POLICY, accepted=accepted, files=files, registered_by=actor,
                     registered_at=datetime.now(timezone.utc).isoformat())
        if recovery:
            value['recovery_proof'] = recovery
        if parser_validation:
            value['registration_authority'] = 'PASSED_PARSER_V1'
            value['parser_validation'] = parser_validation
        self.write(path, value)
        return value

    def retain_database_snapshot(self, sqlite_path, expected_sqlite, expected_source):
        if hashlib.sha256(Path(sqlite_path).read_bytes()).hexdigest() != expected_sqlite:
            raise ValueError('SQLite changed before catalog evidence capture')
        files = capture(self.folder, include_backgrounds=False)
        if files != capture(self.folder, include_backgrounds=False):
            raise ValueError('Master changed during database evidence capture')
        if source_digest(files) != expected_source:
            raise ValueError('Master changed after parsing; rerun parser before ingest')
        path = self.root / 'database-snapshots' / (expected_sqlite + '.json')
        value = dict(sqlite_sha256=expected_sqlite, source_manifest_sha256=expected_source, files=files)
        if path.exists():
            if self.read(path) != value:
                raise ValueError('Retained database snapshot differs')
        else:
            self.write(path, value)
        self.retain_preview_archive(files, expected_source, expected_sqlite)

    def retain_preview_archive(self, files, source_hash, sqlite_hash):
        """Retain exact external-link XML bytes, never embedded image copies."""
        if (not re.fullmatch('[a-f0-9]{64}', source_hash)
                or not re.fullmatch('[a-f0-9]{64}', sqlite_hash)
                or source_digest(files) != source_hash):
            raise ValueError('Invalid preview history source binding')
        directory = self.root / 'preview-history'
        archive = directory / 'archives' / (source_hash + '.zip')
        archive.parent.mkdir(parents=True, exist_ok=True)
        expected = {f['filename']: f['sha256'] for f in files}
        def validate(path):
            with zipfile.ZipFile(path) as saved:
                if len(saved.namelist()) != len(expected) or set(saved.namelist()) != set(expected):
                    raise ValueError('Preview history inventory mismatch')
                for name, sha in expected.items():
                    if Path(name).name != name or '/' in name or '\\' in name or ':' in name:
                        raise ValueError('Unsafe preview history filename')
                    if hashlib.sha256(saved.read(name)).hexdigest() != sha:
                        raise ValueError('Preview history byte verification failed')
        if not archive.exists():
            temporary = archive.with_name('.' + uuid.uuid4().hex + '.writing')
            try:
                with temporary.open('xb') as stream:
                    with zipfile.ZipFile(stream, 'w', compression=zipfile.ZIP_DEFLATED) as saved:
                        for name in sorted(expected, key=str.casefold):
                            raw = (self.folder / name).read_bytes()
                            if hashlib.sha256(raw).hexdigest() != expected[name]:
                                raise ValueError('Master changed before preview history capture')
                            info = zipfile.ZipInfo(name, date_time=(1980,1,1,0,0,0))
                            info.compress_type = zipfile.ZIP_DEFLATED
                            saved.writestr(info, raw)
                    stream.flush(); os.fsync(stream.fileno())
                validate(temporary)
                if source_digest(capture(self.folder, include_backgrounds=False)) != source_hash:
                    raise ValueError('Master changed during preview history capture')
                os.replace(temporary, archive)
            finally:
                temporary.unlink(missing_ok=True)
        validate(archive)
        record = dict(source_manifest_sha256=source_hash, sqlite_sha256=sqlite_hash,
                      lor_version=self.version, source_folder=str(self.folder),
                      archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
                      files=[dict(filename=f['filename'], sha256=f['sha256'], preview_id=f['preview_id'], revision=f['revision']) for f in files])
        path = directory / 'records' / (sqlite_hash + '.json')
        if path.exists():
            prior = self.read(path)
            record['captured_at'] = prior.get('captured_at')
            if prior != record:
                raise ValueError('Preview history record differs')
        else:
            record['captured_at'] = datetime.now(timezone.utc).isoformat()
            self.write(path, record)
        return record

    def recover_database_baseline(self, accepted, files):
        expected = accepted['source_sqlite_sha256']
        if hashlib.sha256(self.recovery_db.read_bytes()).hexdigest() != expected:
            raise ValueError('Recovery requires the exact reconciled SQLite snapshot')
        with closing(sqlite3.connect(self.recovery_db.resolve().as_uri() + '?mode=ro', uri=True)) as db:
            row = db.execute('SELECT ParserSHA256, SourceManifestSHA256, SourceLORVersion, ValidationStatus, Status FROM parser_run').fetchall()
        parser_hash = hashlib.sha256(self.parser_path.read_bytes()).hexdigest()
        if len(row) != 1 or row[0][:4] != (parser_hash, accepted['source_manifest_sha256'], self.version, 'PASSED') or row[0][4] != 'COMPLETE':
            raise ValueError('Reconciled SQLite/parser provenance mismatch')
        self.root.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='catalog-recovery-', dir=self.root) as temporary:
            work = Path(temporary); source = work / 'previews'; source.mkdir()
            for item in files:
                raw = (self.folder / item['filename']).read_bytes()
                if hashlib.sha256(raw).hexdigest() != item['sha256']:
                    raise ValueError('Master changed during catalog recovery')
                (source / item['filename']).write_bytes(raw)
            output = work / 'candidate.db'
            result = subprocess.run([sys.executable, str(self.parser_path), '--db-file', str(output),
                '--preview-folder', str(source), '--reports-folder', str(work / 'reports'),
                '--run-mode', 'TEST', '--source-lor-version', self.version, '--non-interactive'],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=900)
            if result.returncode or not output.is_file():
                raise ValueError('Disposable catalog recovery parse failed; no baseline registered. ' + result.stdout.decode('utf-8', errors='replace')[-1500:])
            verified = prove_database_rows(self.recovery_db, output)
        if (hashlib.sha256(self.recovery_db.read_bytes()).hexdigest() != expected
                or hashlib.sha256(self.parser_path.read_bytes()).hexdigest() != parser_hash
                or self.scan() != files):
            raise ValueError('Source changed during catalog recovery')
        return files, dict(method='SAME_PARSER_SQLITE_PROJECTION_V1', sqlite_sha256=expected,
                           parser_sha256=parser_hash, verified_tables=verified,
                           current_manifest_sha256=source_digest(files))

    def comparison_baseline(self, directory, baseline_files, current):
        # Append-only policy anchors supplement legacy hash-only evidence. Only
        # exact old bytes or an independently reviewed export can establish one.
        result = {}
        for identity, original in baseline_files.items():
            base = dict(original)
            if base.get('comparison_policy') != COMPARISON_POLICY or not base.get('sequencing_contract_sha256'):
                base.pop('sequencing_contract_sha256', None)
                binding = dict(comparison_policy=COMPARISON_POLICY, preview_id=identity,
                               baseline_sha256=base['sha256'])
                path = directory / 'comparison-anchors' / (digest(binding) + '.json')
                if path.exists():
                    record = self.read(path)
                    if any(record.get(k) != v for k,v in binding.items()):
                        raise ValueError('Sequencing comparison anchor binding mismatch')
                    base['sequencing_contract_sha256'] = record['sequencing_contract_sha256']
                else:
                    fingerprint = LEGACY_SEQUENCING_ANCHORS.get(base['sha256'])
                    live = current.get(identity)
                    if live and live['sha256'] == base['sha256']:
                        fingerprint = live['sequencing_contract_sha256']
                    if not fingerprint and live and VERIFIED_V4_BRIDGES.get(base['sha256']) == live.get('previous_policy_contract_sha256'):
                        fingerprint = live['sequencing_contract_sha256']
                    recovered = None
                    if not fingerprint and live and base['sha256'] in LEGACY_BACKGROUND_LINKS:
                        # The two-pass scan already bound these current bytes.
                        source = self.folder / live['filename']
                        raw = source.read_bytes()
                        if hashlib.sha256(raw).hexdigest() != live['sha256']:
                            raise ValueError('Master changed during legacy evidence recovery')
                        recovered = recover_legacy_background_contract(base, ET.fromstring(raw))
                        if recovered:
                            fingerprint = recovered['sequencing_contract_sha256']
                    if fingerprint:
                        self.write(path, dict(binding, sequencing_contract_sha256=fingerprint, **({k:v for k,v in recovered.items() if k != 'sequencing_contract_sha256'} if recovered else {})))
                        base['sequencing_contract_sha256'] = fingerprint
            if base.get('sequencing_contract_sha256'): base['comparison_policy'] = COMPARISON_POLICY
            result[identity] = base
        return result

    def review(self, accepted, actor):
        baseline = self.baseline(accepted, actor)
        files = self.scan()
        directory = self.context(accepted)
        parser_validation = self.parser_validation(files)
        if baseline.get('registration_authority') == 'PASSED_PARSER_V1' and not parser_validation:
            raise ValueError('Run the parser successfully for the current exports before catalog approval. Ingest is not required.')
        pointer = directory / 'current.json'
        parent = self.parent(directory)
        baseline_files = {f['preview_id']: f for f in baseline['files']}
        old = baseline_files
        if parent:
            published = self.read(directory / 'publications' / (parent + '.json'))
            old_review = self.read(directory / 'reviews' / (published['review_id'] + '.json'))
            old = {f['preview_id']: f for f in old_review['files']}
        new = {f['preview_id']: f for f in files}
        baseline_files = self.comparison_baseline(directory, baseline_files, new)
        protected = set(baseline_files) != set(new)
        changes = []
        for name in sorted(set(old) | set(new)):
            a, b = old.get(name), new.get(name)
            if a and b and a['sha256'] == b['sha256'] and a['filename'] == b['filename'] and a.get('background_assets', []) == b.get('background_assets', []):
                continue
            base = baseline_files.get(name)
            requires_review = not base or not b or not same_database_contract(base, b)
            comparison_status = ('PREVIEW_IDENTITY_CHANGED' if not base or not b else
                                 'DATABASE_CONTRACT_UNCHANGED' if not requires_review else
                                 'BASELINE_EVIDENCE_MISSING' if not base.get('sequencing_contract_sha256') and base['sha256'] not in LEGACY_SEQUENCING_ANCHORS else
                                 'PROTECTED_CONTENT_DIFFERS')
            protected |= requires_review
            details = []
            if a and b:
                for prop in sorted(set(a['metadata']) & set(b['metadata'])):
                    for field in ('Name', 'MasterDimmable'):
                        before, after = a['metadata'][prop][field], b['metadata'][prop][field]
                        if before != after:
                            details.append(dict(prop_id=prop, field=field, before=before, after=after))
            asset_notes = background_changes(a.get('background_assets') if a else None, b.get('background_assets') if b else [])
            changes.append(dict(comparison_status=comparison_status, image_registration_only=bool(a and b and a['sha256'] == b['sha256'] and a['filename'] == b['filename'] and a.get('background_assets') is None), background_changes=asset_notes, filename=b['filename'] if b else a['filename'], preview_id=name,
                                previous_filename=a['filename'] if a else None, previous_name=a['name'] if a else None,
                                name=b['name'] if b else None, database_contract_review_required=bool(requires_review),
                                before_sha256=a['sha256'] if a else None, after_sha256=b['sha256'] if b else None,
                                metadata_changes=details))
        if parser_validation:
            # The parser independently validated identity, source and output.
            # Keep the database comparison as information, not an ingest gate.
            for change in changes:
                change['database_contract_changed'] = change['database_contract_review_required']
                change['database_contract_review_required'] = False
                change['comparison_status'] = 'PARSER_VALIDATED'
            protected = False
        proposal = dict(policy=POLICY, comparison_policy=COMPARISON_POLICY, baseline_evidence_id=accepted['evidence_id'], parent_publication_id=parent,
                        source_manifest_sha256=source_digest(files), files=files, changes=changes,
                        database_contract_review_required=bool(protected), reviewed_by=actor)
        if parser_validation:
            proposal['parser_validation'] = parser_validation
        proposal_id = digest(proposal)
        self.write(directory / 'reviews' / (proposal_id + '.json'), proposal)
        return dict(review_id=proposal_id, minimum_updater_version='1.1.2', changes=changes, source_folder=str(self.folder), catalog_evidence_folder=str(self.root), database_contract_review_required=bool(protected),
                    can_publish=not protected and (parent is None or bool(changes)), master_digest=proposal['source_manifest_sha256'],
                    baseline_run_id=accepted['run_id'], parent_publication_id=parent, parser_validation=parser_validation)

    def publish(self, accepted, actor, review_id):
        if not re.fullmatch('[a-f0-9]{64}', str(review_id)):
            raise ValueError('Invalid catalog review identity')
        directory = self.context(accepted)
        review = self.read(directory / 'reviews' / (review_id + '.json'))
        if review['reviewed_by'] != actor:
            raise ValueError('This catalog review belongs to another publisher')
        fresh = self.review(accepted, actor)
        if fresh['review_id'] != review_id or not fresh['can_publish']:
            raise ValueError('Catalog review is stale or requires database-contract review; nothing published')
        document = dict(accepted, schema_version=3, status='ACCEPTED', acceptance_kind='PREVIEW_CATALOG',
                        database_baseline_evidence_id=accepted['evidence_id'], catalog_policy=POLICY,
                        source_manifest_sha256=review['source_manifest_sha256'],
                        background_assets=sorted({asset['path'].casefold(): asset for f in review['files'] for asset in f['background_assets']}.values(), key=lambda x:x['path'].casefold()),
                        minimum_updater_version='1.1.2',
                        previews=[{k: f[k] for k in ('filename', 'preview_id', 'name', 'revision')} for f in review['files']],
                        published_by=actor, published_at=datetime.now(timezone.utc).isoformat(),
                        parent_publication_id=review['parent_publication_id'])
        if review.get('parser_validation'):
            document['distribution_authority'] = 'PASSED_PARSER_V1'
            document['parser_validation'] = review['parser_validation']
        document.pop('evidence_id')
        document['evidence_id'] = digest(document)
        publication_id = document['evidence_id']
        self.write(directory / 'publications' / (publication_id + '.json'), dict(document=document, review_id=review_id))
        # One atomic pointer is the only publication commit point. No master write.
        self.write(directory / 'current.json', dict(publication_id=publication_id))
        return document

    def parent(self, directory):
        pointer = directory / 'current.json'
        if not pointer.exists():
            if any((directory / 'publications').glob('*.json')):
                raise ValueError('Published catalog pointer is missing; do not fall back to older source')
            return None
        publication_id = self.read(pointer)['publication_id']
        if not re.fullmatch('[a-f0-9]{64}', publication_id):
            raise ValueError('Invalid catalog pointer')
        return publication_id

    def current(self, accepted):
        directory = self.context(accepted)
        publication_id = self.parent(directory)
        if publication_id is None:
            return accepted
        document = self.read(directory / 'publications' / (publication_id + '.json'))['document']
        unsigned = dict(document); unsigned.pop('evidence_id', None)
        if (digest(unsigned) != publication_id or document['database_baseline_evidence_id'] != accepted['evidence_id']):
            raise ValueError('Published catalog does not match current database baseline')
        return document


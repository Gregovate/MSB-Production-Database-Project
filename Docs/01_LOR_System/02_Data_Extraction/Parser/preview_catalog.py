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
from datetime import datetime, timezone
from pathlib import Path
import xml.etree.ElementTree as ET

POLICY = 'MSB_PREVIEW_CATALOG_V1'


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode()


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def source_digest(files):
    # Exact Python parser captured-byte algorithm, not PC semantic comparison.
    return digest(sorted([dict(filename=f['filename'], identity='PreviewClass:' + f['preview_id'].casefold(), sha256=f['sha256'])
                          for f in files], key=lambda f: (f['identity'], f['filename'].casefold())))


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


def capture(folder):
    files = []
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
        files.append(dict(filename=path.name, preview_id=identity, name=root.get('Name'), revision=root.get('Revision'),
                          sha256=hashlib.sha256(raw).hexdigest(), contract_sha256=digest(contract_node(root)),
                          metadata=metadata))
    return files


class Catalog:
    def __init__(self, root, folder, version):
        self.root, self.folder, self.version = Path(root), Path(folder), version
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

    def baseline(self, accepted, actor):
        directory = self.context(accepted)
        path = directory / 'baseline.json'
        if path.exists():
            baseline = self.read(path)
            if baseline['accepted'] != accepted or baseline['policy'] != POLICY:
                raise ValueError('Catalog baseline/source mismatch')
            return baseline
        files = self.scan()
        if source_digest(files) != accepted['source_manifest_sha256']:
            raise ValueError('Initial catalog registration requires unchanged accepted master bytes. Do not regenerate evidence from unaccepted files.')
        actual = sorted((f['filename'], f['preview_id'], f['name'], f['revision']) for f in files)
        expected = sorted((f['filename'], f['preview_id'], f['name'], f['revision']) for f in accepted['previews'])
        if actual != expected:
            raise ValueError('Initial master inventory does not match frozen completed source')
        value = dict(policy=POLICY, accepted=accepted, files=files, registered_by=actor,
                     registered_at=datetime.now(timezone.utc).isoformat())
        self.write(path, value)
        return value

    def review(self, accepted, actor):
        baseline = self.baseline(accepted, actor)
        files = self.scan()
        directory = self.context(accepted)
        pointer = directory / 'current.json'
        parent = self.parent(directory)
        baseline_files = {f['filename']: f for f in baseline['files']}
        old = baseline_files
        if parent:
            published = self.read(directory / 'publications' / (parent + '.json'))
            old_review = self.read(directory / 'reviews' / (published['review_id'] + '.json'))
            old = {f['filename']: f for f in old_review['files']}
        new = {f['filename']: f for f in files}
        protected = set(baseline_files) != set(new)
        changes = []
        for name in sorted(set(old) | set(new)):
            a, b = old.get(name), new.get(name)
            if a == b:
                continue
            base = baseline_files.get(name)
            requires_review = not base or not b or base['contract_sha256'] != b['contract_sha256']
            protected |= requires_review
            details = []
            if a and b:
                for prop in sorted(set(a['metadata']) & set(b['metadata'])):
                    for field in ('Name', 'MasterDimmable'):
                        before, after = a['metadata'][prop][field], b['metadata'][prop][field]
                        if before != after:
                            details.append(dict(prop_id=prop, field=field, before=before, after=after))
            changes.append(dict(filename=name, database_contract_review_required=bool(requires_review),
                                before_sha256=a['sha256'] if a else None, after_sha256=b['sha256'] if b else None,
                                metadata_changes=details))
        proposal = dict(policy=POLICY, baseline_evidence_id=accepted['evidence_id'], parent_publication_id=parent,
                        source_manifest_sha256=source_digest(files), files=files, changes=changes,
                        database_contract_review_required=bool(protected), reviewed_by=actor)
        proposal_id = digest(proposal)
        self.write(directory / 'reviews' / (proposal_id + '.json'), proposal)
        return dict(review_id=proposal_id, changes=changes, database_contract_review_required=bool(protected),
                    can_publish=not protected, master_digest=proposal['source_manifest_sha256'],
                    baseline_run_id=accepted['run_id'], parent_publication_id=parent)

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
        document = dict(accepted, schema_version=2, status='ACCEPTED', acceptance_kind='PREVIEW_CATALOG',
                        database_baseline_evidence_id=accepted['evidence_id'], catalog_policy=POLICY,
                        source_manifest_sha256=review['source_manifest_sha256'],
                        previews=[{k: f[k] for k in ('filename', 'preview_id', 'name', 'revision')} for f in review['files']],
                        published_by=actor, published_at=datetime.now(timezone.utc).isoformat(),
                        parent_publication_id=review['parent_publication_id'])
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

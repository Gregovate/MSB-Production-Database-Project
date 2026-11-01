"""Read-only proof of the new policy against the registered production baseline.

Never call review/publish: those persist evidence. Only independently bound
legacy contracts or supplied original exports can recover a policy anchor.
"""
import hashlib
import importlib.util
import os
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


def main():
    spec = importlib.util.spec_from_file_location('catalog_candidate', sys.argv[1])
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    evidence = Path(os.environ['LOCALAPPDATA'])/'MSB/LORRunner/preview-catalog/e6b7d2d6928243d1694649498caa31235b9dbbe1667bffd39682dfb35b47ccb7'
    baseline = module.Catalog.read(None, evidence/'baseline.json')
    folder = Path(baseline['accepted']['source_folder'])
    current = {}
    for path in folder.glob('*.lorprev'):
        raw = path.read_bytes()
        if b'<!DOCTYPE' in raw.upper() or b'<!ENTITY' in raw.upper():
            raise ValueError('Unsupported XML declaration')
        root = ET.fromstring(raw)
        identity = root.get('id')
        if not identity or identity in current:
            raise ValueError('Missing or duplicate preview identity')
        current[identity] = (path, raw, root)
    if set(current) != {f['preview_id'] for f in baseline['files']}:
        raise ValueError('Preview identity inventory changed')
    failures = []
    for old in baseline['files']:
        path, raw, root = current[old['preview_id']]
        legacy = module.digest(module.contract_node(root))
        if legacy == old['contract_sha256']:
            continue
        actual = module.digest(module.sequencing_contract_node(root))
        expected = module.LEGACY_SEQUENCING_ANCHORS.get(old['sha256'])
        if not expected and module.VERIFIED_V4_BRIDGES.get(old['sha256']) == module.digest(module.sequencing_contract_node_v4(root)):
            expected = actual
        recovered = None if expected else module.recover_legacy_background_contract(old, root)
        if recovered:
            expected = recovered['sequencing_contract_sha256']
        if expected != actual:
            failures.append(path.name + ': ' + ('protected comparison differs' if expected else 'original comparison evidence unavailable'))
        else:
            print('PASS: ' + path.name + ' — ' + ('exact original legacy contract recovered' if recovered else 'matches independently supplied original under presentation policy'), flush=True)
    if failures:
        raise ValueError('\n'.join(failures))
    print('PASS: all registered preview database contracts proven; read-only, no publication or evidence changes.', flush=True)

if __name__ == '__main__':
    main()

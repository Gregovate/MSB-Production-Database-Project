"""Read-only Run 34 recovery diagnosis; never register, publish or ingest."""
import hashlib
import json
import os
import sqlite3
import sys
import uuid
from collections import defaultdict
from contextlib import closing
from pathlib import Path

REPO=Path(r'C:\MSB_LORRunner')
sys.path.insert(0,str(REPO/'Docs/01_LOR_System/02_Data_Extraction/Parser'))
import preview_catalog as catalog

EXPECTED='3bb9fa7cec12a7e042e9d79f404d23fafc94188f98c51d6515a0b884f4efe313'
DB=Path(r'G:\Shared drives\MSB Database\database\lor_output_v7_scene.db')
FOLDER=Path(r'G:\Shared drives\MSB Database\Database Previews V6.6.12')
KEYS={'props':('PropID',),'subProps':('SubPropID',),'dmxChannels':('PreviewId','PropId','ChannelGridRowNumber'),'scene_lor_props':('PreviewId','PropID'),'scenes':('SceneID',),'previews':('id',)}

def groups(path,table):
    with closing(sqlite3.connect(path.resolve().as_uri()+'?mode=ro',uri=True)) as db:
        db.row_factory=sqlite3.Row
        schema=list(db.execute('PRAGMA table_info("'+table+'")'))
        excluded=catalog.RECOVERY_TABLES[table] | {r[1] for r in schema if r[1].startswith('Int') and r[2].upper()=='INTEGER' and r[5]}
        result=defaultdict(list)
        for row in db.execute('SELECT * FROM "'+table+'"'):
            value={k:row[k] for k in row.keys() if k not in excluded}
            if table in ('props','subProps') and str(value.get('LORComment') or '').strip():value['Name']=None
            key=tuple(row[k] for k in KEYS[table]);result[key].append(value)
        return result

def diagnose(a,b):
    differences=[]
    for table in catalog.RECOVERY_TABLES:
        old,new=groups(a,table),groups(b,table)
        for key in sorted(set(old)|set(new),key=str):
            before=sorted(old.get(key,[]),key=lambda x:json.dumps(x,sort_keys=True))
            after=sorted(new.get(key,[]),key=lambda x:json.dumps(x,sort_keys=True))
            if before==after:continue
            if len(before)==len(after)==1:
                changes={k:{'accepted':before[0].get(k),'current':after[0].get(k)} for k in set(before[0])|set(after[0]) if before[0].get(k)!=after[0].get(k)}
                differences.append(dict(table=table,key=dict(zip(KEYS[table],key)),display=after[0].get('LORComment') or before[0].get('LORComment'),changes=changes))
            else:differences.append(dict(table=table,key=dict(zip(KEYS[table],key)),accepted=before,current=after))
    destination=report/'differences.json'
    destination.write_text(json.dumps(dict(accepted_sqlite_sha256=EXPECTED,differences=differences),indent=2),encoding='utf-8')
    print('Protected rows differing: '+str(len(differences)))
    print(json.dumps(differences[:20],indent=2))
    print('Full report: '+str(destination))
    # Always interrupt before any baseline registration. This is diagnosis only.
    raise ValueError('DIAGNOSTIC COMPLETE: no baseline, publication or database changes made.')

if __name__=='__main__':
    if hashlib.sha256(DB.read_bytes()).hexdigest()!=EXPECTED:
        raise SystemExit('HOLD: production SQLite no longer matches Run 34; no diagnostic parse started')
    with closing(sqlite3.connect(DB.resolve().as_uri()+'?mode=ro',uri=True)) as db:
        row=db.execute('SELECT SourceManifestSHA256,SourceLORVersion FROM parser_run').fetchone()
    report=Path(os.environ['LOCALAPPDATA'])/'MSB/LORRunner'/('catalog-diagnosis-'+uuid.uuid4().hex)
    report.mkdir(parents=True)
    catalog.prove_database_rows=diagnose
    c=catalog.Catalog(report,FOLDER,row[1],recovery_db=DB,parser_path=REPO/'Docs/01_LOR_System/02_Data_Extraction/Parser/parse_props_v7_scene_parser.py')
    try:c.recover_database_baseline(dict(source_sqlite_sha256=EXPECTED,source_manifest_sha256=row[0]),c.scan())
    except ValueError as error:print(str(error))

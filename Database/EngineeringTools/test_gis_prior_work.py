import unittest
from gis_track_reconcile import prior_master_evidence, evidence_label, evidence_summary

class PriorWorkTests(unittest.TestCase):
 def setUp(self):
  self.points=[(43+i*.00002,-87) for i in range(19)]
  self.times=[f'2026-10-14T12:00:{i:02}Z' for i in range(19)]
 def track(self, indexes, name='Edited master', shift=.00001):
  return dict(index=1,name=name,points=[(self.points[i][0]+shift,self.points[i][1]) for i in indexes],times=[self.times[i] for i in indexes])
 def test_renamed_moved_deleted_points_field_case(self):
  e=prior_master_evidence(self.points,self.times,[self.track(range(17),'NET FE-00 to RA-01A')])
  self.assertEqual((e['status'],e['matched']),('likely',17))
  self.assertIn('NET FE-00 to RA-01A',evidence_summary(e))
  self.assertTrue(evidence_label(e).startswith('✓?'))
 def test_split_union_and_shared_endpoint_not_double_counted(self):
  e=prior_master_evidence(self.points,self.times,[self.track(range(10),'First'),self.track(range(9,19),'Second')])
  self.assertEqual((e['status'],e['matched'],len(e['matches'])),('likely',19,2))
 def test_partial_split_leaves_unmatched_visible(self):
  e=prior_master_evidence(self.points,self.times,[self.track(range(7))])
  self.assertEqual(e['status'],'partial');self.assertEqual(e['unmatched_points'],list(range(8,20)))
 def test_duplicate_master_derivatives_do_not_inflate_coverage(self):
  t=self.track(range(7));e=prior_master_evidence(self.points,self.times,[t,t])
  self.assertEqual(e['matched'],7);self.assertEqual(e['status'],'partial')
 def test_reused_times_far_away_not_match(self):
  e=prior_master_evidence(self.points,self.times,[self.track(range(19),shift=1)])
  self.assertEqual(e['status'],'none')
 def test_no_times_geometry_is_only_possible(self):
  e=prior_master_evidence(self.points,[],[self.track(range(19),shift=0)])
  self.assertEqual(e['status'],'possible');self.assertEqual(e['matched'],0)
 def test_parallel_track_is_not_completed(self):
  t=self.track(range(19),shift=.00001);t['times']=[]
  self.assertEqual(prior_master_evidence(self.points,self.times,[t])['status'],'none')
 def test_timezone_equivalence(self):
  t=self.track(range(19));t['times']=[v.replace('T12:','T07:').replace('Z','-05:00') for v in t['times']]
  self.assertEqual(prior_master_evidence(self.points,self.times,[t])['matched'],19)

class ProcessingReceiptTests(unittest.TestCase):
 def test_old_master_receipts_survive_and_partial_is_not_complete(self):
  import tempfile,json
  from pathlib import Path
  from gis_track_reconcile import processing_coverage,mark_processed
  with tempfile.TemporaryDirectory() as folder:
   p=Path(folder)/'Reconciliation'/'old-master';p.mkdir(parents=True)
   (p/'review.json').write_text(json.dumps(dict(schema='msb.gis.track-replacement.v1',source_sha256='source',raw_index=1,vertices=[dict(source_index=i) for i in range(7)])))
   c=processing_coverage(folder)
   self.assertEqual(c[('source',1)],set(range(7)))
   self.assertFalse(set(range(19))<=c[('source',1)])
   mark_processed(folder,'source',1,19,'new-master')
   self.assertEqual(processing_coverage(folder)[('source',1)],set(range(19)))
   self.assertEqual(len(list((Path(folder)/'Processed').glob('*.json'))),1)

if __name__=='__main__':unittest.main()


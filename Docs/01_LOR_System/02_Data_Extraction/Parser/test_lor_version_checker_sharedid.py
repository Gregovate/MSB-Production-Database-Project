"""Only the known optional view field may bypass same-version vocabulary blocking."""
import tempfile
import unittest
from pathlib import Path
import lor_version_checker as checker

class SharedViewIdTests(unittest.TestCase):
    def compare(self, attribute, version='6.6.12', tag='ViewMember'):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);name='preview.lorprev'
            xml='<PreviewClass id="11111111-1111-4111-8111-111111111111" Name="Stage"><PropViews><PropView><%s id="row" %s/></PropView></PropViews></PreviewClass>'
            (p/name).write_text(xml % (tag,''))
            old=checker.build_manifest(p,'6.6.12',name)
            (p/name).write_text(xml % (tag,attribute))
            new=checker.build_manifest(p,version,name)
            return checker.compare_manifests(old,new)
    def test_optional_sharedid_is_retained_as_information(self):
        findings=self.compare('sharedid="abc"')
        self.assertFalse(any(f.severity=='BLOCKING' for f in findings))
        self.assertTrue(any(f.area=='ViewMember' and f.message=='New attribute: sharedid' and f.severity=='INFO' for f in findings))
    def test_unknown_view_attribute_still_blocks(self):
        self.assertTrue(any(f.severity=='BLOCKING' for f in self.compare('unknown="abc"')))
    def test_same_attribute_on_another_element_still_blocks(self):
        self.assertTrue(any(f.severity=='BLOCKING' for f in self.compare('sharedid="abc"',tag='PropView')))
    def test_cross_version_sharedid_still_blocks(self):
        self.assertTrue(any(f.severity=='BLOCKING' for f in self.compare('sharedid="abc"',version='6.7.0')))
if __name__=='__main__':unittest.main()

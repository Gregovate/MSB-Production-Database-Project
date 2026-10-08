"""Real-Git regression for the clean Windows mixed-EOL packaging failure."""
from pathlib import Path
import shutil
import subprocess
import pytest
import setup_88_report_transport as transport
from setup_88_report_read_deploy import git_blob, TRANSPORT_BLOBS


@pytest.fixture
def checkout(tmp_path):
    repo=tmp_path/'checkout'; repo.mkdir()
    def git(*args):
        return subprocess.check_output(['git','-C',str(repo),*args],stderr=subprocess.PIPE)
    git('init','-q'); git('config','user.name','Transport test')
    git('config','user.email','transport@example.invalid')
    git('config','core.autocrlf','false')
    folder=repo/'Setup/Acceptance'; folder.mkdir(parents=True)
    for name in transport.FILES:
        shutil.copyfile(Path(__file__).with_name(name),folder/name)
    git('add','.'); git('commit','-qm','mixed-EOL committed runners')
    return repo,git


def test_clean_windows_filter_mismatch_packages_exact_committed_transport(checkout,tmp_path):
    repo,git=checkout
    git('config','core.autocrlf','true')
    relative='Setup/Acceptance/setup_maintenance_deploy.py'
    assert not git('status','--porcelain')
    tracked=git('rev-parse','HEAD:'+relative).strip()
    filtered=git('hash-object','--path='+relative,str(repo/relative)).strip()
    # This is the original failing guard, reproduced on a CLEAN real checkout.
    assert filtered != tracked
    bundle=tmp_path/'bundle'
    transport.package(repo,bundle)
    for name in transport.FILES:
        assert b'\r' not in (bundle/name).read_bytes()
        compile((bundle/name).read_bytes(),name,'exec')
    for name,blob in TRANSPORT_BLOBS.items():
        assert git_blob((bundle/name).read_bytes())==blob


def test_crlf_working_files_are_accepted_without_changing_packaged_bytes(checkout,tmp_path):
    repo,git=checkout
    before=tmp_path/'before'; after=tmp_path/'after'
    transport.package(repo,before)
    for name in transport.FILES:
        path=repo/'Setup/Acceptance'/name
        path.write_bytes(path.read_bytes().replace(b'\r',b'').replace(b'\n',b'\r\n'))
    transport.package(repo,after)
    assert all((before/name).read_bytes()==(after/name).read_bytes() for name in transport.FILES)


def test_real_content_change_rejected_before_transport(checkout,tmp_path):
    repo,git=checkout
    path=repo/'Setup/Acceptance/setup_maintenance_deploy.py'
    path.write_bytes(path.read_bytes()+b'\nraise RuntimeError("uncommitted change")\n')
    with pytest.raises(RuntimeError,match='local content differs'):
        transport.package(repo,tmp_path/'bundle')


def test_missing_committed_runner_rejected(checkout,tmp_path):
    repo,git=checkout
    git('rm','-q','Setup/Acceptance/setup_88_report_source_only_deploy.py')
    git('commit','-qm','remove required committed runner')
    with pytest.raises(RuntimeError,match='Git transport read failed'):
        transport.package(repo,tmp_path/'bundle')

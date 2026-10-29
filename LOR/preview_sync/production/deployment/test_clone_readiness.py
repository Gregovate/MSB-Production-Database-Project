"""Exercise the actual shell readiness gate with fake Docker process states."""
from pathlib import Path
import subprocess
import unittest


class CloneReadinessTests(unittest.TestCase):
    def test_temporary_server_is_not_accepted_even_when_pg_isready_succeeds(self):
        source=Path(__file__).with_name('review_clone.sh').read_text()
        start=source.index("ready=0\npid1=''")
        end=source.index('docker exec -i "$name" pg_restore',start)
        gate=source[start:end]
        fake='''
name=fixture
counter=$(mktemp)
printf '0' > "$counter"
trap 'rm -f "$counter" "$counter.ready"' EXIT
function sleep() { :; }
function docker() {
    if [[ "$1" == inspect ]]; then echo true
    elif [[ "$3" == sh ]]; then
        count=$(<"$counter"); count=$((count+1)); printf '%s' "$count" > "$counter"
        if [[ $count -lt 3 ]]; then echo bash; else echo postgres; fi
    elif [[ "$3" == pg_isready ]]; then
        printf '%s\n' "$(<"$counter")" >> "$counter.ready"
        return 0
    else return 2; fi
}
'''
        result=subprocess.run(['bash','-c','set -euo pipefail\n'+fake+gate+'\necho ACCEPTED; cat "$counter.ready"'],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout.strip(),'ACCEPTED\n3')
        self.assertIn('ACCEPTED',result.stdout)

    def test_container_failure_blocks_before_restore(self):
        source=Path(__file__).with_name('review_clone.sh').read_text()
        start=source.index("ready=0\npid1=''");end=source.index('docker exec -i "$name" pg_restore',start)
        result=subprocess.run(['bash','-c','set -euo pipefail\nname=fixture\nfunction docker(){ echo false; }\n'+source[start:end]+'\necho RESTORE_WOULD_RUN'],capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertNotIn('RESTORE_WOULD_RUN',result.stdout)

    def test_cleanup_captures_state_and_logs_before_removal(self):
        source=Path(__file__).with_name('review_clone.sh').read_text()
        self.assertLess(source.index('docker logs "$name"'),source.index('docker rm -f "$name"'))
        self.assertIn("--format '{{json .State}}'",source)
        self.assertNotIn('{{json .Config}}',source)

if __name__=='__main__': unittest.main()

"""Reject stale Setup footer dates using the candidate's UI commit history."""
import argparse
from pathlib import Path
import re
import subprocess

UI_PATHS = [' :(glob)Setup/Application/**/*.html',
            ' :(glob)Setup/Application/**/*.css',
            ' :(glob)Setup/Application/**/*.js']
UI_PATHS = [path.strip() for path in UI_PATHS]

def check(repository, target='HEAD'):
    def git(*args):
        return subprocess.check_output(['git', '-C', str(repository), *args], text=True).strip()
    expected = git('log', '-1', '--format=%cs', target, '--', *UI_PATHS)
    source = git('show', target + ':Setup/Application/production.html')
    dates = re.findall(r'Updated\s+(\d{4}-\d{2}-\d{2})', source)
    if not expected or dates != [expected]:
        raise RuntimeError(f'Stale UI footer: expected Updated {expected}, found {dates}')
    return expected

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--repository', default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument('--target', default='HEAD')
    args = parser.parse_args()
    print('PASS: UI date ' + check(args.repository, args.target))


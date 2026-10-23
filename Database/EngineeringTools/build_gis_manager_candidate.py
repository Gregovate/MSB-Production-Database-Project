"""Engineering build of the existing Manager; not a workstation-profile release.

Run with Python 3.13, Pillow 12.0.0 and PyInstaller 6.16.0 on Windows.
The output runs without an end-user Python/Git installation. No installation,
shortcut, registry, shared source or Production mutation is performed here.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def main():
    here = Path(__file__).resolve().parent
    repo = here.parents[1]
    output = Path(sys.argv[1]).resolve()
    output.mkdir(parents=True, exist_ok=True)
    sha = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
    if subprocess.check_output(['git', '-C', str(repo), 'status', '--porcelain', '--untracked-files=no'], text=True).strip():
        raise SystemExit('Commit tracked source before packaging a candidate')
    manifest = dict(source_commit=sha, candidate=True,
                    source_files={p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in here.iterdir() if p.suffix in ('.py', '.pyw', '.json')})
    build_manifest = output / 'source_build.json'
    build_manifest.write_text(json.dumps(manifest, indent=2), encoding='utf8')
    command = [sys.executable, '-m', 'PyInstaller', '--noconfirm', '--onefile', '--windowed',
               '--name', 'MSB-GIS-Manager', '--distpath', str(output),
               '--workpath', str(output / 'work'), '--specpath', str(output),
               '--icon', str(here / 'assets' / 'MSB-Icon-Library-Manager.ico'),
               '--add-data', str(here / 'assets') + ';assets',
               '--add-data', str(here / 'garmin_symbol_registry.json') + ';.',
               '--add-data', str(here / 'site_network_catalog.json') + ';.',
               '--add-data', str(build_manifest) + ';.', str(here / 'icon_library_manager.pyw')]
    subprocess.run(command, check=True)
    executable = output / 'MSB-GIS-Manager.exe'
    manifest['executable_sha256'] = hashlib.sha256(executable.read_bytes()).hexdigest()
    (output / 'candidate-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf8')
    print(executable)


if __name__ == '__main__':
    main()
